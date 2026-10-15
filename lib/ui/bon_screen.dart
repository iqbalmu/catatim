import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import '../core/dates_id.dart';

/// Tab Bon: utang-piutang pribadi.
class BonTab extends StatelessWidget {
  const BonTab({
    super.key,
    required this.repository,
    this.headerActions = const [],
  });

  final LedgerRepository repository;

  /// Aksi header global dari shell (lonceng + ⋯) — sama di semua tab.
  final List<Widget> headerActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: QuestHeader(
        title: 'Bon',
        subtitle: 'Utang & piutang pribadi',
        actions: headerActions,
      ),
      // Tombol + tinggal di tengah navbar (dinamis per tab) — tanpa FAB
      // melayang di tab ini.
      body: StreamBuilder<List<Bon>>(
        stream: repository.watchBons(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          final bons = snapshot.data ?? const <Bon>[];
          var piutang = 0;
          var utang = 0;
          for (final b in bons) {
            if (b.settledAt != null) continue;
            if (b.direction == BonDirection.lent) {
              piutang += b.amount;
            } else {
              utang += b.amount;
            }
          }
          final open = [
            for (final b in bons)
              if (b.settledAt == null) b,
          ];
          final done = [
            for (final b in bons)
              if (b.settledAt != null) b,
          ];

          return ListView(
            padding: EdgeInsets.fromLTRB(
              Spacing.m,
              Spacing.s,
              Spacing.m,
              Spacing.m + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _NetCard(net: piutang - utang),
              const SizedBox(height: Spacing.s),
              Row(
                children: [
                  Expanded(
                    child: _TotalCard(
                      label: 'Piutang',
                      hint: 'orang berutang padamu',
                      amount: piutang,
                      incoming: true,
                    ),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: _TotalCard(
                      label: 'Utang',
                      hint: 'kamu berutang',
                      amount: utang,
                      incoming: false,
                    ),
                  ),
                ],
              ),
              if (bons.isEmpty)
                const QuestEmpty(
                  title: 'Belum ada bon',
                  hint: 'Catat bon lewat tombol + di navbar bawah.',
                )
              else ...[
                if (open.isNotEmpty) ...[
                  const QuestSectionHeader(title: 'Belum lunas'),
                  for (final b in open)
                    _BonTile(bon: b, repository: repository),
                ],
                if (done.isNotEmpty) ...[
                  const QuestSectionHeader(title: 'Lunas'),
                  for (final b in done)
                    _BonTile(bon: b, repository: repository),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Kartu posisi bersih: piutang − utang (belum lunas saja).
class _NetCard extends StatelessWidget {
  const _NetCard({required this.net});

  final int net;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final positive = net >= 0;
    return Container(
      padding: const EdgeInsets.all(Spacing.m),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SeedColors.honeyBright, SeedColors.honey],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            'POSISI BERSIH',
            style: context.qEyebrow().copyWith(color: q.honeyInk),
          ),
          const SizedBox(height: 2),
          Text(
            '${positive ? '+' : '-'}${Money.format(net.abs())}',
            style: context.qDisplay(30).copyWith(color: q.text),
          ),
          Text(
            positive
                ? 'kamu dipinjami bersih segini'
                : 'kamu berutang bersih segini',
            style: context.qSmall(11).copyWith(color: q.honeyInk),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.hint,
    required this.amount,
    required this.incoming,
  });

  final String label;
  final String hint;
  final int amount;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    return QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.qTitle(15)),
          Text(hint, style: context.qSmall(11)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              Money.format(amount),
              style: context.qAmount(22, incoming: incoming),
            ),
          ),
        ],
      ),
    );
  }
}

class _BonTile extends StatelessWidget {
  const _BonTile({required this.bon, required this.repository});

  final Bon bon;
  final LedgerRepository repository;

