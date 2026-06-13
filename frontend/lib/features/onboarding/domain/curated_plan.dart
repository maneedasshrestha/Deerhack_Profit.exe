// ═══════════════════════════════════════════════════════════════════════════
// CuratedPlan — the study plan the backend builds from the learner's condition
// (exam, days remaining, target marks, daily hours). Persisted locally as JSON
// once generated so we don't regenerate on every launch.
// ═══════════════════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';

@immutable
class SubjectFocus {
  const SubjectFocus({
    required this.subject,
    required this.weight,
    required this.note,
  });

  final String subject;

  /// Rough share of effort, 0–100.
  final int weight;
  final String note;

  Map<String, dynamic> toJson() =>
      {'subject': subject, 'weight': weight, 'note': note};

  factory SubjectFocus.fromJson(Map<String, dynamic> json) => SubjectFocus(
        subject: json['subject'] as String? ?? '',
        weight: (json['weight'] as num?)?.toInt() ?? 0,
        note: json['note'] as String? ?? '',
      );
}

@immutable
class PlanMilestone {
  const PlanMilestone({
    required this.phase,
    required this.theme,
    required this.detail,
  });

  /// e.g. "Weeks 1–3".
  final String phase;
  final String theme;
  final String detail;

  Map<String, dynamic> toJson() =>
      {'phase': phase, 'theme': theme, 'detail': detail};

  factory PlanMilestone.fromJson(Map<String, dynamic> json) => PlanMilestone(
        phase: json['phase'] as String? ?? '',
        theme: json['theme'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
      );
}

@immutable
class CuratedPlan {
  const CuratedPlan({
    required this.summary,
    required this.totalWeeks,
    required this.weeklyHours,
    required this.focusAreas,
    required this.subjectFocus,
    required this.milestones,
    required this.generatedAt,
  });

  final String summary;
  final int totalWeeks;
  final double weeklyHours;
  final List<String> focusAreas;
  final List<SubjectFocus> subjectFocus;
  final List<PlanMilestone> milestones;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'totalWeeks': totalWeeks,
        'weeklyHours': weeklyHours,
        'focusAreas': focusAreas,
        'subjectFocus': subjectFocus.map((s) => s.toJson()).toList(),
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory CuratedPlan.fromJson(Map<String, dynamic> json) => CuratedPlan(
        summary: json['summary'] as String? ?? '',
        totalWeeks: (json['totalWeeks'] as num?)?.toInt() ?? 1,
        weeklyHours: (json['weeklyHours'] as num?)?.toDouble() ?? 0,
        focusAreas: (json['focusAreas'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        subjectFocus: (json['subjectFocus'] as List?)
                ?.whereType<Map>()
                .map((m) => SubjectFocus.fromJson(m.cast<String, dynamic>()))
                .toList() ??
            const [],
        milestones: (json['milestones'] as List?)
                ?.whereType<Map>()
                .map((m) => PlanMilestone.fromJson(m.cast<String, dynamic>()))
                .toList() ??
            const [],
        generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
