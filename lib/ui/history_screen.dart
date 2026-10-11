import 'package:flutter/material.dart';

import '../core/dates_id.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_filter.dart';
import 'account_manage_screen.dart';
import 'month_picker.dart';
import 'quest.dart';
import 'range_calendar.dart';
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

enum _HistoryPeriod { all, month, custom }

/// Tab Riwayat: pencarian + filter (akun & waktu) dalam satu sheet.
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
  DateTime? _month; // bulan terpilih, dinormalisasi ke tanggal 1
  DateTimeRange? _custom;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    var n = 0;
    if (_accountId != null) n++;
    if (_period != _HistoryPeriod.all) n++;
    return n;
  }

  String get _periodLabel => switch (_period) {
        _HistoryPeriod.month => _month == null
            ? 'Bulan'
            : _monthLabel(_month!),
        _HistoryPeriod.custom => _custom == null
            ? 'Rentang'
            : '${idDayMonth(_custom!.start)} – ${idDayMonth(_custom!.end)}',
        _HistoryPeriod.all => 'Semua waktu',
      };

  /// 'Bulan ini' bila bulan berjalan, selain itu 'Okt 2026'.
  String _monthLabel(DateTime m) {
    final now = DateTime.now();
    if (m.year == now.year && m.month == now.month) return 'Bulan ini';
    return idMonthYear(m);
  }

  Future<void> _openFilterSheet() async {
    await showQuestSheet<void>(
      context,
      (context) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.m,
          right: Spacing.m,
          top: Spacing.s,
          bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.m,
        ),
        child: _FilterSheet(
          repository: widget.repository,
          accountId: _accountId,
          period: _period,
          month: _month,
          custom: _custom,
          onApply: (accountId, period, month, custom) {
            setState(() {
              _accountId = accountId;
              _period = period;
              _month = month;
              _custom = custom;
            });
          },
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final DateTime? winStart;
    final DateTime? winEnd;
    switch (_period) {
      case _HistoryPeriod.all:
        winStart = null;
        winEnd = null;
      case _HistoryPeriod.month:
        final m = _month ?? DateTime(now.year, now.month);
        winStart = DateTime(m.year, m.month);
        winEnd = DateTime(m.year, m.month + 1);
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
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Bersihkan pencarian',
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
                  Badge(
                    isLabelVisible: _activeFilterCount > 0,
                    label: Text('$_activeFilterCount'),
                    backgroundColor: context.q.honey,
                    child: IconButton(
                      tooltip: 'Filter',
                      icon: const Icon(Icons.filter_list_rounded),
                      onPressed: _openFilterSheet,
                    ),
                  ),
                ],
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          if (_activeFilterCount > 0) ...[
            const SizedBox(height: Spacing.s),
            _ActiveFilterChips(
              accountName: _accountName(),
              periodLabel:
                  _period == _HistoryPeriod.all ? null : _periodLabel,
              onClearAccount:
                  _accountId == null ? null : () => setState(() => _accountId = null),
              onClearPeriod: _period == _HistoryPeriod.all
                  ? null
                  : () => setState(() => _period = _HistoryPeriod.all),
              onTapPeriod:
                  _period == _HistoryPeriod.custom ? _pickRange : null,
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
                    _query.isNotEmpty || _activeFilterCount > 0;
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

  String? _accountName() {
    if (_accountId == null) return null;
    // Nama dicari di build _ActiveFilterChips via stream akun; di sini
    // cukup label generik.
    return 'Akun';
  }
}

/// Chip filter aktif yang bisa dihapus satu per satu.
class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.accountName,
    required this.periodLabel,
    required this.onClearAccount,
    required this.onClearPeriod,
    this.onTapPeriod,
  });

  final String? accountName;
  final String? periodLabel;
  final VoidCallback? onClearAccount;
  final VoidCallback? onClearPeriod;
  final VoidCallback? onTapPeriod;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.s,
      runSpacing: Spacing.s,
      children: [
        if (accountName != null)
          _RemovableChip(
            label: accountName!,
            onClear: onClearAccount!,
          ),
        if (periodLabel != null)
          _RemovableChip(
            label: periodLabel!,
            onClear: onClearPeriod!,
            onTap: onTapPeriod,
          ),
      ],
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({
    required this.label,
    required this.onClear,
    this.onTap,
  });

  final String label;
  final VoidCallback onClear;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: onTap,
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
              label,
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

/// Isi sheet filter: akun + waktu (bulan atau rentang tanggal).
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.repository,
    required this.accountId,
    required this.period,
    required this.month,
    required this.custom,
    required this.onApply,
  });

  final LedgerRepository repository;
  final int? accountId;
  final _HistoryPeriod period;
  final DateTime? month;
  final DateTimeRange? custom;
  final void Function(
    int? accountId,
    _HistoryPeriod period,
    DateTime? month,
    DateTimeRange? custom,
  ) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  int? _accountId;
  _HistoryPeriod _period = _HistoryPeriod.all;
  DateTime? _month;
  DateTimeRange? _custom;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accountId;
    _period = widget.period;
    _month = widget.month;
    _custom = widget.custom;
  }

  void _selectPeriod(_HistoryPeriod v) {
    setState(() {
      _period = v;
      if (v == _HistoryPeriod.month && _month == null) {
        final now = DateTime.now();
        _month = DateTime(now.year, now.month);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter', style: context.qTitle(20)),
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
            const SizedBox(height: Spacing.m),
            Text('Waktu', style: context.qEyebrow()),
            const SizedBox(height: Spacing.s),
            QuestSegmented<_HistoryPeriod>(
              selected: _period,
              onChanged: _selectPeriod,
              options: const [
                (value: _HistoryPeriod.month, label: 'Bulan', icon: null),
                (value: _HistoryPeriod.custom, label: 'Rentang', icon: null),
              ],
            ),
            if (_period == _HistoryPeriod.month) ...[
              const SizedBox(height: Spacing.m),
              QuestCard(
                radius: 16,
                child: QuestMonthPicker(
                  initialMonth: _month,
                  onChanged: (m) => setState(() => _month = m),
                ),
              ),
            ],
            if (_period == _HistoryPeriod.custom) ...[
              const SizedBox(height: Spacing.m),
              QuestCard(
                radius: 16,
                child: QuestRangeCalendar(
                  initialRange: _custom,
                  onChanged: (r) => setState(() => _custom = r),
                ),
              ),
            ],
            const SizedBox(height: Spacing.l),
            QuestButton(
              label: 'Terapkan',
              icon: Icons.check_rounded,
              onPressed: () {
                // Rentang tanpa pilihan tanggal = tanpa filter waktu,
                // jangan biarkan _custom! crash di build.
                final period =
                    _period == _HistoryPeriod.custom && _custom == null
                        ? _HistoryPeriod.all
                        : _period;
                widget.onApply(_accountId, period, _month, _custom);
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
