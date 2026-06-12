import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/student_turn.dart';
import '../../domain/student_engine.dart';

/// Thrown for engine-level failures the controller can surface gracefully.
class StudentEngineException implements Exception {
  StudentEngineException(this.message);
  final String message;
  @override
  String toString() => 'StudentEngineException: $message';
}

/// Turn-based engine: POSTs the explanation to the backend proxy and parses the
/// strict-JSON reply. The proxy holds the LLM key — this client never does.
///
/// Contract (see README "Backend proxy contract"):
///   POST {baseUrl}/v1/student/turn
///   { concept, explanation, history: [{role:'user'|'student', text}] }
///   200 → { reaction, question, clarity, jargon[] }
class TurnBasedStudentEngine implements StudentEngine {
  TurnBasedStudentEngine({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  /// Base URL of the proxy, e.g. http://10.0.2.2:8787 (Android emulator) or
  /// http://localhost:8787 (iOS simulator / desktop).
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<StudentTurn> respond(StudentRequest request) async {
    final uri = Uri.parse('$baseUrl/v1/student/turn');
    final body = jsonEncode({
      'concept': request.concept,
      'explanation': request.explanation,
      'history': request.history.map((t) => t.toJson()).toList(),
    });

    final http.Response res;
    try {
      res = await _client
          .post(uri, headers: const {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);
    } catch (e) {
      throw StudentEngineException('Could not reach the student ($e).');
    }

    if (res.statusCode != 200) {
      throw StudentEngineException('Student unavailable (HTTP ${res.statusCode}).');
    }

    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      // StudentTurn.fromJson clamps/validates defensively.
      return StudentTurn.fromJson(decoded);
    } catch (_) {
      throw StudentEngineException('The student gave a confusing answer.');
    }
  }

  void dispose() => _client.close();
}
