import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/dates_id.dart';
import '../core/money.dart';
import '../core/targets.dart';
import '../game/progress.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Segmen Target layar Rencana: kartu pos target (progres + laju setoran),
class RencanaTarget extends StatefulWidget {
  const RencanaTarget({super.key, required this.repository, this.progress});

  final LedgerRepository repository;

  /// Agar Beranda ikut segar setelah Sisihkan (diisi RencanaScreen).
  final ProgressService? progress;

  @override
  State<RencanaTarget> createState() => _RencanaTargetState();
}

class _RencanaTargetState extends State<RencanaTarget> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TargetWithProgress>>(
      stream: widget.repository.watchTargets(),
      builder: (context, snapshot) {
        final targets = snapshot.data ?? const <TargetWithProgress>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.m,
            Spacing.s,
            Spacing.m,
            Spacing.l,
          ),
          children: [
            Row(
              children: [
                Expanded(child: Text('Pos target', style: context.qEyebrow())),
                QuestPress(
                  onTap: _addTargetFlow,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xs),
                    child: Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: context.q.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.s),
            if (targets.isEmpty)
              QuestEmpty(
                title: 'Belum ada pos target',
                hint:
                    'Tetapkan tujuan menabung — dana darurat, gadget, '
                    'atau liburan — lalu sisihkan tiap bulan.',
                actionLabel: '＋Target',
                onAction: _addTargetFlow,
              )
            else
              for (final t in targets) ...[
                _TargetCard(
                  repository: widget.repository,
                  entry: t,
                  onSisihkan: () => _sisihkan(t),
                  onRename: () => _renameFlow(t),
                  onArsip: () => _arsipFlow(t),
                ),
                const SizedBox(height: Spacing.m),
              ],
          ],
        );
      },
    );
  }

  Future<void> _addTargetFlow() async {
    final result = await _askTarget(context);
    if (result == null) return;
    try {
      await widget.repository.addTarget(
        name: result.name,
        goalAmount: result.goal,
        deadline: result.deadline,
      );
    } catch (_) {
      if (mounted) {
        questSnack(context, 'Nama pos "${result.name}" sudah dipakai');
      }
    }
  }

  Future<void> _renameFlow(TargetWithProgress entry) async {
    final name = await _askName(
      context,
      title: 'Ubah nama pos',
      current: entry.target.name,
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.repository.renameTarget(entry.target.id, name);
    } catch (_) {
      if (mounted) {
        questSnack(context, 'Nama pos "$name" sudah dipakai');
      }
    }
  }

  Future<void> _arsipFlow(TargetWithProgress entry) async {
    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Arsipkan pos?',
      content: Text(
        'Pos "${entry.target.name}" beserta setorannya dihapus dari Rencana. '
        'Transaksi Sisihkan di riwayat tetap utuh.',
        style: context.qBody(),
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Arsip',
          icon: Icons.archive_outlined,
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed ?? false) {
      await widget.repository.deleteTarget(entry.target.id);
    }
  }

  Future<void> _sisihkan(TargetWithProgress entry) {
    return SisihkanSheet.show(
      context,
      widget.repository,
      entry,
      progress: widget.progress,
    );
  }
}

