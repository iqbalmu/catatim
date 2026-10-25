import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../core/budget.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'bank_accounts_screen.dart';
import 'bon_screen.dart';
import 'quest.dart';
import 'transaction_sheet.dart';

/// Satu item perhatian di layar Notifikasi.
class _NotifItem {
  const _NotifItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// Layar Notifikasi: hal yang perlu perhatianmu SAAT INI.
///
/// Paling atas = draf transaksi dari bank terhubung yang menunggu keputusan
/// (catat / buang). Di bawahnya item perhatian lain dalam bahasa manusia —
/// tanpa istilah teknis, tanpa teks notifikasi mentah.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.progress,
    required this.ruleSet,
    required this.onOpenAnggaran,
    required this.onOpenBon,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;
  final RuleSet ruleSet;

  /// Tutup layar ini lalu alih ke tab Rencana / Bon.
  final VoidCallback onOpenAnggaran;
  final VoidCallback onOpenBon;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final Future<bool> _listenerEnabled =
      widget.pipeline.channel.isListenerEnabled();

  LedgerRepository get _repo => widget.repository;

  String _bankName(String bankId) =>
      widget.ruleSet.bank(bankId)?.displayName ?? bankId;

  void _openBankAccounts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BankAccountsScreen(
          repository: _repo,
          pipeline: widget.pipeline,
          ruleSet: widget.ruleSet,
        ),
      ),
    );
  }

  void _goTo(VoidCallback navigate) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    navigate();
  }

  void _openDraft(Draft draft) {
    TransactionSheet.show(
      context,
      _repo,
      draft: draft,
      progress: widget.progress,
    );
  }

  Future<void> _handleUnread(int count, Set<String> connected) async {
    final action = await showQuestDialog<String>(
      context,
      title: '$count belum terbaca',
      content: Text(
        'Notifikasi dari bankmu ini belum bisa dibaca otomatis. '
        'Coba baca lagi, atau catat sendiri secara manual.',
        style: context.qBody(13),
      ),
      actions: [
        QuestButton(
          label: 'Catat manual',
          icon: Icons.edit_rounded,
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, 'manual'),
        ),
        QuestButton(
          label: 'Coba baca lagi',
          icon: Icons.refresh_rounded,
          onPressed: () => Navigator.pop(context, 'retry'),
        ),
      ],
    );
    if (action == null || !mounted) return;
    if (action == 'manual') {
      TransactionSheet.show(context, _repo, progress: widget.progress);
      return;
    }
    final created = await _repo.reparseUnparsed(
      widget.pipeline.engine,
      connectedBankIds: connected,
    );
    if (!mounted) return;
    questSnack(
      context,
      created > 0
          ? '$created draf baru menunggu keputusanmu.'
          : 'Masih belum terbaca — coba catat manual.',
      icon: created > 0
          ? Icons.mark_as_unread_rounded
          : Icons.info_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Scaffold(
      backgroundColor: q.bg,
      appBar: const QuestHeader(
        title: 'Notifikasi',
        subtitle: 'Yang perlu perhatianmu',
        showBack: true,
      ),
      body: FutureBuilder<bool>(
        future: _listenerEnabled,
        builder: (context, listenerSnap) {
          final enabled = listenerSnap.data ?? false;
          return StreamBuilder<Set<String>>(
            stream: _repo.watchConnectedBanks(),
            builder: (context, connSnap) {
              final connected = connSnap.data ?? const <String>{};
              return StreamBuilder<List<Draft>>(
                stream: _repo.watchDrafts(),
                builder: (context, draftSnap) {
                  final drafts = draftSnap.data ?? const <Draft>[];
                  return StreamBuilder<List<CaptureLog>>(
                    stream: _repo.watchCaptureLog(),
                    builder: (context, logSnap) {
                      final unread = (logSnap.data ?? const <CaptureLog>[])
                          .where((l) => !l.parsed)
                          .length;
                      return StreamBuilder<List<Bon>>(
                        stream: _repo.watchBons(),
                        builder: (context, bonSnap) {
                          final bons = bonSnap.data ?? const <Bon>[];
                          final aging = bons
                              .where(
                                (b) =>
                                    b.settledAt == null &&
                                    bonNeedsBadge(b.occurredAt),
                              )
                              .length;
                          final summary = widget.progress.latest;
                          final level = summary?.snapshot.worstLevel;
                          final critical = summary?.snapshot.criticalLine;
                          final items = [
                            if (connected.isNotEmpty && !enabled)
                              _NotifItem(
                                icon: Icons.notifications_off_rounded,
                                color: q.bad,
                                title: 'Izin baca notifikasi belum nyala',
                                subtitle:
                                    'Nyalakan agar draf transaksi masuk lagi',
                                onTap: _openBankAccounts,
                              ),
                            if (unread > 0)
                              _NotifItem(
                                icon: Icons.mark_as_unread_rounded,
                                color: SeedColors.honeyDeep,
                                title: '$unread belum terbaca',
                                subtitle:
                                    'Coba baca lagi atau catat manual',
                                onTap: () =>
                                    _handleUnread(unread, connected),
                              ),
                            if (level == BudgetLevel.over)
                              _NotifItem(
                                icon: Icons.warning_amber_rounded,
                                color: q.bad,
                                title:
                                    'Batas ${critical?.label ?? 'harian'} terlampaui',
                                subtitle: 'Yuk cek batas pengeluaranmu di Anggaran',
                                onTap: () => _goTo(widget.onOpenAnggaran),
                              )
                            else if (level == BudgetLevel.warning)
                              _NotifItem(
                                icon: Icons.error_outline_rounded,
                                color: SeedColors.honeyDeep,
                                title:
                                    'Batas ${critical?.label ?? 'harian'} '
                                    'mendekati plafon',
                                subtitle: 'Yuk cek batas pengeluaranmu di Anggaran',
                                onTap: () => _goTo(widget.onOpenAnggaran),
                              ),
                            if (aging > 0)
                              _NotifItem(
                                icon: Icons.handshake_outlined,
                                color: q.bad,
                                title: '$aging bon lebih dari 30 hari '
                                    'belum lunas',
                                subtitle: 'Ingatkan dirimu atau tandai lunas',
                                onTap: () => _goTo(widget.onOpenBon),
                              ),
                          ];
                          if (drafts.isEmpty && items.isEmpty) {
                            return ListView(
                              padding: const EdgeInsets.all(Spacing.m),
                              children: [
                                QuestEmpty(
                                  title: 'Tidak ada notifikasi',
                                  hint:
                                      'Semua aman — lanjutkan aktivitasmu.',
                                ),
                              ],
                            );
                          }
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(
                              Spacing.m,
                              Spacing.s,
                              Spacing.m,
                              Spacing.m,
                            ),
                            children: [
                              if (drafts.isNotEmpty) ...[
                                const QuestSectionHeader(
                                  title: 'Menunggu keputusanmu',
                                ),
                                for (final d in drafts)
                                  _DraftTile(
                                    draft: d,
                                    bankName: _bankName(d.bankId),
                                    onTap: () => _openDraft(d),
                                  ),
                                const SizedBox(height: Spacing.s),
                              ],
                              if (items.isNotEmpty) ...[
                                const QuestSectionHeader(
                                  title: 'Perlu perhatian',
                                ),
                                for (final item in items)
                                  _AttentionTile(item: item),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.draft,
    required this.bankName,
    required this.onTap,
  });

  final Draft draft;
  final String bankName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final incoming = draft.direction == Direction.incoming;
    final counterparty = (draft.counterparty ?? '').trim();
    final now = DateTime.now();
    final day = DateTime(
      draft.occurredAt.year,
      draft.occurredAt.month,
      draft.occurredAt.day,
    );
    final time =
        '${draft.occurredAt.hour.toString().padLeft(2, '0')}:'
        '${draft.occurredAt.minute.toString().padLeft(2, '0')}';
    final initial = bankName.isEmpty
        ? '?'
        : bankName.characters.first.toUpperCase();
    return QuestPress(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.s),
        padding: Insets.tile,
        decoration: BoxDecoration(
          color: q.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          boxShadow: [
            BoxShadow(
              color: q.shadow,
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SeedColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: TextStyle(
                  color: q.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    counterparty.isEmpty ? bankName : counterparty,
                    style: context.qTitle(14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$bankName · ${idRelativeDay(day, now)} $time',
                    style: context.qSmall(11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.s),
            Text(
              '${incoming ? '+' : '−'}${Money.format(draft.amount)}',
              style: context.qAmount(15, incoming: incoming),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.item});

  final _NotifItem item;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: item.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.s),
        padding: Insets.tile,
        decoration: BoxDecoration(
          color: q.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          boxShadow: [
            BoxShadow(
              color: q.shadow,
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 19, color: item.color),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.qTitle(14)),
                  Text(item.subtitle, style: context.qSmall(11)),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: q.muted,
            ),
          ],
        ),
      ),
    );
  }
}
