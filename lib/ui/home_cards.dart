import 'dart:async';

import 'package:flutter/material.dart';

import '../core/budget.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import 'transaction_sheet.dart';

/// Kartu-kartu Beranda ala mock pastel: batas 3 kolom, arus keluar/masuk,
/// disiplin bulanan, dan transaksi terbaru. Semua mengalir via
/// stream/service sehingga selalu segar.

/// Kartu uang: saldo + sisa aman hari ini dalam satu grid — label di
/// kiri, nilai di kanan (mockup L1).
///
/// Tap kartu → Rencana·Batas; tap avatar akun → Kelola Akun.
class UangCard extends StatefulWidget {
  const UangCard({
    super.key,
    required this.repository,
    required this.progress,
    required this.onTap,
    this.onTapAccounts,
  });

  final LedgerRepository repository;
  final ProgressService progress;
  final VoidCallback onTap;
  final VoidCallback? onTapAccounts;

  @override
  State<UangCard> createState() => _UangCardState();
}

class _UangCardState extends State<UangCard> {
  /// Disematkan sekali agar rebuild tak subscribe ulang (anti-kedip).
  late final Stream<List<Account>> _accounts;
  late final Stream<Map<int, int>> _balances;

  @override
  void initState() {
    super.initState();
    _accounts = widget.repository.watchAccounts();
    _balances = widget.repository.watchAccountBalances();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: _accounts,
      builder: (context, accSnap) => StreamBuilder<Map<int, int>>(
        stream: _balances,
        builder: (context, balSnap) {
          final accounts = accSnap.data ?? const <Account>[];
          final balances = balSnap.data ?? const <int, int>{};
          final total = balances.values.fold(0, (a, b) => a + b);
          return ListenableBuilder(
            listenable: widget.progress,
            builder: (context, _) {
              final lines = widget.progress.latest?.snapshot.lines;
              LimitLine? at(int i) =>
                  lines != null && lines.length > i ? lines[i] : null;
              return _UangCardBody(
                total: total,
                accounts: accounts,
                daily: at(0),
                weekly: at(1),
                monthly: at(2),
                streakDays: widget.progress.latest?.streakDays ?? 0,
                onTap: widget.onTap,
                onTapAccounts: widget.onTapAccounts,
              );
            },
          );
        },
      ),
    );
  }
}

class _UangCardBody extends StatelessWidget {
  const _UangCardBody({
    required this.total,
    required this.accounts,
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.streakDays,
    required this.onTap,
    this.onTapAccounts,
  });

