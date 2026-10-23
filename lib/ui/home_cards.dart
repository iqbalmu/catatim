import 'dart:async';

import 'package:flutter/material.dart';

import '../core/budget.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/mascot.dart';
import '../game/progress.dart';
import '../models.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';
import 'transaction_sheet.dart';

/// Seksi-seksi Beranda v5.2 "Dunia Pochy" — konsep game ala KobyBank:
/// layar dibuka dunia (langit hangat → rumput mint) berisi maskot besar
/// di tengah, langsung disusul spending card "Pengeluaran hari ini"
/// dengan stats bar mingguan & bulanan. Semua warna dari piksel maskot
/// (SeedColors, ADR-010); angka selalu tabular.

/// Bayangan kartu lembut — tinta maskot 8%, jatuh 8px.
const _softShadow = BoxShadow(
  color: Color(0x145B4433), // SeedColors.ink @ 8%
  offset: Offset(0, 8),
  blurRadius: 24,
);

/// Dekorasi kartu putih standar.
BoxDecoration _cardDecoration() => BoxDecoration(
      color: SeedColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sheet),
      boxShadow: const [_softShadow],
    );

/// Wadah kartu dengan tap opsional.
class _CardBox extends StatelessWidget {
  const _CardBox({required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: _cardDecoration(),
        padding: padding ?? const EdgeInsets.all(Spacing.m + 2),
        child: child,
      ),
    );
  }
}

/// Label mikro seksi: uppercase renggang, warna redup.
TextStyle _label() => const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: SeedColors.muted,
    );

/// Teks meta/sekunder.
TextStyle _meta([double size = 13]) =>
    TextStyle(fontSize: size, height: 1.45, color: SeedColors.muted);

const _tabular = [FontFeature.tabularFigures()];

/// Rupiah ringkas: 1500000 → '1,5jt', 78000 → '78rb'.
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

/// Ikon kategori dari bahasa data colorIndex (ADR-010) — urutan sama
/// dengan SeedColors.categoryPalette.
const _categoryIcons = <IconData>[
  Icons.restaurant_rounded, // 0 Makanan
  Icons.directions_bus_rounded, // 1 Transportasi
  Icons.receipt_long_rounded, // 2 Tagihan
  Icons.shopping_bag_rounded, // 3 Belanja
  Icons.sports_esports_rounded, // 4 Hiburan
  Icons.favorite_rounded, // 5 Kesehatan
  Icons.payments_rounded, // 6 Gaji
  Icons.swap_horiz_rounded, // 7 Transfer
  Icons.category_rounded, // 8 Lainnya
];

IconData _categoryIcon(int colorIndex) =>
    _categoryIcons[colorIndex % _categoryIcons.length];

/// Panggung dunia Pochy: langit hangat → rumput mint, maskot besar
/// di tengah dengan glow + bayangan tanah, nama + kalimatnya.
class UangCard extends StatelessWidget {
  const UangCard({super.key, required this.progress});

  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final latest = progress.latest;
        return _PochyWorld(
          mood: latest?.mood ?? MascotMood.idle,
          caption: latest?.moodCaption,
        );
      },
    );
  }
}

/// Isi dunia: scene + kalimat Duit. Tanpa kartu lain — murni dunia.
class _PochyWorld extends StatelessWidget {
  const _PochyWorld({required this.mood, required this.caption});