/// Kartu satu pos target: nama, RpX/RpY, persen, bar progres, dan laju
/// setoran ('−RpZ/bln s/d Mar', atau persen saja tanpa tenggat).
class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.repository,
    required this.entry,
    required this.onSisihkan,
    required this.onRename,
    required this.onArsip,
  });

  final LedgerRepository repository;
  final TargetWithProgress entry;
  final VoidCallback onSisihkan;
  final VoidCallback onRename;
  final VoidCallback onArsip;

  @override
  Widget build(BuildContext context) {
    final target = entry.target;
    final done = target.goalAmount > 0 && entry.deposited >= target.goalAmount;
    final pace = targetPace(
      goal: target.goalAmount,
      saved: entry.deposited,
      deadline: target.deadline,
    );
    final paceText = pace.perMonth == null
        ? '${pace.percent}%'
        : '−${Money.format(pace.perMonth!)}/bln s/d '
              '${idMonthsShort[target.deadline!.month - 1]}';

    return QuestCard(
      onTap: onSisihkan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  target.name,
                  style: context.qTitle(16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (done) ...[_DoneBadge(), const SizedBox(width: Spacing.s)],
              QuestIconButton(
                icon: Icons.more_vert_rounded,
                onPressed: () => _openMenu(context),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            '${Money.format(entry.deposited)} / '
            '${Money.format(target.goalAmount)}',
            style: context.qAmount(15, incoming: true),
          ),
          const SizedBox(height: Spacing.s),
          QuestBar(value: entry.progress, color: context.q.honey),
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$paceText • ${pace.percent}%',
                  style: context.qSmall().copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              QuestButton(
                label: 'Sisihkan',
                icon: Icons.savings_outlined,
                expanded: false,
                onPressed: onSisihkan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMenu(BuildContext context) {
    return showQuestDialog<void>(
      context,
      title: entry.target.name,
      content: Text(
        '${Money.format(entry.deposited)} dari '
        '${Money.format(entry.target.goalAmount)}',
        style: context.qBody().copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      actions: [
        QuestButton(
          label: 'Ubah nama',
          tone: QuestTone.secondary,
          icon: Icons.edit_outlined,
          onPressed: () {
            Navigator.pop(context);
            onRename();
          },
        ),
        QuestButton(
          label: 'Arsip',
          tone: QuestTone.danger,
          icon: Icons.archive_outlined,
          onPressed: () {
            Navigator.pop(context);
            onArsip();
          },
        ),
      ],
    );
  }
}

class _DoneBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.q.good,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Tercapai 🎉',
        style: context
            .qSmall(11)
            .copyWith(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Hasil dialog ＋Target.
class _TargetDraft {
  const _TargetDraft(this.name, this.goal, this.deadline);

  final String name;
  final int goal;
  final DateTime? deadline;
}

/// Dialog tambah pos: nama, target rupiah, tenggat opsional.
Future<_TargetDraft?> _askTarget(BuildContext context) {
  final nameCtrl = TextEditingController();
  final goalCtrl = TextEditingController();
  DateTime? deadline;
  return showQuestDialog<_TargetDraft>(
    context,
    title: '＋Target',
    content: StatefulBuilder(
      builder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama pos'),
          ),
          const SizedBox(height: Spacing.m),
          TextField(
            controller: goalCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Target (rupiah)'),
          ),
          const SizedBox(height: Spacing.m),
          QuestButton(
            label: deadline == null
                ? 'Tenggat: tanpa tenggat'
                : 'Tenggat: ${idMonthYear(deadline!)}',
            tone: QuestTone.secondary,
            icon: Icons.event_outlined,
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: deadline ?? DateTime(now.year, now.month + 3),
                firstDate: DateTime(now.year, now.month + 1),
                lastDate: DateTime(now.year + 10),
              );
              if (picked != null) {
                setDialogState(() => deadline = picked);
              }
            },
          ),
        ],
      ),
    ),
    actions: [
      QuestButton(
        label: 'Batal',
        tone: QuestTone.secondary,
        onPressed: () => Navigator.pop(context),
      ),
      QuestButton(
        label: 'Simpan',
        icon: Icons.check_rounded,
        onPressed: () {
          final goal = Money.tryParseGroup(goalCtrl.text);
          if (nameCtrl.text.trim().isEmpty || goal == null || goal <= 0) {
            return;
          }
          Navigator.pop(
            context,
            _TargetDraft(nameCtrl.text.trim(), goal, deadline),
          );
        },
      ),
    ],
  );
}

/// Dialog input nama pos.
Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String current,
}) {
  final ctrl = TextEditingController(text: current);
  return showQuestDialog<String>(
    context,
    title: title,
    content: TextField(
      controller: ctrl,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Nama pos'),
    ),
    actions: [
      QuestButton(
        label: 'Batal',
        tone: QuestTone.secondary,
        onPressed: () => Navigator.pop(context),
      ),
      QuestButton(
        label: 'Simpan',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.pop(context, ctrl.text.trim()),
      ),
    ],
  );
}