  final int total;
  final List<Account> accounts;
  final LimitLine? daily;
  final LimitLine? weekly;
  final LimitLine? monthly;
  final int streakDays;
  final VoidCallback onTap;
  final VoidCallback? onTapAccounts;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final limit = daily?.limit;
    final used = daily?.used ?? 0;
    final hasLimit = limit != null && limit > 0;
    final sisa = (limit ?? 0) - used;
    final over = hasLimit && sisa < 0;
    final fraction = hasLimit ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return QuestCard(
      onTap: onTap,
      radius: AppRadius.sheet,
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1 — saldo + akun (tap avatar → Kelola Akun).
          Row(
            children: [
              Text(
                'Saldo',
                style: context.qSmall(11).copyWith(
                  color: q.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: Spacing.s),
              if (accounts.isNotEmpty)
                GestureDetector(
                  onTap: onTapAccounts,
                  behavior: HitTestBehavior.opaque,
                  child: _AkunChips(accounts: accounts),
                ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(Money.format(total), style: context.qDisplay(28)),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.m),
          Divider(height: 1, thickness: 1, color: q.line),
          const SizedBox(height: Spacing.m),
          // Baris 2 — sisa aman hari ini.
          Row(
            children: [
              Text('SISA AMAN HARI INI', style: context.qEyebrow(10)),
              const SizedBox(width: Spacing.s),
              if (streakDays > 0)
                _MiniChip(
                  '$streakDays hari',
                  QuestPalette.mintTint,
                  QuestPalette.mintInk,
                ),
              const Spacer(),
              Text(
                !hasLimit
                    ? 'Tanpa batas'
                    : over
                        ? '−${Money.format(-sisa)}'
                        : Money.format(sisa),
                style: context.qTitle(22).copyWith(color: over ? q.bad : null),
              ),
            ],
          ),
          const SizedBox(height: Spacing.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Stack(
              children: [
                Container(height: 10, color: q.line.withValues(alpha: 0.7)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: Container(height: 10, color: over ? q.bad : q.honey),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.s),
          // Baris 3 — terpakai + sisa batas mingguan/bulanan.
          Row(
            children: [
              Expanded(
                child: Text(
                  hasLimit
                      ? 'Terpakai ${Money.format(used)}'
                      : 'Belum ada batas harian',
                  overflow: TextOverflow.ellipsis,
                  style: context.qSmall(11),
                ),
              ),
              if (weekly?.limit != null)
                _MiniChip(
                  'Mingguan ${_shortMoney(weekly!.limit! - weekly!.used)}',
                  q.bg,
                  q.muted,
                ),
              if (weekly?.limit != null && monthly?.limit != null)
                const SizedBox(width: Spacing.xs),
              if (monthly?.limit != null)
                _MiniChip(
                  'Bulanan ${_shortMoney(monthly!.limit! - monthly!.used)}',
                  q.bg,
                  q.muted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip kecil inline (streak, sisa batas mingguan/bulanan).
class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

/// Avatar mini akun di baris saldo — warna dari colorIndex akun (bahasa
/// data, ADR-010).
class _AkunChips extends StatelessWidget {
  const _AkunChips({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in accounts.take(3))
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SeedColors.categoryColor(a.colorIndex),
                shape: BoxShape.circle,
              ),
              child: Text(
                a.name.trim().isEmpty ? '?' : a.name.trim()[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: SeedColors.surface,
                ),
              ),
            ),
          ),
        if (accounts.length > 3)
          Text(
            '+${accounts.length - 3}',
            style: context.qSmall(11).copyWith(
              color: q.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        Icon(Icons.chevron_right_rounded, size: 15, color: q.muted),
      ],
    );
  }
}

/// Rupiah ringkas untuk kolom sempit: -78000 → '-78rb',
/// 1500000 → '1,5jt', 11002000 → '11jt'. Nominal penuh tetap tampil di
/// baris kecil "dari …" agar tidak ada info yang hilang.
String _shortMoney(int v) {
  final sign = v < 0 ? '-' : '';
  final a = v.abs();
  if (a >= 1000000) {
    final jt = (a / 100000).round() / 10;
    final s = jt == jt.roundToDouble()
        ? jt.toStringAsFixed(0)
        : jt.toStringAsFixed(1);
    return '$sign${s.replaceAll('.', ',')}jt';
  }
  if (a >= 10000) return '$sign${a ~/ 1000}rb';
  return '$sign${Money.format(a)}';
}

/// Arus bulan berjalan: KELUAR | MASUK dalam satu kartu dua kolom.
/// Tap → Rekap (via [onTap]).
class ArusCard extends StatelessWidget {
  const ArusCard({super.key, required this.service, this.onTap});

  final ProgressService service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final snap = service.latest;
        if (snap == null) {
          return QuestCard(
            radius: AppRadius.sheet,
            padding: const EdgeInsets.all(Spacing.m),
            child: const SizedBox(height: 64),
          );
        }
        final q = context.q;
        final shot = snap.snapshot;
        return QuestCard(
          onTap: onTap,
          radius: AppRadius.sheet,
          padding: const EdgeInsets.all(Spacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ARUS BULAN INI', style: context.qEyebrow(10)),
              const SizedBox(height: Spacing.m),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ArusColumn(
                      label: 'Keluar',
                      amount: snap.monthOut,
                      previous: shot.lastMonthOut,
                      incoming: false,
                    ),
                  ),
                  Container(width: 1, height: 46, color: q.line),
                  Expanded(
                    child: _ArusColumn(
                      label: 'Masuk',
                      amount: snap.monthIn,
                      previous: shot.lastMonthIn,
                      incoming: true,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Satu kolom arus: label + delta + nominal.
class _ArusColumn extends StatelessWidget {
  const _ArusColumn({
    required this.label,
    required this.amount,
    required this.previous,
    required this.incoming,
    this.alignEnd = false,
  });

  final String label;
  final int amount;
  final int previous;
  final bool incoming;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final delta = deltaLabel(amount, previous);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.qSmall(11).copyWith(
                color: q.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (delta != null) ...[
              const SizedBox(width: Spacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: q.bg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  delta,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: q.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Spacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            Money.format(amount),
            style: context.qTitle(22).copyWith(
              color: incoming ? q.good : q.bad,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Transaksi terbaru (3 teratas) di Beranda. Tap baris = ubah,
/// "Lihat semua" → Rekap (via [onSeeAll]).
class TransaksiTerbaruCard extends StatefulWidget {
  const TransaksiTerbaruCard({
    super.key,
    required this.repository,
    required this.progress,
    required this.onSeeAll,
  });

  final LedgerRepository repository;
  final ProgressService progress;
  final VoidCallback onSeeAll;

  @override
  State<TransaksiTerbaruCard> createState() => _TransaksiTerbaruCardState();
}

class _TransaksiTerbaruCardState extends State<TransaksiTerbaruCard> {
  /// Disematkan sekali agar rebuild tak subscribe ulang (anti-kedip).
  late final Stream<List<TxWithCategory>> _recent;

  @override
  void initState() {
    super.initState();
    _recent = widget.repository.watchRecentWithCategory(limit: 3);
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestCard(
      radius: AppRadius.sheet,
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestPress(
            onTap: widget.onSeeAll,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Transaksi Terbaru',
                    style: context.qTitle(15),
                  ),
                ),
                Text('Lihat semua', style: context.qSmall(13)),
                const SizedBox(width: Spacing.xxs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: q.muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.s),
          StreamBuilder<List<TxWithCategory>>(
            stream: _recent,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const QuestSkeleton(rows: 3, height: 60);
              }
              final items = snapshot.data ?? const <TxWithCategory>[];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.s),
                  child: Text(
                    'Hari ini masih sepi — catat yang pertama, ya',
                    style: context.qSmall(12),
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Divider(height: 1, thickness: 1, color: q.line),
                    _RecentRow(
                      item: items[i],
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

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.item,
    required this.repository,
    required this.progress,
  });

  final TxWithCategory item;
  final LedgerRepository repository;
  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final tx = item.tx;
    final incoming = tx.direction == Direction.incoming;
    final title = (tx.counterparty != null && tx.counterparty!.isNotEmpty)
        ? tx.counterparty!
        : tx.kind.label;
    final subtitle =
        '${incoming ? 'Pemasukan' : 'Pengeluaran'} • ${idDayMonth(tx.occurredAt)} ${tx.occurredAt.year}';
    final tint = (incoming ? q.good : q.bad).withValues(alpha: 0.14);
    final tintIcon = incoming ? q.good : q.bad;
    return QuestPress(
      onTap: () => TransactionSheet.show(
        context,
        repository,
        existing: item,
        progress: progress,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(
                incoming
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 22,
                color: tintIcon,
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: context.qTitle(14),
                  ),
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: context.qSmall(12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.s),
            Text(
              '${incoming ? '+' : '-'}${Money.format(tx.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: incoming ? q.good : q.bad,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Insight 7 hari terakhir (mockup v2.1): sparkline keluar harian +
/// 3 kategori teratas — jembatan ke Rekap (tap via [onTap]).
class InsightTujuhHariCard extends StatefulWidget {
  const InsightTujuhHariCard({super.key, required this.repository, this.onTap});

  final LedgerRepository repository;
  final VoidCallback? onTap;

  @override
  State<InsightTujuhHariCard> createState() => _InsightTujuhHariCardState();
}

class _InsightTujuhHariCardState extends State<InsightTujuhHariCard> {
  late Stream<List<TxWithCategory>> _rows;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 6);
    final end = DateTime(now.year, now.month, now.day + 1);
    _rows = widget.repository.watchBetweenWithCategory(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TxWithCategory>>(
      stream: _rows,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const QuestSkeleton(rows: 1, height: 90);
        }
        final rows = snapshot.data ?? const <TxWithCategory>[];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Keluar murni per hari (7 ember) + per kategori.
        final daily = List<int>.filled(7, 0);
        final byCategory = <Category?, int>{};
        for (final r in rows) {
          if (r.tx.direction != Direction.outgoing) continue;
          if (r.tx.kind == TxKind.transfer) continue;
          final d = r.tx.occurredAt;
          final day = DateTime(d.year, d.month, d.day);
          final idx = today.difference(day).inDays;
          if (idx >= 0 && idx < 7) daily[6 - idx] += r.tx.amount;
          byCategory.update(
            r.category,
            (v) => v + r.tx.amount,
            ifAbsent: () => r.tx.amount,
          );
        }
        final topCats = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final maxDaily = daily.fold(0, (a, b) => a > b ? a : b);

        return QuestCard(
          onTap: widget.onTap,
          radius: AppRadius.sheet,
          padding: const EdgeInsets.all(Spacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('7 HARI TERAKHIR', style: context.qEyebrow(10)),
                  const Spacer(),
                  if (topCats.isNotEmpty)
                    Flexible(
                      child: Text(
                        'keluar terbesar ${topCats.first.key?.name ?? '—'} '
                        '${_shortMoney(topCats.first.value)}',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: context.qSmall(11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.s),
              if (maxDaily == 0)
                Text(
                  'Belum ada pengeluaran dalam 7 hari terakhir.',
                  style: context.qSmall(12),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Sparkline 7 batang — batang terakhir = hari ini.
                    for (var i = 0; i < 7; i++)
                      Container(
                        width: 12,
                        height: daily[i] == 0
                            ? 4
                            : 6 + (daily[i] / maxDaily * 36),
                        margin: const EdgeInsets.only(right: Spacing.xs),
                        decoration: BoxDecoration(
                          color: i == 6
                              ? SeedColors.honeyDeep
                              : SeedColors.honey.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Column(
                        children: [
                          for (final e in topCats.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: e.key == null
                                          ? context.q.muted
                                          : SeedColors.categoryColor(
                                              e.key!.colorIndex,
                                            ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.xs),
                                  Expanded(
                                    child: Text(
                                      e.key?.name ?? 'Tanpa kategori',
                                      overflow: TextOverflow.ellipsis,
                                      style: context.qSmall(11).copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    _shortMoney(e.value),
                                    style: context.qSmall(11).copyWith(
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
