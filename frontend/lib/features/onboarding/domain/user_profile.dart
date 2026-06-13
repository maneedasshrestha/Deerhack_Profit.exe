import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Onboarding domain — the four facts the weekly plan is built from (see
// plan_data.dart): the exam, when it is, the mark you're chasing, and how many
// hours a day you can give it. Plus the personal details that name the account.
//
// Stored locally as JSON (no codegen) the same way sessions are — see
// ProfileRepository. The signup password is intentionally NOT part of this
// model: there is no auth backend, so we validate it during signup but never
// persist it in plaintext.
// ═══════════════════════════════════════════════════════════════════════════

/// One selectable exam, with the marks it's scored out of so the target slider
/// can be bounded sensibly.
@immutable
class ExamType {
  const ExamType({
    required this.id,
    required this.name,
    required this.fullName,
    required this.totalMarks,
    required this.icon,
  });

  final String id;
  final String name;

  /// Longer descriptor shown under the name on the selection card.
  final String fullName;
  final int totalMarks;
  final IconData icon;
}

/// The catalogue offered during onboarding. `custom` is the escape hatch — the
/// learner types their own exam name and we score it out of 100 by default.
class ExamCatalog {
  ExamCatalog._();

  static const String customId = 'custom';

  static const List<ExamType> all = [
    ExamType(
      id: 'ioe',
      name: 'IOE Entrance',
      fullName: 'Engineering · Institute of Engineering',
      totalMarks: 100,
      icon: Icons.engineering_rounded,
    ),
    ExamType(
      id: 'cee',
      name: 'CEE Medical',
      fullName: 'Medical · Common Entrance Examination',
      totalMarks: 200,
      icon: Icons.medical_services_rounded,
    ),
    ExamType(
      id: 'cmat',
      name: 'CMAT',
      fullName: 'Management · Central Management Admission Test',
      totalMarks: 100,
      icon: Icons.trending_up_rounded,
    ),
    ExamType(
      id: 'loksewa',
      name: 'Lok Sewa',
      fullName: 'Civil service · Public Service Commission',
      totalMarks: 100,
      icon: Icons.account_balance_rounded,
    ),
    ExamType(
      id: customId,
      name: 'Something else',
      fullName: 'Name your own exam',
      totalMarks: 100,
      icon: Icons.edit_rounded,
    ),
  ];

  static ExamType byId(String id) =>
      all.firstWhere((e) => e.id == id, orElse: () => all.first);
}

@immutable
class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.examId,
    required this.examName,
    required this.examDate,
    required this.targetMarks,
    required this.totalMarks,
    required this.dailyHours,
    required this.createdAt,
    this.photoPath,
  });

  final String fullName;
  final String email;

  /// Local file path to the chosen profile photo, or null to fall back to the
  /// gradient-initials avatar. (A device path for now; becomes a remote URL once
  /// photos are uploaded to Supabase storage.)
  final String? photoPath;

  /// Whether a real photo was set (vs the default avatar).
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  /// One of [ExamCatalog] ids (or `custom`).
  final String examId;

  /// The display name — either the catalogue name or the custom text.
  final String examName;
  final DateTime examDate;
  final int targetMarks;
  final int totalMarks;
  final double dailyHours;
  final DateTime createdAt;

  /// First initials, e.g. "Aarav Sharma" → "AS". Falls back to "?".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.map((w) => w[0].toUpperCase()).take(2).join();
  }

  /// Whole days from now until the exam, never negative.
  int daysToExam([DateTime? now]) => daysUntil(examDate, now);

  /// Whole days from now until [date], never negative. Shared so the onboarding
  /// steps can show a live countdown before a profile exists.
  static int daysUntil(DateTime date, [DateTime? now]) {
    final today = _dateOnly(now ?? DateTime.now());
    final target = _dateOnly(date);
    final diff = target.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Target as a fraction of the total, for rings/labels.
  double get targetFraction =>
      totalMarks == 0 ? 0 : (targetMarks / totalMarks).clamp(0.0, 1.0);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? examId,
    String? examName,
    DateTime? examDate,
    int? targetMarks,
    int? totalMarks,
    double? dailyHours,
    DateTime? createdAt,
    String? photoPath,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      examId: examId ?? this.examId,
      examName: examName ?? this.examName,
      examDate: examDate ?? this.examDate,
      targetMarks: targetMarks ?? this.targetMarks,
      totalMarks: totalMarks ?? this.totalMarks,
      dailyHours: dailyHours ?? this.dailyHours,
      createdAt: createdAt ?? this.createdAt,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'examId': examId,
        'examName': examName,
        'examDate': examDate.toIso8601String(),
        'targetMarks': targetMarks,
        'totalMarks': totalMarks,
        'dailyHours': dailyHours,
        'createdAt': createdAt.toIso8601String(),
        'photoPath': photoPath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        examId: json['examId'] as String? ?? ExamCatalog.customId,
        examName: json['examName'] as String? ?? 'My exam',
        examDate: DateTime.parse(json['examDate'] as String),
        targetMarks: (json['targetMarks'] as num?)?.toInt() ?? 0,
        totalMarks: (json['totalMarks'] as num?)?.toInt() ?? 100,
        dailyHours: (json['dailyHours'] as num?)?.toDouble() ?? 1.0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        photoPath: json['photoPath'] as String?,
      );
}
