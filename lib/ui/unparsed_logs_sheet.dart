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

  late Stream<List<CaptureLog>> _logsStream;

  @override
  void initState() {
    super.initState();
    _logsStream = widget.repository.watchCaptureLog(limit: 100);
  }

  @override
  void didUpdateWidget(covariant UnparsedLogsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _logsStream = widget.repository.watchCaptureLog(limit: 100);
    }
  }

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
            ? 'Beres! $created draf baru dari pemindaian ulang!'
            : 'Belum ada notifikasi yang cocok.',
        icon: created > 0
            ? Icons.check_circle_rounded
            : Icons.info_outline_rounded,
      );
    } catch (e) {
      if (mounted) {
        questSnack(
          context,
          'Yah, gagal pindai ulang: $e',
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
          stream: _logsStream,
          builder: (context, snapshot) {
            final allLogs = snapshot.data ?? const <CaptureLog>[];
            final unparsed = allLogs
                .where((l) => !l.parsed && !l.ignoredDup)
                .toList();

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                Spacing.m,
                Spacing.xs,
                Spacing.m,
                Spacing.l,
              ),
              children: [
                // Header Ramping
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Format Belum Dikenali',
                            style: context.qTitle(),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Notifikasi yang belum cocok dengan aturan bank',
                            style: context.qSmall().copyWith(color: q.muted),
                          ),
                        ],
                      ),
                    ),
                    if (unparsed.isNotEmpty) ...[
                      QuestPress(
                        onTap: _isReparsing ? null : _reparseAll,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: q.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: q.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 14,
                                color: _isReparsing ? q.muted : q.text,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isReparsing ? 'Memindai...' : 'Pindai Ulang',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _isReparsing ? q.muted : q.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.xs),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
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
                            size: 44,
                            color: q.good,
                          ),
                          const SizedBox(height: Spacing.s),
                          Text(
                            'Semua notifikasi telah terbaca!',
                            style: context.qTitle(15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Belum ada notifikasi bank yang tertinggal atau gagal kebaca.',
                            style: context.qSmall().copyWith(color: q.muted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${unparsed.length} notifikasi belum diproses',
                        style: context.qSmall(11.5).copyWith(color: q.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  for (final log in unparsed) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: Spacing.s),
                      decoration: BoxDecoration(
                        color: q.surface,
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        border: Border.all(
                          color: q.line.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: q.surface2,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                  child: Text(
                                    log.packageName.isEmpty
                                        ? 'Tempel / SMS'
                                        : (log.packageName.contains('.')
                                              ? log.packageName.split('.').last
                                              : log.packageName),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: q.muted,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  idDateTime(log.postedAt),
                                  style: context
                                      .qSmall(10.5)
                                      .copyWith(color: q.muted),
                                ),
                              ],
                            ),
                            const SizedBox(height: Spacing.xs),
                            if (log.title.isNotEmpty &&
                                log.title != log.body) ...[
                              Text(
                                log.title,
                                style: context.qTitle(13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              log.body,
                              style: context.qSmall().copyWith(
                                color: q.text.withValues(alpha: 0.85),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: Spacing.s),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                QuestPress(
                                  onTap: () async {
                                    await widget.repository.deleteCaptureLog(
                                      log.id,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      'Abaikan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: q.muted,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.xs),
                                QuestPress(
                                  onTap: () async {
                                    await CaptureTuneSheet.show(
                                      context,
                                      log: log,
                                      repository: widget.repository,
                                      pipeline: widget.pipeline,
                                      ruleSet: widget.ruleSet,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: q.primary.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.tune_rounded,
                                          size: 14,
                                          color: q.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Latih Pola',
                                          style: TextStyle(
                                            color: q.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
        );
      },
    );
  }
}
