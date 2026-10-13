import 'package:flutter/material.dart';

import 'package:drift/drift.dart' show Value;

import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../rules/engine.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Layar Aturan: daftar aturan capture buatan pengguna + editor + uji coba.
class RulesScreen extends StatefulWidget {
  const RulesScreen({
    super.key,
    required this.repository,
    required this.engine,
    required this.progress,
  });

  final LedgerRepository repository;
  final RuleEngine engine;
  final ProgressService progress;

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  Future<void> _openEditor({UserRule? existing}) async {
    final saved = await showQuestSheet<bool>(
      context,
      (context) =>
          _RuleEditor(repository: widget.repository, existing: existing),
    );
    if (saved ?? false) {
      await _syncEngine();
      if (mounted) {
        questSnack(
          context,
          'Aturan disimpan.',
          icon: Icons.check_circle_rounded,
        );
      }
      // Parse ulang notifikasi yang dulu gagal — aturan baru mungkin cocok.
      final count = await widget.repository.reparseUnparsed(widget.engine);
      if (count > 0 && mounted) {
        questSnack(
          context,
          '$count notifikasi lama berhasil diparse ulang.',
          icon: Icons.auto_fix_high_rounded,
        );
      }
    }
  }

  Future<void> _syncEngine() async {
    widget.engine.setUserRules(await widget.repository.userRuleDefs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Aturan capture',
        subtitle: 'Aturan buatanmu dipakai sebelum aturan bawaan',
        showBack: true,
      ),
      floatingActionButton: QuestFab(
        label: 'Aturan',
        icon: Icons.add_rounded,
        onTap: () => _openEditor(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m,
        ),
        children: [
          QuestCard(
            child: Text(
              'Aturan menentukan bagaimana notifikasi diubah jadi transaksi: '
              'pakai aplikasi mana, harus mengandung kata apa, arah, dan '
              'jenisnya. Aturanmu diprioritaskan di atas aturan bawaan.',
              style: context.qSmall(),
            ),
          ),
          const QuestSectionHeader(title: 'Aturan kamu'),
          StreamBuilder<List<UserRule>>(
            stream: widget.repository.watchUserRules(),
            builder: (context, snapshot) {
              final rules = snapshot.data ?? const <UserRule>[];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const QuestSkeleton();
              }
              if (rules.isEmpty) {
                return QuestEmpty(
                  title: 'Belum ada aturan',
                  hint:
                      'Aturan bawaan masih dipakai. Tambahkan aturan untuk '
                      'menggantinya.',
                  actionLabel: 'Buat aturan',
                  onAction: () => _openEditor(),
                );
              }
              return Column(
                children: [
                  for (final rule in rules)
                    _RuleTile(
                      rule: rule,
                      repository: widget.repository,
                      onChanged: () => _syncEngine(),
                      onEdit: () => _openEditor(existing: rule),
                    ),
                ],
              );
            },
          ),
          const QuestSectionHeader(title: 'Uji coba'),
          _RuleTestCard(engine: widget.engine, repository: widget.repository),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.repository,
    required this.onChanged,
    required this.onEdit,
  });

