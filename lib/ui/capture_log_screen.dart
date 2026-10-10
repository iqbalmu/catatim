import 'package:flutter/material.dart';

import '../capture/capture_channel.dart';
import '../core/money.dart';
import '../models.dart';
import '../rules/engine.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';

/// Teks prominent disclosure — syarat kebijakan User Data Google Play
/// sebelum mengarahkan user ke pengaturan akses notifikasi.
const String disclosureText =
    'Bukuduit membaca notifikasi dari aplikasi perbankan dan e-wallet yang '
    'terpasang di perangkat ini untuk mendeteksi transaksi dan mencatatnya '
    'secara otomatis.\n\n'
    'Seluruh data notifikasi dan catatan transaksi disimpan hanya di '
    'penyimpanan lokal perangkat ini (terenkripsi) dan tidak pernah dikirim '
    'ke server mana pun. Akses ini opsional — tanpa izin, kamu tetap bisa '
    'mencatat transaksi secara manual. Kamu dapat mencabut akses kapan saja '
    'lewat Pengaturan Android → Akses notifikasi.';

class CaptureLogScreen extends StatefulWidget {
  const CaptureLogScreen({
    super.key,
    required this.repository,
    required this.channel,
    required this.engine,
  });

  final LedgerRepository repository;
  final CaptureChannel channel;
  final RuleEngine engine;

  @override
  State<CaptureLogScreen> createState() => _CaptureLogScreenState();
}

class _CaptureLogScreenState extends State<CaptureLogScreen> {
  late Future<bool> _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.channel.isListenerEnabled();
  }

  Future<void> _requestAccess() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izinkan akses notifikasi?'),
        content: const Text(disclosureText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Saya mengerti'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await widget.channel.openListenerSettings();
    }
    if (mounted) setState(() => _enabled = widget.channel.isListenerEnabled());
  }

  Future<void> _reparse(CaptureLog log) async {
    final draft = widget.engine.parse(
      packageName: log.packageName,
      title: log.title,
      body: log.body,
    );
    final messenger = ScaffoldMessenger.of(context);
    if (draft == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Masih tidak dikenali — template perlu disetel.'),
        ),
      );
      return;
    }
    await widget.repository.recordFromCapture(
      raw: RawCapture(
        packageName: log.packageName,
        title: log.title,
        body: log.body,
        postedAt: log.postedAt,
      ),
      draft: draft,
      existingLogId: log.id,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Tercatat: ${draft.direction.label} ${Money.format(draft.amount)} '
          '(${draft.bankName})',
        ),
      ),
    );
  }

  Future<void> _showFullText(CaptureLog log) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifikasi mentah'),
        content: SelectableText(
          'App      : ${log.packageName}\n'
          'Waktu    : ${_time(log.postedAt)}\n'
          'Judul    : ${log.title}\n'
          'Isi      : ${log.body}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Capture log')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.m),
        children: [
          FutureBuilder<bool>(
            future: _enabled,
            builder: (context, snapshot) {
              final enabled = snapshot.data ?? false;
              return Card(
                color: enabled
                    ? scheme.secondaryContainer
                    : scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            enabled ? Icons.check_circle : Icons.warning_amber,
                            color: enabled
                                ? scheme.onSecondaryContainer
                                : scheme.onErrorContainer,
                          ),
                          const SizedBox(width: Spacing.s),
                          Expanded(
                            child: Text(
                              enabled
                                  ? 'Akses notifikasi aktif — transaksi dari '
                                      'bank tertangkap otomatis.'
                                  : 'Akses notifikasi belum aktif.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (!enabled) ...[
                        const SizedBox(height: Spacing.s),
                        FilledButton(
                          onPressed: _requestAccess,
                          child: const Text('Beri izin akses notifikasi'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: Spacing.m),
          Text(
            'Notifikasi tertangkap (mentah)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.s),
          StreamBuilder<List<CaptureLog>>(
            stream: widget.repository.watchCaptureLog(),
            builder: (context, snapshot) {
              final logs = snapshot.data ?? const <CaptureLog>[];
              if (logs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: Spacing.xl),
                  child: Center(
                    child: Text(
                      'Belum ada notifikasi tertangkap.\n'
                      'Coba kirim uang kecil dari aplikasi bank-mu.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final log in logs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        log.parsed ? Icons.receipt : Icons.help_outline,
                        color: log.parsed
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(
                        log.title.isEmpty ? '(tanpa judul)' : log.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${log.packageName}\n'
                        '${log.body}\n'
                        '${_time(log.postedAt)}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      onTap: () => _showFullText(log),
                      trailing: log.parsed
                          ? Chip(
                              label: const Text('Tercatat'),
                              visualDensity: VisualDensity.compact,
                            )
                          : IconButton(
                              tooltip: 'Parse ulang',
                              icon: const Icon(Icons.refresh),
                              onPressed: () => _reparse(log),
                            ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _time(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
