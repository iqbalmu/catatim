import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';

class ManualAddSheet extends StatefulWidget {
  const ManualAddSheet({super.key, required this.repository});

  final LedgerRepository repository;

  static Future<void> show(BuildContext context, LedgerRepository repository) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ManualAddSheet(repository: repository),
      ),
    );
  }

  @override
  State<ManualAddSheet> createState() => _ManualAddSheetState();
}

class _ManualAddSheetState extends State<ManualAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _counterpartyCtrl = TextEditingController();
  Direction _direction = Direction.outgoing;
  TxKind _kind = TxKind.payment;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _counterpartyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount =
        int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) return;
    await widget.repository.addManual(
      amount: amount,
      direction: _direction,
      kind: _kind,
      counterparty: _counterpartyCtrl.text,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.l, Spacing.m, Spacing.m),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Catat transaksi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _amountCtrl,
                autofocus: true,
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
                onSelectionChanged: (s) => setState(() => _direction = s.first),
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
                label: const Text('Simpan'),
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
}
