import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../storage/database.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import 'restore_flow.dart';

/// App utama saat database tak bisa dibuka dengan kunci perangkat ini
/// — mis. data dipulihkan/pindah ke HP lain tanpa kuncinya (audit A-06).
class BukuduitLockedApp extends StatelessWidget {
  const BukuduitLockedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bukuduit',
      locale: const Locale('id'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id')],
      theme: QuestSchemes.light(),
      themeMode: ThemeMode.light,
      home: const LockedScreen(),
    );
  }
}

/// Dua jalan keluar: pulihkan file backup (PIN), atau mulai dari awal.
class LockedScreen extends StatelessWidget {
  const LockedScreen({super.key});

  Future<void> _startFresh(BuildContext context) async {
    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Mulai dari awal?',
      content: Text(
        'Semua catatan yang ada di HP ini akan dihapus permanen dan '
        'app mulai kosong lagi. Kalau kamu punya file backup, lebih '
        'baik pulihkan daripada mulai awal.',
        style: context.qBody(13),
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Hapus & mulai',
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed != true) return;
    final dbFile = await currentDatabaseFile();
    if (dbFile.existsSync()) await dbFile.delete();
    for (final suffix in ['-wal', '-shm']) {
      final side = File('${dbFile.path}$suffix');
      if (side.existsSync()) await side.delete();
    }
    if (context.mounted) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: QuestHeader(
        textScale: MediaQuery.textScalerOf(context).scale(1.0),
        title: 'Data terkunci',
        subtitle: 'Catatanmu ada, tapi kuncinya tidak cocok',
        showBack: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.l),
                decoration: BoxDecoration(
                  color: context.q.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.q.line),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 44,
                      color: context.q.muted,
                    ),
                    const SizedBox(height: Spacing.m),
                    Text(
                      'Data di HP ini disimpan terkunci, dan kuncinya '
                      'tidak ada di HP ini. Biasanya terjadi kalau data '
                      'dipindahkan dari HP lain.',
                      style: context.qBody(13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.s),
                    Text(
                      'File backup yang kamu simpan sebelumnya (dengan '
                      'PIN) tetap bisa dipulihkan di sini.',
                      style: context.qSmall(12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.l),
              QuestButton(
                label: 'Pulihkan dari backup',
                icon: Icons.restore_rounded,
                onPressed: () => startRestoreFlow(context),
              ),
              const SizedBox(height: Spacing.m),
              QuestButton(
                label: 'Mulai dari awal',
                tone: QuestTone.ghost,
                onPressed: () => _startFresh(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
