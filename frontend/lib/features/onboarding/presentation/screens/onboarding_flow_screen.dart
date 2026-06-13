import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../application/auth_providers.dart';
import '../../application/onboarding_providers.dart';
import '../../application/plan_providers.dart';
import '../../domain/auth_account.dart';
import '../../domain/user_profile.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/range_calendar.dart';
import 'welcome_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Onboarding — sign in with Google, then a calm six-step flow that collects
// everything the weekly plan is built from:
//   (gate) Continue with Google → name + email come from the account
//   0. Your profile      (photo + name; email is from Google)
//   1. Type of exam
//   2. Exam date
//   3. Target marks
//   4. Hours to study per day
//   5. Review → create the plan
//
// Built entirely from the shared design system (AppCard / AppButton / palette).
// State lives in one place as a mutable draft; each step gates the Continue
// button until it's valid; the final step commits a UserProfile.
// ═══════════════════════════════════════════════════════════════════════════

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  static const _stepCount = 6;

  final _page = PageController();
  int _step = 0;

  // ── Account (from Google sign-in) ───────────────────────────────────────────
  // Null until the learner signs in; while null the WelcomeScreen is shown.
  AuthAccount? _account;

  // ── Draft state ────────────────────────────────────────────────────────────
  // Name is pre-filled from the account but stays editable. Email is taken
  // straight from the account (read-only). Password is gone — Google owns auth.
  final _nameCtrl = TextEditingController();
  final _customExamCtrl = TextEditingController();

  String? _photoPath; // chosen profile photo, or null → gradient-initials default
  String? _examId;
  DateTime? _examDate;
  int _targetMarks = 0;
  double _dailyHours = 2.0;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the Continue button as the learner types.
    for (final c in [_nameCtrl, _customExamCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    _customExamCtrl.dispose();
    super.dispose();
  }

  ExamType? get _exam => _examId == null ? null : ExamCatalog.byId(_examId!);

  bool get _isCustomExam => _examId == ExamCatalog.customId;

  // ── Validation per step ──────────────────────────────────────────────────────
  bool _canContinue() {
    switch (_step) {
      case 0:
        // Name is pre-filled from Google; just make sure it isn't blanked out.
        // The photo is optional — we fall back to a default avatar.
        return _nameCtrl.text.trim().isNotEmpty;
      case 1:
        if (_examId == null) return false;
        return !_isCustomExam || _customExamCtrl.text.trim().isNotEmpty;
      case 2:
        return _examDate != null;
      case 3:
        return _targetMarks > 0;
      case 4:
        return _dailyHours > 0;
      default:
        return true;
    }
  }

  // ── Account & photo ──────────────────────────────────────────────────────────
  void _onSignedIn(AuthAccount account) {
    setState(() {
      _account = account;
      _nameCtrl.text = account.name;
      _step = 0;
    });
    // A fresh sign-in always starts at the first step.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_page.hasClients) _page.jumpToPage(0);
    });
  }

  Future<void> _signOut() async {
    FocusScope.of(context).unfocus();
    await ref.read(authServiceProvider).signOut();
    if (!mounted) return;
    setState(() {
      _account = null;
      _photoPath = null;
      _nameCtrl.clear();
      _step = 0;
    });
  }

  Future<void> _pickPhotoFrom(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) setState(() => _photoPath = picked.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the photo picker.")),
      );
    }
  }

  void _showPhotoSheet() {
    FocusScope.of(context).unfocus();
    final p = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: p.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _PhotoSheetTile(
                icon: Icons.photo_camera_rounded,
                label: 'Take a photo',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickPhotoFrom(ImageSource.camera);
                },
              ),
              _PhotoSheetTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from gallery',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickPhotoFrom(ImageSource.gallery);
                },
              ),
              if (_photoPath != null)
                _PhotoSheetTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove photo',
                  destructive: true,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    setState(() => _photoPath = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigation ───────────────────────────────────────────────────────────────
  void _next() {
    FocusScope.of(context).unfocus();
    if (!_canContinue()) return;
    if (_step == _stepCount - 1) {
      _finish();
      return;
    }
    // Picking an exam seeds a sensible target (60% of the total) the first time.
    if (_step == 1 && _targetMarks == 0 && _exam != null) {
      _targetMarks = (_exam!.totalMarks * 0.6).round();
    }
    HapticFeedback.lightImpact();
    _page.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) return;
    _page.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final exam = _exam;
    final account = _account;
    if (exam == null || _examDate == null || account == null) return;
    setState(() => _submitting = true);

    final examName =
        _isCustomExam ? _customExamCtrl.text.trim() : exam.name;

    final profile = UserProfile(
      fullName: _nameCtrl.text.trim(),
      email: account.email,
      examId: exam.id,
      examName: examName,
      examDate: _examDate!,
      targetMarks: _targetMarks,
      totalMarks: exam.totalMarks,
      dailyHours: _dailyHours,
      createdAt: DateTime.now(),
      photoPath: _photoPath,
    );

    HapticFeedback.mediumImpact();

    // Push to the cloud (uploads the photo, upserts the profiles row, and
    // rewrites photoPath to the public Storage URL). If anything fails we keep
    // the local profile so the demo never dead-ends behind a flaky network.
    var toSave = profile;
    try {
      toSave = await ref
          .read(profileSyncProvider)
          .persist(profile, userId: account.id);
    } catch (e) {
      debugPrint('Profile cloud sync failed, saving locally: $e');
    }

    // Clear any plan from a previous profile FIRST so the gate lands on the
    // loading screen (and not briefly on a stale plan), then save the profile.
    await ref.read(curatedPlanProvider.notifier).clear();
    // Flips userProfileProvider non-null → FeynmanApp swaps to the plan loader.
    await ref.read(userProfileProvider.notifier).complete(toSave);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // Front door: until they sign in, the whole screen is the welcome.
    final account = _account;
    if (account == null) {
      return WelcomeScreen(onSignedIn: _onSignedIn);
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              step: _step,
              stepCount: _stepCount,
              // Backing out of the first step returns to the welcome screen.
              onBack: _step == 0 ? _signOut : _back,
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _ProfileStep(
                    nameCtrl: _nameCtrl,
                    email: account.email,
                    photoPath: _photoPath,
                    initials: _nameCtrl.text.trim().isEmpty
                        ? account.initials
                        : _initialsOf(_nameCtrl.text),
                    onEditPhoto: _showPhotoSheet,
                  ),
                  _ExamTypeStep(
                    selectedId: _examId,
                    customCtrl: _customExamCtrl,
                    onSelect: (id) => setState(() {
                      _examId = id;
                      // Re-seed target against the new total next time we advance.
                      _targetMarks = 0;
                    }),
                  ),
                  _ExamDateStep(
                    examName: _isCustomExam
                        ? (_customExamCtrl.text.trim().isEmpty
                            ? 'your exam'
                            : _customExamCtrl.text.trim())
                        : (_exam?.name ?? 'your exam'),
                    date: _examDate,
                    onPick: () => _pickDate(),
                  ),
                  _TargetMarksStep(
                    total: _exam?.totalMarks ?? 100,
                    value: _targetMarks,
                    onChanged: (v) => setState(() => _targetMarks = v),
                  ),
                  _StudyHoursStep(
                    value: _dailyHours,
                    onChanged: (v) => setState(() => _dailyHours = v),
                  ),
                  _ReviewStep(
                    name: _nameCtrl.text.trim(),
                    photoPath: _photoPath,
                    initials: _initialsOf(_nameCtrl.text),
                    examName: _isCustomExam
                        ? _customExamCtrl.text.trim()
                        : (_exam?.name ?? ''),
                    examDate: _examDate,
                    targetMarks: _targetMarks,
                    totalMarks: _exam?.totalMarks ?? 100,
                    dailyHours: _dailyHours,
                  ),
                ],
              ),
            ),
            _Footer(
              isLast: _step == _stepCount - 1,
              enabled: _canContinue() && !_submitting,
              submitting: _submitting,
              onContinue: _next,
            ),
          ],
        ),
      ),
    );
  }

  /// First initials of a typed name, e.g. "Aarav Sharma" → "AS". Falls back to
  /// the signed-in account's initials (or "?") when the field is blank.
  String _initialsOf(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (parts.isEmpty) return _account?.initials ?? '?';
    return parts.map((w) => w[0].toUpperCase()).take(2).join();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final examLabel = _isCustomExam
        ? (_customExamCtrl.text.trim().isEmpty
            ? 'your exam'
            : _customExamCtrl.text.trim())
        : (_exam?.name ?? 'your exam');
    final picked = await showExamDatePicker(
      context,
      initial: _examDate,
      examName: examLabel,
    );
    if (picked != null) setState(() => _examDate = picked);
  }
}

