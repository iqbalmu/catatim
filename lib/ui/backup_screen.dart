import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';

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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
      _snack('Gagal: $e');
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
        _snack('Backup dibagikan — simpan juga passphrase-nya!');
      });

  Future<void> _restore() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Database', extensions: ['sqlite', 'db']),
      ],
    );
    if (!mounted) return;
    if (picked == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pulihkan backup?'),
        content: Text(
          'Semua data saat ini akan DIGANTI dengan isi file '
          '"${picked.name}". App akan menutup sendiri — buka lagi setelah itu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pulihkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final dir = await getTemporaryDirectory();
      // Stage di temp; main() akan memindahkannya sebelum DB dibuka.
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
      appBar: AppBar(title: const Text('Backup & pulihkan')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.m),
        children: [
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: Spacing.m),
          Text('Ekspor', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.s),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Ekspor CSV'),
                  subtitle:
                      const Text('Semua transaksi, siap dibuka di spreadsheet'),
                  onTap: _busy ? null : _exportCsv,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.l),
          Text('Backup penuh (terenkripsi)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.s),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Buat backup database'),
                  subtitle: const Text(
                      'File .sqlite terenkripsi — dibagikan via share sheet'),
                  onTap: _busy ? null : _backupDb,
                ),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Pulihkan dari backup'),
                  subtitle: const Text('Pilih file .sqlite hasil backup'),
                  onTap: _busy ? null : _restore,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.l),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key_outlined),
                      const SizedBox(width: Spacing.s),
                      Expanded(
                        child: Text(
                          'Passphrase database',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Salin passphrase',
                        icon: const Icon(Icons.copy_all_outlined),
                        onPressed: _passphrase == null
                            ? null
                            : () {
                                Clipboard.setData(
                                    ClipboardData(text: _passphrase!));
                                _snack('Passphrase disalin');
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.s),
                  SelectableText(
                    _passphrase ?? 'memuat…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  const SizedBox(height: Spacing.s),
                  Text(
                    'WAJIB disimpan terpisah dari file backup. Backup tanpa '
                    'passphrase ini tidak bisa dibuka.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
