import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../game/progress.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'ocr_screen.dart';
import 'quest.dart';
import 'transaction_sheet.dart';

/// Lembar Kotak Masuk Draf Transaksi dari Capture Bank / OCR / Tempel Teks.
class DraftInboxSheet extends StatefulWidget {
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
      builder: (_) => DraftInboxSheet(
        repository: repository,
        pipeline: pipeline,
        ruleSet: ruleSet,
        progress: progress,
      ),
    );
  }

  @override
  State<DraftInboxSheet> createState() => _DraftInboxSheetState();
}

class _DraftInboxSheetState extends State<DraftInboxSheet> {
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
        'Ada ${drafts.length} draf yang belum dicatat. Semua draf akan dihapus dari kotak masuk.',
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
              subtitle: const Text('Hapus dari kotak masuk saat ini.'),
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

  Future<void> _showPasteDialog() async {
    final controller = TextEditingController();
    final text = await showQuestDialog<String>(
      context,
      title: 'Tempel Teks',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tempel pesan notifikasi, SMS, atau email transaksi di sini. '
            'Bukuduit akan membacanya menjadi draf.',
            style: context.qBody(13),
          ),
          const SizedBox(height: Spacing.m),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Contoh:\nTransfer masuk Rp150.000 dari BUDI...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(Spacing.s),
            ),
          ),
        ],
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        QuestButton(
          label: 'Proses',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context, controller.text),
        ),
      ],
    );

    if (text == null || text.trim().isEmpty || !mounted) return;
    final ok = await widget.pipeline.submitPastedText(text);
    if (!mounted) return;
    questSnack(
      context,
      ok ? 'Teks berhasil diproses menjadi draf!' : 'Gagal memproses teks.',
      icon: ok
          ? Icons.check_circle_outline_rounded
          : Icons.error_outline_rounded,
    );
  }

  Future<void> _showOcrOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(Spacing.m),
        decoration: BoxDecoration(
          color: context.q.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const QuestGrabber(),
              const SizedBox(height: Spacing.s),
              Text('Pindai Struk / Bukti Transaksi', style: context.qTitle(16)),
              const SizedBox(height: Spacing.xs),
              Text(
                'Teks struk akan dipindai secara offline di perangkat.',
                style: context.qSmall(12).copyWith(color: context.q.muted),
              ),
              const SizedBox(height: Spacing.m),
              QuestListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Ambil Foto Kamera'),
                subtitle: const Text('Arahkan kamera ke struk/nota pembayaran'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              QuestListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text(
                  'Gunakan foto struk atau screenshot bukti transfer',
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    await OcrScreen.start(
      context,
      pipeline: widget.pipeline,
      pickSource: source,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: q.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: StreamBuilder<List<Draft>>(
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

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Spacing.xs),
                const Center(child: QuestGrabber()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.m,
                    Spacing.s,
                    Spacing.m,
                    Spacing.xs,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: q.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.inbox_rounded,
                          color: q.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kotak Masuk Draf (${drafts.length})',
                              style: context.qTitle(16),
                            ),
                            Text(
                              'Notifikasi bank & tangkapan menunggu keputusan',
                              style: context
                                  .qSmall(11.5)
                                  .copyWith(color: q.muted),
                            ),
                          ],
                        ),
                      ),
                      QuestIconButton(
                        icon: Icons.document_scanner_rounded,
                        tooltip: 'Foto Struk (OCR)',
                        onPressed: _showOcrOptions,
                      ),
                      QuestIconButton(
                        icon: Icons.content_paste_rounded,
                        tooltip: 'Tempel Teks',
                        onPressed: _showPasteDialog,
                      ),
                      if (drafts.length > 1)
                        QuestPress(
                          onTap: () => _discardAllDrafts(drafts),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'Abaikan Semua',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: q.bad,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: drafts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(Spacing.l),
                            child: QuestEmpty(
                              title: 'Kotak masuk bersih',
                              hint:
                                  'Semua notifikasi bank sudah dicatat atau diabaikan.',
                              actionLabel: 'Tempel Teks Transaksi',
                              onAction: _showPasteDialog,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(Spacing.m),
                          children: [
                            if (nonTxDrafts.isNotEmpty) ...[
                              Container(
                                margin:
                                    const EdgeInsets.only(bottom: Spacing.s),
                                padding: const EdgeInsets.all(Spacing.m),
                                decoration: BoxDecoration(
                                  color: q.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.tile),
                                  border: Border.all(
                                    color: q.warn.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.cleaning_services_rounded,
                                          color: q.warn,
                                          size: 18,
                                        ),
                                        const SizedBox(width: Spacing.xs),
                                        Expanded(
                                          child: Text(
                                            '${nonTxDrafts.length} pesan bukan transaksi',
                                            style: context
                                                .qTitle(13.5)
                                                .copyWith(color: q.text),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: Spacing.xs),
                                    Text(
                                      'Pesan OTP, info login, sisa saldo, atau promo terdeteksi di draf.',
                                      style: context
                                          .qSmall(11.5)
                                          .copyWith(color: q.muted),
                                    ),
                                    const SizedBox(height: Spacing.s),
                                    QuestButton(
                                      label:
                                          'Bersihkan Otomatis (${nonTxDrafts.length})',
                                      icon: Icons.auto_delete_outlined,
                                      tone: QuestTone.secondary,
                                      onPressed: () async {
                                        final purged = await _repo
                                            .purgeNonTransactionDrafts(
                                              widget.pipeline.engine,
                                            );
                                        if (!context.mounted) return;
                                        questSnack(
                                          context,
                                          '$purged draf bukan transaksi dibersihkan.',
                                          icon: Icons
                                              .check_circle_outline_rounded,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            for (var i = 0; i < pairs.length; i++)
                              FutureBuilder<String>(
                                future: _bankName(pairs[i].outDraft.bankId),
                                builder: (context, fromSnap) =>
                                    FutureBuilder<String>(
                                  future: _bankName(pairs[i].inDraft.bankId),
                                  builder: (context, toSnap) =>
                                      _TransferPairTile(
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
                            for (var i = 0; i < singles.length; i++)
                              FutureBuilder<String>(
                                future: _bankName(singles[i].bankId),
                                builder: (context, nameSnap) => _DraftTile(
                                  draft: singles[i],
                                  bankName:
                                      nameSnap.data ?? singles[i].bankId,
                                  onTap: () => _openDraft(singles[i]),
                                  onConfirm: () =>
                                      _confirmDraftQuick(singles[i]),
                                  onDiscard: () =>
                                      _discardDraftQuick(singles[i]),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
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
        border: Border.all(color: q.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestPress(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.m, 10, Spacing.m, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: q.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 13,
                              color: q.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Transfer Antar Rekening',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: q.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${idRelativeDay(day, now)} $time',
                        style: context.qSmall(10.5).copyWith(color: q.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$fromBankName → $toBankName',
                          style: context.qTitle(15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
                      QuestMoney(
                        amount: pair.amount,
                        alignment: Alignment.centerRight,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: q.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (rawText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: q.surface2.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: q.line.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.sms_outlined, size: 13, color: q.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rawText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: q.text.withValues(alpha: 0.8),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: q.line.withValues(alpha: 0.6),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: QuestPress(
                    onTap: onConfirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: q.primary,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Konfirmasi Transfer',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                QuestPress(
                  onTap: onDiscard,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: q.surface2,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: q.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, size: 14, color: q.muted),
                        const SizedBox(width: 4),
                        Text(
                          'Abaikan',
                          style: TextStyle(
                            color: q.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Tooltip(
                  message: 'Detail transfer',
                  child: QuestIconButton(
                    icon: Icons.info_outline_rounded,
                    tooltip: 'Detail',
                    onPressed: onTap,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      titleText = 'Dana Masuk $bankName';
    } else if (draft.kind == TxKind.payment) {
      titleText = 'Pembayaran $bankName';
    } else if (draft.kind == TxKind.transfer) {
      titleText = 'Transfer Keluar $bankName';
    } else {
      titleText = 'Transaksi $bankName';
    }

    final rawText = (draft.rawBody ?? draft.rawTitle ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: q.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestPress(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.m, 10, Spacing.m, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: incoming
                              ? q.good.withValues(alpha: 0.12)
                              : q.bad.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              incoming
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 11,
                              color: incoming ? q.good : q.bad,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              incoming ? 'Uang Masuk' : 'Uang Keluar',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: incoming ? q.good : q.bad,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Spacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: q.surface2,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          bankName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: q.muted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${idRelativeDay(day, now)} $time',
                        style: context.qSmall(10.5).copyWith(color: q.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titleText,
                          style: context.qTitle(14.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
                      QuestMoney(
                        amount: draft.amount,
                        alignment: Alignment.centerRight,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: incoming ? q.good : q.bad,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (rawText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: q.surface2.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: q.line.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.sms_outlined, size: 13, color: q.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rawText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: q.text.withValues(alpha: 0.8),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: q.line.withValues(alpha: 0.6),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: QuestPress(
                    onTap: onConfirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: q.primary,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            incoming ? 'Catat Pemasukan' : 'Catat Pengeluaran',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                QuestPress(
                  onTap: onDiscard,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: q.surface2,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: q.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, size: 14, color: q.muted),
                        const SizedBox(width: 4),
                        Text(
                          'Abaikan',
                          style: TextStyle(
                            color: q.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Tooltip(
                  message: 'Edit & Lengkapi',
                  child: QuestIconButton(
                    icon: Icons.edit_note_rounded,
                    tooltip: 'Edit',
                    onPressed: onTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
