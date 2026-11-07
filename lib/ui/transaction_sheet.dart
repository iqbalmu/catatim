import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import '../core/dates_id.dart';

class TransactionSheet extends StatefulWidget {
  const TransactionSheet({
    super.key,
    required this.repository,
    this.existing,
    this.draft,
    this.progress,
  });

  final LedgerRepository repository;
  final TxWithCategory? existing;

  /// Draf hasil notifikasi bank terhubung — dikoreksi lalu dicatat
  /// (atau dibuang). Tak pernah dipakai bersamaan dengan [existing].
  final Draft? draft;
  final ProgressService? progress;

  static Future<void> show(
    BuildContext context,
    LedgerRepository repository, {
    TxWithCategory? existing,
    Draft? draft,
    ProgressService? progress,
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

  late Direction _direction;
  late TxKind _kind;
  late DateTime _occurredAt;
  int? _categoryId;
  List<Category> _categories = const [];
  int? _accountId;
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
    setState(() => _accounts = accs);
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

    if (_isDraft) {
      await widget.repository.confirmDraft(
        widget.draft!,
        amount: _amount,
        direction: _direction,
        kind: _kind,
        counterparty: counterparty.isEmpty ? null : counterparty,
        categoryId: _categoryId,
        accountId: _accountId,
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
          accountId: Value(_accountId),
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
        accountId: _accountId,
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

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    // Keyboard sistem hanya muncul untuk field keterangan opsional. Saat itu
    // keypad disembunyikan — keduanya bertukar di area yang sama, jadi sheet
    // tidak pernah terdorong naik-turun.
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isDraft
                    ? 'Periksa & catat'
                    : (_isEdit ? 'Ubah transaksi' : 'Catat transaksi'),
                style: context.qTitle(20),
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
        Text(
          _amount > 0 ? Money.format(_amount) : 'Rp0',
          style: context
              .qDisplay(30)
              .copyWith(
                color: _amount > 0 ? null : q.muted.withValues(alpha: 0.5),
              ),
        ),
        const SizedBox(height: Spacing.m),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                _buildCategoryChips(),
                const SizedBox(height: Spacing.m),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _accountId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Akun'),
                        items: [
                          for (final a in _accounts)
                            DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.name} · ${a.kind.label}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _accountId = v),
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: DropdownButtonFormField<TxKind>(
                        initialValue: _kind,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Jenis'),
                        items: [
                          for (final k in TxKind.values)
                            DropdownMenuItem(
                              value: k,
                              child: Text(
                                k.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (k) =>
                            setState(() => _kind = k ?? TxKind.payment),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.m),
                QuestButton(
                  label: _dateLabel(_occurredAt),
                  icon: Icons.event_outlined,
                  tone: QuestTone.secondary,
                  onPressed: _pickDate,
                ),
                const SizedBox(height: Spacing.m),
                TextFormField(
                  controller: _counterpartyCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onChanged: _onCounterpartyChanged,
                  onEditingComplete: () {
                    _onCounterpartyChanged(_counterpartyCtrl.text);
                    FocusScope.of(context).unfocus();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Siapa / keterangan (opsional)',
                  ),
                ),
                const SizedBox(height: Spacing.s),
              ],
            ),
          ),
        ),
        // Saat keyboard keterangan terbuka, Simpan tetap terjangkau tanpa
        // menutup keyboard; saat keyboard tertutup, keypad kustom terpasang fixed di bawah.
        if (keyboardVisible)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.m),
            child: QuestButton(
              label: _isDraft ? 'Catat' : 'Simpan',
              icon: Icons.check_rounded,
              onPressed: _amount > 0 ? _save : null,
            ),
          )
        else ...[
          const SizedBox(height: Spacing.xs),
          Container(height: 1, color: q.line),
          const SizedBox(height: Spacing.xs),
          QuestKeypad(
            amount: _amount,
            saveLabel: _isDraft ? 'Catat' : 'Simpan',
            onChanged: (val) => setState(() => _amount = val),
            onSave: _save,
          ),
          const SizedBox(height: Spacing.xs),
        ],
      ],
    );
  }

  String _dateLabel(DateTime dt) =>
      '${idFullDate(dt)} · '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
