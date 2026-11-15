import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../capture/pipeline.dart';
import '../core/csv_export.dart' show buildTransactionCsv;
import '../game/mascot.dart';
import '../game/progress.dart';
import '../rules/rule_set.dart';
import '../storage/repository.dart';
import '../storage/seed_dummy.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'backup_screen.dart';
import 'budget_alert_sheet.dart';
import 'capture_settings_screen.dart';
import 'gamification_sheet.dart';
import 'quest.dart';

typedef ProfileSettingsScreen = SettingsScreen;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    this.progress,
    this.showBack = true,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final ProgressService? progress;
  final bool showBack;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  LedgerRepository get repository => widget.repository;
  CapturePipeline get pipeline => widget.pipeline;
  RuleSet get ruleSet => widget.ruleSet;
  ProgressService? get progress => widget.progress;
  bool get showBack => widget.showBack;

  late Stream<ThemeMode> _themeModeStream;
  late Stream<bool> _budgetAlertsStream;

  @override
  void initState() {
    super.initState();
    _themeModeStream = widget.repository.watchThemeMode();
    _budgetAlertsStream = widget.repository.watchBudgetAlertsEnabled();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _themeModeStream = widget.repository.watchThemeMode();
      _budgetAlertsStream = widget.repository.watchBudgetAlertsEnabled();
    }
  }

  /// Satu baris status streak untuk kartu gamifikasi — tiap kondisi
  /// singkat agar muat tanpa membungkus.
  String _streakLine(ProgressSummary? summary, SaverStats? stats) {
    final streakDays = summary?.streakDays ?? 0;
    if (summary?.streakPaused ?? false) {
      return 'Belum mulai · atur batas harian dulu';
    }
    if (streakDays > 0) {
      return '$streakDays hari berturut-turut';
    }
    if (stats != null) {
      return 'Catat rutin untuk mulai streak';
    }
    return 'Catat rutin untuk naik level';
  }

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
          0,
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
                    // Pochy ikut bereaksi ke kondisi keuangan (mood-aware),
                    // satu jangkar visual yang sama dengan sheet gamifikasi.
                    MascotStage(
                      mood: summary?.mood ?? MascotMood.idle,
                      size: 56,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (stats != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.q.primarySolid,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                  child: Text(
                                    'Level ${stats.level}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: context.q.onPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.s),
                              ],
                              Expanded(
                                child: Text(
                                  stats?.title ?? 'Disiplin mencatat',
                                  style: context.qTitle(15.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.xs),
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 14,
                                color:
                                    streakDays > 0 &&
                                        !(summary?.streakPaused ?? false)
                                    ? context.q.warn
                                    : context.q.muted,
                              ),
                              const SizedBox(width: Spacing.xs),
                              Expanded(
                                child: Text(
                                  _streakLine(summary, stats),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: context.q.muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (stats != null) ...[
                            const SizedBox(height: Spacing.s),
                            Row(
                              children: [
                                Expanded(
                                  child: QuestProgressBar(
                                    value: stats.progress.clamp(0.0, 1.0),
                                    color: context.q.primary,
                                    backgroundColor: context.q.surface2,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(width: Spacing.s),
                                Text(
                                  '${stats.currentXp} / ${stats.nextLevelXp} XP',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.q.muted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
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
          ),
          QuestTabEnter(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const QuestSectionHeader(title: 'Pengaturan & Sistem'),
                QuestCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      StreamBuilder<ThemeMode>(
                        stream: _themeModeStream,
                        initialData: ThemeMode.system,
                        builder: (context, snapshot) {
                          final currentMode = snapshot.data ?? ThemeMode.system;
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

                      QuestListTile(
                        leading: const _SettingIcon(
                          icon: Icons.notifications_active_rounded,
                        ),
                        title: Text(
                          'Capture Notifikasi Bank',
                          style: context.qTitle(15),
                        ),
                        subtitle: Text(
                          'Izin, bank terhubung, dan aturan',
                          style: context.qSmall(),
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

                      StreamBuilder<bool>(
                        stream: _budgetAlertsStream,
                        initialData: false,
                        builder: (context, snap) => QuestListTile(
                          leading: const _SettingIcon(
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
                            style: context.qSmall(),
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

                      QuestListTile(
                        leading: const _SettingIcon(
                          icon: Icons.shield_outlined,
                        ),
                        title: Text(
                          'Backup & Pulihkan Data',
                          style: context.qTitle(15),
                        ),
                        subtitle: Text(
                          'Salinan data terenkripsi PIN',
                          style: context.qSmall(),
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

                      QuestListTile(
                        leading: const _SettingIcon(
                          icon: Icons.table_view_rounded,
                        ),
                        title: Text('Ekspor CSV', style: context.qTitle(15)),
                        subtitle: Text(
                          'Semua transaksi untuk spreadsheet',
                          style: context.qSmall(),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: q.muted,
                        ),
                        onTap: () => _exportCsv(context),
                      ),
                      Divider(height: 1, thickness: 1, color: q.line),

                      if (kDebugMode) ...[
                        Divider(height: 1, thickness: 1, color: q.line),
                        QuestListTile(
                          leading: const _SettingIcon(
                            icon: Icons.dataset_outlined,
                          ),
                          title: Text(
                            'Isi Data Contoh',
                            style: context.qTitle(15),
                          ),
                          subtitle: Text(
                            'Transaksi, anggaran, dan saldo contoh',
                            style: context.qSmall(),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: q.muted,
                          ),
                          onTap: () => _seedDemoData(context),
                        ),
                      ],

                      QuestListTile(
                        leading: const _SettingIcon(
                          icon: Icons.delete_forever_rounded,
                          danger: true,
                        ),
                        title: Text(
                          'Kosongkan Data Aplikasi',
                          style: context.qTitle(15).copyWith(color: q.bad),
                        ),
                        subtitle: Text(
                          'Hapus semua data dan mulai dari awal',
                          style: context.qSmall(),
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
          // Jarak ekstra sebelum footer: blok "Tentang" bukan section baru,
          // jadi butuh napas lebih dari jarak antar-kartu biasa.
          const SizedBox(height: Spacing.xl),

          // Tentang: logo app sejajar di kiri nama + versi, tanpa kartu.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.cell),
                  child: Image.asset(
                    'assets/logo/catatim_logo.png',
                    width: 40,
                    height: 40,
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('catatim', style: context.qTitle(14)),
                      const SizedBox(height: 2),
                      Text(
                        'Versi 1.0.0. Data terenkripsi di perangkat ini.',
                        style: context.qSmall(),
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

  /// Ekspor seluruh transaksi ke CSV dan serahkan ke share sheet.
  /// File ditaruh di cache lalu dibuang setelah diserahkan — pola yang
  /// sama dengan backup (share() bisa tidak selesai, jadi pembersihan
  /// lama dilakukan proaktif sebelum menulis).
  Future<void> _exportCsv(BuildContext context) async {
    final rows = await repository.exportRows();
    if (!context.mounted) return;
    if (rows.isEmpty) {
      questSnack(
        context,
        'Belum ada transaksi untuk diekspor.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    final csv = buildTransactionCsv(rows);
    final dir = await getTemporaryDirectory();
    for (final entry in dir.listSync()) {
      if (entry is File && entry.path.contains('catatim-export-')) {
        entry.deleteSync();
      }
    }
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final path =
        '${dir.path}/catatim-export-'
        '${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}.csv';
    final file = File(path);
    await file.writeAsString(csv);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Ekspor transaksi CatatIM — buka dengan spreadsheet.',
        ),
      );
    } finally {
      if (file.existsSync()) await file.delete();
    }
    if (context.mounted) {
      questSnack(
        context,
        'CSV ${rows.length} transaksi siap dibagikan.',
        icon: Icons.table_view_rounded,
      );
    }
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
            'Transaksi contoh, batas harian/mingguan/bulanan, saldo awal akun, dan alokasi kategori bakal diisi. Data yang udah ada nggak dihapus.',
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
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (confirmed == true && context.mounted) {
      unawaited(HapticFeedback.mediumImpact());
      await reseedDummyData(repository.db, repository);
      await progress?.refresh();
      if (context.mounted) {
        questSnack(
          context,
          'Beres! Data contoh terisi.',
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
            'Semua riwayat transaksi, saldo akun, draf notifikasi, bon/utang, alokasi anggaran, dan preferensi bakal dihapus bersih.',
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
                Icon(
                  Icons.warning_amber_rounded,
                  color: context.q.bad,
                  size: 18,
                ),
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
      unawaited(HapticFeedback.heavyImpact());
      await repository.resetAllData();
      await progress?.refresh();
      if (context.mounted) {
        questSnack(
          context,
          'Beres! Semua data udah dibersihkan.',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    }
  }

  Future<void> _openThemeSheet(
    BuildContext context,
    ThemeMode currentMode,
  ) async {
    unawaited(HapticFeedback.selectionClick());
    await showQuestSheet<void>(
      context,
      (ctx) => _ThemePickerSheet(
        initialMode: currentMode,
        onModeSelected: (newMode) async {
          unawaited(HapticFeedback.selectionClick());
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
          color: selected ? q.primary.withValues(alpha: 0.08) : q.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: selected ? q.primary : q.line.withValues(alpha: 0.6),
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
                    style: context
                        .qTitle(15)
                        .copyWith(
                          color: selected ? q.primary : q.text,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: context.qSmall().copyWith(
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
