import 'dart:async';

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'mascot.dart';
import 'progress.dart';

/// Hero beranda: saldo total + Duit.
/// Ekspresi maskot tetap mengikuti kondisi anggaran nyata (via [service]).
/// Layout ala mock pastel (label + eye, angka besar, baris akun);
/// warna tetap palet Quest saat ini (gradient madu).
class GameHeroCard extends StatefulWidget {
  const GameHeroCard({
    super.key,
    required this.service,
    required this.repository,
    this.onTapAccounts,
  });

  final ProgressService service;
  final LedgerRepository repository;
  final VoidCallback? onTapAccounts;

  @override
  State<GameHeroCard> createState() => _GameHeroCardState();
}

class _GameHeroCardState extends State<GameHeroCard> {
  /// Disematkan sekali agar rebuild tak subscribe ulang (anti-kedip).
  late final Stream<List<Account>> _accounts;
  /// Disematkan sekali agar rebuild tak subscribe ulang (anti-kedip).
  late final Stream<Map<int, int>> _balances;

  @override
  void initState() {
    super.initState();
    _accounts = widget.repository.watchAccounts();
    _balances = widget.repository.watchAccountBalances();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final mood = widget.service.latest?.mood ?? MascotMood.idle;
        return StreamBuilder<List<Account>>(
          stream: _accounts,
          builder: (context, accSnap) {
            return StreamBuilder<Map<int, int>>(
              stream: _balances,
              builder: (context, balSnap) {
                final accounts = accSnap.data ?? const <Account>[];
                final balances = balSnap.data ?? const <int, int>{};
                final total = balances.values.fold(0, (a, b) => a + b);
                return _HeroSaldo(
                  total: total,
                  accounts: accounts,
                  mood: mood,
                  onTap: widget.onTapAccounts,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Zona madu: teks kiri (label + eye, angka, baris akun) + Duit kanan.
/// Eye toggle sembunyikan angka; tap kartu → Kelola Akun.
class _HeroSaldo extends StatefulWidget {
  const _HeroSaldo({
    required this.total,
    required this.accounts,
    required this.mood,
    this.onTap,
  });

  final int total;

  /// Daftar akun — dipakai untuk avatar mini di hero (mockup v2.1:
  /// tap langsung ke Kelola Akun, bukan teks "N akun").
  final List<Account> accounts;
  final MascotMood mood;
  final VoidCallback? onTap;

  @override
  State<_HeroSaldo> createState() => _HeroSaldoState();
}

class _HeroSaldoState extends State<_HeroSaldo> {
  bool _obscured = false;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final amount = _obscured ? 'Rp••••••' : Money.format(widget.total);
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Spacing.l,
          Spacing.m,
          Spacing.m,
          Spacing.m,
        ),
        // Catatan: avatar akun memakai warna kategori dari colorIndex
        // akun — bahasa data, tidak diubah palet (ADR-010).
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [SeedColors.honeyBright, SeedColors.honey],
          ),
          borderRadius: BorderRadius.circular(24),
          // Cushion shadow yang sama dengan kartu Quest — hero melayang
          // di atas latar, bukan tempelan datar.
          boxShadow: [
            BoxShadow(
              color: q.shadow,
              offset: const Offset(0, 10),
              blurRadius: 26,
            ),
            BoxShadow(
              color: const Color(0x174A3A14),
              offset: const Offset(0, -1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Saldo',
                        style: context.qTitle(15).copyWith(color: q.honeyInk),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _obscured = !_obscured),
                        child: Icon(
                          _obscured
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: q.honeyInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      amount,
                      style: context.qDisplay(30).copyWith(
                        color: widget.total < 0 ? q.bad : q.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.accounts.isEmpty)
                        Text(
                          'Belum ada akun — yuk tambah',
                          style: context.qSmall(13).copyWith(
                            color: q.honeyInk,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else ...[
                        // Avatar mini per akun — warna dari colorIndex
                        // akun (bahasa data, ADR-010).
                        for (final a in widget.accounts.take(3))
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _AccountAvatar(account: a),
                          ),
                        if (widget.accounts.length > 3)
                          Text(
                            '+${widget.accounts.length - 3}',
                            style: context.qSmall(12).copyWith(
                              color: q.honeyInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: q.honeyInk,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.s),
            // Duit berdiri di panggung — karakter jadi wajah kartu,
            // bukan ikon kecil di sudut.
            RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MascotStage(
                    mood: widget.mood,
                    size: 124,
                    // Glow putih di atas gradien madu.
                    glow: SeedColors.surface,
                  ),
                  const SizedBox(height: Spacing.xs),
                  // Kalimat Duit — pil bubble supaya suara karakter terbaca.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: SeedColors.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      mascotCaption(widget.mood),
                      style: context.qSmall(11).copyWith(
                        color: q.honeyInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar mini akun di hero — lingkaran warna akun + inisial.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final color = SeedColors.categoryColor(account.colorIndex);
    return Tooltip(
      message: account.name,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Color(0x334A3A14), offset: Offset(0, 1), blurRadius: 3),
          ],
        ),
        child: Text(
          account.name.isEmpty ? '?' : account.name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
