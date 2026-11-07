import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/budget.dart';
import '../core/dates_id.dart';
import '../game/progress.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'bank_accounts_screen.dart';
import 'bon_screen.dart';
import 'ocr_screen.dart';
import 'quest.dart';
import 'transaction_sheet.dart';
import 'unparsed_logs_sheet.dart';
import 'package:image_picker/image_picker.dart';

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
    required this.ruleSet,
    this.progress,
    this.onOpenAnggaran,
    this.onOpenBon,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService? progress;
  final RuleSet ruleSet;

  /// Tutup layar ini lalu alih ke tab Rencana / Bon.
  final VoidCallback? onOpenAnggaran;
  final VoidCallback? onOpenBon;
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final Future<bool> _listenerEnabled = widget.pipeline.channel
      .isListenerEnabled();

  bool _showAllDrafts = false;

  /// Nama bank custom mode belajar — bankId `app:<paket>` → label.
  late final Future<Map<String, String>> _customNames = widget.repository
      .customBanks()
      .then((list) => {for (final c in list) 'app:${c.package}': c.label});

  LedgerRepository get _repo => widget.repository;

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

  Future<String> _bankName(String bankId) async {
    if (bankId == 'paste') return 'Tempelan / Struk';
    if (bankId.startsWith('app:')) {
      final customs = await _customNames;
      return customs[bankId] ?? bankId.substring(4);
    }
    return widget.ruleSet.bank(bankId)?.displayName ?? bankId;
  }

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

  void _goTo(VoidCallback? navigate) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    navigate?.call();
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
              subtitle: const Text('Hapus dari daftar draf saat ini.'),
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

  Future<void> _handleUnread(int count, Set<String> connected) async {
    await UnparsedLogsSheet.show(
      context,
      repository: _repo,
      pipeline: widget.pipeline,
      ruleSet: widget.ruleSet,
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
    return Scaffold(
      backgroundColor: q.bg,
      appBar: QuestHeader(
        title: 'Notifikasi',
        subtitle: 'Yang perlu perhatianmu',
        showBack: true,
        actions: [
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
        ],
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
                          final summary = widget.progress?.latest;
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
                                icon: Icons.help_outline_rounded,
                                color: q.warn,
                                title: '$unread notifikasi belum dikenali formatnya',
                                subtitle: 'Ketuk untuk melatih pola bank atau catat manual',
                                onTap: () => _handleUnread(unread, connected),
                              ),
                            if (level == BudgetLevel.over)
                              _NotifItem(
                                icon: Icons.warning_amber_rounded,
                                color: q.bad,
                                title:
                                    'Batas ${critical?.label ?? 'harian'} terlampaui',
                                subtitle:
                                    'Yuk cek batas pengeluaranmu di Anggaran',
                                onTap: () => _goTo(widget.onOpenAnggaran),
                              )
                            else if (level == BudgetLevel.warning)
                              _NotifItem(
                                icon: Icons.error_outline_rounded,
                                color: q.warn,
                                title:
                                    'Batas ${critical?.label ?? 'harian'} '
                                    'mendekati plafon',
                                subtitle:
                                    'Yuk cek batas pengeluaranmu di Anggaran',
                                onTap: () => _goTo(widget.onOpenAnggaran),
                              ),
                            if (aging > 0)
                              _NotifItem(
                                icon: Icons.handshake_outlined,
                                color: q.bad,
                                title:
                                    '$aging bon lebih dari 30 hari '
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
                                      'Semua aman — atau tempel teks transaksi manual.',
                                  actionLabel: 'Tempel Teks',
                                  onAction: _showPasteDialog,
                                ),
                              ],
                            );
                          }
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
                          final partitioned =
                              LedgerRepository.partitionDrafts(drafts);
                          final totalDraftCount =
                              partitioned.pairs.length +
                              partitioned.singles.length;
                          final bool shouldCollapse =
                              totalDraftCount > 4 && !_showAllDrafts;
                          final visiblePairs = shouldCollapse
                              ? partitioned.pairs.take(2).toList()
                              : partitioned.pairs;
                          final remainingSlots = shouldCollapse
                              ? (3 - visiblePairs.length).clamp(1, 4)
                              : partitioned.singles.length;
                          final visibleSingles = shouldCollapse
                              ? partitioned.singles.take(remainingSlots).toList()
                              : partitioned.singles;
                          final hiddenCount = totalDraftCount -
                              (visiblePairs.length + visibleSingles.length);

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(
                              Spacing.m,
                              Spacing.s,
                              Spacing.m,
                              Spacing.m,
                            ),
                            children: [
                              // 1. Peringatan sistem & perhatian (DI ATAS)
                              if (items.isNotEmpty) ...[
                                const QuestEnter(
                                  index: 0,
                                  child: QuestSectionHeader(
                                    title: 'Perlu perhatian',
                                  ),
                                ),
                                for (var i = 0; i < items.length; i++)
                                  QuestEnter(
                                    index: 1 + i,
                                    child: _AttentionTile(item: items[i]),
                                  ),
                                const SizedBox(height: Spacing.xs),
                              ],

                              // 2. Draf transaksi menunggu keputusan
                              if (drafts.isNotEmpty) ...[
                                QuestEnter(
                                  index: items.length + 1,
                                  child: QuestSectionHeader(
                                    title:
                                        'Menunggu keputusanmu (${drafts.length})',
                                    trailing: drafts.length > 1
                                        ? QuestPress(
                                            onTap: () =>
                                                _discardAllDrafts(drafts),
                                            child: Text(
                                              'Abaikan Semua',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: q.bad,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                if (nonTxDrafts.isNotEmpty) ...[
                                  QuestEnter(
                                    index: items.length + 2,
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        bottom: Spacing.s,
                                      ),
                                      padding: const EdgeInsets.all(Spacing.m),
                                      decoration: BoxDecoration(
                                        color: q.surface,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.tile,
                                        ),
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
                                  ),
                                ],
                                for (var i = 0; i < visiblePairs.length; i++)
                                  QuestEnter(
                                    index: items.length + 2 + i,
                                    child: FutureBuilder<String>(
                                      future: _bankName(
                                        visiblePairs[i].outDraft.bankId,
                                      ),
                                      builder: (context, fromSnap) =>
                                          FutureBuilder<String>(
                                            future: _bankName(
                                              visiblePairs[i].inDraft.bankId,
                                            ),
                                            builder: (context, toSnap) =>
                                                _TransferPairTile(
                                                  pair: visiblePairs[i],
                                                  fromBankName:
                                                      fromSnap.data ??
                                                      visiblePairs[i]
                                                          .outDraft.bankId,
                                                  toBankName:
                                                      toSnap.data ??
                                                      visiblePairs[i]
                                                          .inDraft.bankId,
                                                  onTap: () =>
                                                      _openTransferPair(
                                                        visiblePairs[i],
                                                      ),
                                                  onConfirm: () =>
                                                      _confirmTransferPairQuick(
                                                        visiblePairs[i],
                                                      ),
                                                  onDiscard: () =>
                                                      _discardTransferPairQuick(
                                                        visiblePairs[i],
                                                      ),
                                                ),
                                          ),
                                    ),
                                  ),
                                for (var i = 0;
                                    i < visibleSingles.length;
                                    i++)
                                  QuestEnter(
                                    index: items.length +
                                        2 +
                                        visiblePairs.length +
                                        i,
                                    child: FutureBuilder<String>(
                                      future: _bankName(
                                        visibleSingles[i].bankId,
                                      ),
                                      builder: (context, nameSnap) =>
                                          _DraftTile(
                                            draft: visibleSingles[i],
                                            bankName:
                                                nameSnap.data ??
                                                visibleSingles[i].bankId,
                                            onTap: () => _openDraft(
                                              visibleSingles[i],
                                            ),
                                            onConfirm: () =>
                                                _confirmDraftQuick(
                                                  visibleSingles[i],
                                                ),
                                            onDiscard: () =>
                                                _discardDraftQuick(
                                                  visibleSingles[i],
                                                ),
                                          ),
                                    ),
                                  ),
                                if (shouldCollapse && hiddenCount > 0)
                                  QuestCard(
                                    variant: QuestCardVariant.flat,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: Spacing.m,
                                    ),
                                    onTap: () =>
                                        setState(() => _showAllDrafts = true),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Tampilkan $hiddenCount draf lainnya',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: q.primaryDeep,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: q.primaryDeep,
                                        ),
                                      ],
                                    ),
                                  )
                                else if (!shouldCollapse && totalDraftCount > 4)
                                  QuestCard(
                                    variant: QuestCardVariant.flat,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: Spacing.m,
                                    ),
                                    onTap: () =>
                                        setState(() => _showAllDrafts = false),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Perkecil daftar',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: q.muted,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_up_rounded,
                                          size: 16,
                                          color: q.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: Spacing.s),
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
    final rawText = (pair.outDraft.rawBody ?? pair.inDraft.rawBody ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: q.primary.withValues(alpha: 0.3)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestPress(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: q.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TRANSFER ANTAR AKUN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: q.primaryDeep,
                            letterSpacing: 0.3,
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

    final rawText = (draft.rawBody ?? draft.rawTitle ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final badgeColor = incoming
        ? q.good
        : (draft.kind == TxKind.transfer ? q.primary : q.bad);
    final badgeLabel = incoming
        ? 'Uang Masuk'
        : (draft.kind == TxKind.transfer
            ? 'Transfer'
            : (draft.kind == TxKind.payment
                ? 'Pembayaran / QRIS'
                : 'Pengeluaran'));

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      decoration: BoxDecoration(
        color: q.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: q.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestPress(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: q.surface2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: q.line),
                        ),
                        child: Text(
                          bankName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: q.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                            letterSpacing: 0.2,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          titleText,
                          style: context.qTitle(15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
                      if (draft.amount == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: q.warnTint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Isi nominal',
                            style: context.qSmall(11).copyWith(
                              color: q.warn,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        QuestMoney(
                          amount: draft.amount,
                          prefix: incoming ? '+' : '−',
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
                            'Catat Transaksi',
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
                  message: 'Ubah kategori / akun sebelum mencatat',
                  child: QuestIconButton(
                    icon: Icons.edit_note_rounded,
                    tooltip: 'Edit & Catat',
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
            Icon(Icons.chevron_right_rounded, size: 18, color: q.muted),
          ],
        ),
      ),
    );
  }
}