/// Sheet Sisihkan: pos terkunci, nominal, akun sumber (dengan saldo).
/// Nominal melebihi saldo sumber ditolak dengan pesan jelas.
class SisihkanSheet extends StatefulWidget {
  const SisihkanSheet({
    super.key,
    required this.repository,
    required this.entry,
    this.progress,
  });

  final LedgerRepository repository;
  final TargetWithProgress entry;

  /// Bila ada, dipanggil setelah setoran agar Beranda ikut segar.
  final ProgressService? progress;

  static Future<void> show(
    BuildContext context,
    LedgerRepository repository,
    TargetWithProgress entry, {
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
        child: SisihkanSheet(
          repository: repository,
          entry: entry,
          progress: progress,
        ),
      ),
    );
  }

  @override
  State<SisihkanSheet> createState() => _SisihkanSheetState();
}

class _SisihkanSheetState extends State<SisihkanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  int? _accountId;
  bool _saving = false;

  /// Pesan error saldo — ditampilkan DI DALAM sheet (snackbar tertutup
  /// modal bottom sheet, user tidak melihatnya).
  String? _saldoError;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(
    List<Account> accounts,
    Map<int, int> balances,
    int accountId,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = Money.tryParseGroup(_amountCtrl.text);
    if (amount == null || amount <= 0) return;
    final account = accounts.firstWhere((a) => a.id == accountId);
    final balance = balances[accountId] ?? 0;
    if (amount > balance) {
      setState(() {
        _saldoError =
            'Saldo ${account.name} tidak cukup — sisa '
            '${Money.format(balance)}. Kurangi nominal atau pilih akun lain.';
      });
      return;
    }
    if (_saldoError != null) setState(() => _saldoError = null);
    setState(() => _saving = true);
    try {
      await widget.repository.depositToTarget(
        targetId: widget.entry.target.id,
        accountId: accountId,
        amount: amount,
      );
      // Sisihkan = transaksi keluar efektif: Beranda (pace/streak)
      // harus ikut berubah tanpa menunggu tab dipilih ulang.
      await widget.progress?.onTransactionRecorded();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.pop(context);
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
              Text('Sisihkan', style: context.qTitle(20)),
              const SizedBox(height: Spacing.xs),
              // Pos terkunci — sumber setoran tidak bisa diganti di sini.
              Text(
                'Ke pos: ${widget.entry.target.name}',
                style: context.qSmall(),
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _amountCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final amount = Money.tryParseGroup(v);
                  if (amount == null || amount <= 0) {
                    return 'Isi nominal lebih dari 0';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Nominal (rupiah)',
                ),
              ),
              const SizedBox(height: Spacing.m),
              StreamBuilder<List<Account>>(
                stream: widget.repository.watchAccounts(),
                builder: (context, accountSnap) {
                  final accounts = accountSnap.data ?? const <Account>[];
                  return StreamBuilder<Map<int, int>>(
                    stream: widget.repository.watchAccountBalances(),
                    builder: (context, balanceSnap) {
                      final balances = balanceSnap.data ?? const <int, int>{};
                      // Fallback akun pertama bila pilihan belum ada /
                      // terhapus — dihitung, tidak di-setState saat build.
                      final selected =
                          _accountId != null &&
                              accounts.any((a) => a.id == _accountId)
                          ? _accountId!
                          : accounts.isEmpty
                          ? null
                          : accounts.first.id;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: selected,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Dari akun',
                            ),
                            items: [
                              for (final a in accounts)
                                DropdownMenuItem(
                                  value: a.id,
                                  child: Text(
                                    '${a.name} • '
                                    '${Money.format(balances[a.id] ?? 0)}',
                                    overflow: TextOverflow.ellipsis,
                                    style: context.qBody().copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: accounts.isEmpty
                                ? null
                                : (v) => setState(() => _accountId = v),
                          ),
                          if (_saldoError != null) ...[
                            const SizedBox(height: Spacing.s),
                            Text(
                              _saldoError!,
                              style: context.qSmall().copyWith(
                                color: context.q.bad,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: Spacing.m),
                          QuestButton(
                            label: 'Sisihkan',
                            icon: Icons.savings_outlined,
                            onPressed: _saving || selected == null
                                ? null
                                : () => _save(accounts, balances, selected),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
