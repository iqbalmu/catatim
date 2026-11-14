import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../storage/database.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Minta PIN 6–12 angka ke user; null bila batal.
///
/// Dipakai alur simpan backup (buat PIN baru, dua kali) maupun pulihkan
/// (masukkan PIN yang sama).
Future<String?> askBackupPin(
  BuildContext context, {
  required bool repeat,
}) async {
  final firstCtrl = TextEditingController();
  final secondCtrl = TextEditingController();
  final pins = await showQuestDialog<(String, String)>(
    context,
    title: 'Kunci backup (PIN)',
    content: QuestDialogDisposer(
      controllers: [firstCtrl, secondCtrl],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            repeat
                ? 'Masukkan PIN yang kamu buat saat menyimpan backup ini.'
                : 'Bikin PIN buat kunci file backup-nya. Ingat baik-baik ya, '
                      'tanpa PIN ini backup nggak bisa dibuka.',
            style: context.qBody(13),
          ),
          const SizedBox(height: Spacing.m),
          const QuestFieldLabel('PIN (6–12 angka)'),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: firstCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            obscureText: true,
            maxLength: 12,
            decoration: const InputDecoration(
              hintText: 'Masukkan 6–12 angka PIN',
              counterText: '',
            ),
          ),
          if (!repeat) ...[
            const SizedBox(height: Spacing.m),
            const QuestFieldLabel('Ulangi PIN'),
            const SizedBox(height: Spacing.xs),
            TextField(
              controller: secondCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              obscureText: true,
              maxLength: 12,
              decoration: const InputDecoration(
                hintText: 'Ketik ulang PIN yang sama',
                counterText: '',
              ),
            ),
          ],
        ],
      ),
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
        // Baca kedua PIN di sini — setelah await controller sudah dibuang.
        onPressed: () => Navigator.pop(context, (
          firstCtrl.text.trim(),
          secondCtrl.text.trim(),
        )),
      ),
    ],
  );
  if (!context.mounted) return null;
  if (pins == null) return null;
  final (pin, confirm) = pins;
  if (pin.isEmpty) return null;
  // PIN pendek mudah dipaksa (brute force offline pada file backup).
  if (pin.length < 6) {
    questSnack(
      context,
      'PIN minimal 6 angka.',
      icon: Icons.info_outline_rounded,
    );
    return null;
  }
  if (!repeat && pin != confirm) {
    questSnack(
      context,
      'PIN tidak sama, coba lagi.',
      icon: Icons.info_outline_rounded,
    );
    return null;
  }
  return pin;
}

/// Alur lengkap pulihkan backup: pilih file → konfirmasi → PIN →
/// verifikasi PIN bisa membuka file → kunci ulang ke kunci perangkat →
/// pasang marker → tutup app agar dibuka ulang dengan data baru.
///
/// Dipakai layar Backup dan layar "data terkunci" — tidak butuh
/// database yang sedang hidup.
Future<void> startRestoreFlow(BuildContext context) async {
  final picked = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(label: 'Backup', extensions: ['sqlite', 'db']),
    ],
  );
  if (!context.mounted) return;
  if (picked == null) return;
  final confirmed = await showQuestDialog<bool>(
    context,
    title: 'Pulihkan backup?',
    content: Text(
      'Semua data di HP ini akan diganti dengan isi file "${picked.name}". '
      'App-nya akan menutup sendiri. Buka lagi setelahnya, ya.',
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
  if (!context.mounted) return;
  final pin = await askBackupPin(context, repeat: true);
  if (pin == null) return;
  final dir = await getTemporaryDirectory();
  final stagingPath = '${dir.path}/restore_staging.sqlite';
  await File(picked.path).copy(stagingPath);
  // Verifikasi PIN bisa membuka file, lalu kunci ulang ke kunci
  // perangkat agar DB utama tetap terbuka normal setelah restart.
  final deviceKey = await currentPassphrase();
  final probe = AppDatabase(encryptedExecutor(File(stagingPath), pin));
  try {
    await probe.customSelect('SELECT count(*) AS c FROM sqlite_master').get();
    await probe.customStatement("PRAGMA rekey = '$deviceKey'");
  } catch (_) {
    await probe.close();
    await File(stagingPath).delete();
    if (!context.mounted) return;
    questSnack(
      context,
      'PIN-nya tidak cocok atau filenya rusak. Coba lagi, ya.',
      icon: Icons.error_outline_rounded,
    );
    return;
  }
  await probe.close();
  final docs = await getApplicationDocumentsDirectory();
  File('${docs.path}/restore_pending').writeAsStringSync('1');
  if (context.mounted) {
    await SystemNavigator.pop();
  }
}
