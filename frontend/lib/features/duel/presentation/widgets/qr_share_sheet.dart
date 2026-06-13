import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../home/domain/mock_data.dart';
import '../../domain/duel_invite.dart';
import 'invite_qr_code.dart';

/// Present the user's QR code in a bottom sheet so a friend can scan it to
/// start a head-to-head race.
Future<void> showQrShareSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QrShareSheet(),
  );
}

class _QrShareSheet extends StatelessWidget {
  const _QrShareSheet();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final code = DuelInvite.codeFor(MockData.userName);
    final payload = DuelInvite.payloadFor(MockData.userName);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: p.hairline, width: 1),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle.
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: p.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Your race code', style: text.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Have a friend scan this to challenge you to a live race.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),
          // The code itself — framed on a clean white card, accent-haloed.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.28),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                InviteQrCode(data: payload, size: 220, foreground: p.accent),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: p.accent,
                      child: Text(
                        MockData.userName[0],
                        style: text.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      MockData.userName,
                      style: text.labelLarge?.copyWith(
                        color: const Color(0xFF12101A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Manual code fallback.
          Pressable(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Code $code copied'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: p.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.copy_rounded, size: 18, color: p.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'or share the code manually',
            style: text.labelSmall?.copyWith(color: p.textTertiary),
          ),
        ],
      ),
    );
  }
}
