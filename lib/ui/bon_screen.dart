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

  // Stream di-hoist dari build (audit O-02): tanpa ini tiap geser
  // PageView / ganti sub-tab membuat ulang 4 stream Drift sekaligus.
  late final Stream<List<Bon>> _bonsStream = widget.repository.watchBons();
  late final Stream<List<Category>> _categoriesStream =
      widget.repository.watchCategories();
  late final Stream<List<Account>> _accountsStream =
      widget.repository.watchAccounts();

  @override
  void dispose() {
    _bonPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _settleBon(Bon bon) async {
    if (bon.settledAt != null) {
      final confirmCancel = await showQuestDialog<bool>(
        context,
        title: 'Batalkan Status Lunas?',
        content: Text(
          'Status bon ${bon.person} akan dikembalikan menjadi Belum Lunas. '
          'Transaksi kas pelunasan terkait juga akan dihapus.',
          style: context.qBody(13),
        ),
        actions: [
          QuestButton(
            label: 'Batal',
            tone: QuestTone.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
          QuestButton(
            label: 'Batalkan Lunas',
            tone: QuestTone.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      );
      if (confirmCancel != true || !mounted) return;

      await widget.repository.unsettleBon(bon.id);
      if (mounted) questSnack(context, 'Status lunas dibatalkan dan transaksi kas dihapus.');
      return;
    }

    final accounts = await widget.repository.getAccounts();
    final categories = await widget.repository.getCategories();
    if (!mounted) return;

    if (accounts.isEmpty) {
      questSnack(context, 'Tambahkan akun terlebih dahulu di pengaturan.');
      return;
    }

    final isLent = bon.direction == BonDirection.lent;
    final isUncalculated = bon.amount <= 0;

    int? selectedAccountId = bon.accountId ?? accounts.firstOrNull?.id;
    int? selectedCategoryId = bon.categoryId ?? categories.firstWhere(
      (c) {
        final n = c.name.toLowerCase();
        return n.contains('makan') || n.contains('belanja') || n.contains('lain');
      },
      orElse: () => categories.first,
    ).id;

    final amountController = TextEditingController(
      text: isUncalculated ? '' : '${bon.amount}',
    );

    final shouldSettle = await showQuestDialog<bool>(
      context,
      title: isLent ? 'Terima Pelunasan' : 'Lunasi Bon',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          final q = context.q;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUncalculated) ...[
                  Text(
                    'Nominal',
                    style: context.qSmall(12).copyWith(
                      fontWeight: FontWeight.w700,
                      color: q.muted,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: q.text,
                    ),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      prefixStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: q.text,
                        fontSize: 13.5,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: q.surface2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        borderSide: BorderSide(color: q.primary, width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.m),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.q.surface2,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Nominal', style: context.qSmall(12)),
                        Text(
                          Money.format(bon.amount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isLent ? context.q.good : context.q.bad,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.m),
                ],
                Text(
                  isLent ? 'Masuk ke Akun' : 'Sumber Dana',
                  style: context.qSmall(12).copyWith(
                    fontWeight: FontWeight.w700,
                    color: q.muted,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                DropdownButtonFormField<int>(
                  initialValue: selectedAccountId,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: q.muted,
                    size: 20,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: q.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      borderSide: BorderSide(color: q.primary, width: 1.4),
                    ),
                  ),
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedAccountId = v),
                ),
                const SizedBox(height: Spacing.m),
                Text(
                  'Kategori',
                  style: context.qSmall(12).copyWith(
                    fontWeight: FontWeight.w700,
                    color: q.muted,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                DropdownButtonFormField<int>(
                  initialValue: selectedCategoryId,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: q.muted,
                    size: 20,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.category_outlined, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: q.surface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      borderSide: BorderSide(color: q.primary, width: 1.4),
                    ),
                  ),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                ),
              ],
            ),
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
          onPressed: () {
            final amt = Money.tryParseGroup(amountController.text) ?? (isUncalculated ? 0 : bon.amount);
            if (amt <= 0) {
              questSnack(context, 'Masukkan nominal pembayaran.');
              return;
            }
            Navigator.pop(context, true);
          },
        ),
      ],
    );

    if (shouldSettle != true || !mounted) return;

    final finalAmount = Money.tryParseGroup(amountController.text) ?? (isUncalculated ? 0 : bon.amount);
    if (finalAmount <= 0 || selectedAccountId == null || selectedCategoryId == null) return;

    await widget.repository.settleBon(
      bonId: bon.id,
      amount: finalAmount,
      accountId: selectedAccountId!,
      categoryId: selectedCategoryId!,
    );
    await widget.progress?.onTransactionRecorded();

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
              stream: _bonsStream,
              builder: (context, snapshot) {
                final bons = snapshot.data ?? const [];
                final unpaidPiutang = bons
                    .where((b) => b.settledAt == null && b.direction == BonDirection.lent)
                    .toList();
                final piutangTotal = unpaidPiutang.fold<int>(0, (sum, b) => sum + b.amount);
                final uncalcPiutang = unpaidPiutang.where((b) => b.amount <= 0).length;

                final unpaidUtang = bons
                    .where((b) => b.settledAt == null && b.direction == BonDirection.borrowed)
                    .toList();
                final utangTotal = unpaidUtang.fold<int>(0, (sum, b) => sum + b.amount);
                final uncalcUtang = unpaidUtang.where((b) => b.amount <= 0).length;

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
                              boxShadow: context.q.cardShadow,
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
                                  uncalcPiutang > 0
                                      ? 'Orang berutang (+ $uncalcPiutang open)'
                                      : 'Orang berutang ke kita',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: uncalcPiutang > 0
                                      ? TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.q.warn,
                                        )
                                      : context.qSmall(10.5),
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
                              boxShadow: context.q.cardShadow,
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
                                  uncalcUtang > 0
                                      ? 'Kita berutang (+ $uncalcUtang open)'
                                      : 'Kita berutang ke orang',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: uncalcUtang > 0
                                      ? TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.q.warn,
                                        )
                                      : context.qSmall(10.5),
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
                stream: _bonsStream,
                builder: (context, bonSnap) {
                  return StreamBuilder<List<Category>>(
                    stream: _categoriesStream,
                    builder: (context, catSnap) {
                      return StreamBuilder<List<Account>>(
                        stream: _accountsStream,
                        builder: (context, accSnap) {
                          final allBons = bonSnap.data ?? const [];
                          final catMap = {for (final c in catSnap.data ?? const <Category>[]) c.id: c};
                          final accMap = {for (final a in accSnap.data ?? const <Account>[]) a.id: a};
                          final unpaid = allBons.where((b) => b.settledAt == null).toList();
                          final paid = allBons.where((b) => b.settledAt != null).toList();

                          return PageView(
                            controller: _bonPageCtrl,
                            onPageChanged: (page) => setState(() => _bonSubTab = page),
                            children: [
                              _buildBonList(
                                unpaid,
                                isLunas: false,
                                catMap: catMap,
                                accMap: accMap,
                                key: const PageStorageKey('bon_unpaid'),
                              ),
                              _buildBonList(
                                paid,
                                isLunas: true,
                                catMap: catMap,
                                accMap: accMap,
                                key: const PageStorageKey('bon_paid'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonList(
    List<Bon> bons, {
    required bool isLunas,
    required Map<int, Category> catMap,
    required Map<int, Account> accMap,
    Key? key,
  }) {
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
        final cat = bon.categoryId != null ? catMap[bon.categoryId] : null;
        final acc = bon.accountId != null ? accMap[bon.accountId] : null;
        final card = Container(
          margin: const EdgeInsets.only(bottom: Spacing.s),
          decoration: BoxDecoration(
            color: context.q.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.q.line),
            boxShadow: context.q.cardShadow,
          ),
          child: Semantics(
            button: true,
            label:
                '${bon.person}, ${bon.amount > 0 ? Money.format(bon.amount) : 'nominal belum dihitung'}'
                '${bon.settledAt != null ? ', sudah lunas' : ''}',
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
                      color: isPiutang ? context.q.incomingTint : context.q.outgoingTint,
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
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            if (cat != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: context.q.surface2,
                                  borderRadius: BorderRadius.circular(AppRadius.cell),
                                  border: Border.all(color: context.q.line),
                                ),
                                child: Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: context.q.text,
                                  ),
                                ),
                              ),
                            if (acc != null)
                              Text(
                                '· ${acc.name}',
                                style: context.qSmall(10.5),
                              ),
                            Text(
                              idDayMonth(bon.occurredAt),
                              style: context.qSmall(10.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (bon.amount <= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: context.q.warn.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: context.q.warn.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Belum Dihitung',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: context.q.warn,
                            ),
                          ),
                        )
                      else
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
                      Semantics(
                        button: true,
                        label:
                            '${bon.settledAt == null ? (bon.amount <= 0 ? 'Hitung & Lunasi' : 'Lunasi') : 'Batal Lunas'} ${bon.person}',
                        child: InkWell(
                        onTap: () => _settleBon(bon),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bon.settledAt == null
                                ? context.q.primaryLight
                                : context.q.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            bon.settledAt == null
                                ? (bon.amount <= 0 ? 'Hitung & Lunasi' : 'Lunasi')
                                : 'Batal Lunas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: bon.settledAt == null
                                  ? context.q.primaryText
                                  : context.q.muted,
                            ),
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
          ),
        );
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
  int? _categoryId;
  int? _accountId;
  List<Category> _categories = [];
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _personCtrl = TextEditingController(text: e?.person ?? '');
    _amountCtrl = TextEditingController(
      text: (e != null && e.amount > 0) ? '${e.amount}' : '',
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _direction = e?.direction ?? BonDirection.lent;
    _date = e?.occurredAt ?? DateTime.now();
    _categoryId = e?.categoryId;
    _accountId = e?.accountId;
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final cats = await widget.repository.getCategories();
    final accs = await widget.repository.getAccounts();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _accounts = accs;
      if (_categoryId == null && cats.isNotEmpty) {
        _categoryId = cats.firstWhere(
          (c) {
            final n = c.name.toLowerCase();
            return n.contains('makan') || n.contains('belanja') || n.contains('lain');
          },
          orElse: () => cats.first,
        ).id;
      }
      if (_accountId == null && accs.isNotEmpty) {
        _accountId = accs.first.id;
      }
    });
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

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final q = context.q;
    final name = await showQuestDialog<String>(
      context,
      title: 'Tambah Kategori Baru',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nama Kategori',
            style: context.qSmall(12).copyWith(
              fontWeight: FontWeight.w700,
              color: q.muted,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: q.text,
            ),
            decoration: InputDecoration(
              hintText: 'Misalnya: Kopi, Langganan, Hobi...',
              hintStyle: TextStyle(
                color: q.muted.withValues(alpha: 0.6),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              isDense: true,
              filled: true,
              fillColor: q.surface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.primary, width: 1.4),
              ),
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
          label: 'Tambah',
          icon: Icons.add_rounded,
          onPressed: () => Navigator.pop(context, ctrl.text),
        ),
      ],
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final cat = await widget.repository.addCategory(name);
      final cats = await widget.repository.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _categoryId = cat.id;
        });
      }
    } catch (_) {
      if (mounted) {
        questSnack(
          context,
          'Kategori "$name" sudah ada.',
          icon: Icons.info_outline_rounded,
        );
      }
    }
  }

  Future<void> _save() async {
    final person = _personCtrl.text.trim();
    final amount = Money.tryParseGroup(_amountCtrl.text) ?? 0;
    if (person.isEmpty) {
      questSnack(context, 'Nama pihak atau warung tidak boleh kosong.');
      return;
    }
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
          categoryId: Value(_categoryId),
          accountId: Value(_accountId),
        ),
      );
    } else {
      await widget.repository.addBon(
        person: person,
        amount: amount,
        direction: _direction,
        occurredAt: _date,
        note: note,
        categoryId: _categoryId,
        accountId: _accountId,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final isUncalc = existing.amount <= 0;
    final sure = await showQuestDialog<bool>(
      context,
      title: 'Hapus catatan bon?',
      content: Text(
        isUncalc
            ? 'Bon ${existing.person} (Belum Dihitung) akan dihapus permanen.'
            : 'Bon ${existing.person} sebesar ${Money.format(existing.amount)} akan dihapus permanen.',
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
    await widget.repository.deleteBon(existing.id, deleteLinkedTx: true);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _settleDirectly() async {
    final existing = widget.existing;
    if (existing == null) return;

    final person = _personCtrl.text.trim();
    if (person.isEmpty) {
      questSnack(context, 'Nama pihak atau warung tidak boleh kosong.');
      return;
    }
    final amount = Money.tryParseGroup(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      questSnack(context, 'Masukkan nominal pembayaran.');
      return;
    }
    if (_accountId == null) {
      questSnack(context, 'Pilih sumber dana / akun.');
      return;
    }
    if (_categoryId == null) {
      questSnack(context, 'Pilih kategori.');
      return;
    }

    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    await widget.repository.updateBon(
      existing.id,
      BonsCompanion(
        person: Value(person),
        amount: Value(amount),
        direction: Value(_direction),
        occurredAt: Value(_date),
        note: Value(note),
        categoryId: Value(_categoryId),
        accountId: Value(_accountId),
      ),
    );

    await widget.repository.settleBon(
      bonId: existing.id,
      amount: amount,
      accountId: _accountId!,
      categoryId: _categoryId!,
      settledAt: DateTime.now(),
    );

    if (mounted) {
      Navigator.pop(context);
      questSnack(context, 'Bon $person berhasil dilunasi!');
    }
  }

  Future<void> _unsettleDirectly() async {
    final existing = widget.existing;
    if (existing == null) return;

    await widget.repository.unsettleBon(existing.id);
    if (mounted) {
      Navigator.pop(context);
      questSnack(context, 'Status lunas dibatalkan dan transaksi kas dihapus.');
    }
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
          const SizedBox(height: Spacing.m),
          Text(
            'Pihak / Kontak',
            style: context.qSmall(12).copyWith(
              fontWeight: FontWeight.w700,
              color: q.muted,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: _personCtrl,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: q.text,
            ),
            decoration: InputDecoration(
              hintText: 'Nama orang atau warung...',
              hintStyle: TextStyle(
                color: q.muted.withValues(alpha: 0.6),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
              isDense: true,
              filled: true,
              fillColor: q.surface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: Spacing.m),
          Text(
            'Nominal',
            style: context.qSmall(12).copyWith(
              fontWeight: FontWeight.w700,
              color: q.muted,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: q.text,
            ),
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: q.text,
                fontSize: 13.5,
              ),
              hintText: '0',
              hintStyle: TextStyle(
                color: q.muted.withValues(alpha: 0.6),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(Icons.payments_outlined, size: 18),
              isDense: true,
              filled: true,
              fillColor: q.surface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.primary, width: 1.4),
              ),
            ),
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: Spacing.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kategori',
                  style: context.qSmall(12).copyWith(
                    fontWeight: FontWeight.w700,
                    color: q.muted,
                  ),
                ),
                QuestPress(
                  onTap: _addCategory,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: q.primaryText),
                      const SizedBox(width: 2),
                      Text(
                        'Tambah',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: q.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            DropdownButtonFormField<int>(
              key: ValueKey('bon_category_$_categoryId'),
              initialValue: _categories.any((c) => c.id == _categoryId) ? _categoryId : null,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: q.muted,
                size: 20,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.category_outlined, size: 18),
                isDense: true,
                filled: true,
                fillColor: q.surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  borderSide: BorderSide(color: q.primary, width: 1.4),
                ),
              ),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      c.name,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ],
          if (_accounts.isNotEmpty) ...[
            const SizedBox(height: Spacing.m),
            Text(
              _direction == BonDirection.borrowed ? 'Sumber Dana' : 'Masuk ke Akun',
              style: context.qSmall(12).copyWith(
                fontWeight: FontWeight.w700,
                color: q.muted,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            DropdownButtonFormField<int>(
              key: ValueKey('bon_account_$_accountId'),
              initialValue: _accounts.any((a) => a.id == _accountId) ? _accountId : null,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: q.muted,
                size: 20,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                isDense: true,
                filled: true,
                fillColor: q.surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  borderSide: BorderSide(color: q.primary, width: 1.4),
                ),
              ),
              items: [
                for (final a in _accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(
                      a.name,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
          ],
          const SizedBox(height: Spacing.m),
          Text(
            'Tanggal Bon',
            style: context.qSmall(12).copyWith(
              fontWeight: FontWeight.w700,
              color: q.muted,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          QuestPress(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: q.surface2,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: q.line.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, size: 18, color: q.primaryText),
                  const SizedBox(width: Spacing.s),
                  Text(
                    idFullDate(_date),
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13.5,
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
          const SizedBox(height: Spacing.m),
          Text(
            'Catatan (Opsional)',
            style: context.qSmall(12).copyWith(
              fontWeight: FontWeight.w700,
              color: q.muted,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: _noteCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: q.text,
            ),
            decoration: InputDecoration(
              hintText: 'Tulis catatan bila perlu...',
              hintStyle: TextStyle(
                color: q.muted.withValues(alpha: 0.6),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(Icons.notes_rounded, size: 18),
              isDense: true,
              filled: true,
              fillColor: q.surface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.line.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                borderSide: BorderSide(color: q.primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: Spacing.m),
          if (editing && widget.existing?.settledAt == null) ...[
            QuestButton(
              label: _direction == BonDirection.lent ? 'Terima Pelunasan' : 'Lunasi Bon',
              icon: Icons.check_circle_outline_rounded,
              tone: QuestTone.primary,
              onPressed: _settleDirectly,
            ),
            const SizedBox(height: Spacing.xs),
          ] else if (editing && widget.existing?.settledAt != null) ...[
            QuestButton(
              label: 'Batalkan Status Lunas',
              icon: Icons.undo_rounded,
              tone: QuestTone.danger,
              onPressed: _unsettleDirectly,
            ),
            const SizedBox(height: Spacing.xs),
          ],
          QuestButton(
            label: editing ? 'Simpan Perubahan' : 'Simpan Bon',
            icon: Icons.check_rounded,
            tone: (editing && widget.existing?.settledAt == null)
                ? QuestTone.secondary
                : QuestTone.primary,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
