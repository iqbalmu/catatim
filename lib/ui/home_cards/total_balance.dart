part of '../home_cards.dart';

/// Total Saldo Card (Hero Beranda) & Rekap Akun Horizontal

class TotalBalanceCard extends StatefulWidget {
  const TotalBalanceCard({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    this.progress,
    this.margin,
    this.initialObscured = false,
    this.onObscuredChanged,
    this.onTap,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final ProgressService? progress;
  final EdgeInsetsGeometry? margin;
  final bool initialObscured;
  final ValueChanged<bool>? onObscuredChanged;

  /// Tap kartu (di luar kontrol internal) — pembuka manajemen akun.
  final VoidCallback? onTap;

  @override
  State<TotalBalanceCard> createState() => _TotalBalanceCardState();
}

class _TotalBalanceCardState extends State<TotalBalanceCard> {
  late bool _obscured = widget.initialObscured;
  late Stream<Map<int, int>> _balancesStream;
  late Stream<List<Account>> _accountsStream;
  Map<int, int> _cachedBalances = const {};
  List<Account> _cachedAccounts = const [];

  @override
  void initState() {
    super.initState();
    _balancesStream = widget.repository.watchAccountBalances();
    _accountsStream = widget.repository.watchAccounts();
  }

  @override
  void didUpdateWidget(covariant TotalBalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _balancesStream = widget.repository.watchAccountBalances();
      _accountsStream = widget.repository.watchAccounts();
    }
    if (oldWidget.initialObscured != widget.initialObscured &&
        _obscured != widget.initialObscured) {
      _obscured = widget.initialObscured;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return Padding(
      padding: widget.margin ?? const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, 0),
      child: StreamBuilder<Map<int, int>>(
        stream: _balancesStream,
        builder: (context, balanceSnap) {
          if (balanceSnap.hasData) {
            _cachedBalances = balanceSnap.data!;
          }
          final balances = _cachedBalances;
          final total = balances.values.fold<int>(0, (sum, val) => sum + val);

          return StreamBuilder<List<Account>>(
            stream: _accountsStream,
            builder: (context, accSnap) {
              if (accSnap.hasData) {
                _cachedAccounts = accSnap.data!;
              }
              final accounts = _cachedAccounts;

              return QuestCard(
                variant: QuestCardVariant.hero,
                onTap: widget.onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row Label Saldo & Eye Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL SALDO',
                          style: context.qSmall(11.5).copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: q.muted,
                              ),
                        ),
                        AnimatedContainer(
                          duration: QuestMotion.medium,
                          curve: QuestMotion.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _obscured
                                ? q.primaryLight
                                : q.surface2.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: _obscured
                                  ? q.primary.withValues(alpha: 0.3)
                                  : q.line,
                            ),
                          ),
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            tooltip: _obscured
                                ? 'Tampilkan saldo'
                                : 'Sembunyikan saldo',
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: QuestMotion.spring,
                              switchOutCurve: QuestMotion.easeOut,
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.45,
                                      end: 1.0,
                                    ).animate(anim),
                                    child: RotationTransition(
                                      turns: Tween<double>(
                                        begin: -0.1,
                                        end: 0.0,
                                      ).animate(anim),
                                      child: FadeTransition(
                                        opacity: anim,
                                        child: child,
                                      ),
                                    ),
                                  ),
                              child: Icon(
                                _obscured
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_outlined,
                                key: ValueKey(_obscured),
                                size: 18,
                                color: _obscured ? q.primary : q.muted,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _obscured = !_obscured);
                              widget.onObscuredChanged?.call(_obscured);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xxs),

                    // Big Hero Balance Display (Frosted Blur + Shimmer Wave + Count-Up)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _PrivacyBalanceReveal(
                        obscured: _obscured,
                        visibleChild: QuestMoney(
                          key: const ValueKey('saldo-visible'),
                          amount: total,
                          replayKey: _obscured,
                          duration: const Duration(milliseconds: 520),
                          // Saldo minus tampil merah — sinyal sama dengan
                          // label "Defisit" di kartu jatah harian.
                          style: context.qDisplay(34).copyWith(
                                color: total < 0 ? q.bad : null,
                              ),
                        ),
                        hiddenChild: Text(
                          '••••••••',
                          key: const ValueKey('saldo-hidden'),
                          style: context
                              .qDisplay(34)
                              .copyWith(letterSpacing: 3, color: q.primaryDeep),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xxs),
                    QuestSwap(
                      slide: false,
                      child: _obscured
                          ? Row(
                              key: const ValueKey('subtitle-hidden'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 12,
                                  color: q.primaryText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Saldo disembunyikan',
                                  style: context
                                      .qSmall(12)
                                      .copyWith(
                                        color: q.primaryText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            )
                          : Text(
                              '${accounts.length} akun terdaftar',
                              key: ValueKey('subtitle-${accounts.length}'),
                              style: context
                                  .qSmall(12)
                                  .copyWith(color: q.muted),
                            ),
                    ),

                    const SizedBox(height: Spacing.m),
                    Divider(height: 1, thickness: 1, color: q.line),
                    const SizedBox(height: Spacing.s),

                    // Horizontal Accounts List
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (var i = 0; i < accounts.length; i++)
                            _AccountChip(
                              account: accounts[i],
                              balance:
                                  balances[accounts[i].id] ??
                                  accounts[i].openingBalance,
                              obscured: _obscured,
                              staggerIndex: i,
                              onTap: () => AccountDetailSheet.show(
                                context,
                                repository: widget.repository,
                                pipeline: widget.pipeline,
                                ruleSet: widget.ruleSet,
                                accountId: accounts[i].id,
                              ),
                            ),
                          Semantics(
                            button: true,
                            label: 'Tambah akun',
                            child: QuestPress(
                              onTap: () => AddAccountSheet.show(
                                context,
                                repository: widget.repository,
                                pipeline: widget.pipeline,
                                ruleSet: widget.ruleSet,
                              ),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 48),
                                margin: const EdgeInsets.only(right: Spacing.xs),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: q.surface2,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.tile,
                                  ),
                                  border: Border.all(
                                    color: q.primary.withValues(alpha: 0.25),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      size: 16,
                                      color: q.primaryText,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tambah',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: q.primaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.account,
    required this.balance,
    required this.obscured,
    required this.onTap,
    this.staggerIndex = 0,
  });

  final Account account;
  final int balance;
  final bool obscured;
  final VoidCallback onTap;
  final int staggerIndex;
  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final IconData icon = switch (account.kind) {
      AccountKind.bank => Icons.account_balance_rounded,
      AccountKind.ewallet => Icons.phone_android_rounded,
      AccountKind.cash => Icons.payments_outlined,
    };

    return Container(
      margin: const EdgeInsets.only(right: Spacing.s),
      child: Semantics(
        button: true,
        label: 'Akun ${account.name}',
        child: QuestPress(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: q.surface2.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: q.line),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: q.text),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: q.text,
                    ),
                  ),
                  _PrivacyBalanceReveal(
                    obscured: obscured,
                    compact: true,
                    staggerMs: staggerIndex.clamp(0, 5) * 40,
                    visibleChild: QuestMoney(
                      key: const ValueKey('chip-visible'),
                      amount: balance,
                      replayKey: obscured,
                      duration: const Duration(milliseconds: 460),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: q.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    hiddenChild: Text(
                      '••••••',
                      key: const ValueKey('chip-hidden'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: q.primaryText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

/// Transisi privasi saldo (Show/Hide): efek kabur kaca (frosted blur) +
/// skala pegas + sapuan kilau bertahap dari kiri ke kanan pada titik privasi.

class _PrivacyBalanceReveal extends StatelessWidget {
  const _PrivacyBalanceReveal({
    required this.obscured,
    required this.visibleChild,
    required this.hiddenChild,
    this.compact = false,
    this.staggerMs = 0,
  });

  final bool obscured;
  final Widget visibleChild;
  final Widget hiddenChild;
  final bool compact;
  final int staggerMs;

  @override
  Widget build(BuildContext context) {
    final active = obscured ? hiddenChild : visibleChild;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return active;
    }
    final baseMs = compact ? 300 : 380;
    final totalMs = baseMs + staggerMs;
    final startFrac = totalMs > 0
        ? (staggerMs / totalMs).clamp(0.0, 0.45)
        : 0.0;
    final primary = context.q.primary;

    return AnimatedSwitcher(
      duration: Duration(milliseconds: totalMs),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, anim) {
        final isHiddenNode =
            child.key == const ValueKey('saldo-hidden') ||
            child.key == const ValueKey('chip-hidden');
        return AnimatedBuilder(
          animation: anim,
          child: child,
          builder: (context, cachedChild) {
            final raw = ((anim.value - startFrac) / (1.0 - startFrac)).clamp(
              0.0,
              1.0,
            );
            final t = QuestMotion.easeOut.transform(raw);
            if (t >= 0.995) return cachedChild!;

            final maxSigma = compact ? 5.5 : 10.0;
            final sigma = (1.0 - t) * maxSigma;
            final scale = (compact ? 0.94 : 0.90) + (compact ? 0.06 : 0.10) * t;
            final dy =
                (1.0 - t) * (compact ? 4.0 : 8.0) * (isHiddenNode ? -1 : 1);

            Widget content = cachedChild!;
            if (isHiddenNode && !compact) {
              final sweep = (t * 1.35).clamp(0.0, 1.0);
              content = ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    context.q.primaryDeep,
                    primary,
                    primary.withValues(alpha: 0.25),
                  ],
                  stops: [
                    (sweep - 0.35).clamp(0.0, 1.0),
                    sweep,
                    (sweep + 0.2).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds),
                child: content,
              );
            }

            if (sigma > 0.05) {
              content = ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma * 0.55,
                ),
                child: content,
              );
            }

            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.centerLeft,
                  child: content,
                ),
              ),
            );
          },
        );
      },
      child: active,
    );
  }
}