// ─── Header: back arrow + segmented progress ─────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.stepCount,
    required this.onBack,
  });

  final int step;
  final int stepCount;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? const SizedBox()
                : IconButton(
                    onPressed: onBack,
                    icon: Icon(Icons.arrow_back_rounded,
                        color: p.textSecondary),
                    tooltip: 'Back',
                  ),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < stepCount; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= step ? p.accent : p.surfaceHigh,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

// ─── Footer: the single Continue / Create action ─────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer({
    required this.isLast,
    required this.enabled,
    required this.submitting,
    required this.onContinue,
  });

  final bool isLast;
  final bool enabled;
  final bool submitting;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppButton(
        label: submitting
            ? 'Building your plan…'
            : isLast
                ? 'Create my plan'
                : 'Continue',
        icon: isLast ? Icons.auto_awesome_rounded : null,
        onTap: enabled ? onContinue : null,
      ),
    );
  }
}

// ─── A consistent title + subtitle block atop each step ──────────────────────
class _StepIntro extends StatelessWidget {
  const _StepIntro({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggeredEntrance(
          child: Text(title, style: text.displayMedium?.copyWith(fontSize: 32)),
        ),
        const SizedBox(height: 10),
        StaggeredEntrance(
          index: 1,
          child: Text(subtitle,
              style: text.bodyMedium?.copyWith(color: p.textSecondary)),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// Shared scrollable body padding so the keyboard never clips a field.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 0 — your profile (photo + name; email comes from the Google account)
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.nameCtrl,
    required this.email,
    required this.photoPath,
    required this.initials,
    required this.onEditPhoto,
  });

  final TextEditingController nameCtrl;
  final String email;
  final String? photoPath;
  final String initials;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final hasPhoto = photoPath != null;

    return _StepBody(
      children: [
        const _StepIntro(
          title: 'Make it yours',
          subtitle:
              'Add a photo and confirm your name — you can change these anytime.',
        ),
        // Tappable avatar with a camera badge.
        Center(
          child: StaggeredEntrance(
            child: Pressable(
              onTap: onEditPhoto,
              scale: 0.96,
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  children: [
                    ProfileAvatar(
                      initials: initials,
                      photoPath: photoPath,
                      size: 120,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.bg, width: 3),
                        ),
                        child: const Icon(Icons.photo_camera_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Pressable(
            onTap: onEditPhoto,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                hasPhoto ? 'Change photo' : 'Add a photo',
                style: text.labelLarge?.copyWith(
                  color: p.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _LabeledField(
          label: 'Full name',
          child: _OnboardingField(
            controller: nameCtrl,
            hint: 'e.g. Aarav Sharma',
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            keyboardType: TextInputType.name,
            icon: Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(height: 18),
        _SignedInChip(email: email),
      ],
    );
  }
}

/// Read-only "signed in with Google" row — reassures the learner their account
/// is connected without asking them to retype the email.
class _SignedInChip extends StatelessWidget {
  const _SignedInChip({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.hairline, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, size: 18, color: p.positive),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signed in with Google',
                    style: text.labelSmall?.copyWith(color: p.textTertiary)),
                const SizedBox(height: 1),
                Text(email,
                    style: text.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the "choose photo" bottom sheet.
class _PhotoSheetTile extends StatelessWidget {
  const _PhotoSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final color = destructive ? p.recordingDot : p.textPrimary;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: destructive ? p.recordingDot : p.accent),
            const SizedBox(width: 16),
            Text(label,
                style: text.titleMedium?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 1 — exam type
// ═══════════════════════════════════════════════════════════════════════════
class _ExamTypeStep extends StatelessWidget {
  const _ExamTypeStep({
    required this.selectedId,
    required this.customCtrl,
    required this.onSelect,
  });

  final String? selectedId;
  final TextEditingController customCtrl;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isCustom = selectedId == ExamCatalog.customId;
    return _StepBody(
      children: [
        const _StepIntro(
          title: 'Which exam?',
          subtitle: 'Your whole plan is shaped around the one you pick.',
        ),
        for (var i = 0; i < ExamCatalog.all.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          StaggeredEntrance(
            index: i,
            child: _ExamCard(
              exam: ExamCatalog.all[i],
              selected: selectedId == ExamCatalog.all[i].id,
              onTap: () => onSelect(ExamCatalog.all[i].id),
            ),
          ),
        ],
        if (isCustom) ...[
          const SizedBox(height: 18),
          _LabeledField(
            label: 'Exam name',
            child: _OnboardingField(
              controller: customCtrl,
              hint: 'e.g. NEB Grade 12, SAT…',
              textCapitalization: TextCapitalization.words,
              icon: Icons.edit_outlined,
              autofocus: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.selected,
    required this.onTap,
  });

  final ExamType exam;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? p.accent : p.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? p.accent : p.surfaceHigh,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(exam.icon,
                  size: 22, color: selected ? Colors.white : p.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam.name, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(exam.fullName,
                      style: text.labelMedium
                          ?.copyWith(color: p.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? p.accent : Colors.transparent,
        border: Border.all(
          color: selected ? p.accent : p.hairline,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 2 — exam date
// ═══════════════════════════════════════════════════════════════════════════
class _ExamDateStep extends StatelessWidget {
  const _ExamDateStep({
    required this.examName,
    required this.date,
    required this.onPick,
  });

  final String examName;
  final DateTime? date;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final days = date == null ? null : UserProfile.daysUntil(date!);

    return _StepBody(
      children: [
        _StepIntro(
          title: 'When is it?',
          subtitle: 'We count backwards from $examName to pace your weeks.',
        ),
        StaggeredEntrance(
          index: 1,
          child: AppCard(
            onTap: onPick,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.event_rounded, color: p.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date == null ? 'Pick a date' : _formatDate(date!),
                        style: text.titleMedium?.copyWith(
                          color: date == null ? p.textTertiary : p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date == null
                            ? 'Tap to choose your exam day'
                            : 'Tap to change',
                        style: text.labelMedium
                            ?.copyWith(color: p.textTertiary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textTertiary),
              ],
            ),
          ),
        ),
        if (days != null) ...[
          const SizedBox(height: 20),
          StaggeredEntrance(
            index: 2,
            child: Center(
              child: Column(
                children: [
                  Text('$days',
                      style: text.displayLarge?.copyWith(color: p.accent)),
                  Text('days to prepare',
                      style: text.bodyMedium
                          ?.copyWith(color: p.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 3 — target marks
// ═══════════════════════════════════════════════════════════════════════════
class _TargetMarksStep extends StatelessWidget {
  const _TargetMarksStep({
    required this.total,
    required this.value,
    required this.onChanged,
  });

  final int total;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final pct = total == 0 ? 0 : ((value / total) * 100).round();

    return _StepBody(
      children: [
        const _StepIntro(
          title: 'Your target',
          subtitle: 'The mark we\'ll keep you aimed at. You can change it later.',
        ),
        StaggeredEntrance(
          index: 1,
          child: Center(
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$value',
                        style: text.displayLarge?.copyWith(color: p.accent),
                      ),
                      TextSpan(
                        text: ' / $total',
                        style: text.headlineSmall
                            ?.copyWith(color: p.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('$pct% of the paper',
                    style: text.bodyMedium
                        ?.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        StaggeredEntrance(
          index: 2,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: p.accent,
              inactiveTrackColor: p.surfaceHigh,
              thumbColor: p.accent,
              overlayColor: p.accentSoft,
              trackHeight: 6,
            ),
            child: Slider(
              value: value.toDouble().clamp(0, total.toDouble()),
              min: 0,
              max: total.toDouble(),
              divisions: total,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        StaggeredEntrance(
          index: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final preset in _presetsFor(total))
                _PresetChip(
                  label: '$preset',
                  selected: value == preset,
                  onTap: () => onChanged(preset),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Quick-pick marks at 50 / 60 / 75 / 90% of the paper.
  static List<int> _presetsFor(int total) =>
      [0.5, 0.6, 0.75, 0.9].map((f) => (total * f).round()).toList();
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? p.accent : p.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: text.labelLarge?.copyWith(
            color: selected ? Colors.white : p.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 4 — study hours per day
// ═══════════════════════════════════════════════════════════════════════════
class _StudyHoursStep extends StatelessWidget {
  const _StudyHoursStep({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return _StepBody(
      children: [
        const _StepIntro(
          title: 'Daily commitment',
          subtitle:
              'How many hours can you realistically study each day? Honest beats ambitious.',
        ),
        StaggeredEntrance(
          index: 1,
          child: Center(
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _formatHours(value),
                        style: text.displayLarge?.copyWith(color: p.accent),
                      ),
                      TextSpan(
                        text: value == 1 ? ' hour' : ' hours',
                        style: text.headlineSmall
                            ?.copyWith(color: p.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('a day · ${_weeklyLabel(value)} a week',
                    style: text.bodyMedium
                        ?.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        StaggeredEntrance(
          index: 2,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: p.accent,
              inactiveTrackColor: p.surfaceHigh,
              thumbColor: p.accent,
              overlayColor: p.accentSoft,
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              min: 0.5,
              max: 8,
              divisions: 15, // 0.5-hour steps
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('30 min', style: text.labelSmall),
            Text('8 hours', style: text.labelSmall),
          ],
        ),
      ],
    );
  }

  static String _formatHours(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _weeklyLabel(double daily) {
    final weekly = daily * 7;
    return '${_formatHours(weekly)} ${weekly == 1 ? 'hour' : 'hours'}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step 5 — review
// ═══════════════════════════════════════════════════════════════════════════
class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.name,
    required this.photoPath,
    required this.initials,
    required this.examName,
    required this.examDate,
    required this.targetMarks,
    required this.totalMarks,
    required this.dailyHours,
  });

  final String name;
  final String? photoPath;
  final String initials;
  final String examName;
  final DateTime? examDate;
  final int targetMarks;
  final int totalMarks;
  final double dailyHours;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final days =
        examDate == null ? null : UserProfile.daysUntil(examDate!);

    return _StepBody(
      children: [
        Center(
          child: StaggeredEntrance(
            child: ProfileAvatar(
              initials: initials,
              photoPath: photoPath,
              size: 76,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _StepIntro(
          title: name.isEmpty ? 'All set' : 'Ready, $name',
          subtitle:
              'Here\'s the plan we\'ll build for you. Tap Create my plan to begin.',
        ),
        StaggeredEntrance(
          index: 1,
          child: AppCard(
            child: Column(
              children: [
                _ReviewRow(
                  icon: Icons.school_rounded,
                  label: 'Exam',
                  value: examName.isEmpty ? '—' : examName,
                ),
                _divider(p),
                _ReviewRow(
                  icon: Icons.event_rounded,
                  label: 'Exam date',
                  value: examDate == null
                      ? '—'
                      : '${_ExamDateStep._formatDate(examDate!)}'
                          '${days != null ? '  ·  $days days' : ''}',
                ),
                _divider(p),
                _ReviewRow(
                  icon: Icons.track_changes_rounded,
                  label: 'Target',
                  value: '$targetMarks / $totalMarks marks',
                ),
                _divider(p),
                _ReviewRow(
                  icon: Icons.schedule_rounded,
                  label: 'Study time',
                  value:
                      '${_StudyHoursStep._formatHours(dailyHours)} ${dailyHours == 1 ? 'hour' : 'hours'} a day',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        StaggeredEntrance(
          index: 2,
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 15, color: p.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Everything stays on this device.',
                  style: text.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _divider(AppPalette p) =>
      Divider(height: 28, thickness: 0.5, color: p.hairline);
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: p.accent),
        const SizedBox(width: 14),
        Text(label, style: text.labelMedium?.copyWith(color: p.textTertiary)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared field primitives
// ═══════════════════════════════════════════════════════════════════════════
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: text.labelMedium?.copyWith(
                color: p.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _OnboardingField extends StatelessWidget {
  const _OnboardingField({
    required this.controller,
    required this.hint,
    this.icon,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: p.textTertiary),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              textCapitalization: textCapitalization,
              style: text.bodyLarge,
              cursorColor: p.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                border: InputBorder.none,
                hintText: hint,
                hintStyle: text.bodyLarge?.copyWith(color: p.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
