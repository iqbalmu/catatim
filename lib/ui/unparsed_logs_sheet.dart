import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'capture_tune_sheet.dart';
import 'quest.dart';

/// Sheet daftar notifikasi yang belum dikenali polanya (unparsed captures).
class UnparsedLogsSheet extends StatefulWidget {
  const UnparsedLogsSheet({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;

  static Future<void> show(
    BuildContext context, {
    required LedgerRepository repository,
    required CapturePipeline pipeline,
    required RuleSet ruleSet,
  }) {
    return showQuestSheet<void>(
      context,
      (ctx) => UnparsedLogsSheet(
        repository: repository,
        pipeline: pipeline,
        ruleSet: ruleSet,
      ),
    );
  }

  @override
  State<UnparsedLogsSheet> createState() => _UnparsedLogsSheetState();
}

class _UnparsedLogsSheetState extends State<UnparsedLogsSheet> {
  bool _isReparsing = false;

  Future<void> _reparseAll() async {
    if (_isReparsing) return;
    setState(() => _isReparsing = true);

    try {
      final connected = await widget.repository.connectedBankIds();
      final customs = await widget.repository.customBanks();
      final activeIds = {
        ...connected,
        for (final c in customs) 'app:${c.package}',
      };

      final created = await widget.repository.reparseUnparsed(
        widget.pipeline.engine,
        connectedBankIds: activeIds,
      );

      if (!mounted) return;
      questSnack(
        context,
        created > 0
            ? '$created draf baru berhasil dibuat dari pemindaian ulang!'
            : 'Tidak ada notifikasi baru yang cocok.',
        icon: created > 0
            ? Icons.check_circle_rounded
            : Icons.info_outline_rounded,
      );
    } catch (e) {
      if (mounted) {
        questSnack(
          context,
          'Gagal memindai ulang: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isReparsing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return StreamBuilder<List<CaptureLog>>(
          stream: widget.repository.watchCaptureLog(limit: 100),
          builder: (context, snapshot) {
            final allLogs = snapshot.data ?? const <CaptureLog>[];
            final unparsed = allLogs
                .where((l) => !l.parsed && !l.ignoredDup)
                .toList();

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                Spacing.l,
                Spacing.xs,
                Spacing.l,
                Spacing.xl,
              ),
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifikasi Belum Terbaca',
                            style: context.qTitle(18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pilih notifikasi untuk melihat detail atau membuat aturan kustom.',
                            style: context.qSmall(12).copyWith(color: q.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.m),

                // Tombol Pindai Ulang
                QuestButton(
                  label: _isReparsing
                      ? 'Memindai Ulang...'
                      : 'Pindai Ulang Semua Notifikasi',
                  icon: Icons.refresh_rounded,
                  tone: QuestTone.secondary,
                  onPressed: (_isReparsing || unparsed.isEmpty)
                      ? null
                      : _reparseAll,
                ),
                const SizedBox(height: Spacing.m),

                if (unparsed.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 48,
                            color: q.good,
                          ),
                          const SizedBox(height: Spacing.s),
                          Text(
                            'Semua notifikasi telah terbaca!',
                            style: context.qTitle(15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tidak ada notifikasi bank yang tertinggal atau gagal terbaca.',
                            style: context.qSmall(12).copyWith(color: q.muted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    '${unparsed.length} NOTIFIKASI TERTUNDA',
                    style: context
                        .qSmall(11.5)
                        .copyWith(color: q.muted, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: Spacing.s),
                  QuestCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < unparsed.length; i++) ...[
                          QuestListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: q.surface2,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.mark_email_unread_rounded,
                                color: q.warn,
                                size: 19,
                              ),
                            ),
                            title: Text(
                              unparsed[i].title.isNotEmpty
                                  ? unparsed[i].title
                                  : unparsed[i].body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.qTitle(13.5),
                            ),
                            subtitle: Text(
                              '${idDateTime(unparsed[i].postedAt)} · ${unparsed[i].packageName.isEmpty ? 'Manual/Tempel' : unparsed[i].packageName}\n${unparsed[i].body}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: q.muted),
                            ),
                            trailing: Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: q.primary,
                            ),
                            onTap: () async {
                              final updated = await CaptureTuneSheet.show(
                                context,
                                log: unparsed[i],
                                repository: widget.repository,
                                pipeline: widget.pipeline,
                                ruleSet: widget.ruleSet,
                              );
                              if (updated == true && mounted) {
                                // Refresh stream otomatis via database
                              }
                            },
                          ),
                          if (i < unparsed.length - 1)
                            Divider(height: 1, thickness: 1, color: q.line),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
