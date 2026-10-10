import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_filter.dart';
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

enum _HistoryPeriod { all, month, sixMonths, custom }

/// Tab Riwayat: cari + filter akun + filter waktu + daftar penuh per hari.
class HistoryTab extends StatefulWidget {
  const HistoryTab({
    super.key,
    required this.repository,
    required this.progress,
  });

  final LedgerRepository repository;
  final ProgressService progress;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int? _accountId;
  _HistoryPeriod _period = _HistoryPeriod.all;
  DateTimeRange? _custom;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRange(DateTime today) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: _custom,
      helpText: 'Pilih rentang tanggal',
      saveText: 'Pilih',
    );
    if (picked != null && mounted) {
      setState(() {
        _custom = picked;
        _period = _HistoryPeriod.custom;
      });
    }
  }

  void _onPeriodChanged(_HistoryPeriod v, DateTime today) {
    if (v == _HistoryPeriod.custom) {
      if (_custom == null) {
        _pickRange(today);
      } else {
        setState(() => _period = _HistoryPeriod.custom);
      }
    } else {
      setState(() => _period = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final DateTime? winStart;
    final DateTime? winEnd;
    switch (_period) {
      case _HistoryPeriod.all:
        winStart = null;
        winEnd = null;
      case _HistoryPeriod.month:
        winStart = DateTime(now.year, now.month);
        winEnd = DateTime(now.year, now.month + 1);
      case _HistoryPeriod.sixMonths:
        winStart = DateTime(now.year, now.month - 5);
        winEnd = DateTime(now.year, now.month + 1);
      case _HistoryPeriod.custom:
        final c = _custom!;
        winStart = DateTime(c.start.year, c.start.month, c.start.day);
        winEnd = DateTime(c.end.year, c.end.month, c.end.day + 1);
    }

    final stream = (winStart == null || winEnd == null)
        ? widget.repository.watchRecentWithCategory(accountId: _accountId)
        : widget.repository.watchBetweenWithCategory(
            winStart, winEnd,
            accountId: _accountId);

    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Riwayat',
        subtitle: 'Semua transaksi',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m,
        ),
        children: [
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari pihak, kategori, nominal…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Bersihkan',
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: Spacing.s),
          AccountFilter(
            repository: widget.repository,
            selectedId: _accountId,
            onChanged: (id) => setState(() => _accountId = id),
          ),
          const SizedBox(height: Spacing.s),
          QuestSegmented<_HistoryPeriod>(
            selected: _period,
            onChanged: (v) => _onPeriodChanged(v, today),
            options: const [
              (value: _HistoryPeriod.all, label: 'Semua', icon: null),
              (value: _HistoryPeriod.month, label: 'Bulan ini', icon: null),
              (
                value: _HistoryPeriod.sixMonths,
                label: '6 bulan',
                icon: null
              ),
              (value: _HistoryPeriod.custom, label: 'Rentang', icon: null),
            ],
          ),
          if (_period == _HistoryPeriod.custom && _custom != null) ...[
            const SizedBox(height: Spacing.s),
            QuestChip(
              label:
                  '${idDayMonth(_custom!.start)} – ${idDayMonth(_custom!.end)} · Ubah',
              selected: true,
              onTap: () => _pickRange(today),
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
                  if (matchesQuery(r, _query)) r,
              ];
              if (items.isEmpty) {
                final filtering =
                    _query.isNotEmpty || _accountId != null || _custom != null;
                return QuestEmpty(
                  title: filtering ? 'Tidak ada yang cocok' : 'Belum ada catatan',
                  hint: filtering
                      ? 'Coba kata kunci, akun, atau rentang lain.'
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
      ),
    );
  }
}