  final UserRule rule;
  final LedgerRepository repository;
  final VoidCallback onChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scope = rule.packageName ?? 'Semua aplikasi';
    final match = rule.matchText ?? 'Bebas kata kunci';
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      child: QuestCard(
        onTap: onEdit,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule.name, style: context.qTitle(15)),
                  const SizedBox(height: 2),
                  Text(
                    '$scope · mengandung "$match"',
                    overflow: TextOverflow.ellipsis,
                    style: context.qSmall(),
                  ),
                  Text(
                    '${rule.direction.direction.label} · ${rule.kind.label}',
                    style: context.qSmall(11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.s),
            QuestSwitch(
              value: rule.enabled,
              label: 'Aktifkan aturan ${rule.name}',
              onChanged: (v) async {
                await repository.updateUserRule(
                  rule.id,
                  UserRulesCompanion(enabled: Value(v)),
                );
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleTestCard extends StatefulWidget {
  const _RuleTestCard({required this.engine, required this.repository});

  final RuleEngine engine;
  final LedgerRepository repository;

  @override
  State<_RuleTestCard> createState() => _RuleTestCardState();
}

class _RuleTestCardState extends State<_RuleTestCard> {
  final _bodyCtrl = TextEditingController(
    text: 'Penambahan dana ke bluSaving sisa Rp 2.000 berhasil',
  );

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Uji coba notifikasi', style: context.qTitle(15)),
          const SizedBox(height: Spacing.s),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Isi notifikasi',
              hintText: 'Tempel teks notifikasi bank di sini',
            ),
          ),
          const SizedBox(height: Spacing.m),
          QuestButton(
            label: 'Uji',
            icon: Icons.science_outlined,
            tone: QuestTone.secondary,
            onPressed: () {
              final draft = widget.engine.parse(
                packageName: '',
                title: '',
                body: _bodyCtrl.text,
              );
              questSnack(
                context,
                draft == null
                    ? 'Tidak ada aturan yang cocok.'
                    : '${draft.ruleName}: ${draft.direction.label} '
                          '${Money.format(draft.amount)}',
                icon: draft == null
                    ? Icons.help_outline_rounded
                    : Icons.check_circle_rounded,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({required this.repository, this.existing});

  final LedgerRepository repository;
  final UserRule? existing;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _packageCtrl;
  late final TextEditingController _matchCtrl;
  late final TextEditingController _amountCtrl;
  late UserRuleDirection _direction;
  late TxKind _kind;
  int? _accountId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _packageCtrl = TextEditingController(text: r?.packageName ?? '');
    _matchCtrl = TextEditingController(text: r?.matchText ?? '');
    _amountCtrl = TextEditingController(text: r?.amountPattern ?? '');
    _direction = r?.direction ?? UserRuleDirection.out_;
    _kind = r?.kind ?? TxKind.payment;
    _accountId = r?.accountId;
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accs = await widget.repository.getAccounts();
    if (!mounted) return;
    setState(() {
      if (_accountId != null && !accs.any((a) => a.id == _accountId)) {
        _accountId = null;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _packageCtrl.dispose();
    _matchCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = UserRulesCompanion.insert(
      name: _nameCtrl.text.trim(),
      packageName: Value(
        _packageCtrl.text.trim().isEmpty ? null : _packageCtrl.text.trim(),
      ),
      matchText: Value(
        _matchCtrl.text.trim().isEmpty ? null : _matchCtrl.text.trim(),
      ),
      amountPattern: Value(
        _amountCtrl.text.trim().isEmpty ? null : _amountCtrl.text.trim(),
      ),
      direction: _direction,
      kind: _kind,
      accountId: Value(_accountId),
    );
    if (_isEdit) {
      await widget.repository.updateUserRule(widget.existing!.id, data);
    } else {
      await widget.repository.addUserRule(data);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: Spacing.m,
          right: Spacing.m,
          top: Spacing.s,
          bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.m,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Ubah aturan' : 'Aturan baru',
                style: context.qTitle(20),
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _nameCtrl,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nama aturan'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _packageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Package aplikasi (opsional)',
                  hintText: 'mis. com.bcadigital.blu',
                  helperText: 'Kosong = berlaku untuk semua aplikasi',
                ),
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _matchCtrl,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Harus mengandung teks (opsional)',
                  hintText: 'mis. transfer masuk',
                ),
              ),
              const SizedBox(height: Spacing.m),
              TextFormField(
                controller: _amountCtrl,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Pola nominal custom (opsional)',
                  hintText: r'sebesar\s*(?:rp\.?\s*)?([\d][\d.,]*)',
                  helperText: 'Kosong = pola default (angka setelah "Rp")',
                ),
              ),
              const SizedBox(height: Spacing.m),
              QuestSegmented<UserRuleDirection>(
                selected: _direction,
                onChanged: (d) => setState(() => _direction = d),
                options: const [
                  (
                    value: UserRuleDirection.out_,
                    label: 'Keluar',
                    icon: Icons.arrow_upward_rounded,
                  ),
                  (
                    value: UserRuleDirection.in_,
                    label: 'Masuk',
                    icon: Icons.arrow_downward_rounded,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.m),
              DropdownButtonFormField<TxKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Jenis'),
                items: [
                  for (final k in TxKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (k) => setState(() => _kind = k ?? TxKind.payment),
              ),
              const SizedBox(height: Spacing.m),
              FutureBuilder<List<Account>>(
                future: widget.repository.getAccounts(),
                builder: (context, snap) {
                  final accs = snap.data ?? const <Account>[];
                  return DropdownButtonFormField<int?>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Akun (opsional)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Auto (dari bank)'),
                      ),
                      for (final a in accs)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => setState(() => _accountId = v),
                  );
                },
              ),
              const SizedBox(height: Spacing.l),
              QuestButton(
                label: 'Simpan',
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
