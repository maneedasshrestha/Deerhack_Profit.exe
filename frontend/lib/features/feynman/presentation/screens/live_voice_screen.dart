import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics.dart';
import '../../../../core/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/providers.dart';
import '../../application/session_args.dart';
import '../../domain/models/feynman_phase.dart';
import '../../domain/models/feynman_state.dart';
import '../widgets/glass_panel.dart';
import '../widgets/gaps_counter.dart';
import '../widgets/live_caption.dart';
import '../widgets/orb/feynman_orb.dart';
import '../widgets/status_pill.dart';
import '../widgets/transcript_bubble.dart';
import 'reflection_screen.dart';

/// Mode A — the immersive, full-screen voice experience built around the orb.
/// Everything overlaid is kept minimal so it never competes with the orb.
class LiveVoiceScreen extends ConsumerStatefulWidget {
  const LiveVoiceScreen({super.key, required this.args});

  final SessionArgs args;

  @override
  ConsumerState<LiveVoiceScreen> createState() => _LiveVoiceScreenState();
}

class _LiveVoiceScreenState extends ConsumerState<LiveVoiceScreen> {
  bool _ending = false;
  // Once the learner sends their first typed message, the orb view gives way to
  // a full chat layout. They can toggle back to voice from the chat header.
  bool _chatMode = false;

  @override
  void initState() {
    super.initState();
    Haptics.sessionStart();
  }

