import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/dates_id.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Sheet "Notifikasi Asal" — isi mentah notifikasi yang menjadi sumber
/// transaksi/draf tercatat, persis seperti ditangkap lapisan native.
/// Berguna untuk memastikan draf tercatat dari notifikasi yang benar
/// dan menyetel template parser bila kategorinya meleset.
void showCaptureSourceSheet(
  BuildContext context, {
  required String bankLabel,
  required DateTime capturedAt,
  required String title,
  required String body,
}) {
  showQuestSheet(
    context,
    (ctx) => CaptureSourceSheet(
      bankLabel: bankLabel,
      capturedAt: capturedAt,
      title: title,
      body: body,
    ),
  );
}

class CaptureSourceSheet extends StatelessWidget {
  const CaptureSourceSheet({
    super.key,
    required this.bankLabel,
    required this.capturedAt,
    required this.title,
    required this.body,
  });

  final String bankLabel;
  final DateTime capturedAt;
  final String title;
  final String body;

  Future<void> _copy() {
    return Clipboard.setData(ClipboardData(text: '$title\n$body'));
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final timeLabel =
        '${idFullDate(capturedAt)} · '
        '${capturedAt.hour.toString().padLeft(2, '0')}:'
        '${capturedAt.minute.toString().padLeft(2, '0')}';
    final hasTitle = title.trim().isNotEmpty;
    final hasBody = body.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, Spacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: q.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  size: 20,
                  color: q.primary,
                ),
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notifikasi Asal', style: context.qTitle()),
                    Text(
                      '$bankLabel · $timeLabel',
                      style: context.qSmall(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.m),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: q.surface2,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: q.line.withValues(alpha: 0.6)),
            ),
            child: SelectableText.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13.5,
                  color: q.text,
                  height: 1.45,
                ),
                children: [
                  if (hasTitle)
                    TextSpan(
                      text: title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  if (hasTitle && hasBody) const TextSpan(text: '\n'),
                  if (hasBody)
                    TextSpan(
                      text: body,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.m),
          QuestButton(
            label: 'Salin Teks',
            icon: Icons.copy_rounded,
            tone: QuestTone.secondary,
            onPressed: () async {
              await _copy();
              if (context.mounted) {
                questSnack(context, 'Teks notifikasi disalin');
              }
            },
          ),
        ],
      ),
    );
  }
}
