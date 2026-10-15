import 'dart:io';

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

/// Backup & restore: CSV untuk spreadsheet, file DB terenkripsi + passphrase
/// untuk pemulihan penuh.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _passphrase;

  @override
  void initState() {
    super.initState();
    currentPassphrase().then((v) {
      if (mounted) setState(() => _passphrase = v);
    });
  }

  void _snack(String message, {IconData? icon}) {
    if (!mounted) return;
    questSnack(context, message, icon: icon);
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

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack('Gagal: $e', icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() => _run(() async {
    final csv = await widget.repository.buildCsv();
    final path = await _tmpPath('bukuduit-export-${_stamp()}.csv');
    await File(path).writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Ekspor transaksi Bukuduit'),
    );
  });

  Future<void> _backupDb() => _run(() async {
    await widget.repository.checkpoint();
    final dbFile = await currentDatabaseFile();
    final path = await _tmpPath('bukuduit-backup-${_stamp()}.sqlite');
    await dbFile.copy(path);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: 'Backup database Bukuduit (terenkripsi)',
      ),
    );
    _snack(
      'Backup dibagikan — simpan juga passphrase-nya!',
      icon: Icons.backup_outlined,
    );
  });

  Future<void> _restore() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Database', extensions: ['sqlite', 'db']),
      ],
    );
    if (!mounted) return;
    if (picked == null) return;
    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Pulihkan backup?',
      content: Text(
        'Semua data saat ini akan DIGANTI dengan isi file "${picked.name}". '
        'App akan menutup sendiri — buka lagi setelah itu.',
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
      final dir = await getTemporaryDirectory();
      await File(picked.path).copy('${dir.path}/restore_staging.sqlite');
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
      appBar: const QuestHeader(title: 'Backup & pulihkan', showBack: true),
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
          const QuestSectionHeader(title: 'Ekspor'),
          QuestCard(
            padding: EdgeInsets.zero,
            child: _ActionRow(
              icon: Icons.table_chart_outlined,
              title: 'Ekspor CSV',
              subtitle: 'Semua transaksi, siap dibuka di spreadsheet',
              onTap: _busy ? null : _exportCsv,
            ),
          ),
          const QuestSectionHeader(title: 'Backup penuh (terenkripsi)'),
          QuestCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.backup_outlined,
                  title: 'Buat backup database',
                  subtitle:
                      'File .sqlite terenkripsi — dibagikan via share sheet',
                  onTap: _busy ? null : _backupDb,
                ),
                Divider(
                  height: 1,
                  thickness: 2,
                  color: context.q.line.withValues(alpha: 0.35),
                ),
                _ActionRow(
                  icon: Icons.restore_outlined,
                  title: 'Pulihkan dari backup',
                  subtitle: 'Pilih file .sqlite hasil backup',
                  onTap: _busy ? null : _restore,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),
          Container(
            padding: const EdgeInsets.all(Spacing.m),
            decoration: BoxDecoration(
              color: context.q.bad.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.key_outlined, color: context.q.bad),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Text(
                        'Passphrase database',
                        style: context.qTitle(15),
                      ),
                    ),
                    QuestIconButton(
                      icon: Icons.copy_all_outlined,
                      tooltip: 'Salin passphrase',
                      onPressed: _passphrase == null
                          ? null
                          : () {
                              Clipboard.setData(
                                ClipboardData(text: _passphrase!),
                              );
                              _snack(
                                'Passphrase disalin',
                                icon: Icons.copy_all_outlined,
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.s),
                SelectableText(
                  _passphrase ?? 'memuat…',
                  style: context
                      .qBody(13)
                      .copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                const SizedBox(height: Spacing.s),
                Text(
                  'WAJIB disimpan terpisah dari file backup. Backup tanpa '
                  'passphrase ini tidak bisa dibuka.',
                  style: context.qSmall(),
                ),
              ],
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
