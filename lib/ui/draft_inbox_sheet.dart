import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../game/progress.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import 'transaction_sheet.dart';

/// Modal bottom sheet untuk melihat dan mengelola draf tangkapan bank.
class DraftInboxSheet extends StatelessWidget {
  const DraftInboxSheet({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    this.progress,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final ProgressService? progress;

  static Future<void> show(
    BuildContext context, {
    required LedgerRepository repository,
    required CapturePipeline pipeline,
    required RuleSet ruleSet,
    ProgressService? progress,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: context.q.bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Spacing.xs),
              const Center(child: QuestGrabber()),
              Expanded(
                child: DraftInboxView(
                  repository: repository,
                  pipeline: pipeline,
                  ruleSet: ruleSet,
                  progress: progress,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraftInboxView(
      repository: repository,
      pipeline: pipeline,
      ruleSet: ruleSet,
      progress: progress,
    );
  }
}

/// Tampilan daftar draf notifikasi bank yang tertangkap (bisa ditempatkan di tab atau sheet).
class DraftInboxView extends StatefulWidget {
  const DraftInboxView({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    this.progress,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final ProgressService? progress;

  @override
  State<DraftInboxView> createState() => _DraftInboxViewState();
}

class _DraftInboxViewState extends State<DraftInboxView> {
  late final Future<Map<String, String>> _customNames = widget.repository
      .customBanks()
      .then((list) => {for (final c in list) 'app:${c.package}': c.label});

  LedgerRepository get _repo => widget.repository;

  Future<String> _bankName(String bankId) async {
    if (bankId == 'paste') return 'Tempelan / Struk';
    if (bankId.startsWith('app:')) {
      final customs = await _customNames;
      return customs[bankId] ?? bankId.substring(4);
    }
    return widget.ruleSet.bank(bankId)?.displayName ?? bankId;
  }

  Future<void> _discardAllDrafts(List<Draft> drafts) async {
    final sure = await showQuestDialog<bool>(
      context,
      title: 'Abaikan semua draf?',
      content: Text(
        'Ada ${drafts.length} draf yang belum dicatat. Semua draf akan dihapus dari daftar.',
        style: context.qBody(13),
      ),
      actions: [
        QuestButton(
          label: 'Abaikan Semua',
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (sure == true && mounted) {
      await _repo.discardDrafts(drafts.map((d) => d.id));
      if (mounted) {
        questSnack(context, '${drafts.length} draf berhasil diabaikan.');
      }
    }
  }

  void _openDraft(Draft draft) {
    TransactionSheet.show(
      context,
      _repo,
      draft: draft,
      progress: widget.progress,
    );
  }

  Future<void> _confirmDraftQuick(Draft draft) async {
    HapticFeedback.lightImpact();
    await _repo.confirmDraft(
      draft,
      amount: draft.amount,
      direction: draft.direction,
      kind: draft.kind,
      counterparty: draft.counterparty,
      categoryId: draft.categoryId,
      accountId: draft.accountId,
      occurredAt: draft.occurredAt,
    );
    await widget.progress?.onTransactionRecorded();
    if (mounted) {
      questSnack(
        context,
        'Transaksi berhasil dicatat ke pembukuan!',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  Future<void> _discardDraftQuick(Draft draft) async {
    final result = await showQuestSheet<String>(
      context,
      (sheetContext) => Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const QuestGrabber(),
            const SizedBox(height: Spacing.s),
            Text('Abaikan Notifikasi', style: sheetContext.qTitle(16)),
            const SizedBox(height: Spacing.xs),
            Text(
              'Pilih perlakuan untuk draf notifikasi ini:',
              style:
                  sheetContext.qSmall(12).copyWith(color: sheetContext.q.muted),
            ),
            const SizedBox(height: Spacing.m),
            QuestListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: sheetContext.q.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: sheetContext.q.muted,
                  size: 20,
                ),
              ),
              title: const Text('Abaikan Draf Ini Saja'),
              subtitle: const Text('Hapus dari daftar saat ini.'),
              onTap: () => Navigator.pop(sheetContext, 'once'),
            ),
            const SizedBox(height: Spacing.xs),
            QuestListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: sheetContext.q.bad.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.block_rounded,
                  color: sheetContext.q.bad,
                  size: 20,
                ),
              ),
              title: const Text('Abaikan Pola Ini Seterusnya'),
              subtitle: const Text(
                'Otomatis buang notifikasi serupa di masa depan tanpa membuat draf.',
              ),
              onTap: () => Navigator.pop(sheetContext, 'always'),
            ),
          ],
        ),
      ),
    );

    if (result == 'once' && mounted) {
      HapticFeedback.lightImpact();
      await _repo.discardDrafts([draft.id]);
      if (mounted) {
        questSnack(context, 'Draf transaksi diabaikan.');
      }
    } else if (result == 'always' && mounted) {
      HapticFeedback.mediumImpact();
      final pattern = await _repo.discardDraftAndLearnPattern(draft);
      await widget.pipeline.refreshRules();
      if (mounted) {
        questSnack(
          context,
          'Pola "$pattern" berhasil diabaikan seterusnya.',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    }
  }

  Future<void> _confirmTransferPairQuick(InternalTransferPair pair) async {
    HapticFeedback.lightImpact();
    await _repo.confirmTransferPair(pair: pair);
    if (mounted) {
      questSnack(
        context,
        'Transfer antar akun berhasil dicatat!',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  Future<void> _discardTransferPairQuick(InternalTransferPair pair) async {
    HapticFeedback.lightImpact();
    await _repo.discardDrafts([pair.outDraft.id, pair.inDraft.id]);
    if (mounted) {
      questSnack(context, 'Draf transfer diabaikan.');
    }
  }

  Future<void> _openTransferPair(InternalTransferPair pair) async {
    final fromName = await _bankName(pair.outDraft.bankId);
    final toName = await _bankName(pair.inDraft.bankId);
    if (!mounted) return;

    await showQuestSheet<void>(
      context,
      (sheetContext) => Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: sheetContext.q.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    color: sheetContext.q.primary,
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer Antar Akun',
                        style: sheetContext.qTitle(16),
                      ),
                      Text(
                        'Pindah saldo antar rekening sendiri',
                        style: sheetContext.qSmall(12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.m),
            Container(
              padding: const EdgeInsets.all(Spacing.m),
              decoration: BoxDecoration(
                color: sheetContext.q.surface,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: sheetContext.q.line),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Dari (Akun Asal)', style: sheetContext.qSmall(12)),
                      Text(
                        fromName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ke (Akun Tujuan)', style: sheetContext.qSmall(12)),
                      Text(
                        toName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const Divider(height: Spacing.l),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nominal Transfer', style: sheetContext.qSmall(12)),
                      QuestMoney(
                        amount: pair.amount,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: sheetContext.q.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.s),
            Text(
              'Kedua draf akan disatukan sebagai transfer dan tidak dihitung sebagai pengeluaran baru di anggaran/laporan.',
              style: sheetContext.qSmall(11.5).copyWith(color: sheetContext.q.muted),
            ),
            const SizedBox(height: Spacing.m),
            QuestButton(
              label: 'Konfirmasi Transfer',
              icon: Icons.check_rounded,
              onPressed: () async {
                await _repo.confirmTransferPair(pair: pair);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) questSnack(context, 'Transfer antar akun dicatat.');
              },
            ),
            const SizedBox(height: Spacing.s),
            Row(
              children: [
                Expanded(
                  child: QuestButton(
                    label: 'Buka Terpisah',
                    tone: QuestTone.secondary,
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openDraft(pair.outDraft);
                    },
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Expanded(
                  child: QuestButton(
                    label: 'Abaikan Keduanya',
                    tone: QuestTone.secondary,
                    onPressed: () async {
                      await _repo.discardDrafts([pair.outDraft.id, pair.inDraft.id]);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (mounted) questSnack(context, 'Draf transfer diabaikan.');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return StreamBuilder<List<Draft>>(
      stream: _repo.watchDrafts(),
      builder: (context, draftSnap) {
        final drafts = draftSnap.data ?? const <Draft>[];
        final nonTxDrafts = drafts.where((d) {
          final text =
              '${d.rawTitle ?? ''} ${d.rawBody ?? ''} ${d.counterparty ?? ''}'
                  .trim();
          return widget.pipeline.engine.isIgnored(
                text,
                bankId: d.bankId,
              ) ||
              d.amount == 0;
        }).toList();
        final partitioned = LedgerRepository.partitionDrafts(drafts);
        final pairs = partitioned.pairs;
        final singles = partitioned.singles;

        if (drafts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.l),
              child: QuestEmpty(
                title: 'Belum ada tangkapan baru',
                hint:
                    'Notifikasi SMS atau m-banking yang masuk akan otomatis tampil di sini untuk kamu konfirmasi.',
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.m,
            Spacing.xs,
            Spacing.m,
            Spacing.m,
          ),
          children: [
            // Sub-header draf
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${drafts.length} tangkapan belum dicatat',
                  style: context.qSmall(11.5).copyWith(color: q.muted),
                ),
                if (drafts.length > 1)
                  QuestPress(
                    onTap: () => _discardAllDrafts(drafts),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Abaikan Semua',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: q.bad,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xs),

            // Banner deteksi bukan transaksi (ringkas sebaris)
            if (nonTxDrafts.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: Spacing.s),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.m,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: q.surface,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  border: Border.all(
                    color: q.warn.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cleaning_services_rounded,
                      color: q.warn,
                      size: 16,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: Text(
                        '${nonTxDrafts.length} pesan non-transaksi (OTP / promo)',
                        style: context.qSmall(11.5).copyWith(color: q.text),
                      ),
                    ),
                    QuestPress(
                      onTap: () async {
                        final purged = await _repo.purgeNonTransactionDrafts(
                          widget.pipeline.engine,
                        );
                        if (!context.mounted) return;
                        questSnack(
                          context,
                          '$purged draf bukan transaksi dibersihkan.',
                          icon: Icons.check_circle_outline_rounded,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          'Bersihkan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: q.warn,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Pairs
            for (var i = 0; i < pairs.length; i++)
              FutureBuilder<String>(
                future: _bankName(pairs[i].outDraft.bankId),
                builder: (context, fromSnap) =>
                    FutureBuilder<String>(
                  future: _bankName(pairs[i].inDraft.bankId),
                  builder: (context, toSnap) => _TransferPairTile(
                    pair: pairs[i],
                    fromBankName:
                        fromSnap.data ?? pairs[i].outDraft.bankId,
                    toBankName:
                        toSnap.data ?? pairs[i].inDraft.bankId,
                    onTap: () => _openTransferPair(pairs[i]),
                    onConfirm: () =>
                        _confirmTransferPairQuick(pairs[i]),
                    onDiscard: () =>
                        _discardTransferPairQuick(pairs[i]),
                  ),
                ),
              ),

            // Singles
            for (var i = 0; i < singles.length; i++)
              FutureBuilder<String>(
                future: _bankName(singles[i].bankId),
                builder: (context, nameSnap) => _DraftTile(
                  draft: singles[i],
                  bankName: nameSnap.data ?? singles[i].bankId,
                  onTap: () => _openDraft(singles[i]),
                  onConfirm: () =>
                      _confirmDraftQuick(singles[i]),
                  onDiscard: () =>
                      _discardDraftQuick(singles[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TransferPairTile extends StatelessWidget {
  const _TransferPairTile({
    required this.pair,
    required this.fromBankName,
    required this.toBankName,
    required this.onTap,
    required this.onConfirm,
    required this.onDiscard,
  });

  final InternalTransferPair pair;
  final String fromBankName;
  final String toBankName;
  final VoidCallback onTap;
  final VoidCallback onConfirm;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final now = DateTime.now();
    final day = DateTime(
      pair.occurredAt.year,
      pair.occurredAt.month,
      pair.occurredAt.day,
    );
    final time =
        '${pair.occurredAt.hour.toString().padLeft(2, '0')}:'
        '${pair.occurredAt.minute.toString().padLeft(2, '0')}';

    final rawText = (pair.outDraft.rawBody ??
            pair.inDraft.rawBody ??
            pair.outDraft.rawTitle ??
            pair.inDraft.rawTitle ??
            '')
        .trim();

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: q.line.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuestPress(
              onTap: onTap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: q.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: q.primary,
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$fromBankName → $toBankName',
                          style: context.qTitle(14.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transfer Antar Akun · ${idRelativeDay(day, now)} $time',
                          style: context.qSmall(11.5).copyWith(color: q.muted),
                        ),
                        if (rawText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            rawText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: q.muted.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  QuestMoney(
                    amount: pair.amount,
                    alignment: Alignment.centerRight,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: q.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                QuestPress(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: q.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Detail',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: q.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                QuestPress(
                  onTap: onDiscard,
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
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: q.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: q.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Konfirmasi Transfer',
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
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.draft,
    required this.bankName,
    required this.onTap,
    required this.onConfirm,
    required this.onDiscard,
  });

  final Draft draft;
  final String bankName;
  final VoidCallback onTap;
  final VoidCallback onConfirm;
  final VoidCallback onDiscard;

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

    final String titleText;
    if (counterparty.isNotEmpty) {
      titleText = counterparty;
    } else if (incoming) {
      titleText = 'Dana Masuk';
    } else if (draft.kind == TxKind.payment) {
      titleText = 'Pembayaran';
    } else if (draft.kind == TxKind.transfer) {
      titleText = 'Transfer Keluar';
    } else {
      titleText = 'Transaksi';
    }

    final rawText = (draft.rawBody ?? draft.rawTitle ?? '').trim();

    final Color directionColor = incoming ? q.good : q.bad;
    final IconData directionIcon = incoming
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: q.line.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row Utama: Ikon, Info Transaksi, Nominal
            QuestPress(
              onTap: onTap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: directionColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(directionIcon, size: 18, color: directionColor),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: context.qTitle(14.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$bankName · ${idRelativeDay(day, now)} $time',
                          style: context.qSmall(11.5).copyWith(color: q.muted),
                        ),
                        if (rawText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            rawText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: q.muted.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  QuestMoney(
                    amount: draft.amount,
                    prefix: incoming ? '+' : '−',
                    alignment: Alignment.centerRight,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: directionColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.s),

            // Baris Aksi Ringan & Minimalis
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                QuestPress(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 16,
                          color: q.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ubah',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: q.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                QuestPress(
                  onTap: onDiscard,
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
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: q.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: q.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Catat',
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
    );
  }
}
