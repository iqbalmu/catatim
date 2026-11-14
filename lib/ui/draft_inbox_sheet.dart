import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
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

  late Stream<List<Draft>> _draftsStream;

  @override
  void initState() {
    super.initState();
    _repo.purgeNonTransactionDrafts(widget.pipeline.engine);
    _draftsStream = _repo.watchDrafts();
  }

  @override
  void didUpdateWidget(covariant DraftInboxView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _draftsStream = _repo.watchDrafts();
    }
  }

  Future<String> _bankName(String bankId) async {
    if (bankId == 'paste') return 'Tempelan / Struk';
    if (bankId.startsWith('app:')) {
      final customs = await _customNames;
      return customs[bankId] ?? bankId.substring(4);
    }
    return widget.ruleSet.bank(bankId)?.displayName ?? bankId;
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
    unawaited(HapticFeedback.lightImpact());
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
        'Beres! Transaksinya masuk pembukuan!',
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
              'Mau diapain draf ini?',
              style: sheetContext.qSmall().copyWith(
                color: sheetContext.q.muted,
              ),
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
      unawaited(HapticFeedback.lightImpact());
      await _repo.discardDrafts([draft.id]);
      if (mounted) {
        questSnack(context, 'Draf transaksi diabaikan.');
      }
    } else if (result == 'always' && mounted) {
      unawaited(HapticFeedback.mediumImpact());
      final pattern = await _repo.discardDraftAndLearnPattern(draft);
      await widget.pipeline.refreshRules();
      if (mounted) {
        questSnack(
          context,
          'Beres! Pola "$pattern" diabaikan seterusnya.',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    }
  }

  Future<void> _openTransferPair(InternalTransferPair pair) async {
    final fromName = await _bankName(pair.outDraft.bankId);
    final toName = await _bankName(pair.inDraft.bankId);
    if (!mounted) return;

    final rawText =
        (pair.outDraft.rawBody ??
                pair.inDraft.rawBody ??
                pair.outDraft.rawTitle ??
                pair.inDraft.rawTitle ??
                '')
            .trim();

    await showQuestSheet<void>(
      context,
      (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sheetContext.q.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 22,
                    color: sheetContext.q.primary,
                  ),
                ),
                const SizedBox(width: Spacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer Antar Akun',
                        style: sheetContext.qTitle(16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pindah saldo antar rekening sendiri',
                        style: sheetContext.qSmall().copyWith(
                          color: sheetContext.q.muted,
                        ),
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
                color: sheetContext.q.bg,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(
                  color: sheetContext.q.line.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Dari (Akun Asal)', style: sheetContext.qSmall()),
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
                      Text('Ke (Akun Tujuan)', style: sheetContext.qSmall()),
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
                      Text('Nominal Transfer', style: sheetContext.qSmall()),
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
            if (rawText.isNotEmpty) ...[
              const SizedBox(height: Spacing.m),
              Container(
                padding: const EdgeInsets.all(Spacing.m),
                decoration: BoxDecoration(
                  color: sheetContext.q.bg,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  border: Border.all(
                    color: sheetContext.q.line.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          size: 15,
                          color: sheetContext.q.muted,
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'Pesan Notifikasi Asli',
                          style: sheetContext
                              .qSmall(11.5)
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                color: sheetContext.q.muted,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xs),
                    SelectableText(
                      rawText,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: sheetContext.q.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.s),
            Text(
              'Kedua draf disatukan jadi transfer — nggak dihitung sebagai pengeluaran baru di anggaran/laporan.',
              style: sheetContext
                  .qSmall(11.5)
                  .copyWith(color: sheetContext.q.muted),
            ),
            const SizedBox(height: Spacing.m),
            QuestButton(
              label: 'Konfirmasi Transfer',
              icon: Icons.check_rounded,
              onPressed: () async {
                await _repo.confirmTransferPair(pair: pair);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) {
                  questSnack(context, 'Transfer antar akun dicatat.');
                }
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
                      await _repo.discardDrafts([
                        pair.outDraft.id,
                        pair.inDraft.id,
                      ]);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (mounted) {
                        questSnack(context, 'Draf transfer diabaikan.');
                      }
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

  Future<void> _openDraftDetail(Draft draft) async {
    final bankName = await _bankName(draft.bankId);
    if (!mounted) return;

    final incoming = draft.direction == Direction.incoming;
    final isUnparsed = draft.amount == 0;
    final counterparty = (draft.counterparty ?? '').trim();

    final String titleText;
    if (counterparty.isNotEmpty) {
      titleText = counterparty;
    } else if (isUnparsed) {
      final rawTitle = draft.rawTitle?.trim() ?? '';
      titleText = rawTitle.isNotEmpty ? rawTitle : 'Format Belum Dikenali';
    } else if (incoming) {
      titleText = 'Dana Masuk';
    } else if (draft.kind == TxKind.payment) {
      titleText = 'Pembayaran';
    } else if (draft.kind == TxKind.transfer) {
      titleText = 'Transfer Keluar';
    } else {
      titleText = 'Transaksi';
    }

    final rawTitle = (draft.rawTitle ?? '').trim();
    final rawBody = (draft.rawBody ?? '').trim();
    final now = DateTime.now();
    final day = DateTime(
      draft.occurredAt.year,
      draft.occurredAt.month,
      draft.occurredAt.day,
    );
    final time =
        '${draft.occurredAt.hour.toString().padLeft(2, '0')}:'
        '${draft.occurredAt.minute.toString().padLeft(2, '0')}';

    await showQuestSheet<void>(context, (sheetContext) {
      final q = sheetContext.q;
      final Color directionColor = isUnparsed
          ? q.warn
          : (incoming ? q.good : q.bad);
      final IconData directionIcon = isUnparsed
          ? Icons.help_outline_rounded
          : (incoming
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded);

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: directionColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(directionIcon, size: 22, color: directionColor),
                ),
                const SizedBox(width: Spacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: sheetContext.qTitle(16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$bankName · ${idRelativeDay(day, now)} $time',
                        style: sheetContext.qSmall().copyWith(color: q.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.m),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.m,
                vertical: Spacing.s,
              ),
              decoration: BoxDecoration(
                color: q.bg,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: q.line.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nominal',
                    style: sheetContext.qSmall().copyWith(color: q.muted),
                  ),
                  if (isUnparsed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: q.warn.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'Isi nominal saat mencatat',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: q.warn,
                        ),
                      ),
                    )
                  else
                    QuestMoney(
                      amount: draft.amount,
                      tone: incoming ? MoneyTone.incoming : MoneyTone.outgoing,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: directionColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.m),

            if (rawBody.isNotEmpty || rawTitle.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(Spacing.m),
                decoration: BoxDecoration(
                  color: q.bg,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  border: Border.all(color: q.line.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          size: 15,
                          color: q.muted,
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'Pesan Notifikasi Asli',
                          style: sheetContext
                              .qSmall(11.5)
                              .copyWith(
                                fontWeight: FontWeight.w700,
                                color: q.muted,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xs),
                    if (rawTitle.isNotEmpty && rawTitle != titleText) ...[
                      Text(
                        rawTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    SelectableText(
                      rawBody.isNotEmpty ? rawBody : rawTitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: q.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.l),
            ] else ...[
              const SizedBox(height: Spacing.s),
            ],

            if (!isUnparsed) ...[
              QuestButton(
                label: 'Catat Transaksi',
                icon: Icons.check_rounded,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _confirmDraftQuick(draft);
                },
              ),
              const SizedBox(height: Spacing.s),
              Row(
                children: [
                  Expanded(
                    child: QuestButton(
                      label: 'Ubah Detail',
                      icon: Icons.edit_note_rounded,
                      tone: QuestTone.secondary,
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openDraft(draft);
                      },
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: QuestButton(
                      label: 'Abaikan',
                      icon: Icons.close_rounded,
                      tone: QuestTone.secondary,
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _discardDraftQuick(draft);
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              QuestButton(
                label: 'Lengkapi & Catat',
                icon: Icons.edit_rounded,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _openDraft(draft);
                },
              ),
              const SizedBox(height: Spacing.s),
              QuestButton(
                label: 'Abaikan Notifikasi Ini',
                icon: Icons.close_rounded,
                tone: QuestTone.secondary,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _discardDraftQuick(draft);
                },
              ),
            ],
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Draft>>(
      stream: _draftsStream,
      builder: (context, draftSnap) {
        final drafts = draftSnap.data ?? const <Draft>[];
        final validDrafts = drafts.where((d) {
          final text =
              '${d.rawTitle ?? ''} ${d.rawBody ?? ''} ${d.counterparty ?? ''}'
                  .trim();
          return !widget.pipeline.engine.isIgnored(text, bankId: d.bankId);
        }).toList();
        final partitioned = LedgerRepository.partitionDrafts(validDrafts);
        final pairs = partitioned.pairs;
        final singles = partitioned.singles;

        if (validDrafts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(Spacing.l),
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
            Spacing.s,
            Spacing.m,
            Spacing.m,
          ),
          children: [
            for (var i = 0; i < pairs.length; i++)
              FutureBuilder<String>(
                future: _bankName(pairs[i].outDraft.bankId),
                builder: (context, fromSnap) => FutureBuilder<String>(
                  future: _bankName(pairs[i].inDraft.bankId),
                  builder: (context, toSnap) => _TransferPairTile(
                    pair: pairs[i],
                    fromBankName: fromSnap.data ?? pairs[i].outDraft.bankId,
                    toBankName: toSnap.data ?? pairs[i].inDraft.bankId,
                    onTap: () => _openTransferPair(pairs[i]),
                  ),
                ),
              ),

            for (var i = 0; i < singles.length; i++)
              FutureBuilder<String>(
                future: _bankName(singles[i].bankId),
                builder: (context, nameSnap) => _DraftTile(
                  draft: singles[i],
                  bankName: nameSnap.data ?? singles[i].bankId,
                  onTap: () => _openDraftDetail(singles[i]),
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
  });

  final InternalTransferPair pair;
  final String fromBankName;
  final String toBankName;
  final VoidCallback onTap;

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

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: q.line.withValues(alpha: 0.6)),
      ),
      child: QuestPress(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.m),
          child: Row(
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
              const SizedBox(width: Spacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: q.muted.withValues(alpha: 0.4),
              ),
            ],
          ),
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
  });

  final Draft draft;
  final String bankName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final incoming = draft.direction == Direction.incoming;
    final counterparty = (draft.counterparty ?? '').trim();
    final isUnparsed = draft.amount == 0;
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
    } else if (isUnparsed) {
      final rawTitle = draft.rawTitle?.trim() ?? '';
      titleText = rawTitle.isNotEmpty ? rawTitle : 'Format Belum Dikenali';
    } else if (incoming) {
      titleText = 'Dana Masuk';
    } else if (draft.kind == TxKind.payment) {
      titleText = 'Pembayaran';
    } else if (draft.kind == TxKind.transfer) {
      titleText = 'Transfer Keluar';
    } else {
      titleText = 'Transaksi';
    }

    final Color directionColor = isUnparsed
        ? q.warn
        : (incoming ? q.good : q.bad);
    final IconData directionIcon = isUnparsed
        ? Icons.help_outline_rounded
        : (incoming
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: q.line.withValues(alpha: 0.6)),
      ),
      child: QuestPress(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.m),
          child: Row(
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
                  ],
                ),
              ),
              const SizedBox(width: Spacing.s),
              if (isUnparsed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: q.warn.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Isi nominal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: q.warn,
                    ),
                  ),
                )
              else
                QuestMoney(
                  amount: draft.amount,
                  tone: incoming ? MoneyTone.incoming : MoneyTone.outgoing,
                  alignment: Alignment.centerRight,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: directionColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(width: Spacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: q.muted.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
