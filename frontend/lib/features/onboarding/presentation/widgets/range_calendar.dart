import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Exam date picker — a calendar that picks ONE day (the exam) but paints the
// whole stretch from today to that day as a single connected range, the way a
// Google Calendar event shows its span. The point is to *feel* the runway:
// tap a date further out and watch more weeks fill with violet.
// ═══════════════════════════════════════════════════════════════════════════

/// Opens the picker as a bottom sheet. Returns the chosen exam date, or null if
/// dismissed. [initial] pre-selects a date; selectable range is tomorrow → +3y.
Future<DateTime?> showExamDatePicker(
  BuildContext context, {
  DateTime? initial,
  required String examName,
}) {
  final p = context.palette;
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ExamDatePickerSheet(initial: initial, examName: examName),
  );
}

class _ExamDatePickerSheet extends StatefulWidget {
  const _ExamDatePickerSheet({required this.initial, required this.examName});

  final DateTime? initial;
  final String examName;

  @override
  State<_ExamDatePickerSheet> createState() => _ExamDatePickerSheetState();
}

class _ExamDatePickerSheetState extends State<_ExamDatePickerSheet> {
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  late final DateTime _today = _dateOnly(DateTime.now());
  late final DateTime _firstSelectable = _today.add(const Duration(days: 1));
  late final DateTime _lastSelectable = _today.add(const Duration(days: 365 * 3));

  late DateTime _visibleMonth; // first day of the month on screen
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial == null ? null : _dateOnly(widget.initial!);
    final anchor = _selected ?? _today.add(const Duration(days: 100));
    _visibleMonth = DateTime(anchor.year, anchor.month);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _minMonth => DateTime(_today.year, _today.month);
  DateTime get _maxMonth => DateTime(_lastSelectable.year, _lastSelectable.month);

  bool get _canPrev => _visibleMonth.isAfter(_minMonth);
  bool get _canNext => _visibleMonth.isBefore(_maxMonth);

  void _step(int months) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + months);
    });
    HapticFeedback.selectionClick();
  }

  void _select(DateTime day) {
    if (day.isBefore(_firstSelectable) || day.isAfter(_lastSelectable)) return;
    HapticFeedback.lightImpact();
    setState(() => _selected = day);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final days = _selected?.difference(_today).inDays;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('When is your exam?', style: text.headlineSmall),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'We shade every day from today to ${widget.examName}.',
                style: text.bodyMedium?.copyWith(color: p.textSecondary),
              ),
            ),
            const SizedBox(height: 18),
            // Month nav.
            Row(
              children: [
                Text(
                  '${_months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _NavButton(
                  icon: Icons.chevron_left_rounded,
                  enabled: _canPrev,
                  onTap: () => _step(-1),
                ),
                const SizedBox(width: 4),
                _NavButton(
                  icon: Icons.chevron_right_rounded,
                  enabled: _canNext,
                  onTap: () => _step(1),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Weekday labels.
            Row(
              children: [
                for (final w in _weekdays)
                  Expanded(
                    child: Center(
                      child: Text(w,
                          style: text.labelSmall
                              ?.copyWith(color: p.textTertiary)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _MonthGrid(
              month: _visibleMonth,
              today: _today,
              firstSelectable: _firstSelectable,
              lastSelectable: _lastSelectable,
              selected: _selected,
              onSelect: _select,
            ),
            const SizedBox(height: 16),
            // Live duration readout.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: days == null
                  ? Text(
                      'Pick the day of your exam',
                      key: const ValueKey('empty'),
                      style: text.bodyMedium?.copyWith(color: p.textTertiary),
                    )
                  : Row(
                      key: ValueKey(days),
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$days',
                            style: text.headlineSmall?.copyWith(
                                color: p.accent, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Text('days to prepare',
                            style: text.bodyMedium
                                ?.copyWith(color: p.textSecondary)),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Set exam date',
              icon: Icons.check_rounded,
              onTap: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── The 7-column month grid with the connected range band ───────────────────
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.firstSelectable,
    required this.lastSelectable,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime firstSelectable;
  final DateTime lastSelectable;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Sunday = 0 … Saturday = 6. Dart: Monday=1 … Sunday=7.
    final lead = DateTime(month.year, month.month, 1).weekday % 7;
    final cellCount = lead + daysInMonth;
    final rowCount = (cellCount / 7).ceil();

    // The visualised span is [today, selected].
    final rangeEnd = selected;

    return Column(
      children: [
        for (var row = 0; row < rowCount; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _buildCell(
                    context,
                    index: row * 7 + col,
                    lead: lead,
                    daysInMonth: daysInMonth,
                    rangeEnd: rangeEnd,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(
    BuildContext context, {
    required int index,
    required int lead,
    required int daysInMonth,
    required DateTime? rangeEnd,
  }) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    final dayNum = index - lead + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 46);
    }
    final day = DateTime(month.year, month.month, dayNum);

    final isToday = _sameDay(day, today);
    final isSelected = rangeEnd != null && _sameDay(day, rangeEnd);
    final inRange = rangeEnd != null &&
        !day.isBefore(today) &&
        !day.isAfter(rangeEnd);
    final isStart = inRange && isToday; // range always begins at today
    final selectable =
        !day.isBefore(firstSelectable) && !day.isAfter(lastSelectable);

    // The connecting band reaches the cell edges so adjacent days/rows join up;
    // only the true start (today) and end (selected) get a rounded cap.
    final bandRadius = Radius.circular(isStart || isSelected ? 23 : 0);
    final band = inRange
        ? Align(
            child: Container(
              height: 38,
              width: double.infinity,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.horizontal(
                  left: isStart ? bandRadius : Radius.zero,
                  right: isSelected ? bandRadius : Radius.zero,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    // Endpoint discs: today is an outlined anchor, the exam day a filled disc.
    Widget numberChild;
    if (isSelected) {
      numberChild = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: p.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: p.accent.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text('$dayNum',
            style: text.labelLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      );
    } else if (isToday) {
      numberChild = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: p.accent, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text('$dayNum',
            style: text.labelLarge
                ?.copyWith(color: p.accent, fontWeight: FontWeight.w700)),
      );
    } else {
      final color = !selectable
          ? p.textTertiary.withValues(alpha: 0.45)
          : inRange
              ? p.accent
              : p.textPrimary;
      numberChild = Text('$dayNum',
          style: text.labelLarge?.copyWith(
            color: color,
            fontWeight: inRange ? FontWeight.w600 : FontWeight.w500,
          ));
    }

    final cell = SizedBox(
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [band, numberChild],
      ),
    );

    if (!selectable) return cell;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(day),
      child: cell,
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled ? p.textSecondary : p.textTertiary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
