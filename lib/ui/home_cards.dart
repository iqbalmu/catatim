import 'package:flutter/material.dart';

import '../core/budget.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
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
  });

  final int? dailyLimit;
  final int dailyUsed;
  final int? weeklyLimit;
  final int weeklyUsed;
  final int? monthlyLimit;
  final int monthlyUsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestCard(
      onTap: onTap,
      radius: 24,
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: q.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.donut_small_rounded,
                  size: 19,
                  color: SeedColors.honeyDeep,
                ),
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                child: Text(
                  'Sisa Batas Pengeluaran',
                  style: context.qTitle(15),
                ),
              ),
              Text('Lihat detail', style: context.qSmall(13)),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: q.muted,
              ),
            ],
          ),
          const SizedBox(height: Spacing.m),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BatasColumn(
                    label: 'Harian',
                    icon: Icons.calendar_today_rounded,
                    limit: dailyLimit,
                    used: dailyUsed,
                  ),
                ),
                VerticalDivider(
                  width: Spacing.m,
                  thickness: 1,
                  color: q.line,
                ),
                Expanded(
                  child: _BatasColumn(
                    label: 'Mingguan',
                    icon: Icons.calendar_month_rounded,
                    limit: weeklyLimit,
                    used: weeklyUsed,
                  ),
                ),
                VerticalDivider(
                  width: Spacing.m,
                  thickness: 1,
                  color: q.line,
                ),
                Expanded(
                  child: _BatasColumn(
                    label: 'Bulanan',
                    icon: Icons.event_note_rounded,
                    limit: monthlyLimit,
                    used: monthlyUsed,
                  ),
                ),
              ],
            ),
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

class _BatasColumn extends StatelessWidget {
  const _BatasColumn({
    required this.label,
    required this.icon,
    required this.limit,
    required this.used,
  });

  final String label;
  final IconData icon;
  final int? limit;
  final int used;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final hasLimit = limit != null && limit! > 0;
    final sisa = (limit ?? 0) - used;
    final over = hasLimit && sisa < 0;
    final fraction = hasLimit ? (sisa / limit!).clamp(0.0, 1.0) : 0.0;
    final barColor = switch (LimitLine(label: label, used: used, limit: limit)
        .level) {
      BudgetLevel.over => q.bad,
      BudgetLevel.warning => q.honey,
      BudgetLevel.ok => q.good,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: q.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: q.text),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: context.qSmall(12).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.s),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            !hasLimit
                ? 'Tanpa batas'
                : over
                    ? '${_shortMoney(sisa)} · OVER'
                    : _shortMoney(sisa),
            style: context.qTitle(17).copyWith(
              color: over ? q.bad : q.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(height: 8, color: q.line.withValues(alpha: 0.6)),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: Container(height: 8, color: barColor),
              ),
            ],
          ),
        ),
        if (hasLimit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'dari ${Money.format(limit!)}',
              overflow: TextOverflow.ellipsis,
              style: context.qSmall(11),
            ),
          ),
      ],
    );
  }
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
                  radius: 24,
                  padding: EdgeInsets.all(Spacing.m),
                  child: SizedBox(height: 56),
                ),
              ),
              SizedBox(width: Spacing.s),
              Expanded(
                child: QuestCard(
                  radius: 24,
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
                radius: 24,
                padding: const EdgeInsets.all(14),
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
                radius: 24,
                padding: const EdgeInsets.all(14),
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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: context.qSmall(13)),
              const SizedBox(height: 2),
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
              const SizedBox(height: 2),
              Text(
                delta == null ? 'bulan pertama' : '$delta · $lastShort',
                overflow: TextOverflow.ellipsis,
                style: context.qSmall(11),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: 18, color: q.muted),
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
            radius: 24,
            padding: EdgeInsets.all(Spacing.m),
            child: SizedBox(height: 120),
          );
        }
        final q = context.q;
        final rows = snap.disciplineMonth;
        if (rows.isEmpty) {
          return QuestCard(
            radius: 24,
            padding: const EdgeInsets.all(Spacing.m),
            child: Text(
              'Atur batas untuk melihat disiplin harian',
              style: context.qSmall(12),
            ),
          );
        }
        final elapsed = rows.where((d) => !d.future).toList();
        final disiplin = elapsed
            .where((d) => d.within && snap.activeDays.contains(d.day))
            .length;
        return QuestCard(
          radius: 24,
          padding: const EdgeInsets.all(Spacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.track_changes_rounded,
                    size: 22,
                    color: q.text,
                  ),
                  const SizedBox(width: Spacing.s),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final d in rows)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: d.future
                                ? q.line.withValues(alpha: 0.7)
                                : !d.within
                                    ? q.bad
                                    : snap.activeDays.contains(d.day)
                                        ? q.good
                                        : q.line,
                            shape: BoxShape.circle,
                          ),
                        ),
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

/// Transaksi terbaru (3 teratas) di Beranda. Tap baris = ubah,
/// "Lihat semua" → Rekap (via [onSeeAll]).
class TransaksiTerbaruCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestCard(
      radius: 24,
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestPress(
            onTap: onSeeAll,
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 22,
                  color: SeedColors.honeyDeep,
                ),
                const SizedBox(width: Spacing.s),
                Expanded(
                  child: Text(
                    'Transaksi Terbaru',
                    style: context.qTitle(15),
                  ),
                ),
                Text('Lihat semua', style: context.qSmall(13)),
                const SizedBox(width: 2),
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
            stream: repository.watchRecentWithCategory(limit: 3),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <TxWithCategory>[];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.s),
                  child: Text(
                    'Belum ada transaksi — catat transaksi pertamamu.',
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
                      repository: repository,
                      progress: progress,
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
        padding: const EdgeInsets.symmetric(vertical: 10),
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
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
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
