import 'dart:async';

import 'package:flutter/material.dart';

import '../core/rekap_filter.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_filter.dart';
import 'account_manage_screen.dart';
import 'quest.dart';
import 'transaction_tile.dart';

/// Cocokkan transaksi dengan query: pihak, kategori, bank, jenis, nominal.
bool matchesQuery(TxWithCategory item, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final tx = item.tx;
  final haystacks = [
    tx.counterparty ?? '',
    item.category?.name ?? '',
    tx.bankId,
    tx.kind.label,
    tx.amount.toString(),
  ].map((s) => s.toLowerCase());
  return haystacks.any((h) => h.contains(q));
}

/// Segmen Transaksi pada layar Rekap: pencarian + filter akun + daftar
/// transaksi sesuai [filter]. State filter dimiliki shell; perubahan
/// dilaporkan lewat [onFilterChanged] (tidak diduplikasi di sini).
class RekapTransaksi extends StatefulWidget {
  const RekapTransaksi({
    super.key,
    required this.repository,
    required this.filter,
    required this.onFilterChanged,
    this.progress,
  });

  final LedgerRepository repository;
  final RekapFilter filter;
  final ValueChanged<RekapFilter> onFilterChanged;
  final ProgressService? progress;

  @override
  State<RekapTransaksi> createState() => _RekapTransaksiState();
}

