import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

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

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

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

  /// Minta PIN 4–12 digit ke user; null bila batal.
  Future<String?> _askPin({required bool repeat}) async {
    final firstCtrl = TextEditingController();
    final secondCtrl = TextEditingController();
    final pin = await showQuestDialog<String>(
      context,
      title: 'Kunci backup (PIN)',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            repeat
                ? 'Masukkan PIN yang kamu buat saat menyimpan backup ini.'
                : 'Buat PIN untuk mengunci file backup. Ingat baik-baik — '
                      'tanpa PIN ini backup tidak bisa dibuka.',
            style: context.qBody(13),
          ),
          const SizedBox(height: Spacing.m),
          TextField(
            controller: firstCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            obscureText: true,
            maxLength: 12,
            decoration: const InputDecoration(
              labelText: 'PIN (4–12 angka)',
              counterText: '',
            ),
          ),
          if (!repeat) ...[
            const SizedBox(height: Spacing.s),
            TextField(
              controller: secondCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              obscureText: true,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'Ulangi PIN',
                counterText: '',
              ),
            ),
          ],
        ],
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        QuestButton(
          label: 'Lanjut',
          icon: Icons.check_rounded,
          onPressed: () {
            final first = firstCtrl.text.trim();
            if (first.length < 4) {
              Navigator.pop(context);
              return;
            }
            if (!repeat && first != secondCtrl.text.trim()) {
              Navigator.pop(context);
              return;
            }
            Navigator.pop(context, first);
          },
        ),
      ],
    );
    if (pin == null || pin.length < 4) return null;
    if (!repeat && pin != secondCtrl.text.trim()) {
      _snack('PIN tidak sama, coba lagi.', icon: Icons.info_outline_rounded);
      return null;
    }
    return pin;
  }

  Future<void> _backup() => _run(() async {
    final pin = await _askPin(repeat: false);
    if (pin == null) return;
    await widget.repository.checkpoint();
    final dbFile = await currentDatabaseFile();
    final path = await _tmpPath('bukuduit-backup-${_stamp()}.sqlite');
    await dbFile.copy(path);
    // Kunci ulang salinan dengan PIN user (DB aktif tetap terkunci
    // passphrase perangkat).
    final deviceKey = await currentPassphrase();
    final db = AppDatabase(
      NativeDatabase.createInBackground(
        File(path),
        setup: (rawDb) {
          rawDb.execute("PRAGMA key = '$deviceKey'");
        },
      ),
    );
    try {
      await db.customStatement("PRAGMA rekey = '$pin'");
    } finally {
      await db.close();
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: 'Backup data Bukuduit — simpan + ingat PIN-nya!',
      ),
    );
    _snack('Backup tersimpan — ingat PIN-nya!', icon: Icons.backup_outlined);
  });

  Future<void> _restore() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Backup', extensions: ['sqlite', 'db']),
      ],
    );
    if (!mounted) return;
    if (picked == null) return;
    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Pulihkan backup?',
      content: Text(
        'Semua data di HP ini akan diganti dengan isi file "${picked.name}". '
        'App-nya akan menutup sendiri — buka lagi setelahnya, ya.',
        style: context.qBody(),
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Pulihkan',
          icon: Icons.restore_rounded,
          tone: QuestTone.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed != true) return;
    await _run(() async {
      final pin = await _askPin(repeat: true);
      if (pin == null) return;
      final dir = await getTemporaryDirectory();
      final stagingPath = '${dir.path}/restore_staging.sqlite';
      await File(picked.path).copy(stagingPath);
      // Verifikasi PIN bisa membuka file, lalu kunci ulang ke passphrase
      // perangkat agar DB utama tetap terbuka normal setelah restart.
      final deviceKey = await currentPassphrase();
      final probe = AppDatabase(
        NativeDatabase.createInBackground(
          File(stagingPath),
          setup: (rawDb) {
            rawDb.execute("PRAGMA key = '$pin'");
          },
        ),
      );
      try {
        await probe.customSelect(
          'SELECT count(*) AS c FROM sqlite_master',
          variables: const [],
          readsFrom: const {},
        ).get();
        await probe.customStatement("PRAGMA rekey = '$deviceKey'");
      } catch (_) {
        await probe.close();
        await File(stagingPath).delete();
        _snack(
          'PIN-nya tidak cocok atau filenya rusak — coba lagi, ya.',
          icon: Icons.error_outline_rounded,
        );
        return;
      }
      await probe.close();
      final docs = await getApplicationDocumentsDirectory();
      File('${docs.path}/restore_pending').writeAsStringSync('1');
      if (mounted) {
        await SystemNavigator.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Backup & pulihkan',
        subtitle: 'Simpan salinan datamu — aman di HP ini',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m,
        ),
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: Spacing.m),
              child: LinearProgressIndicator(),
            ),
          QuestCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.backup_outlined,
                  title: 'Simpan datamu',
                  subtitle: 'Buat salinan terkunci PIN',
                  onTap: _busy ? null : _backup,
                ),
                Divider(
                  height: 1,
                  thickness: 2,
                  color: context.q.line.withValues(alpha: 0.35),
                ),
                _ActionRow(
                  icon: Icons.restore_outlined,
                  title: 'Pulihkan data',
                  subtitle: 'Kembalikan dari file backup + PIN',
                  onTap: _busy ? null : _restore,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),
          Text(
            'Backup berisi seluruh catatanmu. Simpan file-nya di tempat aman '
            'dan ingat PIN-nya — tanpa PIN backup tidak bisa dibuka.',
            style: context.qSmall(),
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
                color: context.q.honey.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.q.text),
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
