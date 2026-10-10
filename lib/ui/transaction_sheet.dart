import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';

const _daysShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Sheet tambah/ubah transaksi. Mode edit bila [existing] diberikan.
class TransactionSheet extends StatefulWidget {
  const TransactionSheet({
    super.key,
    required this.repository,
    this.existing,
    this.progress,
  });

  final LedgerRepository repository;
  final TxWithCategory? existing;
  final ProgressService? progress;

  static Future<void> show(
    BuildContext context,
    LedgerRepository repository, {
    TxWithCategory? existing,
    ProgressService? progress,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TransactionSheet(
          repository: repository,
          existing: existing,
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

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.existing?.tx;
    _direction = tx?.direction ?? Direction.outgoing;
    _kind = tx?.kind ?? TxKind.payment;
    _occurredAt = tx?.occurredAt ?? DateTime.now();
    _categoryId = tx?.categoryId;
    if (tx != null) {
      _amountCtrl.text = tx.amount.toString();
      _counterpartyCtrl.text = tx.counterparty ?? '';
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.repository.getCategories();
    if (!mounted) return;
    setState(() => _categories = cats);
    // Pada transaksi baru, pre-select kategori pertama agar tak pernah kosong.
    if (!_isEdit && _categoryId == null && cats.isNotEmpty) {
      setState(() => _categoryId = cats.first.id);
    }
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
          picked.year, picked.month, picked.day, t.hour, t.minute,
        );
      });
    }
  }

  Future<void> _addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Kategori baru'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama kategori'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final cat = await widget.repository.addCategory(name);
      await _loadCategories();
      if (mounted) setState(() => _categoryId = cat.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori "$name" sudah ada.')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount =
        int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) return;
    final counterparty = _counterpartyCtrl.text.trim();
    await HapticFeedback.lightImpact();

    if (_isEdit) {
      await widget.repository.updateTransaction(
        widget.existing!.tx.id,
        TransactionsCompanion(
          amount: Value(amount),
          direction: Value(_direction),
          kind: Value(_kind),
          counterparty: Value(counterparty.isEmpty ? null : counterparty),
          occurredAt: Value(_occurredAt),
          categoryId: Value(_categoryId),
        ),
      );
      final categoryChanged =
          widget.existing!.tx.categoryId != _categoryId;
      if (categoryChanged) {
        await widget.progress?.award(XpEvent.reclassify);
      }
    } else {
      await widget.repository.addManual(
        amount: amount,
        direction: _direction,
        kind: _kind,
        counterparty: counterparty,
        categoryId: _categoryId,
        occurredAt: _occurredAt,
      );
      await widget.progress?.award(XpEvent.manualAdd);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await widget.repository
          .deleteTransaction(widget.existing!.tx.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(Spacing.m, Spacing.l, Spacing.m, Spacing.m),
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
                      _isEdit ? 'Ubah transaksi' : 'Catat transaksi',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_isEdit)
                    IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _delete,
                    ),
                ],
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _amountCtrl,
                autofocus: !_isEdit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nominal (Rp)',
                  hintText: 'Contoh: 150000',
                  helperText: _preview,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ??
                        0) >
                    0
                        ? null
                        : 'Nominal wajib diisi',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.m),
              SegmentedButton<Direction>(
                segments: const [
                  ButtonSegment(
                    value: Direction.outgoing,
                    label: Text('Keluar'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: Direction.incoming,
                    label: Text('Masuk'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (s) =>
                    setState(() => _direction = s.first),
              ),
              const SizedBox(height: Spacing.m),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      decoration: InputDecoration(
                        labelText: 'Kategori',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Kategori baru',
                          icon: const Icon(Icons.add),
                          onPressed: _addCategory,
                        ),
                      ),
                      items: [
                        for (final c in _categories)
                          DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: SeedColors.categoryColor(c.colorIndex),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: Spacing.s),
                                Text(c.name),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.m),
              DropdownButtonFormField<TxKind>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Jenis',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final k in TxKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (k) => setState(() => _kind = k ?? TxKind.payment),
              ),
              const SizedBox(height: Spacing.m),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(_dateLabel(_occurredAt)),
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _counterpartyCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Pihak / keterangan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.l),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(_isEdit ? 'Simpan perubahan' : 'Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _preview {
    final amount =
        int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) return 'Masukkan nominal';
    return '≈ ${Money.format(amount)}';
  }

  String _dateLabel(DateTime dt) =>
      '${_daysShort[dt.weekday - 1]}, ${dt.day} ${_monthsShort[dt.month - 1]} '
      '${dt.year} · '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