class _RekapTransaksiState extends State<RekapTransaksi> {
  final _searchCtrl = TextEditingController();
  // Disematkan sekali agar rebuild tak subscribe ulang (anti-kedip).
  late Stream<List<TxWithCategory>> _rows;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.filter.query ?? '';
    _refreshRows();
  }

  @override
  void didUpdateWidget(RekapTransaksi old) {
    super.didUpdateWidget(old);
    final q = widget.filter.query ?? '';
    if (_searchCtrl.text != q) _searchCtrl.text = q;
    // TANPA setState — build sudah terjadwal; StreamBuilder di bawah melihat stream baru dan subscribe dengan benar.
    // RekapFilter tak punya == — bandingkan field perakit stream satu per satu.
    // query/categoryId disaring lokal di builder, bukan di stream — tak ikut kunci.
    if (widget.repository != old.repository ||
        widget.filter.day != old.filter.day ||
        widget.filter.accountId != old.filter.accountId ||
        _windowKey(widget.filter) != _windowKey(old.filter)) {
      _refreshRows();
    }
  }

  void _refreshRows() {
    _rows = _buildRows(widget.filter);
  }

  Stream<List<TxWithCategory>> _buildRows(RekapFilter filter) {
    final win = filter.window;
    final day = filter.day;
    if (day != null) {
      // Deep-link kalender: sempitkan jendela ke satu hari itu.
      return widget.repository.watchBetweenWithCategory(
        DateTime(day.year, day.month, day.day),
        DateTime(day.year, day.month, day.day + 1),
        accountId: filter.accountId,
      );
    }
    if (win == null) {
      return widget.repository.watchRecentWithCategory(
        accountId: filter.accountId,
      );
    }
    return widget.repository.watchBetweenWithCategory(
      win.start,
      win.end,
      accountId: filter.accountId,
    );
  }

  static String _windowKey(RekapFilter f) {
    final win = f.window;
    return '${win?.start}|${win?.end}';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _update(RekapFilter next) => widget.onFilterChanged(next);

  Future<void> _openAccountSheet() async {
    var accountId = widget.filter.accountId;
    await showQuestSheet<void>(
      context,
      (context) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.m,
          right: Spacing.m,
          top: Spacing.s,
          bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.m,
        ),
        child: _AccountSheet(
          repository: widget.repository,
          accountId: accountId,
          onApply: (id) => accountId = id,
        ),
      ),
    );
    // Selalu emit hasil sheet saat tertutup — jangan bandingkan akun
    // lama (bisa basi bila filter berubah selama sheet terbuka).
    _update(_AccountPatch(base: widget.filter, accountId: accountId).build());
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;
    final query = filter.query ?? '';

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Spacing.m,
        Spacing.s,
        Spacing.m,
        Spacing.m + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Cari pihak, kategori, nominal…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (query.isNotEmpty)
                  IconButton(
                    tooltip: 'Bersihkan pencarian',
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchCtrl.clear();
                      _update(_QueryPatch(base: filter, query: '').build());
                    },
                  ),
                Badge(
                  isLabelVisible: filter.accountId != null,
                  label: const Text('1'),
                  backgroundColor: context.q.honey,
                  child: IconButton(
                    tooltip: 'Filter akun',
                    icon: const Icon(Icons.filter_list_rounded),
                    onPressed: _openAccountSheet,
                  ),
                ),
              ],
            ),
          ),
          onChanged: (v) =>
              _update(_QueryPatch(base: filter, query: v).build()),
        ),
        if (filter.accountId != null ||
            filter.categoryId != null ||
            filter.day != null) ...[
          const SizedBox(height: Spacing.s),
          Wrap(
            spacing: Spacing.s,
            runSpacing: 4,
            children: [
              if (filter.accountId != null)
                _FilterChip(
                  label: 'Akun',
                  onClear: () => _update(
                    _AccountPatch(base: filter, accountId: null).build(),
                  ),
                ),
              if (filter.categoryId != null)
                _FilterChip(
                  label: 'Kategori',
                  onClear: () => _update(filter.clearChip()),
                ),
              // Deep-link Kalender: ✕ membersihkan tanggal (dan kategori
              // — kontrak clearChip sebagaimana dibangun).
              if (filter.day != null)
                _FilterChip(
                  label: 'Tanggal',
                  onClear: () => _update(filter.clearChip()),
                ),
            ],
          ),
        ],
        const SizedBox(height: Spacing.s),
        StreamBuilder<List<TxWithCategory>>(
          stream: _rows,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const QuestSkeleton();
            }
            final items = [
              for (final r in snapshot.data ?? const <TxWithCategory>[])
                if (matchesQuery(r, query) &&
                    (filter.categoryId == null ||
                        r.category?.id == filter.categoryId))
                  r,
            ];
            if (items.isEmpty) {
              final filtering =
                  query.isNotEmpty ||
                  filter.accountId != null ||
                  filter.categoryId != null ||
                  filter.day != null;
              return QuestEmpty(
                title: filtering ? 'Tidak ada yang cocok' : 'Belum ada catatan',
                hint: filtering
                    ? 'Coba kata kunci, akun, atau periode lain.'
                    : 'Catat transaksimu yang pertama.',
              );
            }
            final byDay = groupTxByDay(items);
            return Column(
              children: [
                for (final entry in byDay.entries) ...[
                  TransactionDayHeader(
                    day: entry.key,
                    first: entry.key == byDay.keys.first,
                    totalOut: entry.value.fold<int>(
                      0,
                      (sum, r) =>
                          sum +
                          (r.tx.direction == Direction.outgoing
                              ? r.tx.amount
                              : 0),
                    ),
                  ),
                  for (final item in entry.value)
                    TransactionTile(
                      item: item,
                      repository: widget.repository,
                      progress: widget.progress,
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Salin field filter, ganti accountId.
class _AccountPatch {
  const _AccountPatch({required this.base, required this.accountId});

  final RekapFilter base;
  final int? accountId;

  RekapFilter build() => RekapFilter(
    month: base.month,
    rangeStart: base.rangeStart,
    rangeEnd: base.rangeEnd,
    accountId: accountId,
    query: base.query,
    categoryId: base.categoryId,
    day: base.day,
  );
}

/// Salin field filter, ganti query.
class _QueryPatch {
  const _QueryPatch({required this.base, required this.query});

  final RekapFilter base;
  final String query;

  RekapFilter build() => RekapFilter(
    month: base.month,
    rangeStart: base.rangeStart,
    rangeEnd: base.rangeEnd,
    accountId: base.accountId,
    query: query,
    categoryId: base.categoryId,
    day: base.day,
  );
}

/// Chip filter aktif (akun/kategori) yang bisa dihapus.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onClear,
      child: Container(
        padding: Insets.chip,
        decoration: BoxDecoration(
          color: q.honey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: q.text,
              ),
            ),
            const SizedBox(width: Spacing.xs),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded, size: 16, color: q.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Isi sheet filter akun.
class _AccountSheet extends StatefulWidget {
  const _AccountSheet({
    required this.repository,
    required this.accountId,
    required this.onApply,
  });

  final LedgerRepository repository;
  final int? accountId;
  final void Function(int? accountId) onApply;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  int? _accountId;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accountId;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter akun', style: context.qTitle(20)),
            const SizedBox(height: Spacing.m),
            Row(
              children: [
                Text('Akun', style: context.qEyebrow()),
                const Spacer(),
                QuestPress(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AccountManageScreen(repository: widget.repository),
                    ),
                  ),
                  child: Text(
                    'Kelola',
                    style: TextStyle(
                      color: context.q.honey,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.s),
            AccountFilter(
              repository: widget.repository,
              selectedId: _accountId,
              onChanged: (id) => setState(() => _accountId = id),
            ),
            const SizedBox(height: Spacing.l),
            QuestButton(
              label: 'Terapkan',
              icon: Icons.check_rounded,
              onPressed: () {
                widget.onApply(_accountId);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: Spacing.s),
          ],
        ),
      ),
    );
  }
}
