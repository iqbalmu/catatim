import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../game/progress.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../storage/seed_dummy.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'backup_screen.dart';
import 'bank_accounts_screen.dart';
import 'budget_alert_sheet.dart';
import 'capture_settings_screen.dart';
import 'gamification_sheet.dart';
import 'laporan_screen.dart';
import 'quest.dart';
import 'rencana_screen.dart';

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
    this.showBack = true,
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
        textScale: MediaQuery.textScalerOf(context).scale(1.0),
        title: 'Profil & Pengaturan',
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
          // Ringkasan disiplin mencatat; tap membuka lembar progres.
          QuestTabEnter(
            index: 1,
            child: QuestPress(
              onTap: progress != null
                  ? () => GamificationSheet.show(context, progress!)
                  : null,
              child: QuestCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stats?.title ?? 'Disiplin mencatat',
                            style: context.qTitle(17),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (stats != null) 'Level ${stats.level}',
                              if (streakDays > 0) '$streakDays hari berturut-turut',
                              if (stats == null && streakDays == 0)
                                'Catat rutin untuk naik level',
                            ].join(' · '),
                            style: context.qSmall(12.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (progress != null)
                      Icon(Icons.chevron_right_rounded, color: q.muted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.m),

          // ── Grup 1: MANAJEMEN KEUANGAN ──
          QuestTabEnter(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const QuestSectionHeader(title: 'Manajemen Keuangan'),
                QuestCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 1. Akun Bank & Dompet
                      StreamBuilder<List<Account>>(
                        stream: repository.watchAccounts(),
                        builder: (context, snapshot) {
                          final accounts = snapshot.data ?? const [];
                          return QuestListTile(
                            leading: _SettingIcon(icon: Icons.account_balance_wallet_rounded),
                            title: Text(
                              'Akun Bank & Dompet',
                              style: context.qTitle(15),
                            ),
                            subtitle: Text(
                              '${accounts.length} akun',
                              style: context.qSmall(12),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: q.muted,
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

                      // 2. Anggaran & Kategori
                      StreamBuilder<List<Category>>(
                        stream: repository.watchCategories(),
                        builder: (context, snapshot) {
                          final categories = snapshot.data ?? const [];
                          return QuestListTile(
                            leading: _SettingIcon(icon: Icons.pie_chart_outline_rounded),
                            title: Text(
                              'Anggaran & Kategori',
                              style: context.qTitle(15),
                            ),
                            subtitle: Text(
                              '${categories.length} kategori, batas bulanan',
                              style: context.qSmall(12),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: q.muted,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RencanaScreen(
                                  repository: repository,
                                  progress: progress,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, thickness: 1, color: q.line),

                      // 3. Laporan Finansial
                      QuestListTile(
                        leading: _SettingIcon(icon: Icons.bar_chart_rounded),
                        title: Text(
                          'Laporan Finansial',
                          style: context.qTitle(15),
                        ),
                        subtitle: Text(
                          'Arus kas, tren, dan komposisi pengeluaran',
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // ── Grup 2: PENGATURAN & SISTEM ──
          QuestTabEnter(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const QuestSectionHeader(title: 'Pengaturan & Sistem'),
                QuestCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 1. Tema Tampilan (Light / Dark / System)
                      StreamBuilder<ThemeMode>(
                        stream: repository.watchThemeMode(),
                        initialData: ThemeMode.system,
                        builder: (context, snapshot) {
                          final currentMode =
                              snapshot.data ?? ThemeMode.system;
                          final modeTitle = switch (currentMode) {
                            ThemeMode.system => 'Sistem',
                            ThemeMode.light => 'Terang',
                            ThemeMode.dark => 'Gelap',
                          };
                          final modeIcon = switch (currentMode) {
                            ThemeMode.system => Icons.brightness_auto_rounded,
                            ThemeMode.light => Icons.light_mode_rounded,
                            ThemeMode.dark => Icons.dark_mode_rounded,
                          };

                          return QuestListTile(
                            leading: _SettingIcon(icon: modeIcon),
                            title: Text(
                              'Tema Tampilan',
                              style: context.qTitle(15),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  modeTitle,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: q.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: q.muted,
                                ),
                              ],
                            ),
                            onTap: () => _openThemeSheet(context, currentMode),
                          );
                        },
                      ),
                      Divider(height: 1, thickness: 1, color: q.line),

                      // 2. Capture Notifikasi Bank
                      QuestListTile(
                        leading: _SettingIcon(icon: Icons.notifications_active_rounded),
                        title: Text(
                          'Capture Notifikasi Bank',
                          style: context.qTitle(15),
                        ),
                        subtitle: Text(
                          'Izin, bank terhubung, dan aturan',
                          style: context.qSmall(12),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: q.muted,
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
                      Divider(height: 1, thickness: 1, color: q.line),

                      // 3. Peringatan Batas (notifikasi Android)
                      StreamBuilder<bool>(
                        stream: repository.watchBudgetAlertsEnabled(),
                        initialData: false,
                        builder: (context, snap) => QuestListTile(
                          leading: _SettingIcon(
                            icon: Icons.notification_important_rounded,
                          ),
                          title: Text(
                            'Peringatan Batas',
                            style: context.qTitle(15),
                          ),
                          subtitle: Text(
                            (snap.data ?? false)
                                ? 'Notifikasi saat menyentuh ambang persen'
                                : 'Nonaktif',
                            style: context.qSmall(12),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: q.muted,
                          ),
                          onTap: () =>
                              BudgetAlertSheet.show(context, repository),
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: q.line),

                      // 4. Backup & Pulihkan Data
                      QuestListTile(
                        leading: _SettingIcon(icon: Icons.shield_outlined),
                        title: Text(
                          'Backup & Pulihkan Data',
                          style: context.qTitle(15),
                        ),
                        subtitle: Text(
                          'Salinan data terenkripsi PIN',
                          style: context.qSmall(12),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: q.muted,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BackupScreen(repository: repository),
                          ),
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: q.line),

                      // 5. Isi Data Contoh (hanya build debug)
                      if (kDebugMode) ...[
                        Divider(height: 1, thickness: 1, color: q.line),
                        QuestListTile(
                          leading: _SettingIcon(icon: Icons.dataset_outlined),
                          title: Text(
                            'Isi Data Contoh',
                            style: context.qTitle(15),
                          ),
                          subtitle: Text(
                            'Transaksi, anggaran, dan saldo contoh',
                            style: context.qSmall(12),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: q.muted,
                          ),
                          onTap: () => _seedDemoData(context),
                        ),
                      ],

                      // 6. Kosongkan Data Aplikasi (Danger Zone di bagian paling akhir)
                      QuestListTile(
                        leading: _SettingIcon(icon: Icons.delete_forever_rounded, danger: true),
                        title: Text(
                          'Kosongkan Data Aplikasi',
                          style: context.qTitle(15).copyWith(color: q.bad),
                        ),
                        subtitle: Text(
                          'Hapus semua data dan mulai dari awal',
                          style: context.qSmall(12),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: q.bad.withValues(alpha: 0.5),
                        ),
                        onTap: () => _confirmResetData(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          // Tentang: teks biasa, tanpa kartu.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('bukuduit', style: context.qTitle(14)),
                const SizedBox(height: 2),
                Text(
                  'Versi 1.0.0. Data tersimpan terenkripsi di perangkat ini.',
                  style: context.qSmall(12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seedDemoData(BuildContext context) async {
    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Isi Data Contoh?',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaksi contoh, batas harian/mingguan/bulanan, saldo awal akun, dan alokasi kategori akan diisi. Data yang sudah ada tidak dihapus.',
            style: context.qBody(13),
          ),
        ],
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Isi Data',
          tone: QuestTone.primary,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.mediumImpact();
      await reseedDummyData(repository.db, repository);
      await progress?.refresh();
      if (context.mounted) {
        questSnack(
          context,
          'Data contoh berhasil diisi.',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    }
  }

  Future<void> _confirmResetData(BuildContext context) async {
    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Kosongkan Seluruh Data?',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Semua riwayat transaksi, saldo akun, draf notifikasi, bon/utang, alokasi anggaran, dan preferensi akan dihapus bersih.',
            style: context.qBody(13),
          ),
          const SizedBox(height: Spacing.s),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.q.bad.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: context.q.bad.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: context.q.bad, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tindakan ini permanen dan tidak dapat dibatalkan.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.q.bad,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Kosongkan Data',
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.heavyImpact();
      await repository.resetAllData();
      await progress?.refresh();
      if (context.mounted) {
        questSnack(
          context,
          'Seluruh data berhasil dikosongkan.',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    }
  }

  Future<void> _openThemeSheet(
    BuildContext context,
    ThemeMode currentMode,
  ) async {
    HapticFeedback.selectionClick();
    await showQuestSheet<void>(
      context,
      (ctx) => _ThemePickerSheet(
        initialMode: currentMode,
        onModeSelected: (newMode) async {
          HapticFeedback.selectionClick();
          await repository.setThemeMode(newMode);
          if (ctx.mounted) {
            Future.delayed(const Duration(milliseconds: 180), () {
              if (ctx.mounted) Navigator.pop(ctx);
            });
          }
        },
      ),
    );
  }
}

class _ThemePickerSheet extends StatefulWidget {
  const _ThemePickerSheet({
    required this.initialMode,
    required this.onModeSelected,
  });

  final ThemeMode initialMode;
  final ValueChanged<ThemeMode> onModeSelected;

  @override
  State<_ThemePickerSheet> createState() => _ThemePickerSheetState();
}

class _ThemePickerSheetState extends State<_ThemePickerSheet> {
  late ThemeMode _selected = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    final options = const [
      (
        mode: ThemeMode.system,
        title: 'Sistem',
        desc: 'Ikuti tema perangkat',
        icon: Icons.brightness_auto_rounded,
      ),
      (
        mode: ThemeMode.light,
        title: 'Terang',
        desc: 'Latar terang',
        icon: Icons.light_mode_rounded,
      ),
      (
        mode: ThemeMode.dark,
        title: 'Gelap',
        desc: 'Latar gelap',
        icon: Icons.dark_mode_rounded,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tema Tampilan', style: context.qTitle(18)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: Spacing.m),
            for (final opt in options) ...[
              _ThemeOptionCard(
                title: opt.title,
                desc: opt.desc,
                icon: opt.icon,
                selected: _selected == opt.mode,
                onTap: () {
                  setState(() => _selected = opt.mode);
                  widget.onModeSelected(opt.mode);
                },
              ),
              const SizedBox(height: Spacing.s),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String desc;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return QuestPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: QuestMotion.fast,
        curve: QuestMotion.easeOut,
        padding: const EdgeInsets.all(Spacing.m),
        decoration: BoxDecoration(
          color: selected
              ? q.primary.withValues(alpha: 0.08)
              : q.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: selected
                ? q.primary
                : q.line.withValues(alpha: 0.6),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? q.primary.withValues(alpha: 0.16)
                    : q.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: selected ? q.primary : q.muted,
                size: 22,
              ),
            ),
            const SizedBox(width: Spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.qTitle(15).copyWith(
                          color: selected ? q.primary : q.text,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: context.qSmall(12).copyWith(
                          color: selected ? q.text : q.muted,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.s),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? q.primary : q.muted.withValues(alpha: 0.4),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.icon, this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: q.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: danger ? q.bad : q.primary, size: 20),
    );
  }
}
