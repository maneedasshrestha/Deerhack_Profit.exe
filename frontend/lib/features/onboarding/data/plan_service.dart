import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/curated_plan.dart';
import '../domain/user_profile.dart';

/// Thrown for plan-generation failures the loading screen can surface gracefully.
class PlanServiceException implements Exception {
  PlanServiceException(this.message);
  final String message;
  @override
  String toString() => 'PlanServiceException: $message';
}

/// Turns a learner's condition into a curated study plan.
abstract interface class PlanService {
  Future<CuratedPlan> generate(UserProfile profile);
}

/// Calls the backend proxy, which holds the LLM integration. Mirrors
/// [TurnBasedStudentEngine]: POST strict JSON, parse defensively.
///
///   POST {baseUrl}/v1/plan/generate
///   { exam, examName, daysToExam, targetMarks, totalMarks, dailyHours }
///   200 → { summary, totalWeeks, weeklyHours, focusAreas[], subjectFocus[], milestones[] }
class HttpPlanService implements PlanService {
  HttpPlanService({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<CuratedPlan> generate(UserProfile profile) async {
    final uri = Uri.parse('$baseUrl/v1/plan/generate');
    final body = jsonEncode({
      'exam': profile.examId,
      'examName': profile.examName,
      'daysToExam': profile.daysToExam(),
      'targetMarks': profile.targetMarks,
      'totalMarks': profile.totalMarks,
      'dailyHours': profile.dailyHours,
    });

    final http.Response res;
    try {
      res = await _client
          .post(uri,
              headers: const {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);
    } catch (e) {
      throw PlanServiceException('Could not reach the planner ($e).');
    }

    if (res.statusCode != 200) {
      throw PlanServiceException(
          'Planner unavailable (HTTP ${res.statusCode}).');
    }

    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      // The backend already normalises; fromJson is defensive on top of that.
      // Stamp the generation time on the client.
      final map = Map<String, dynamic>.from(decoded)
        ..putIfAbsent('generatedAt', () => DateTime.now().toIso8601String());
      final plan = CuratedPlan.fromJson(map);
      // A plan with no content is as good as a failure — fall back instead.
      if (plan.milestones.isEmpty && plan.subjectFocus.isEmpty) {
        throw const FormatException('Empty plan.');
      }
      return plan;
    } catch (_) {
      throw PlanServiceException('The planner returned an unexpected result.');
    }
  }

  void dispose() => _client.close();
}

/// Offline / fallback planner. Builds a sensible, deterministic plan from the
/// profile alone — used when [HttpPlanService] can't be reached so the learner
/// is never hard-blocked, and as the default when running without a backend.
class MockPlanService implements PlanService {
  const MockPlanService({this.simulatedDelay = const Duration(milliseconds: 600)});

  final Duration simulatedDelay;

  @override
  Future<CuratedPlan> generate(UserProfile profile) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    return buildLocalPlan(profile);
  }

  /// Pure, synchronous local builder — also reusable as a guaranteed fallback.
  static CuratedPlan buildLocalPlan(UserProfile profile) {
    final days = profile.daysToExam();
    final totalWeeks = (days / 7).round().clamp(1, 200);
    final weeklyHours =
        double.parse((profile.dailyHours * 7).toStringAsFixed(1));
    final pct = (profile.targetFraction * 100).round();

    final subjects = _subjectsFor(profile.examId);

    return CuratedPlan(
      summary:
          'A $totalWeeks-week plan for ${profile.examName}, pacing about '
          '${_fmt(weeklyHours)} hours a week toward ${profile.targetMarks}/'
          '${profile.totalMarks} marks ($pct%). It builds from foundations to '
          'timed mock practice, with weekly checkpoints so the plan adapts.',
      totalWeeks: totalWeeks,
      weeklyHours: weeklyHours,
      focusAreas: const [
        'Cover the full syllabus once before deep revision',
        'Prioritise the highest-scoring topics first',
        'Sit one timed mock every week',
        'Revisit weak spots the mock reveals',
      ],
      subjectFocus: subjects,
      milestones: _milestones(totalWeeks),
      generatedAt: DateTime.now(),
    );
  }

  static List<SubjectFocus> _subjectsFor(String examId) {
    switch (examId) {
      case 'ioe':
        return const [
          SubjectFocus(subject: 'Mathematics', weight: 35, note: 'Highest weight — drill problem speed.'),
          SubjectFocus(subject: 'Physics', weight: 30, note: 'Mechanics and electricity carry the marks.'),
          SubjectFocus(subject: 'Chemistry', weight: 25, note: 'Mostly recall — schedule frequent review.'),
          SubjectFocus(subject: 'English', weight: 10, note: 'Quick wins; keep it ticking over.'),
        ];
      case 'cee':
        return const [
          SubjectFocus(subject: 'Physics', weight: 25, note: 'Concept-heavy — build intuition early.'),
          SubjectFocus(subject: 'Chemistry', weight: 25, note: 'Balance organic, inorganic and physical.'),
          SubjectFocus(subject: 'Botany', weight: 25, note: 'Volume of recall — use spaced repetition.'),
          SubjectFocus(subject: 'Zoology', weight: 25, note: 'Diagrams and processes — practise labelling.'),
        ];
      case 'cmat':
        return const [
          SubjectFocus(subject: 'Quantitative', weight: 30, note: 'Practise timed arithmetic and data.'),
          SubjectFocus(subject: 'Verbal & English', weight: 30, note: 'Reading comprehension and grammar.'),
          SubjectFocus(subject: 'Logical Reasoning', weight: 25, note: 'Pattern drills build speed.'),
          SubjectFocus(subject: 'General Awareness', weight: 15, note: 'Light daily reading.'),
        ];
      case 'loksewa':
        return const [
          SubjectFocus(subject: 'General Knowledge', weight: 30, note: 'Broad coverage — read widely.'),
          SubjectFocus(subject: 'Current Affairs', weight: 25, note: 'Daily news habit pays off.'),
          SubjectFocus(subject: 'Constitution & Governance', weight: 25, note: 'Memorise key articles.'),
          SubjectFocus(subject: 'Aptitude', weight: 20, note: 'Steady practice sets.'),
        ];
      default:
        return const [
          SubjectFocus(subject: 'Core theory', weight: 40, note: 'Read and understand the syllabus.'),
          SubjectFocus(subject: 'Problem solving', weight: 40, note: 'Apply concepts to questions daily.'),
          SubjectFocus(subject: 'Revision & mocks', weight: 20, note: 'Consolidate and test under time.'),
        ];
    }
  }

  static List<PlanMilestone> _milestones(int totalWeeks) {
    if (totalWeeks <= 2) {
      return [
        PlanMilestone(
          phase: 'Week 1',
          theme: 'Rapid coverage',
          detail: 'Skim the whole syllabus, flag weak topics.',
        ),
        PlanMilestone(
          phase: 'Final days',
          theme: 'Mocks & revision',
          detail: 'Timed papers and last-mile fixes.',
        ),
      ];
    }
    final foundationsEnd = (totalWeeks * 0.4).ceil();
    final strengthenEnd = (totalWeeks * 0.8).ceil();
    return [
      PlanMilestone(
        phase: 'Weeks 1–$foundationsEnd',
        theme: 'Foundations',
        detail: 'Build core understanding across every subject.',
      ),
      PlanMilestone(
        phase: 'Weeks ${foundationsEnd + 1}–$strengthenEnd',
        theme: 'Strengthening',
        detail: 'Practice sets on high-weight topics, close gaps.',
      ),
      PlanMilestone(
        phase: 'Weeks ${strengthenEnd + 1}–$totalWeeks',
        theme: 'Final revision & mocks',
        detail: 'Full timed mocks, targeted revision of weak spots.',
      ),
    ];
  }

  static String _fmt(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
