import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import 'restore_flow.dart';

/// Backup & pulihkan: dua tombol, tanpa istilah teknis.
///
/// "Simpan data saya" → file terenkripsi dikunci PIN buatan user sendiri,
/// dibagikan via share sheet. "Pulihkan data" → pilih file + masukkan PIN
/// yang sama, app memuat ulang datanya.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Jendela berbagi bisa ditutup lewat tombol BACK tanpa menyelesaikan
  /// future share() — app kembali aktif = anggap selesai, tombol hidup
  /// lagi (audit A-10).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _busy && mounted) {
      setState(() => _busy = false);
    }
  }

  void _snack(String message, {IconData? icon}) {
    if (!mounted) return;
    questSnack(context, message, icon: icon);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack('Ada kendala: $e', icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _tmpPath(String name) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$name';
  }

  String _stamp() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}'
        '-${n.hour.toString().padLeft(2, '0')}${n.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _backup() => _run(() async {
    final pin = await askBackupPin(context, repeat: false);
    if (pin == null) return;
    // Bersihkan salinan lama secara proaktif: share() bisa tidak
    // pernah selesai bila sheet ditutup paksa (tombol BACK), jadi
    // pembersihan hanya pasca-share tidak bisa diandalkan.
    final cache = (await getTemporaryDirectory()).listSync();
    for (final entry in cache) {
      if (entry is File && entry.path.contains('catatim-backup-')) {
        entry.deleteSync();
      }
    }
    await widget.repository.checkpoint();
    final dbFile = await currentDatabaseFile();
    final path = await _tmpPath('catatim-backup-${_stamp()}.sqlite');
    await dbFile.copy(path);
    // Kunci ulang salinan dengan PIN user (DB aktif tetap terkunci
    // passphrase perangkat).
    final deviceKey = await currentPassphrase();
    final db = AppDatabase(encryptedExecutor(File(path), deviceKey));
    try {
      await db.customStatement("PRAGMA rekey = '$pin'");
    } finally {
      await db.close();
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Backup data CatatIM: simpan dan ingat PIN-nya!',
        ),
      );
    } finally {
      // Salinan sudah diserahkan share target — jangan tinggal di cache.
      final tmp = File(path);
      if (tmp.existsSync()) await tmp.delete();
    }
    _snack('Backup tersimpan: ingat PIN-nya!', icon: Icons.backup_outlined);
  });

  Future<void> _restore() => _run(() => startRestoreFlow(context));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: QuestHeader(
        textScale: MediaQuery.textScalerOf(context).scale(1.0),
        title: 'Backup & pulihkan',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.m, 0, Spacing.m, Spacing.m),
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: Spacing.m),
              child: LinearProgressIndicator(),
            ),
          QuestEnter(
            child: QuestCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.backup_outlined,
                    title: 'Simpan datamu',
                    subtitle: 'Buat salinan terkunci PIN',
                    onTap: _busy ? null : _backup,
                  ),
                  Divider(height: 1, thickness: 1, color: context.q.line),
                  _ActionRow(
                    icon: Icons.restore_outlined,
                    title: 'Pulihkan data',
                    subtitle: 'Kembalikan dari file backup + PIN',
                    onTap: _busy ? null : _restore,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.m),
          QuestEnter(
            index: 1,
            child: Text(
              'Backup berisi seluruh catatanmu. Simpan file-nya di tempat aman '
              'dan ingat PIN-nya. Tanpa PIN, backup tidak bisa dibuka.',
              style: context.qSmall(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return QuestPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.q.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.q.primary),
            ),
            const SizedBox(width: Spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.qTitle(15)),
                  Text(subtitle, style: context.qSmall()),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.q.muted),
          ],
        ),
      ),
    );
  }
}
