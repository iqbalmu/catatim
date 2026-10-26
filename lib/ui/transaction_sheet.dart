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
          bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.m,
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
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _counterpartyCtrl = TextEditingController();

  late Direction _direction;
  late TxKind _kind;
  late DateTime _occurredAt;
  int? _categoryId;
  List<Category> _categories = const [];
  int? _accountId;
  List<Account> _accounts = const [];

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
    if (tx != null) {
      _amountCtrl.text = tx.amount.toString();
      _counterpartyCtrl.text = tx.counterparty ?? '';
    } else if (draft != null) {
      _amountCtrl.text = draft.amount.toString();
      _counterpartyCtrl.text = draft.counterparty ?? '';
    }
    _loadCategories();
    _loadAccounts();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.repository.getCategories();
    if (!mounted) return;
    setState(() => _categories = cats);
    if (!_isEdit && _categoryId == null && cats.isNotEmpty) {
      setState(() => _categoryId = cats.first.id);
    }
  }

  Future<void> _loadAccounts() async {
    final accs = await widget.repository.getAccounts();
    if (!mounted) return;
    setState(() => _accounts = accs);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = int.tryParse(
      _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) return;
    final counterparty = _counterpartyCtrl.text.trim();
    await HapticFeedback.lightImpact();

    if (_isDraft) {
      await widget.repository.confirmDraft(
        widget.draft!,
        amount: amount,
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
          amount: Value(amount),
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
        amount: amount,
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
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
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _amountCtrl,
                autofocus: !_isEdit,
                keyboardType: TextInputType.number,
                style: context.qDisplay(30),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  labelText: 'Nominal',
                  hintText: '0',
                  helperText: _preview,
                ),
                validator: (v) =>
                    (int.tryParse(
                              (v ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                            ) ??
                            0) >
                        0
                    ? null
                    : 'Isi dulu nominalnya, ya',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.m),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: [
                        for (final c in _categories)
                          DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: SeedColors.categoryColor(
                                      c.colorIndex,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.q.line,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.s),
                                Flexible(
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  QuestIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Kategori baru',
                    onPressed: _addCategory,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.m),
              DropdownButtonFormField<int>(
                initialValue: _accountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Akun (opsional)'),
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
              const SizedBox(height: Spacing.m),
              DropdownButtonFormField<TxKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jenis'),
                items: [
                  for (final k in TxKind.values)
                    DropdownMenuItem(
                      value: k,
                      child: Text(k.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (k) => setState(() => _kind = k ?? TxKind.payment),
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
                decoration: const InputDecoration(
                  labelText: 'Siapa / keterangan (opsional)',
                ),
              ),
              const SizedBox(height: Spacing.l),
              QuestButton(
                label: _isDraft
                    ? 'Catat'
                    : (_isEdit ? 'Simpan perubahan' : 'Simpan'),
                icon: Icons.check_rounded,
                onPressed: _save,
              ),
              const SizedBox(height: Spacing.s),
            ],
          ),
        ),
      ),
    );
  }

  String get _preview {
    final amount = int.tryParse(
      _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) return 'Isi nominalnya dulu, ya';
    return '≈ ${Money.format(amount)}';
  }

  String _dateLabel(DateTime dt) =>
      '${idFullDate(dt)} · '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