  /// Umur bon sejak dicatat: 'hari ini', '3 hari', '2 minggu', '1 bulan'.
  String _ageLabel(DateTime occurredAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      occurredAt.year,
      occurredAt.month,
      occurredAt.day,
    );
    final days = today.difference(start).inDays;
    if (days <= 0) return 'hari ini';
    if (days < 14) return '$days hari';
    if (days < 60) return '${days ~/ 7} minggu';
    return '${(days / 30).round()} bulan';
  }

  @override
  Widget build(BuildContext context) {
    final lent = bon.direction == BonDirection.lent;
    final settled = bon.settledAt != null;
    final initial = bon.person.trim().isEmpty
        ? '?'
        : bon.person.trim()[0].toUpperCase();

    return QuestPress(
      onTap: () => BonSheet.show(context, repository, existing: bon),
      child: Opacity(
        opacity: settled ? 0.6 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: Spacing.s),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.q.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: context.q.shadow,
                offset: const Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lent
                      ? context.q.good.withValues(alpha: 0.16)
                      : context.q.bad.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text(initial, style: context.qTitle(19)),
              ),
              const SizedBox(width: Spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bon.person,
                      overflow: TextOverflow.ellipsis,
                      style: context.qTitle(15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lent ? 'Dipinjamkan' : 'Dipinjam'} · '
                      '${_date(bon.occurredAt)}'
                      '${bon.note != null && bon.note!.isNotEmpty ? ' · ${bon.note!}' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: context.qSmall(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  QuestAmount(amount: bon.amount, incoming: !lent, size: 15),
                  const SizedBox(height: 2),
                  if (settled)
                    Text(
                      'Lunas ✓',
                      style: context
                          .qSmall(11)
                          .copyWith(color: context.q.muted),
                    )
                  else
                    Text(
                      _ageLabel(bon.occurredAt),
                      style: context.qSmall(11).copyWith(
                            fontWeight: FontWeight.w800,
                            color: lent ? context.q.good : context.q.bad,
                          ),
                    ),
                ],
              ),
              if (!settled) ...[
                const SizedBox(width: Spacing.s),
                IconButton(
                  tooltip: 'Tandai lunas',
                  icon: Icon(
                    Icons.check_circle_outline_rounded,
                    color: context.q.good,
                    size: 24,
                  ),
                  onPressed: () => repository.updateBon(
                    bon.id,
                    BonsCompanion(settledAt: Value(DateTime.now())),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime dt) => idDayMonth(dt);
}

/// Sheet tambah/ubah bon. Mode edit bila [existing] diberikan.
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
      (context) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.m,
          right: Spacing.m,
          top: Spacing.s,
          bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.m,
        ),
        child: BonSheet(repository: repository, existing: existing),
      ),
    );
  }

  @override
  State<BonSheet> createState() => _BonSheetState();
}

class _BonSheetState extends State<BonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _personCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late BonDirection _direction;
  late DateTime _occurredAt;

  bool get _isEdit => widget.existing != null;
  bool get _isSettled => widget.existing?.settledAt != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _direction = b?.direction ?? BonDirection.lent;
    _occurredAt = b?.occurredAt ?? DateTime.now();
    if (b != null) {
      _personCtrl.text = b.person;
      _amountCtrl.text = b.amount.toString();
      _noteCtrl.text = b.note ?? '';
    }
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
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _occurredAt = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = int.tryParse(
      _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) return;

    if (_isEdit) {
      await widget.repository.updateBon(
        widget.existing!.id,
        BonsCompanion(
          person: Value(_personCtrl.text.trim()),
          amount: Value(amount),
          direction: Value(_direction),
          note: Value(
            _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          ),
          occurredAt: Value(_occurredAt),
        ),
      );
    } else {
      await widget.repository.addBon(
        person: _personCtrl.text,
        amount: amount,
        direction: _direction,
        note: _noteCtrl.text,
        occurredAt: _occurredAt,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleSettled() async {
    await widget.repository.updateBon(
      widget.existing!.id,
      BonsCompanion(
        settledAt: _isSettled ? const Value(null) : Value(DateTime.now()),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Hapus bon?',
      content: Text(
        'Tindakan ini tidak bisa dibatalkan.',
        style: context.qBody(),
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Hapus',
          icon: Icons.delete_outline_rounded,
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed ?? false) {
      await widget.repository.deleteBon(widget.existing!.id);
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
                      _isEdit ? 'Ubah bon' : 'Catat bon',
                      style: context.qTitle(20),
                    ),
                  ),
                  if (_isEdit)
                    QuestIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Hapus',
                      onPressed: _delete,
                    ),
                ],
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _personCtrl,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama orang',
                  hintText: 'Contoh: Budi',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: context.qDisplay(30),
                decoration: const InputDecoration(
                  labelText: 'Nominal (Rp)',
                  hintText: 'Contoh: 50000',
                ),
                validator: (v) =>
                    (int.tryParse(
                              (v ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                            ) ??
                            0) >
                        0
                    ? null
                    : 'Nominal wajib diisi',
              ),
              const SizedBox(height: Spacing.m),
              QuestSegmented<BonDirection>(
                selected: _direction,
                onChanged: (d) => setState(() => _direction = d),
                options: const [
                  (
                    value: BonDirection.lent,
                    label: 'Saya meminjamkan',
                    icon: Icons.arrow_upward_rounded,
                  ),
                  (
                    value: BonDirection.borrowed,
                    label: 'Saya meminjam',
                    icon: Icons.arrow_downward_rounded,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.m),
              QuestButton(
                label: '${idDayMonth(_occurredAt)} ${_occurredAt.year}',
                icon: Icons.event_outlined,
                tone: QuestTone.secondary,
                onPressed: _pickDate,
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _noteCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                ),
              ),
              const SizedBox(height: Spacing.l),
              if (_isEdit) ...[
                QuestButton(
                  label: _isSettled ? 'Batalkan lunas' : 'Tandai lunas ✓',
                  icon: _isSettled
                      ? Icons.undo_rounded
                      : Icons.check_circle_outline_rounded,
                  tone: _isSettled ? QuestTone.secondary : QuestTone.primary,
                  onPressed: _toggleSettled,
                ),
                const SizedBox(height: Spacing.s),
              ],
              QuestButton(
                label: _isEdit ? 'Simpan perubahan' : 'Simpan',
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
}
