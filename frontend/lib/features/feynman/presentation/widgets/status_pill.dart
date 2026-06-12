import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_theme.dart';
import 'glass_panel.dart';

/// Top-of-screen status: the concept name plus a live "recording" dot that
/// pulses only while listening. Kept minimal so it never competes with the orb.
class StatusPill extends StatefulWidget {
  const StatusPill({
    super.key,
    required this.concept,
    required this.version,
    required this.recording,
  });

  final String concept;
  final int version;
  final bool recording;

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.recording) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StatusPill old) {
    super.didUpdateWidget(old);
    if (widget.recording && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.recording && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: widget.recording
          ? 'Recording. Teaching ${widget.concept}, attempt ${widget.version}'
          : 'Teaching ${widget.concept}, attempt ${widget.version}',
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        radius: 24,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: widget.recording
                  ? Tween(begin: 0.35, end: 1.0).animate(_pulse)
                  : const AlwaysStoppedAnimation(0.5),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.recording ? p.recordingDot : p.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                widget.concept,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge,
              ),
            ),
            if (widget.version > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('v${widget.version}',
                    style: text.labelSmall?.copyWith(color: p.accent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A monospace-ish elapsed timer (mm:ss) that ticks from [start].
class ElapsedTimer extends StatefulWidget {
  const ElapsedTimer({super.key, required this.start});

  final DateTime start;

  @override
  State<ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<ElapsedTimer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final now = DateTime.now().difference(widget.start);
      if (now.inSeconds != _elapsed.inSeconds) {
        setState(() => _elapsed = now);
      }
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      '$m:$s',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.palette.textTertiary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}
