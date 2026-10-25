import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../core/money.dart';
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
  late final DateTime _date;

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
        Spacing.l,
        Spacing.xs,
        Spacing.l,
        Spacing.l + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editing ? 'Ubah Catatan Bon' : 'Catat Bon Baru',
            style: context.qTitle(18),
          ),
          const SizedBox(height: Spacing.m),
          QuestSegmented<BonDirection>(
            selected: _direction,
            onChanged: (d) => setState(() => _direction = d),
            options: const [
              (
                value: BonDirection.lent,
                label: 'Dipinjamkan',
                icon: null,
              ),
              (
                value: BonDirection.borrowed,
                label: 'Dipinjam',
                icon: null,
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            _direction == BonDirection.lent
                ? 'Piutang — orang lain berutang kepadamu.'
                : 'Utang — kamu berutang kepada orang lain.',
            style: context.qSmall(12),
          ),
          const SizedBox(height: Spacing.m),
          TextField(
            controller: _personCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama pihak'),
          ),
          const SizedBox(height: Spacing.s),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixText: 'Rp ',
              labelText: 'Nominal',
            ),
          ),
          const SizedBox(height: Spacing.s),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
          ),
          const SizedBox(height: Spacing.l),
          QuestButton(
            label: editing ? 'Simpan perubahan' : 'Simpan bon',
            icon: Icons.check_rounded,
            onPressed: _save,
          ),
          if (editing) ...[
            const SizedBox(height: Spacing.s),
            TextButton.icon(
              onPressed: _delete,
              icon: Icon(Icons.delete_outline_rounded, color: q.bad, size: 18),
              label: Text(
                'Hapus bon ini',
                style: TextStyle(color: q.bad, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
