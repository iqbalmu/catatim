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

/// Satu kartu BATAS: tiga kolom progres (Harian, Mingguan, Bulanan).
/// Angka = sisa (plafon − terpakai); bar = sisa/plafon.
/// Tap → Rencana·Batas (via [onTap]).
class BatasCard extends StatelessWidget {
  const BatasCard({
    super.key,
    required this.dailyLimit,
    required this.dailyUsed,
    required this.weeklyLimit,
    required this.weeklyUsed,
    required this.monthlyLimit,
    required this.monthlyUsed,
    required this.onTap,
    this.streakDays = 0,
  });

  final int? dailyLimit;
  final int dailyUsed;
  final int? weeklyLimit;
  final int weeklyUsed;
  final int? monthlyLimit;
  final int monthlyUsed;
  final VoidCallback onTap;

  /// Streak disiplin — chip di kanan eyebrow (mockup v2.1: streak
  /// menyatu di kartu pace, bukan kartu terpisah).
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final hasLimit = dailyLimit != null && dailyLimit! > 0;
    final sisa = (dailyLimit ?? 0) - dailyUsed;
    final over = hasLimit && sisa < 0;
    final fraction = hasLimit ? (dailyUsed / dailyLimit!).clamp(0.0, 1.0) : 0.0;

    return QuestCard(
      onTap: onTap,
      radius: AppRadius.sheet,
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SISA AMAN HARI INI', style: context.qEyebrow(10)),
              const Spacer(),
              // Streak menyatu di kartu pace (mockup v2.1).
              if (streakDays > 0)
                Container(
                  padding: Insets.chip,
                  decoration: BoxDecoration(
                    color: SeedColors.mintTint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$streakDays hari',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: SeedColors.mintInk,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              !hasLimit
                  ? 'Tanpa batas'
                  : over
                      ? '−${Money.format(-sisa)}'
                      : Money.format(sisa),
              style: context.qDisplay(27).copyWith(color: over ? q.bad : null),
            ),
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
                  child: Container(
                    height: 10,
                    color: over ? q.bad : const Color(0xFFE8B36B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              Expanded(
                child:                Text(
                  !hasLimit
                      ? 'Tap untuk mengatur batas harian'
                      : 'Pakai ${Money.format(dailyUsed)} dari ${Money.format(dailyLimit!)}',
                  style: context.qSmall(11),
                ),
              ),
              Text(
                'Hari ${now.day}/$daysInMonth',
                style: context.qSmall(11),
              ),
            ],
          ),
          // Mingguan & bulanan tetap terlihat — info tidak hilang,
          // hanya turun satu tingkat (mockup v2.1: fokus harian).
          const SizedBox(height: Spacing.s),
          Row(
            children: [
              Expanded(
                child: Text(
                  weeklyLimit == null
                      ? 'Mingguan: tanpa batas'
                      : 'Mingguan: sisa ${_shortMoney((weeklyLimit ?? 0) - weeklyUsed)}',
                  overflow: TextOverflow.ellipsis,
                  style: context.qSmall(11),
                ),
              ),
              Expanded(
                child: Text(
                  monthlyLimit == null
                      ? 'Bulanan: tanpa batas'
                      : 'Bulanan: sisa ${_shortMoney((monthlyLimit ?? 0) - monthlyUsed)}',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: context.qSmall(11),
                ),
              ),
            ],
          ),
        ],
      ),
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

/// Dua kartu arus bulan berjalan: KELUAR | MASUK sejajar dengan celah.
/// Tap tiap kartu → Rekap (via [onTap]).
class MiniInOut extends StatelessWidget {
  const MiniInOut({super.key, required this.service, this.onTap});

