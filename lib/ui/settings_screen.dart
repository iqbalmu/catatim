import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../game/progress.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'backup_screen.dart';
import 'bank_accounts_screen.dart';
import 'capture_settings_screen.dart';
import 'gamification_sheet.dart';
import 'laporan_screen.dart';
import 'quest.dart';

typedef ProfileSettingsScreen = SettingsScreen;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    this.progress,
    this.onOpenAnggaran,
    this.onOpenBon,
    this.showBack = false,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final ProgressService? progress;
  final VoidCallback? onOpenAnggaran;
  final VoidCallback? onOpenBon;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final summary = progress?.latest;
    final stats = summary?.saverStats;
    final streakDays = summary?.streakDays ?? 0;

    return Scaffold(
      backgroundColor: q.bg,
      appBar: QuestHeader(
        title: 'Profil & Pengaturan',
        subtitle: 'Profil, laporan, preferensi & data sistem',
        showBack: showBack,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          (showBack ? Spacing.xl : 104) + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // ── Seksi 0: Profil Disiplin & Maskot ──
          QuestEnter(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuestPress(
                  onTap: progress != null
                      ? () => GamificationSheet.show(context, progress!)
                      : null,
                  child: QuestCard(
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [q.primary, q.violet],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: q.primary.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      stats?.title ?? 'Pribadi & Disiplin',
                                      style: context.qTitle(16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (stats != null) ...[
                                    const SizedBox(width: Spacing.xs),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: q.primaryLight,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.pill,
                                        ),
                                      ),
                                      child: Text(
                                        'Lv. ${stats.level}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: q.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                streakDays > 0
                                    ? '$streakDays hari disiplin berturut-turut'
                                    : 'Catat rutin untuk tingkatkan level hemat',
                                style: context.qSmall(12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (progress != null) ...[
                          const SizedBox(width: Spacing.xs),
                          Icon(Icons.chevron_right_rounded, color: q.muted),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // ── Seksi 1: Laporan & Analisis ──
          QuestEnter(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const QuestSectionHeader(title: 'Laporan & Analisis'),
                QuestCard(
                  padding: EdgeInsets.zero,
                  child: QuestListTile(
                    leading: _SettingIcon(
                      icon: Icons.bar_chart_rounded,
                      color: q.primary,
                      bgColor: q.primaryLight,
                    ),
                    title: Text('Laporan Finansial', style: context.qTitle(15)),
                    subtitle: Text(
                      'Evaluasi arus kas, tren bulanan & komposisi pengeluaran',
                      style: context.qSmall(12),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: q.muted,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LaporanScreen(
                          repository: repository,
                          progress: progress,
                          showBack: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // ── Seksi 2: Data & Rekening ──
          QuestEnter(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          const QuestSectionHeader(title: 'Data & Rekening'),
          QuestCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                StreamBuilder<List<Account>>(
                  stream: repository.watchAccounts(),
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? const [];
                    return QuestListTile(
                      leading: _SettingIcon(
                        icon: Icons.account_balance_wallet_rounded,
                        color: q.primary,
                        bgColor: q.primaryLight,
                      ),
                      title: Text('Kelola Akun & Bank', style: context.qTitle(15)),
                      subtitle: Text(
                        '${accounts.length} akun terdaftar · Tambah & koneksi bank',
                        style: context.qSmall(12),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BankAccountsScreen(
                            repository: repository,
                            pipeline: pipeline,
                            ruleSet: ruleSet,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Divider(height: 1, thickness: 1, color: q.line),
                QuestListTile(
                  leading: _SettingIcon(
                    icon: Icons.shield_outlined,
                    color: q.primary,
                    bgColor: q.primaryLight,
                  ),
                  title: Text('Backup & Pulihkan Data', style: context.qTitle(15)),
                  subtitle: Text(
                    'Salinan database terenkripsi PIN lokal di HP',
                    style: context.qSmall(12),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BackupScreen(repository: repository),
                    ),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: q.line),
                StreamBuilder<List<Category>>(
                  stream: repository.watchCategories(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? const [];
                    return QuestListTile(
                      leading: _SettingIcon(
                        icon: Icons.category_rounded,
                        color: q.violet,
                        bgColor: q.violet.withValues(alpha: 0.12),
                      ),
                      title: Text('Kategori & Anggaran', style: context.qTitle(15)),
                      subtitle: Text(
                        '${categories.length} kategori · Atur batas & alokasi',
                        style: context.qSmall(12),
                      ),
                      onTap: () {
                        if (showBack) {
                          Navigator.pop(context);
                        }
                        onOpenAnggaran?.call();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // ── Seksi 3: Otomatisasi & Capture ──
          QuestEnter(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          const QuestSectionHeader(title: 'Otomatisasi & Capture'),
          QuestCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                QuestListTile(
                  leading: _SettingIcon(
                    icon: Icons.notifications_active_outlined,
                    color: q.good,
                    bgColor: SeedColors.incomingTint,
                  ),
                  title: Text('Pengaturan Capture Notifikasi', style: context.qTitle(15)),
                  subtitle: Text(
                    'Izin sistem, bank terhubung, & optimasi baterai',
                    style: context.qSmall(12),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CaptureSettingsScreen(
                        repository: repository,
                        pipeline: pipeline,
                        ruleSet: ruleSet,
                      ),
                    ),
                  ),
                ),
                QuestListTile(
                  leading: _SettingIcon(
                    icon: Icons.battery_saver_rounded,
                    color: q.text,
                    bgColor: q.surface2,
                  ),
                  title: Text('Pengaturan Baterai Sistem', style: context.qTitle(15)),
                  subtitle: Text(
                    'Cegah Android menutup listener di latar belakang',
                    style: context.qSmall(12),
                  ),
                  onTap: pipeline.channel.openBatterySettings,
                ),
              ],
            ),
          ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // ── Seksi 4: Tentang Aplikasi ──
          QuestEnter(
            index: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          const QuestSectionHeader(title: 'Tentang Bukuduit'),
          QuestCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [q.primary, q.violet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
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
                        Text('bukuduit', style: context.qTitle(16)),
                        Text(
                          'Versi 1.0.0 · Offline Personal Finance',
                          style: context.qSmall(12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.s),
                Text(
                  'Pencatat keuangan pribadi offline dengan capture notifikasi bank lokal di perangkatmu.',
                  style: context.qBody(12.5),
                ),
                const SizedBox(height: Spacing.s),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: SeedColors.incomingTint,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    border: Border.all(color: q.good.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: q.good,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '100% Offline · Data keuangan tersimpan lokal di perangkatmu, tanpa server eksternal atau pelacak.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: q.good,
                          ),
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
          ),
        ],
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
