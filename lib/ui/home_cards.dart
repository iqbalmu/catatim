import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../core/budget.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'account_detail_screen.dart';
import 'add_account_sheet.dart';
import 'gamification_sheet.dart';
import 'notif_screen.dart';
import 'settings_screen.dart';
import 'transaction_sheet.dart';
import 'transaction_tile.dart';

/// Header bagian atas Beranda: Brand logo + streak quick chip + settings icon
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.progress,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    required this.onOpenAnggaran,
    required this.onOpenBon,
  });

  final ProgressService progress;
  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final VoidCallback onOpenAnggaran;
  final VoidCallback onOpenBon;
  @override
  Widget build(BuildContext context) {
    final summary = progress.latest;
    final streakDays = summary?.streakDays ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, Spacing.xs),
      child: Row(
        children: [
          // Brand Logo & Title
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [context.q.primary, context.q.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    boxShadow: [
                      BoxShadow(
                        color: context.q.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'bukuduit',
                      style: context.qTitle(18).copyWith(letterSpacing: -0.5),
                    ),
                    Text(
                      'Kelola uang tanpa ribet',
                      style: context.qSmall(11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Streak Chip Button
          InkWell(
            onTap: () => GamificationSheet.show(context, progress),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$streakDays h',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Spacing.s),

          // Notification Bell Inbox Button
          StreamBuilder<List<Draft>>(
            stream: repository.watchDrafts(),
            builder: (context, snapshot) {
              final draftCount = (snapshot.data ?? const []).length;
              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationScreen(
                      repository: repository,
                      pipeline: pipeline,
                      progress: progress,
                      ruleSet: ruleSet,
                      onOpenAnggaran: onOpenAnggaran,
                      onOpenBon: onOpenBon,
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.q.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.q.line),
                    boxShadow: AppShadows.card,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: context.q.text,
                        size: 20,
                      ),
                      if (draftCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: context.q.bad,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: Spacing.s),

          // Settings Button
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  repository: repository,
                  pipeline: pipeline,
                  ruleSet: ruleSet,
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.q.surface,
                shape: BoxShape.circle,
                border: Border.all(color: context.q.line),
                boxShadow: AppShadows.card,
              ),
              child: Icon(
                Icons.settings_outlined,
                color: context.q.text,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner Draf Notifikasi Bank Aktif: Tampil otomatis bila ada capture bank menunggu konfirmasi
class DraftAttentionBanner extends StatelessWidget {
  const DraftAttentionBanner({
    super.key,
    required this.repository,
    required this.ruleSet,
    required this.progress,
    required this.pipeline,
    required this.onOpenAnggaran,
    required this.onOpenBon,
  });

  final LedgerRepository repository;
  final RuleSet ruleSet;
  final ProgressService progress;
  final CapturePipeline pipeline;
  final VoidCallback onOpenAnggaran;
  final VoidCallback onOpenBon;
  String _bankName(String bankId) =>
      ruleSet.bank(bankId)?.displayName ?? bankId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Draft>>(
      stream: repository.watchDrafts(),
      builder: (context, snapshot) {
        final drafts = snapshot.data ?? const [];
        if (drafts.isEmpty) return const SizedBox.shrink();

        final draft = drafts.first;
        final isIncoming = draft.direction == Direction.incoming;
        final bank = _bankName(draft.bankId);
        final party = (draft.counterparty != null && draft.counterparty!.trim().isNotEmpty)
            ? draft.counterparty!.trim()
            : null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.s, Spacing.m, 0),
          child: Container(
            padding: const EdgeInsets.all(Spacing.m),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: const Color(0xFFC7D2FE), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: context.q.primary.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: context.q.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Text(
                        drafts.length == 1
                            ? 'Transaksi Bank Terdeteksi'
                            : '${drafts.length} Transaksi Bank Terdeteksi',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: context.q.primaryDeep,
                        ),
                      ),
                    ),
                    if (drafts.length > 1)
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationScreen(
                              repository: repository,
                              pipeline: pipeline,
                              ruleSet: ruleSet,
                              progress: progress,
                              onOpenAnggaran: onOpenAnggaran,
                              onOpenBon: onOpenBon,
                            ),
                          ),
                        ),
                        child: Text(
                          'Lihat Semua (${drafts.length}) →',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: context.q.primaryDeep,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.s),

                // Draft Details Box
                Container(
                  padding: const EdgeInsets.all(Spacing.s + 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isIncoming
                              ? SeedColors.incomingTint
                              : SeedColors.outgoingTint,
                          borderRadius: BorderRadius.circular(AppRadius.cell),
                        ),
                        child: Icon(
                          isIncoming
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          color: isIncoming ? context.q.good : context.q.bad,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bank,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.q.text,
                              ),
                            ),
                            if (party != null)
                              Text(
                                party,
                                style: context.qSmall(11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${isIncoming ? '+' : '−'}${Money.format(draft.amount)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isIncoming ? context.q.good : context.q.bad,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.s),

                // Inline Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Konfirmasi & Catat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.q.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        onPressed: () => TransactionSheet.show(
                          context,
                          repository,
                          draft: draft,
                          progress: progress,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.q.muted,
                          side: BorderSide(color: context.q.line),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        onPressed: () async {
                          await repository.discardDraft(draft.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Draf transaksi diabaikan'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Text('Abaikan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Total Saldo Card & Rekap Akun Horizontal
class TotalBalanceCard extends StatefulWidget {
  const TotalBalanceCard({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    this.progress,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final ProgressService? progress;

  @override
  State<TotalBalanceCard> createState() => _TotalBalanceCardState();
}

class _TotalBalanceCardState extends State<TotalBalanceCard> {
  bool _obscured = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.s, Spacing.m, 0),
      child: Container(
        padding: const EdgeInsets.all(Spacing.m),
        decoration: BoxDecoration(
          color: context.q.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: context.q.line),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row Total Saldo & Eye Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL SALDO',
                  style: context.qEyebrow(11),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: context.q.muted,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),

            // Big Balance Display
            StreamBuilder<Map<int, int>>(
              stream: widget.repository.watchAccountBalances(),
              builder: (context, balanceSnap) {
                final balances = balanceSnap.data ?? const {};
                final total = balances.values.fold<int>(0, (sum, val) => sum + val);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _obscured ? '••••••••' : Money.format(total),
                      style: context.qDisplay(28),
                    ),
                    const SizedBox(height: Spacing.xxs),
                    if (widget.progress?.latest != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.trending_down_rounded,
                            size: 16,
                            color: context.q.bad,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Keluar bulan ini: ${Money.format(widget.progress!.latest!.monthOut)}',
                            style: context.qSmall(12),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: Spacing.m),
            Divider(height: 1, thickness: 1, color: context.q.line),
            const SizedBox(height: Spacing.s),

            // Horizontal Accounts List
            StreamBuilder<List<Account>>(
              stream: widget.repository.watchAccounts(),
              builder: (context, accSnap) {
                final accounts = accSnap.data ?? const [];
                return StreamBuilder<Map<int, int>>(
                  stream: widget.repository.watchAccountBalances(),
                  builder: (context, balSnap) {
                    final balances = balSnap.data ?? const {};

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (final acc in accounts)
                            _AccountChip(
                              account: acc,
                              balance: balances[acc.id] ?? acc.openingBalance,
                              obscured: _obscured,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AccountDetailScreen(
                                    repository: widget.repository,
                                    pipeline: widget.pipeline,
                                    ruleSet: widget.ruleSet,
                                    accountId: acc.id,
                                  ),
                                ),
                              ),
                            ),
                          // "+ Tambah" Chip
                          InkWell(
                            onTap: () => AddAccountSheet.show(
                              context,
                              repository: widget.repository,
                              pipeline: widget.pipeline,
                              ruleSet: widget.ruleSet,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                            child: Container(
                              margin: const EdgeInsets.only(right: Spacing.xs),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: context.q.surface2,
                                borderRadius: BorderRadius.circular(AppRadius.tile),
                                border: Border.all(
                                  color: context.q.line,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: context.q.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tambah',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: context.q.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
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
  });

  final Account account;
  final int balance;
  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (account.kind) {
      case AccountKind.bank:
        icon = Icons.account_balance_rounded;
      case AccountKind.ewallet:
        icon = Icons.phone_android_rounded;
      case AccountKind.cash:
        icon = Icons.payments_outlined;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Container(
        margin: const EdgeInsets.only(right: Spacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.q.surface2,
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: context.q.muted),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.name,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: context.q.text,
                  ),
                ),
                Text(
                  obscured ? '••••' : Money.format(balance),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.q.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ringkasan Anggaran Bulan Ini: Ringkas, jelas, menggantikan gauge tapal kuda 248px
class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({
    super.key,
    required this.progress,
    required this.onTap,
  });

  final ProgressService progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(Spacing.m),
          decoration: BoxDecoration(
            color: context.q.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.q.line),
            boxShadow: AppShadows.card,
          ),
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              final summary = progress.latest;
              final snapshot = summary?.snapshot;
              final LimitLine? monthlyLine = snapshot?.lines
                  .cast<LimitLine?>()
                  .firstWhere((l) => l?.label == 'Total bulan ini', orElse: () => null);
              final used = summary?.monthOut ?? 0;
              final int? limit = monthlyLine?.limit;
              final pace = summary?.dailyPace;
              final hasBudget = limit != null && limit > 0;
              final fraction = hasBudget ? (used / limit).clamp(0.0, 1.0) : 0.0;
              final isOver = hasBudget && used > limit;

              Color progressColor;
              if (isOver) {
                progressColor = context.q.bad;
              } else if (fraction >= 0.8) {
                progressColor = SeedColors.honey;
              } else {
                progressColor = context.q.good;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: SeedColors.primaryLight,
                              borderRadius: BorderRadius.circular(AppRadius.cell),
                            ),
                            child: Icon(
                              Icons.pie_chart_outline_rounded,
                              color: context.q.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: Spacing.s),
                          Text(
                            'Anggaran Bulan Ini',
                            style: context.qTitle(15),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.q.muted,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.m),

                  if (!hasBudget) ...[
                    Text(
                      'Batas anggaran bulanan belum diatur.',
                      style: context.qBody(13),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Tap untuk mengatur batas pengeluaran agar keuangan terkontrol.',
                      style: context.qSmall(12),
                    ),
                  ] else ...[
                    // Numbers & Percentage
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Terpakai ',
                                style: context.qSmall(12),
                              ),
                              TextSpan(
                                text: Money.format(used),
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.q.text,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              TextSpan(
                                text: ' dari ${Money.format(limit)}',
                                style: context.qSmall(12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(used * 100 / limit).round()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: progressColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.s),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 10,
                        backgroundColor: context.q.surface2,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    const SizedBox(height: Spacing.s),

                    // Indicators: Remaining & Daily Pace
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOver ? SeedColors.outgoingTint : SeedColors.incomingTint,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            isOver
                                ? 'Over ${Money.format(used - limit)}'
                                : 'Sisa ${Money.format(limit - used)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isOver ? context.q.bad : context.q.good,
                            ),
                          ),
                        ),
                        if (pace?.safeToSpend != null && pace!.safeToSpend! > 0) ...[
                          const SizedBox(width: Spacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.q.surface2,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              'Aman ~${Money.format(pace.safeToSpend!)} / hari',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.q.muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Kartu Transaksi Terbaru (5 transaksi terakhir)
class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    super.key,
    required this.repository,
    this.progress,
    required this.onSeeAll,
  });

  final LedgerRepository repository;
  final ProgressService? progress;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaksi Terbaru',
                style: context.qTitle(17),
              ),
              InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Lihat Semua →',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.q.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.s),

          StreamBuilder<List<TxWithCategory>>(
            stream: repository.watchRecentWithCategory(limit: 5),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Spacing.l),
                  decoration: BoxDecoration(
                    color: context.q.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: context.q.line),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 40,
                        color: context.q.muted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: Spacing.s),
                      Text(
                        'Belum ada transaksi bulan ini',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.q.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap tombol (+) di bawah untuk mulai mencatat.',
                        style: context.qSmall(12),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  for (final item in items)
                    TransactionTile(
                      item: item,
                      repository: repository,
                      progress: progress,
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
