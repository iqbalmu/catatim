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
                  accountCount: accounts.length,
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
    required this.accountCount,
    required this.mood,
    this.onTap,
  });

  final int total;
  final int accountCount;
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
        padding: const EdgeInsets.fromLTRB(Spacing.l, 24, Spacing.l, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [SeedColors.honeyBright, SeedColors.honey],
          ),
          borderRadius: BorderRadius.circular(24),
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
                      Text(
                        widget.accountCount == 0
                            ? 'Belum ada akun'
                            : '${widget.accountCount} akun',
                        style: context.qSmall(13).copyWith(
                          color: q.honeyInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: q.honeyInk,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.m),
            RepaintBoundary(child: Mascot(mood: widget.mood, size: 64)),
          ],
        ),
      ),
    );
  }
}