  final ProgressService service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final snap = service.latest;
        if (snap == null) {
          return const Row(
            children: [
              Expanded(
                child: QuestCard(
                  radius: AppRadius.sheet,
                  padding: EdgeInsets.all(Spacing.m),
                  child: SizedBox(height: 56),
                ),
              ),
              SizedBox(width: Spacing.s),
              Expanded(
                child: QuestCard(
                  radius: AppRadius.sheet,
                  padding: EdgeInsets.all(Spacing.m),
                  child: SizedBox(height: 56),
                ),
              ),
            ],
          );
        }
        final shot = snap.snapshot;
        final now = DateTime.now();
        final lastShort = idMonthsShort[(now.month + 10) % 12];
        return Row(
          children: [
            Expanded(
              child: QuestCard(
                onTap: onTap,
                radius: AppRadius.sheet,
                padding: const EdgeInsets.all(Spacing.m),
                child: _ArusRow(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Keluar',
                  amount: snap.monthOut,
                  previous: shot.lastMonthOut,
                  lastShort: lastShort,
                  incoming: false,
                ),
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: QuestCard(
                onTap: onTap,
                radius: AppRadius.sheet,
                padding: const EdgeInsets.all(Spacing.m),
                child: _ArusRow(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Masuk',
                  amount: snap.monthIn,
                  previous: shot.lastMonthIn,
                  lastShort: lastShort,
                  incoming: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArusRow extends StatelessWidget {
  const _ArusRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.previous,
    required this.lastShort,
    required this.incoming,
  });

  final IconData icon;
  final String label;
  final int amount;
  final int previous;
  final String lastShort;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final delta = deltaLabel(amount, previous);
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: (incoming ? q.good : q.bad).withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 23, color: incoming ? q.good : q.bad),
        ),
        const SizedBox(width: Spacing.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: context.qSmall(13)),
              const SizedBox(height: Spacing.xxs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Money.format(amount),
                  style: context.qTitle(17).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xxs),
              Text(
                delta == null ? 'bulan pertama' : '$delta · $lastShort',
                overflow: TextOverflow.ellipsis,
                style: context.qSmall(11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Disiplin bulan berjalan: hijau = pakai ≤ jatah, merah = jebol,
/// abu = tanpa catatan. Angka kanan = hari disiplin / panjang bulan.
class DisiplinCard extends StatelessWidget {
  const DisiplinCard({super.key, required this.service});

  final ProgressService service;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final snap = service.latest;
        if (snap == null) {
          return const QuestCard(
            radius: AppRadius.sheet,
            padding: EdgeInsets.all(Spacing.m),
            child: SizedBox(height: 120),
          );
        }
        final q = context.q;
        final rows = snap.disciplineMonth;
        if (rows.isEmpty) {
          return QuestCard(
            radius: AppRadius.sheet,
            padding: const EdgeInsets.all(Spacing.m),
            child: Text(
              'Atur dulu batasnya, ya — biar disiplin harianmu kelihatan.',
              style: context.qSmall(12),
            ),
          );
        }
        final elapsed = rows.where((d) => !d.future).toList();
        final disiplin = elapsed
            .where((d) => d.within && snap.activeDays.contains(d.day))
            .length;
        return QuestCard(
          radius: AppRadius.sheet,
          padding: const EdgeInsets.all(Spacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Disiplin Bulan Ini',
                      style: context.qTitle(15),
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$disiplin/${rows.length}',
                          style: context.qTitle(14).copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        TextSpan(
                          text: ' hari',
                          style: context.qSmall(13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.s),
              Row(
                children: [
                  for (final d in rows)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: d.future
                                ? q.line.withValues(alpha: 0.5)
                                : !d.within
                                    ? q.bad.withValues(alpha: 0.8)
                                    : snap.activeDays.contains(d.day)
                                        ? q.good.withValues(alpha: 0.75)
                                        : q.line.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (snap.streakDays > 0) ...[
                const SizedBox(height: Spacing.s),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 13,
                      color: SeedColors.honeyDeep,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      '${snap.streakDays} hari streak',
                      style: context.qSmall(11),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('7 HARI TERAKHIR', style: context.qEyebrow(10)),
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
                        width: 14,
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
                    const SizedBox(width: Spacing.m),
                    Expanded(
                      child: Column(
                        children: [
                          for (final e in topCats.take(3))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
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
                                  const SizedBox(width: Spacing.s),
                                  Expanded(
                                    child: Text(
                                      e.key?.name ?? 'Tanpa kategori',
                                      overflow: TextOverflow.ellipsis,
                                      style: context.qSmall(12).copyWith(
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
