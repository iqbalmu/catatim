import 'package:drift/drift.dart' show Value;
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
import 'add_account_sheet.dart';
import 'ocr_screen.dart';
import 'quest.dart';

class TransactionSheet extends StatefulWidget {
  const TransactionSheet({
    super.key,
    required this.repository,
    this.existing,
    this.draft,
    this.progress,
    this.pipeline,
    this.ruleSet,
  });

  final LedgerRepository repository;
  final TxWithCategory? existing;

  /// Draf hasil notifikasi bank terhubung — dikoreksi lalu dicatat
  /// (atau dibuang). Tak pernah dipakai bersamaan dengan [existing].
  final Draft? draft;
  final ProgressService? progress;
  final CapturePipeline? pipeline;
  final RuleSet? ruleSet;

  static Future<void> show(
    BuildContext context,
    LedgerRepository repository, {
    TxWithCategory? existing,
    Draft? draft,
    ProgressService? progress,
    CapturePipeline? pipeline,
    RuleSet? ruleSet,
  }) {
    return showQuestSheet<void>(
      context,
      (context) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.m,
          right: Spacing.m,
          top: Spacing.s,
          bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.m,
        ),
        child: TransactionSheet(
          repository: repository,
          existing: existing,
          draft: draft,
          progress: progress,
          pipeline: pipeline,
          ruleSet: ruleSet,
        ),
      ),
    );
  }

  @override
  State<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<TransactionSheet> {
  final _counterpartyCtrl = TextEditingController();

  /// Nominal int rupiah — diisi lewat keypad custom, bukan keyboard sistem,
  /// supaya sheet tidak pernah terdorong naik-turun.
  int _amount = 0;

  /// Alur 2-langkah: 0 = Input Nominal & Arah, 1 = Detail Transaksi.
  int _currentStep = 0;

  late Direction _direction;
  late TxKind _kind;
  late DateTime _occurredAt;
  int? _categoryId;
  List<Category> _categories = const [];
  int? _accountId;
  int? _toAccountId;
  List<Account> _accounts = const [];
  bool _userExplicitlySelectedCategory = false;

  bool get _isEdit => widget.existing != null;
  bool get _isDraft => widget.draft != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.existing?.tx;
    final draft = widget.draft;
    _direction = tx?.direction ?? draft?.direction ?? Direction.outgoing;
    _kind = tx?.kind ?? draft?.kind ?? TxKind.payment;
    _occurredAt = tx?.occurredAt ?? draft?.occurredAt ?? DateTime.now();
    _categoryId = tx?.categoryId ?? draft?.categoryId;
    _accountId = tx?.accountId ?? draft?.accountId;
    _amount = tx?.amount ?? draft?.amount ?? 0;
    _counterpartyCtrl.text = tx?.counterparty ?? draft?.counterparty ?? '';
    _currentStep = (_isEdit || _isDraft) ? 1 : 0;
    _loadCategories();
    _loadAccounts();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.repository.getCategories();
    if (!mounted) return;
    setState(() => _categories = cats);
    if (!_isEdit && _categoryId == null) {
      final preferred = await widget.repository.preferredCategoryId(
        counterparty: _counterpartyCtrl.text,
        kind: _kind,
      );
      if (!mounted) return;
      if (preferred != null) {
        setState(() => _categoryId = preferred);
      } else if (cats.isNotEmpty) {
        setState(() => _categoryId = cats.first.id);
      }
    }
  }

  Future<void> _onCounterpartyChanged(String text) async {
    if (_userExplicitlySelectedCategory || _isEdit) return;
    final preferred = await widget.repository.preferredCategoryId(
      counterparty: text,
      kind: _kind,
    );
    if (preferred != null && mounted && !_userExplicitlySelectedCategory) {
      setState(() => _categoryId = preferred);
    }
  }

  Future<void> _loadAccounts() async {
    final accs = await widget.repository.getAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accs;
      if (_accountId == null && accs.isNotEmpty) {
        _accountId = accs.first.id;
      }
      if (_toAccountId == null && accs.length > 1) {
        _toAccountId = accs
            .firstWhere((a) => a.id != _accountId, orElse: () => accs.last)
            .id;
      }
    });
  }

  Future<void> _addAccount() async {
    if (widget.pipeline != null && widget.ruleSet != null) {
      await AddAccountSheet.show(
        context,
        repository: widget.repository,
        pipeline: widget.pipeline!,
        ruleSet: widget.ruleSet!,
      );
    } else {
      final ctrl = TextEditingController();
      final name = await showQuestDialog<String>(
        context,
        title: 'Akun baru',
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration:
              const InputDecoration(labelText: 'Nama akun (mis. Dompet)'),
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
      if (name != null && name.trim().isNotEmpty) {
        try {
          await widget.repository.addAccount(name.trim(), AccountKind.cash);
        } catch (_) {}
      }
    }
    await _loadAccounts();
  }

  Future<void> _openOcr() async {
    final p = widget.pipeline;
    if (p == null) return;
    Navigator.pop(context);
    await OcrScreen.start(context, pipeline: p);
  }

  Future<void> _showPasteDialog() async {
    final p = widget.pipeline;
    if (p == null) return;
    final controller = TextEditingController();
    final text = await showQuestDialog<String>(
      context,
      title: 'Tempel Teks Transaksi',
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Tempel pesan SMS atau notifikasi transfer di sini...',
          border: OutlineInputBorder(),
        ),
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
    final ok = await p.submitPastedText(text);
    if (!mounted) return;
    Navigator.pop(context);
    questSnack(
      context,
      ok ? 'Teks berhasil diproses menjadi draf!' : 'Gagal memproses teks.',
      icon: ok
          ? Icons.check_circle_outline_rounded
          : Icons.info_outline_rounded,
    );
  }

  @override
  void dispose() {
    _counterpartyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final t = TimeOfDay.fromDateTime(_occurredAt);
      setState(() {
        _occurredAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          t.hour,
          t.minute,
        );
      });
    }
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final name = await showQuestDialog<String>(
      context,
      title: 'Kategori baru',
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nama kategori'),
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
      await _loadCategories();
      if (mounted) setState(() => _categoryId = cat.id);
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
    if (_amount <= 0) return;
    final counterparty = _counterpartyCtrl.text.trim();
    await HapticFeedback.lightImpact();

    final resolvedAccountId =
        _accountId ?? (_accounts.isNotEmpty ? _accounts.first.id : null);

    if (!_isDraft &&
        !_isEdit &&
        _kind == TxKind.transfer &&
        _toAccountId != null &&
        resolvedAccountId != null &&
        _toAccountId != resolvedAccountId) {
      await widget.repository.addManualTransfer(
        fromAccountId: resolvedAccountId,
        toAccountId: _toAccountId!,
        amount: _amount,
        occurredAt: _occurredAt,
        note: counterparty.isEmpty ? null : counterparty,
      );
      await widget.progress?.onTransactionRecorded();
      if (mounted) Navigator.pop(context);
      return;
    }

    if (_isDraft) {
      await widget.repository.confirmDraft(
        widget.draft!,
        amount: _amount,
        direction: _direction,
        kind: _kind,
        counterparty: counterparty.isEmpty ? null : counterparty,
        categoryId: _categoryId,
        accountId: resolvedAccountId,
        occurredAt: _occurredAt,
      );
      await widget.progress?.onTransactionRecorded();
    } else if (_isEdit) {
      await widget.repository.updateTransaction(
        widget.existing!.tx.id,
        TransactionsCompanion(
          amount: Value(_amount),
          direction: Value(_direction),
          kind: Value(_kind),
          counterparty: Value(counterparty.isEmpty ? null : counterparty),
          occurredAt: Value(_occurredAt),
          categoryId: Value(_categoryId),
          accountId: Value(resolvedAccountId),
        ),
      );
      final categoryChanged = widget.existing!.tx.categoryId != _categoryId;
      if (categoryChanged) {
        await widget.progress?.onTransactionRecorded();
      }
    } else {
      await widget.repository.addManual(
        amount: _amount,
        direction: _direction,
        kind: _kind,
        counterparty: counterparty.isEmpty ? null : counterparty,
        categoryId: _categoryId,
        accountId: resolvedAccountId,
        occurredAt: _occurredAt,
      );
      await widget.progress?.onTransactionRecorded();
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final isDraft = _isDraft;
    final confirmed = await showQuestDialog<bool>(
      context,
      title: isDraft ? 'Buang draf ini?' : 'Hapus transaksi?',
      content: Text(
        isDraft
            ? 'Drafnya tidak jadi dicatat. Kalau berubah pikiran, '
                  'kamu bisa catat manual.'
            : 'Setelah dihapus, transaksinya tidak bisa dikembalikan lagi.',
        style: context.qBody(),
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: isDraft ? 'Buang' : 'Hapus',
          icon: Icons.delete_outline_rounded,
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed ?? false) {
      if (isDraft) {
        await widget.repository.discardDraft(widget.draft!.id);
      } else {
        await widget.repository.deleteTransaction(widget.existing!.tx.id);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildCategoryChips() {
    final q = context.q;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in _categories) ...[
            QuestChip(
              label: c.name,
              selected: _categoryId == c.id,
              onTap: () {
                _userExplicitlySelectedCategory = true;
                setState(() => _categoryId = c.id);
              },
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: SeedColors.categoryColor(c.colorIndex),
                  shape: BoxShape.circle,
                  border: Border.all(color: q.line, width: 1.5),
                ),
              ),
            ),
            const SizedBox(width: Spacing.s),
          ],
          QuestIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Kategori baru',
            onPressed: _addCategory,
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Nominal(BuildContext context) {
    final q = context.q;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isDraft
                    ? 'Nominal draf'
                    : (_isEdit ? 'Ubah nominal' : 'Catat transaksi'),
                style: context.qTitle(20),
              ),
            ),
            if (!_isDraft && !_isEdit && widget.pipeline != null) ...[
              QuestIconButton(
                icon: Icons.document_scanner_rounded,
                tooltip: 'Foto Struk (OCR)',
                onPressed: _openOcr,
              ),
              QuestIconButton(
                icon: Icons.content_paste_rounded,
                tooltip: 'Tempel Teks',
                onPressed: _showPasteDialog,
              ),
            ],
            if (_isEdit || _isDraft)
              QuestIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: _isDraft ? 'Buang' : 'Hapus',
                onPressed: _delete,
              ),
          ],
        ),
        const SizedBox(height: Spacing.s),
        QuestSegmented<Direction>(
          selected: _direction,
          onChanged: (d) => setState(() => _direction = d),
          options: const [
            (
              value: Direction.outgoing,
              label: 'Keluar',
              icon: Icons.arrow_upward_rounded,
            ),
            (
              value: Direction.incoming,
              label: 'Masuk',
              icon: Icons.arrow_downward_rounded,
            ),
          ],
        ),
        const SizedBox(height: Spacing.m),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: q.surface2,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: q.line.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nominal',
                style: context.qSmall(13).copyWith(color: q.muted),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _amount > 0 ? Money.format(_amount) : 'Rp0',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _amount > 0
                          ? (_direction == Direction.outgoing ? q.bad : q.good)
                          : q.muted.withValues(alpha: 0.5),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.s),
        Text(
          'KATEGORI',
          style: context.qEyebrow(10).copyWith(color: q.muted),
        ),
        const SizedBox(height: Spacing.xs),
        _buildCategoryChips(),
        const SizedBox(height: Spacing.m),
        Container(height: 1, color: q.line.withValues(alpha: 0.5)),
        const SizedBox(height: Spacing.xs),
        QuestKeypad(
          amount: _amount,
          saveLabel: 'Lanjut',
          onChanged: (val) => setState(() => _amount = val),
          onSave: () {
            if (_amount <= 0) {
              HapticFeedback.heavyImpact();
              questSnack(context, 'Masukkan nominal terlebih dahulu');
              return;
            }
            HapticFeedback.selectionClick();
            setState(() => _currentStep = 1);
          },
        ),
        const SizedBox(height: Spacing.xs),
      ],
    );
  }

  Widget _buildStep2Detail(BuildContext context) {
    final q = context.q;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              tooltip: 'Ubah Nominal',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _currentStep = 0);
              },
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Text(
                _isDraft
                    ? 'Detail Draf'
                    : (_isEdit ? 'Ubah Transaksi' : 'Detail Transaksi'),
                style: context.qTitle(19),
              ),
            ),
            if (_isEdit || _isDraft)
              QuestIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: _isDraft ? 'Buang' : 'Hapus',
                onPressed: _delete,
              ),
          ],
        ),
        const SizedBox(height: Spacing.s),
        QuestPress(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _currentStep = 0);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (_direction == Direction.outgoing ? q.bad : q.good)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: (_direction == Direction.outgoing ? q.bad : q.good)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (_direction == Direction.outgoing ? q.bad : q.good)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _direction == Direction.outgoing
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 16,
                    color: _direction == Direction.outgoing ? q.bad : q.good,
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _direction == Direction.outgoing
                          ? 'PENGELUARAN'
                          : 'PEMASUKAN',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _direction == Direction.outgoing ? q.bad : q.good,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      Money.format(_amount),
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: q.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: q.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: q.line.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ubah',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: q.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.edit_outlined, size: 12, color: q.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.m),
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'KATEGORI',
                  style: context.qEyebrow(10).copyWith(color: q.muted),
                ),
                const SizedBox(height: Spacing.xs),
                _buildCategoryChips(),
                const SizedBox(height: Spacing.m),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('account_$_accountId'),
                        initialValue: _accounts.any((a) => a.id == _accountId)
                            ? _accountId
                            : (_accounts.isNotEmpty ? _accounts.first.id : null),
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _kind == TxKind.transfer ? 'Dari Akun' : 'Akun Pembayaran',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                            borderSide: BorderSide(color: q.line.withValues(alpha: 0.6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                            borderSide: BorderSide(color: q.line.withValues(alpha: 0.6)),
                          ),
                        ),
                        items: [
                          for (final a in _accounts)
                            DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.name} · ${a.kind.label}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _accountId = v),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                      tooltip: 'Tambah akun baru',
                      onPressed: _addAccount,
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.s),
                DropdownButtonFormField<TxKind>(
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Jenis Transaksi',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      borderSide: BorderSide(color: q.line.withValues(alpha: 0.6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      borderSide: BorderSide(color: q.line.withValues(alpha: 0.6)),
                    ),
                  ),
                  items: [
                    for (final k in TxKind.values)
                      DropdownMenuItem(
                        value: k,
                        child: Text(
                          k.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                  onChanged: (k) {
                    final newKind = k ?? TxKind.payment;
                    setState(() {
                      _kind = newKind;
                      if (newKind == TxKind.transfer &&
                          _toAccountId == null &&
                          _accounts.length > 1) {
                        _toAccountId = _accounts
                            .firstWhere((a) => a.id != _accountId,
                                orElse: () => _accounts.last)
                            .id;
                      }
                    });
                  },
                ),
                if (_kind == TxKind.transfer) ...[
                  const SizedBox(height: Spacing.s),
                  DropdownButtonFormField<int>(
                    key: ValueKey('to_account_$_toAccountId'),
                    initialValue: _accounts.any((a) => a.id == _toAccountId)
                        ? _toAccountId
                        : (_accounts.length > 1
                            ? _accounts
                                .firstWhere((a) => a.id != _accountId,
                                    orElse: () => _accounts.last)
                                .id
                            : null),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Ke Akun (Tujuan Transfer)',
                      prefixIcon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        borderSide: BorderSide(color: q.line.withValues(alpha: 0.6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        borderSide: BorderSide(color: q.line.withValues(alpha: 0.6)),
                      ),
                    ),
                    items: [
                      for (final a in _accounts)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            '${a.name} · ${a.kind.label}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _toAccountId = v),
                  ),
                ],
                const SizedBox(height: Spacing.m),
                Text(
                  'WAKTU TRANSAKSI',
                  style: context.qEyebrow(10).copyWith(color: q.muted),
                ),
                const SizedBox(height: Spacing.xs),
                QuestPress(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: q.surface2,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      border: Border.all(color: q.line.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined, size: 18, color: q.primary),
                        const SizedBox(width: Spacing.s),
                        Text(
                          _dateLabel(_occurredAt),
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: q.text,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Ubah',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: q.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.m),
                Text(
                  'KETERANGAN (OPSIONAL)',
                  style: context.qEyebrow(10).copyWith(color: q.muted),
                ),
                const SizedBox(height: Spacing.xs),
                TextFormField(
                  controller: _counterpartyCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onChanged: _onCounterpartyChanged,
                  onEditingComplete: () {
                    _onCounterpartyChanged(_counterpartyCtrl.text);
                    FocusScope.of(context).unfocus();
                  },
                  decoration: InputDecoration(
                    hintText: 'Contoh: Kopi Kenangan, Beli Makan, dll...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      borderSide: BorderSide(color: q.line.withValues(alpha: 0.6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      borderSide: BorderSide(color: q.line.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.s),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.m),
        QuestButton(
          label: _isDraft ? 'Catat Transaksi' : 'Simpan Transaksi',
          icon: Icons.check_rounded,
          onPressed: _amount > 0 ? _save : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: QuestMotion.medium,
      switchInCurve: QuestMotion.easeOut,
      switchOutCurve: QuestMotion.easeOut,
      child: _currentStep == 0
          ? KeyedSubtree(
              key: const ValueKey('step_nominal'),
              child: _buildStep1Nominal(context),
            )
          : KeyedSubtree(
              key: const ValueKey('step_detail'),
              child: _buildStep2Detail(context),
            ),
    );
  }

  String _dateLabel(DateTime dt) =>
      '${idFullDate(dt)} · '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