  final MascotMood mood;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.l,
        0,
        Spacing.l,
        Spacing.s + 4,
      ),
      decoration: const BoxDecoration(
        // Horizon tegas: langit hangat di atas, rumput mint di bawah.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SeedColors.honey50,
            SeedColors.honey50,
            SeedColors.mint,
            SeedColors.mint,
          ],
          stops: [0, 0.42, 0.42, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Wordmark ikut berdiri di langit.
              Padding(
                padding: EdgeInsets.only(
                  top: topPadding + Spacing.s,
                  bottom: Spacing.s,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'bukuduit',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: SeedColors.ink,
                    ),
                  ),
                ),
              ),
              // Sang pemain: Pochy besar di tengah panggung.
              MascotStage(
                mood: mood,
                size: 172,
                glow: SeedColors.honey100,
                glowStrength: 0.55,
              ),
              const SizedBox(height: Spacing.xs),
              // Nama pemain.
              Text(
                'Pochy',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SeedColors.ink,
                ),
              ),
              const SizedBox(height: Spacing.xxs),
              // Kalimat Duit — suara karakter di dunianya.
              if (caption != null)
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: SeedColors.ink,
                  ),
                ),
            ],
          ),
          // Koin emas berserakan di rumput — dunia terasa hidup.
          Positioned(
            left: 34,
            bottom: 148,
            child: _coin(16, SeedColors.honeyDeep),
          ),
          Positioned(
            right: 44,
            bottom: 170,
            child: _coin(12, SeedColors.honey),
          ),
          Positioned(
            right: 22,
            bottom: 128,
            child: _coin(9, SeedColors.honeyBright),
          ),
          Positioned(
            left: 18,
            bottom: 108,
            child: _coin(10, SeedColors.honey),
          ),
        ],
      ),
    );
  }

  /// Koin emas kecil — lingkaran polos dari palet koin maskot.
  Widget _coin(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: SeedColors.surface.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
      );
}

/// Strip record streak mingguan ala "This Week": 7 lingkaran Sen–Min.
/// Hari dengan pengeluaran dalam batas = lingkaran api; hari lewat
/// batas = angka merah; hari mendatang = angka redup.
class StreakStrip extends StatelessWidget {
  const StreakStrip({super.key, required this.progress});

  final ProgressService progress;

  static const _dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  /// Tentukan tampilan satu hari: api bila disiplin terjaga, angka
  /// merah bila lewat batas, angka redup bila belum terjadi.
  _DayCell _cellFor({
    required DateTime day,
    required DateTime today,
    required Map<DateTime, DailyDiscipline> byDay,
  }) {
    final disc = byDay[day];
    final future = disc?.future ?? day.isAfter(today);
    return _DayCell(
      label: _dayLabels[day.weekday - 1],
      number: day.day,
      kept: !future && (disc?.within ?? false),
      broke: !future && disc != null && !disc.within,
      isToday: day == today,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final monday = today.subtract(Duration(days: now.weekday - 1));

        // Disiplin per hari — sumber: hitung ulang transaksi bulan ini.
        final byDay = <DateTime, DailyDiscipline>{
          for (final d in progress.latest?.disciplineMonth ?? const <DailyDiscipline>[])
            DateTime(d.day.year, d.day.month, d.day.day): d,
        };

        return _CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('MINGGU INI', style: _label()),
                  const Spacer(),
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 14,
                    color: SeedColors.honeyDeep,
                  ),
                  const SizedBox(width: Spacing.xxs),
                  Text(
                    '${progress.latest?.streakDays ?? 0} hari',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: SeedColors.honeyInk,
                      fontFeatures: _tabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.s + 2),
              Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: _cellFor(
                        day: monday.add(Duration(days: i)),
                        today: today,
                        byDay: byDay,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Satu sel hari: lingkaran api / angka tanggal + nama hari.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.number,
    required this.kept,
    required this.broke,
    required this.isToday,
  });

  final String label;
  final int number;
  final bool kept;
  final bool broke;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kept ? SeedColors.honey50 : SeedColors.surface2,
            shape: BoxShape.circle,
          ),
          child: kept
              ? Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: SeedColors.honeyDeep,
                )
              : Center(
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: broke ? SeedColors.outgoing : SeedColors.muted,
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday ? SeedColors.honeyInk : SeedColors.muted,
          ),
        ),
      ],
    );
  }
}

/// Spending card: "Pengeluaran hari ini" — angka besar terpakai harian
/// ("/ limit harian"), lalu dua stats bar: pengeluaran minggu ini dan
/// bulan ini (terpakai / limit). Tap kartu → Rencana.
class SpendingCard extends StatelessWidget {
  const SpendingCard({super.key, required this.progress, this.onTap});

  final ProgressService progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final lines = progress.latest?.snapshot.lines;
        LimitLine? at(int i) =>
            lines != null && lines.length > i ? lines[i] : null;
        final dLimit = at(0)?.limit;
        final dUsed = at(0)?.used ?? 0;
        final hasDaily = dLimit != null && dLimit > 0;