  Future<void> _endSession() async {
    if (_ending) return;
    setState(() => _ending = true);
    final controller = ref.read(
      feynmanControllerProvider(widget.args).notifier,
    );
    final session = await controller.endSession();
    if (!mounted) return;
    // Hero transition: the orb collapses into the reflection header.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Motion.hero,
        reverseTransitionDuration: Motion.medium,
        pageBuilder: (_, _, _) => ReflectionScreen(session: session),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: const Interval(0.3, 1)),
          child: child,
        ),
      ),
    );
  }

  void _openTranscript(BuildContext context, FeynmanState state) {
    final p = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: p.hairline, width: 0.5),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: p.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Transcript',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${state.gapCount} gaps so far',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.transcript.isEmpty
                    ? Center(
                        child: Text(
                          'Nothing yet — start explaining.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: state.transcript.length,
                        itemBuilder: (_, i) =>
                            TranscriptBubble(entry: state.transcript[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTypeSheet(BuildContext context) async {
    final controller = ref.read(
      feynmanControllerProvider(widget.args).notifier,
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _TypeSheet(
        onSend: (text) {
          if (text.trim().isEmpty) return;
          controller.submitTyped(text);
          // First typed turn transforms the immersive orb view into a chat.
          if (mounted) setState(() => _chatMode = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduceMotion = context.reduceMotion;
    final state = ref.watch(feynmanControllerProvider(widget.args));
    final controller = ref.read(
      feynmanControllerProvider(widget.args).notifier,
    );
    final phase = state.phase;
    final orbSize = (MediaQuery.sizeOf(context).shortestSide * 0.72).clamp(
      220.0,
      340.0,
    );

    if (_chatMode) {
      return _ChatView(
        args: widget.args,
        ending: _ending,
        onEnd: _endSession,
        onExitToVoice: () => setState(() => _chatMode = false),
      );
    }

    return PopScope(
      // Leaving without ending still persists the session via dispose+end on back.
      canPop: true,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.1,
              colors: [Color.lerp(p.bg, p.accent, 0.06)!, p.bg],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // ── Top status row ──
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Flexible(
                        child: StatusPill(
                          concept: state.conceptName,
                          version: state.version,
                          recording: phase.isListening,
                        ),
                      ),
                      const Spacer(),
                      ElapsedTimer(start: state.startedAt),
                    ],
                  ),
                ),

                // ── The orb (centre, the hero) ──
                Align(
                  alignment: const Alignment(0, -0.18),
                  child: GestureDetector(
                    onTap: () => controller.toggleMic(),
                    behavior: HitTestBehavior.opaque,
                    child: Hero(
                      tag: 'feynman-orb',
                      flightShuttleBuilder: (a, b, c, d, e) =>
                          const OrbBadge(size: 120),
                      child: FeynmanOrb(
                        mode: phase.orbMode,
                        level: state.soundLevel,
                        reduceMotion: reduceMotion,
                        size: orbSize.toDouble(),
                      ),
                    ),
                  ),
                ),

                // ── State hint just under the orb ──
                Align(
                  alignment: const Alignment(0, 0.42),
                  child: _Hint(
                    phase: phase,
                    onRetryTurn: controller.retryLastTurn,
                    onRetryListening: controller.beginListening,
                  ),
                ),

                // ── Live caption / student question ──
                Positioned(
                  left: 28,
                  right: 28,
                  bottom: 150,
                  child: _CaptionArea(state: state),
                ),

                // ── Bottom bar ──
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.gapCount > 0) ...[
                        GapsCounter(
                          count: state.gapCount,
                          onTap: () => _openTranscript(context, state),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          _IconChip(
                            icon: Icons.forum_outlined,
                            tooltip: 'View transcript',
                            onTap: () => _openTranscript(context, state),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _EndButton(
                              onTap: _endSession,
                              busy: _ending,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _IconChip(
                            icon: Icons.keyboard_outlined,
                            tooltip: 'Type instead',
                            onTap: () => _openTypeSheet(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "type instead" bottom sheet. A StatefulWidget so it OWNS its
/// [TextEditingController] and disposes it in its own dispose() — only after the
/// sheet is fully gone. Previously the controller was created in
/// [_openTypeSheet] and disposed right after `await showModalBottomSheet`, but
/// tapping send rebuilds the still-closing sheet against the disposed
/// controller ("used after being disposed" → cascades into the red screen).
class _TypeSheet extends StatefulWidget {
  const _TypeSheet({required this.onSend});

  final void Function(String text) onSend;

  @override
  State<_TypeSheet> createState() => _TypeSheetState();
}

class _TypeSheetState extends State<_TypeSheet> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.hairline, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type your explanation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              cursorColor: p.accent,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Explain it as if to a curious 12-year-old…',
                filled: true,
                fillColor: p.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.accent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: p.accent),
                onPressed: () {
                  final txt = _textController.text;
                  Navigator.of(context).pop();
                  widget.onSend(txt);
                },
                child: const Text('Send to coach'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mode B — the chat layout the screen adopts once the learner starts typing.
/// Pure text in/out: a scrolling transcript of bubbles plus a persistent
/// composer. The header lets them jump back to the immersive voice orb.
class _ChatView extends ConsumerStatefulWidget {
  const _ChatView({
    required this.args,
    required this.ending,
    required this.onEnd,
    required this.onExitToVoice,
  });

  final SessionArgs args;
  final bool ending;
  final Future<void> Function() onEnd;
  final VoidCallback onExitToVoice;

  @override
  ConsumerState<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<_ChatView> {
  final _scroll = ScrollController();
  final _composer = TextEditingController();
  int _lastCount = 0;

  @override
  void dispose() {
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    final state = ref.read(feynmanControllerProvider(widget.args));
    if (state.phase.isBusy || state.phase.isSpeaking) return;
    _composer.clear();
    ref.read(feynmanControllerProvider(widget.args).notifier).submitTyped(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(feynmanControllerProvider(widget.args));
    final phase = state.phase;
    final busy = phase.isBusy;
    final canSend = !busy && !phase.isSpeaking;

    // Auto-scroll whenever a turn (or the thinking row) is appended.
    final rowCount = state.transcript.length + (busy ? 1 : 0);
    if (rowCount != _lastCount) {
      _lastCount = rowCount;
      _scrollToBottom();
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header: back-to-voice · concept · timer · end ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to voice',
                      onPressed: widget.onExitToVoice,
                      icon: Icon(
                        Icons.graphic_eq_rounded,
                        color: p.textSecondary,
                      ),
                    ),
                    Flexible(
                      child: StatusPill(
                        concept: state.conceptName,
                        version: state.version,
                        recording: false,
                      ),
                    ),
                    const Spacer(),
                    ElapsedTimer(start: state.startedAt),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: widget.ending ? null : widget.onEnd,
                      child: widget.ending
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.accent,
                              ),
                            )
                          : Text(
                              'End',
                              style: text.labelLarge?.copyWith(color: p.accent),
                            ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: p.hairline),

              // ── Transcript ──
              Expanded(
                child: state.transcript.isEmpty
                    ? Center(
                        child: Text(
                          'Type your explanation to begin.',
                          style: text.bodyMedium?.copyWith(
                            color: p.textTertiary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: state.transcript.length + (busy ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= state.transcript.length) {
                            return const _ThinkingBubble();
                          }
                          return TranscriptBubble(entry: state.transcript[i]);
                        },
                      ),
              ),

              // ── Composer ──
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border(
                    top: BorderSide(color: p.hairline, width: 0.5),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  12,
                  10,
                  12,
                  10 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        cursorColor: p.accent,
                        style: text.bodyLarge,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Explain it simply…',
                          filled: true,
                          fillColor: p.bg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: p.hairline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: p.hairline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: p.accent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: canSend ? _send : null,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: canSend ? p.accent : p.hairline,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "student is thinking" placeholder shown at the tail of the chat while a
/// reply is in flight — mirrors the student bubble layout with a small orb.
class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 32, bottom: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: OrbBadge(size: 30),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: p.hairline, width: 0.5),
              ),
              child: SizedBox(
                width: 32,
                child: Text(
                  '…',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: p.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptionArea extends StatelessWidget {
  const _CaptionArea({required this.state});

  final FeynmanState state;

  @override
  Widget build(BuildContext context) {
    final phase = state.phase;
    // While the student speaks, surface its question; otherwise the learner's
    // live words.
    if (phase is StudentSpeakingPhase) {
      return LiveCaption(text: phase.question);
    }
    return LiveCaption(text: state.caption, dimmed: phase.isBusy);
  }
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.phase,
    required this.onRetryTurn,
    required this.onRetryListening,
  });

  final FeynmanPhase phase;
  final Future<void> Function() onRetryTurn;
  final Future<void> Function() onRetryListening;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    if (phase is SessionErrorPhase) {
      final err = phase as SessionErrorPhase;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              err.message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: err.retryListening ? onRetryListening : onRetryTurn,
              icon: Icon(Icons.refresh_rounded, size: 18, color: p.accent),
              label: Text(
                'Try again',
                style: text.labelMedium?.copyWith(color: p.accent),
              ),
            ),
          ],
        ),
      );
    }

    final label = switch (phase.orbMode) {
      OrbMode.idle => 'Tap the orb to explain',
      OrbMode.listening => 'Listening — tap again when you’re done',
      OrbMode.thinking => 'Your coach is weighing your explanation…',
      OrbMode.speaking => 'Your coach is responding…',
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        label,
        key: ValueKey(label),
        style: text.labelMedium?.copyWith(color: p.textTertiary),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: GlassPanel(
            padding: const EdgeInsets.all(14),
            radius: 16,
            child: Icon(icon, size: 20, color: p.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _EndButton extends StatelessWidget {
  const _EndButton({required this.onTap, required this.busy});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'End session and review',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.accent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'End & review',
                      style: text.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
