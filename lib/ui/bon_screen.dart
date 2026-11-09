import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Bon tua: belum lunas dan umur kalender (today − occurredAt) > 30 hari.
bool bonNeedsBadge(DateTime occurredAt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
  return today.difference(day).inDays > 30;
}

/// Layar utama Bon & Utang-Piutang (tab navbar).
class BonScreen extends StatefulWidget {
  const BonScreen({
    super.key,
    required this.repository,
    this.progress,
    this.showBack = false,
  });

  final LedgerRepository repository;
  final ProgressService? progress;
  final bool showBack;

  @override
  State<BonScreen> createState() => _BonScreenState();
}

class _BonScreenState extends State<BonScreen> {
  int _bonSubTab = 0; // 0 = Belum Lunas, 1 = Lunas
  late final PageController _bonPageCtrl = PageController(initialPage: _bonSubTab);

  @override
  void dispose() {
    _bonPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _settleBon(Bon bon) async {
    if (bon.settledAt != null) {
      await widget.repository.updateBon(
        bon.id,
        const BonsCompanion(settledAt: Value(null)),
      );
      if (mounted) questSnack(context, 'Status lunas dibatalkan.');
      return;
    }

    final accounts = await widget.repository.getAccounts();
    if (!mounted) return;
    int? selectedAccountId = accounts.firstOrNull?.id;
    bool recordTx = accounts.isNotEmpty;

    final shouldSettle = await showQuestDialog<bool>(
      context,
      title: 'Lunasi Bon',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          final isLent = bon.direction == BonDirection.lent;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tandai bon ${bon.person} (${Money.format(bon.amount)}) sebagai lunas?',
                style: context.qBody(13),
              ),
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: Spacing.m),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: recordTx,
                  title: Text(
                    isLent
                        ? 'Catat uang masuk ke rekening'
                        : 'Catat uang keluar dari rekening',
                    style: context.qTitle(13),
                  ),
                  onChanged: (val) =>
                      setDialogState(() => recordTx = val ?? true),
                ),
                if (recordTx) ...[
                  const SizedBox(height: Spacing.xs),
                  DropdownButtonFormField<int>(
                    initialValue: selectedAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Pilih Akun'),
                    items: [
                      for (final a in accounts)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name} · ${a.kind.label}'),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedAccountId = v),
                  ),
                ],
              ],
            ],
          );
        },
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Lunasi',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (shouldSettle != true || !mounted) return;

    await widget.repository.updateBon(
      bon.id,
      BonsCompanion(settledAt: Value(DateTime.now())),
    );

    if (recordTx && selectedAccountId != null) {
      final isLent = bon.direction == BonDirection.lent;
      final otherCatId = (await widget.repository.getCategories())
          .where((c) => c.name.toLowerCase() == 'lainnya')
          .firstOrNull
          ?.id;
      await widget.repository.addManual(
        amount: bon.amount,
        direction: isLent ? Direction.incoming : Direction.outgoing,
        kind: TxKind.payment,
        counterparty: isLent
            ? 'Pelunasan piutang: ${bon.person}'
            : 'Bayar utang ke: ${bon.person}',
        accountId: selectedAccountId,
        categoryId: otherCatId,
        occurredAt: DateTime.now(),
      );
      await widget.progress?.onTransactionRecorded();
    }

    if (mounted) {
      questSnack(context, 'Bon ${bon.person} berhasil dilunasi!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            QuestTabEnter(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.m,
                  Spacing.m,
                  Spacing.m,
                  Spacing.s,
                ),
                child: Row(
                  children: [
                    if (widget.showBack) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Kembali',
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: Spacing.xs),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bon & Utang-Piutang', style: context.qTitle(20)),
                          Text(
                            'Pencatatan pinjam-meminjam dengan orang lain',
                            style: context.qSmall(12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Piutang vs Utang Summary Cards
            StreamBuilder<List<Bon>>(
              stream: widget.repository.watchBons(),
              builder: (context, snapshot) {
                final bons = snapshot.data ?? const [];
                final piutangTotal = bons
                    .where((b) => b.settledAt == null && b.direction == BonDirection.lent)
                    .fold<int>(0, (sum, b) => sum + b.amount);
                final utangTotal = bons
                    .where((b) => b.settledAt == null && b.direction == BonDirection.borrowed)
                    .fold<int>(0, (sum, b) => sum + b.amount);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.m, vertical: Spacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: QuestTabEnter(
                          index: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: context.q.surface,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              border: Border.all(color: context.q.line),
                              boxShadow: AppShadows.card,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: context.q.good,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'PIUTANG',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.qEyebrow(10),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: QuestMoney(
                                    amount: piutangTotal,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: context.q.good,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                Text(
                                  'Orang berutang ke kita',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.qSmall(10.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
                      Expanded(
                        child: QuestTabEnter(
                          index: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: context.q.surface,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              border: Border.all(color: context.q.line),
                              boxShadow: AppShadows.card,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: context.q.bad,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'UTANG',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.qEyebrow(10),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: QuestMoney(
                                    amount: utangTotal,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: context.q.bad,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                Text(
                                  'Kita berutang ke orang',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.qSmall(10.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: Spacing.s),

            // Sub Tabs: [Belum Lunas] vs [Lunas] via QuestSegmented
            QuestTabEnter(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
                child: QuestSegmented<int>(
                  selected: _bonSubTab,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _bonSubTab = val);
                    if (_bonPageCtrl.hasClients) {
                      _bonPageCtrl.animateToPage(
                        val,
                        duration: QuestMotion.medium,
                        curve: QuestMotion.easeOut,
                      );
                    }
                  },
                  options: const [
                    (value: 0, label: 'Belum Lunas', icon: null),
                    (value: 1, label: 'Lunas', icon: null),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.s),

            // Bon List via PageView for smooth horizontal slide transitions
            Expanded(
              child: StreamBuilder<List<Bon>>(
                stream: widget.repository.watchBons(),
                builder: (context, snapshot) {
                  final allBons = snapshot.data ?? const [];
                  final unpaid = allBons.where((b) => b.settledAt == null).toList();
                  final paid = allBons.where((b) => b.settledAt != null).toList();

                  return PageView(
                    controller: _bonPageCtrl,
                    onPageChanged: (page) => setState(() => _bonSubTab = page),
                    children: [
                      _buildBonList(unpaid, isLunas: false, key: const PageStorageKey('bon_unpaid')),
                      _buildBonList(paid, isLunas: true, key: const PageStorageKey('bon_paid')),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonList(List<Bon> bons, {required bool isLunas, Key? key}) {
    if (bons.isEmpty) {
      return QuestTabEnter(
        index: 4,
        child: QuestEmpty(
          title: isLunas ? 'Belum ada riwayat bon lunas.' : 'Semua bon sudah lunas!',
          hint: isLunas
              ? 'Bon yang sudah dilunasi akan tercatat di sini.'
              : 'Catat bon baru jika ada pinjam-meminjam uang.',
        ),
      );
    }
    return ListView.builder(
      key: key,
      padding: EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.xs,
        Spacing.m,
        96 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: bons.length,
      itemBuilder: (context, i) {
        final bon = bons[i];
        final isPiutang = bon.direction == BonDirection.lent;
        final card = Container(
          margin: const EdgeInsets.only(bottom: Spacing.s),
          decoration: BoxDecoration(
            color: context.q.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.q.line),
            boxShadow: AppShadows.card,
          ),
          child: InkWell(
            onTap: () => BonSheet.show(
              context,
              widget.repository,
              existing: bon,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.m),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPiutang ? SeedColors.incomingTint : SeedColors.outgoingTint,
                      borderRadius: BorderRadius.circular(AppRadius.cell),
                    ),
                    child: Icon(
                      isPiutang ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                      color: isPiutang ? context.q.good : context.q.bad,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bon.person,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: context.q.text,
                          ),
                        ),
                        if (bon.note != null && bon.note!.isNotEmpty)
                          Text(
                            bon.note!,
                            style: context.qSmall(11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          idDayMonth(bon.occurredAt),
                          style: context.qSmall(10.5),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: QuestMoney(
                            amount: bon.amount,
                            alignment: Alignment.centerRight,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: isPiutang ? context.q.good : context.q.bad,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Quick Settle Button
                      InkWell(
                        onTap: () => _settleBon(bon),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bon.settledAt == null
                                ? SeedColors.primaryLight
                                : context.q.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            bon.settledAt == null ? 'Lunasi' : 'Batal Lunas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: bon.settledAt == null
                                  ? context.q.primary
                                  : context.q.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        if (i >= 8) return card;
        return QuestTabEnter(
          index: 4 + i,
          child: card,
        );
      },
    );
  }
}

/// Sheet catat / ubah bon. Mode ubah (existing != null) menampilkan
/// tombol Hapus — satu-satunya jalur hapus bon di aplikasi.
class BonSheet extends StatefulWidget {
  const BonSheet({super.key, required this.repository, this.existing});

  final LedgerRepository repository;
  final Bon? existing;

  static Future<void> show(
    BuildContext context,
    LedgerRepository repository, {
    Bon? existing,
  }) {
    return showQuestSheet<void>(
      context,
      (_) => BonSheet(repository: repository, existing: existing),
    );
  }

  @override
  State<BonSheet> createState() => _BonSheetState();
}

class _BonSheetState extends State<BonSheet> {
  late final TextEditingController _personCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late BonDirection _direction;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _personCtrl = TextEditingController(text: e?.person ?? '');
    _amountCtrl = TextEditingController(
      text: e != null ? '${e.amount}' : '',
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _direction = e?.direction ?? BonDirection.lent;
    _date = e?.occurredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final person = _personCtrl.text.trim();
    final amount = Money.tryParseGroup(_amountCtrl.text) ?? 0;
    if (person.isEmpty || amount <= 0) return;
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    final existing = widget.existing;
    if (existing != null) {
      await widget.repository.updateBon(
        existing.id,
        BonsCompanion(
          person: Value(person),
          amount: Value(amount),
          direction: Value(_direction),
          occurredAt: Value(_date),
          note: Value(note),
        ),
      );
    } else {
      await widget.repository.addBon(
        person: person,
        amount: amount,
        direction: _direction,
        occurredAt: _date,
        note: note,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final sure = await showQuestDialog<bool>(
      context,
      title: 'Hapus catatan bon?',
      content: Text(
        'Bon ${existing.person} sebesar ${Money.format(existing.amount)} '
        'akan dihapus permanen.',
        style: context.qBody(13),
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Hapus',
          tone: QuestTone.danger,
          icon: Icons.delete_outline_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (sure != true || !mounted) return;
    await widget.repository.deleteBon(existing.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final editing = widget.existing != null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.xxs,
        Spacing.m,
        Spacing.m + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  editing ? 'Ubah Catatan Bon' : 'Catat Bon Baru',
                  style: context.qTitle(18),
                ),
              ),
              if (editing)
                QuestIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Hapus bon',
                  onPressed: _delete,
                ),
              QuestIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          Divider(height: 1, thickness: 1, color: q.line),
          const SizedBox(height: Spacing.s),
          QuestSegmented<BonDirection>(
            selected: _direction,
            onChanged: (d) => setState(() => _direction = d),
            options: const [
              (
                value: BonDirection.lent,
                label: 'Dipinjamkan (Piutang)',
                icon: null,
              ),
              (
                value: BonDirection.borrowed,
                label: 'Dipinjam (Utang)',
                icon: null,
              ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          TextField(
            controller: _personCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama pihak',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.s),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              prefixText: 'Rp ',
              labelText: 'Nominal',
              prefixIcon: Icon(Icons.payments_outlined, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.s),
          QuestPress(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: q.surface2,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: q.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, size: 18, color: q.muted),
                  const SizedBox(width: Spacing.s),
                  Text(
                    idFullDate(_date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: q.text,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.edit_calendar_outlined, size: 16, color: q.muted),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.s),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              prefixIcon: Icon(Icons.notes_rounded, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.m),
          QuestButton(
            label: editing ? 'Simpan Perubahan' : 'Simpan Bon',
            icon: Icons.check_rounded,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