        return _CardBox(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PENGELUARAN HARI INI 💰', style: _label()),
              const SizedBox(height: Spacing.s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.format(dUsed),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: -0.5,
                      color: SeedColors.ink,
                      fontFeatures: _tabular,
                    ),
                  ),
                  if (hasDaily) ...[
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '/ ${_shortMoney(dLimit)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: SeedColors.muted,
                          fontFeatures: _tabular,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Spacing.s + 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _StatBar(
                      label: 'Minggu ini',
                      line: at(1),
                      fill: SeedColors.honeyDeep,
                    ),
                  ),
                  const SizedBox(width: Spacing.s + 4),
                  Expanded(
                    child: _StatBar(
                      label: 'Bulan ini',
                      line: at(2),
                      fill: SeedColors.mintDeep,
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

/// Satu stats bar: label, mini bar terpakai/limit, nilai "x /limit".
class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.line,
    required this.fill,
  });

  final String label;
  final LimitLine? line;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final limit = line?.limit;
    final used = line?.used ?? 0;
    final hasLimit = limit != null && limit > 0;
    final over = hasLimit && used > limit;
    final fraction = hasLimit ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: SeedColors.ink,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            height: 5,
            child: Stack(
              children: [
                Container(color: SeedColors.line),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: Container(
                    color: over ? SeedColors.outgoing : fill,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Row(
          children: [
            Text(
              _shortMoney(used),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: over ? SeedColors.outgoing : SeedColors.ink,
                fontFeatures: _tabular,
              ),
            ),
            if (hasLimit)
              Text(
                ' /${_shortMoney(limit)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SeedColors.muted,
                  fontFeatures: _tabular,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Transaksi terbaru (3 teratas): chip ikon kategori + judul + meta +
/// nominal berwarna arah. Tap baris = ubah; label → Rekap.
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
    return _CardBox(
      padding: const EdgeInsets.fromLTRB(
        Spacing.m + 2,
        Spacing.m + 2,
        Spacing.m + 2,
        Spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onSeeAll,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text('TRANSAKSI TERBARU', style: _label()),
                const Spacer(),
                Text(
                  'Lihat semua',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: SeedColors.honeyInk,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: SeedColors.honeyInk,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xs),
          StreamBuilder<List<TxWithCategory>>(
            stream: _recent,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 168);
              }
              final items = snapshot.data ?? const <TxWithCategory>[];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.s),
                  child: Text(
                    'Belum ada catatan — catat transaksi pertamamu.',
                    style: _meta(),
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in items)
                    _RecentRow(
                      item: item,
                      repository: widget.repository,
                      progress: widget.progress,
                    ),
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
    final tx = item.tx;
    final incoming = tx.direction == Direction.incoming;
    final title = (tx.counterparty != null && tx.counterparty!.isNotEmpty)
        ? tx.counterparty!
        : tx.kind.label;

    // Chip ikon: warna + ikon kategori; tanpa kategori → arah.
    final Color chipColor;
    final IconData chipIcon;
    if (item.category != null) {
      chipColor = SeedColors.categoryColor(item.category!.colorIndex);
      chipIcon = _categoryIcon(item.category!.colorIndex);
    } else if (tx.kind == TxKind.transfer) {
      chipColor = SeedColors.muted;
      chipIcon = Icons.swap_horiz_rounded;
    } else {
      chipColor = incoming ? SeedColors.incoming : SeedColors.outgoing;
      chipIcon = incoming
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded;
    }

    return InkWell(
      onTap: () => TransactionSheet.show(
        context,
        repository,
        existing: item,
        progress: progress,
      ),
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.s),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.cell + 2),
              ),
              child: Icon(chipIcon, size: 20, color: chipColor),
            ),
            const SizedBox(width: Spacing.s + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: SeedColors.ink,
                    ),
                  ),
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    '${item.category?.name ?? (incoming ? 'Pemasukan' : 'Pengeluaran')}'
                    ' • ${idDayMonth(tx.occurredAt)}',
                    style: _meta(12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.s),
            Text(
              '${incoming ? '+' : '−'}${Money.format(tx.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: incoming ? SeedColors.incoming : SeedColors.outgoing,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


