import 'package:flutter/material.dart';

import '../core/rekap_filter.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_filter.dart';
import 'account_manage_screen.dart';
import 'history_screen.dart' show matchesQuery;
import 'quest.dart';
import 'transaction_tile.dart';

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

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.filter.query ?? '';
  }

  @override
  void didUpdateWidget(RekapTransaksi old) {
    super.didUpdateWidget(old);
    final q = widget.filter.query ?? '';
    if (_searchCtrl.text != q) _searchCtrl.text = q;
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

    final DateTime? winStart;
    final DateTime? winEnd;
    if (filter.rangeStart != null && filter.rangeEnd != null) {
      final s = filter.rangeStart!;
      final e = filter.rangeEnd!;
      winStart = DateTime(s.year, s.month, s.day);
      // batas eksklusif: akhir + 1 hari
      winEnd = DateTime(e.year, e.month, e.day + 1);
    } else if (filter.month != null) {
      final m = filter.month!;
      winStart = DateTime(m.year, m.month);
      winEnd = DateTime(m.year, m.month + 1);
    } else {
      winStart = null;
      winEnd = null;
    }

    final stream = (winStart == null || winEnd == null)
        ? widget.repository.watchRecentWithCategory(accountId: filter.accountId)
        : widget.repository.watchBetweenWithCategory(
            winStart,
            winEnd,
            accountId: filter.accountId,
          );

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
        if (filter.accountId != null) ...[
          const SizedBox(height: Spacing.s),
          _AccountChip(
            onClear: () => _update(
              _AccountPatch(base: filter, accountId: null).build(),
            ),
          ),
        ],
        const SizedBox(height: Spacing.s),
        StreamBuilder<List<TxWithCategory>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const QuestSkeleton();
            }
            final items = [
              for (final r in snapshot.data ?? const <TxWithCategory>[])
                if (matchesQuery(r, query)) r,
            ];
            if (items.isEmpty) {
              final filtering = query.isNotEmpty || filter.accountId != null;
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

/// Chip filter akun aktif yang bisa dihapus.
class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onClear,
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 6, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: q.honey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Akun',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: q.text,
              ),
            ),
            const SizedBox(width: 4),
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
                      builder: (_) => AccountManageScreen(
                        repository: widget.repository,
                      ),
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
