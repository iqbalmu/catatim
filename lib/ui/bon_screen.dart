import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/dates_id.dart';
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
