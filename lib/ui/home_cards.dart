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
import 'quest.dart';
import 'settings_screen.dart';
import 'transaction_sheet.dart';
import 'transaction_tile.dart';

/// Header bagian atas Beranda: Brand logo + streak chip netral + lonceng + settings
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
    final q = context.q;
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [q.primary, q.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: q.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Text(
                  'bukuduit',
                  style: context.qTitle(19).copyWith(letterSpacing: -0.5),
                ),
              ],
            ),
          ),

          // Streak Chip Button (Netral, tidak menyaingi saldo)
          QuestPress(
            onTap: () => GamificationSheet.show(context, progress),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: q.surface2,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: q.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: streakDays > 0 ? q.warn : q.muted,
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$streakDays h',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: q.text,
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
              return QuestPress(
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
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: q.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: q.line),
                    boxShadow: AppShadows.card,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: q.text,
                        size: 19,
                      ),
                      if (draftCount > 0)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: q.bad,
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
          QuestPress(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  repository: repository,
                  pipeline: pipeline,
                  ruleSet: ruleSet,
                  progress: progress,
                  onOpenAnggaran: onOpenAnggaran,
                  onOpenBon: onOpenBon,
                ),
              ),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: q.surface,
                shape: BoxShape.circle,
                border: Border.all(color: q.line),
                boxShadow: AppShadows.card,
              ),
              child: Icon(
                Icons.settings_outlined,
                color: q.text,
                size: 19,
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
    final q = context.q;

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
          child: QuestCard(
            color: q.primaryLight,
            border: Border.all(color: q.primary.withValues(alpha: 0.2)),
            shadow: null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: q.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 16,
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
                          color: q.primaryDeep,
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
                            color: q.primaryDeep,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.s),

                // Draft Details Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: q.surface,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    border: Border.all(color: q.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
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
                          color: isIncoming ? q.good : q.bad,
                          size: 19,
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
                                color: q.text,
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
                      const SizedBox(width: Spacing.s),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${isIncoming ? '+' : '−'}${Money.format(draft.amount)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isIncoming ? q.good : q.bad,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
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
                      child: QuestButton(
                        label: 'Konfirmasi & Catat',
                        icon: Icons.check_rounded,
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
                      child: QuestButton(
                        label: 'Abaikan',
                        tone: QuestTone.secondary,
                        onPressed: () async {
                          await repository.discardDraft(draft.id);
                          if (context.mounted) {
                            questSnack(context, 'Draf transaksi diabaikan.');
                          }
                        },
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

/// Total Saldo Card (Hero Beranda) & Rekap Akun Horizontal
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
    final q = context.q;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.s, Spacing.m, 0),
      child: StreamBuilder<Map<int, int>>(
        stream: widget.repository.watchAccountBalances(),
        builder: (context, balanceSnap) {
          final balances = balanceSnap.data ?? const {};
          final total = balances.values.fold<int>(0, (sum, val) => sum + val);

          return StreamBuilder<List<Account>>(
            stream: widget.repository.watchAccounts(),
            builder: (context, accSnap) {
              final accounts = accSnap.data ?? const [];

              return QuestCard(
                variant: QuestCardVariant.hero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row Label Saldo & Eye Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL SALDO',
                          style: context.qEyebrow(10.5).copyWith(color: q.muted),
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
                            color: q.muted,
                          ),
                          onPressed: () => setState(() => _obscured = !_obscured),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xxs),

                    // Big Hero Balance Display (Skala 34 prominent)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _obscured ? '••••••••' : Money.format(total),
                        style: context.qDisplay(34),
                      ),
                    ),
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      _obscured
                          ? 'Saldo disembunyikan'
                          : '${accounts.length} akun terdaftar',
                      style: context.qSmall(12).copyWith(color: q.muted),
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
                          for (final acc in accounts)
                            _AccountChip(
                              account: acc,
                              balance: balances[acc.id] ?? acc.openingBalance,
                              obscured: _obscured,
                              onTap: () => AccountDetailSheet.show(
                                context,
                                repository: widget.repository,
                                pipeline: widget.pipeline,
                                ruleSet: widget.ruleSet,
                                accountId: acc.id,
                              ),
                            ),
                          // "+ Tambah" Chip
                          QuestPress(
                            onTap: () => AddAccountSheet.show(
                              context,
                              repository: widget.repository,
                              pipeline: widget.pipeline,
                              ruleSet: widget.ruleSet,
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(right: Spacing.xs),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: q.surface2,
                                borderRadius: BorderRadius.circular(AppRadius.tile),
                                border: Border.all(
                                  color: q.primary.withValues(alpha: 0.25),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: q.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tambah',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: q.primary,
                                    ),
                                  ),
                                ],
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
  });

  final Account account;
  final int balance;
  final bool obscured;
  final VoidCallback onTap;

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
      child: QuestPress(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: q.surface2.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(color: q.line),
          ),
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
                  Text(
                    obscured ? '••••••' : Money.format(balance),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: q.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ringkasan Anggaran Bulan Ini: Ringkas, jelas, dengan bar progres semantik
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
    final q = context.q;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, 0),
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
            progressColor = q.bad;
          } else if (fraction >= 0.75) {
            progressColor = q.warn;
          } else {
            progressColor = q.good;
          }

          return QuestCard(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: q.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.cell),
                      ),
                      child: Icon(
                        Icons.pie_chart_outline_rounded,
                        color: q.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Text(
                        'Anggaran Bulan Ini',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.qTitle(15),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: q.muted,
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
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    'Tap untuk mengatur batas pengeluaran agar keuangan terkontrol.',
                    style: context.qSmall(11.5).copyWith(color: q.muted),
                  ),
                ] else ...[
                  // Numbers & Percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: RichText(
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
                                    color: q.text,
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
                        ),
                      ),
                      const SizedBox(width: Spacing.s),
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
                      minHeight: 8,
                      backgroundColor: q.surface2,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  const SizedBox(height: Spacing.s),

                  // Single Clean Summary Line
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                            color: isOver ? q.bad : q.good,
                          ),
                        ),
                      ),
                      if (pace?.safeToSpend != null && pace!.safeToSpend! > 0) ...[
                        const SizedBox(width: Spacing.s),
                        Expanded(
                          child: Text(
                            '· Aman ~${Money.format(pace.safeToSpend!)} / hari',
                            style: context.qSmall(11.5).copyWith(color: q.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          );
        },
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
    final q = context.q;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, Spacing.m, Spacing.m, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Transaksi Terbaru',
                  style: context.qTitle(16),
                ),
              ),
              QuestPress(
                onTap: onSeeAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'Lihat Semua →',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: q.primary,
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
                return QuestEmpty(
                  title: 'Belum ada transaksi',
                  hint: 'Tap tombol (+) di bawah untuk mulai mencatat.',
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
