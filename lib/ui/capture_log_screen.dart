import 'package:flutter/material.dart';

import '../capture/capture_channel.dart';
import '../capture/pipeline.dart' show lessonModeKey;
import '../core/money.dart';
import '../models.dart';
import '../rules/engine.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

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
    final confirmed = await showQuestDialog<bool>(
      context,
      title: 'Izinkan akses notifikasi?',
      content: Text(disclosureText, style: context.qBody(13)),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context, false),
        ),
        QuestButton(
          label: 'Saya mengerti',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
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
    if (draft == null) {
      questSnack(
        context,
        'Masih tidak dikenali — template perlu disetel.',
        icon: Icons.help_outline_rounded,
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
    if (!mounted) return;
    questSnack(
      context,
      'Tercatat: ${draft.direction.label} ${Money.format(draft.amount)} '
      '(${draft.bankName})',
      icon: Icons.check_circle_rounded,
    );
  }

  Future<void> _showFullText(CaptureLog log) {
    return showQuestDialog<void>(
      context,
      title: 'Notifikasi mentah',
      content: SelectableText(
        'App   : ${log.packageName}\n'
        'Waktu : ${_time(log.postedAt)}\n'
        'Judul : ${log.title}\n'
        'Isi   : ${log.body}',
        style: context.qBody(13),
      ),
      actions: [
        QuestButton(label: 'Tutup', onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(title: 'Capture log', showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m,
        ),
        children: [
          FutureBuilder<bool>(
            future: _enabled,
            builder: (context, snapshot) {
              final enabled = snapshot.data ?? false;
              return QuestCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: enabled ? context.q.good : context.q.honey,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            enabled
                                ? Icons.check_rounded
                                : Icons.warning_amber_rounded,
                            color: enabled ? Colors.white : context.q.honeyInk,
                          ),
                        ),
                        const SizedBox(width: Spacing.m),
                        Expanded(
                          child: Text(
                            enabled
                                ? 'Akses notifikasi aktif — transaksi dari '
                                      'bank tertangkap otomatis.'
                                : 'Akses notifikasi belum aktif.',
                            style: context.qBody(14),
                          ),
                        ),
                      ],
                    ),
                    if (!enabled) ...[
                      const SizedBox(height: Spacing.m),
                      QuestButton(
                        label: 'Beri izin akses notifikasi',
                        icon: Icons.notifications_active_outlined,
                        onPressed: _requestAccess,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: Spacing.m),
          QuestCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mode pelajaran', style: context.qTitle(15)),
                      const SizedBox(height: 2),
                      Text(
                        'Catat SEMUA notifikasi ke log (untuk tuning '
                        'template). Nonaktif = hanya notifikasi bank.',
                        style: context.qSmall(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.s),
                FutureBuilder<String?>(
                  future: widget.repository.getSetting(lessonModeKey),
                  builder: (context, snap) {
                    final on = (snap.data ?? '1') == '1';
                    return QuestSwitch(
                      value: on,
                      label: 'Mode pelajaran',
                      onChanged: (v) async {
                        await widget.repository.setSetting(
                          lessonModeKey,
                          v ? '1' : '0',
                        );
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),
          QuestCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.health_and_safety_outlined,
                      color: context.q.text,
                    ),
                    const SizedBox(width: Spacing.s),
                    Expanded(
                      child: Text(
                        'Kesehatan capture (vivo/Funtouch)',
                        style: context.qTitle(15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.s),
                Text(
                  '1. Setelan → Baterai → Bukuduit → Unrestricted\n'
                  '2. Izinkan Autostart untuk Bukuduit\n'
                  '3. Jangan force-close app dari recents',
                  style: context.qBody(13),
                ),
                const SizedBox(height: Spacing.m),
                QuestButton(
                  label: 'Buka pengaturan baterai',
                  icon: Icons.battery_charging_full_rounded,
                  tone: QuestTone.secondary,
                  onPressed: widget.channel.openBatterySettings,
                ),
              ],
            ),
          ),
          const QuestSectionHeader(title: 'Notifikasi tertangkap (mentah)'),
          StreamBuilder<List<CaptureLog>>(
            stream: widget.repository.watchCaptureLog(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const QuestSkeleton(rows: 2);
              }
              final logs = snapshot.data ?? const <CaptureLog>[];
              if (logs.isEmpty) {
                return QuestEmpty(
                  title: 'Belum ada notifikasi',
                  hint: 'Kirim uang kecil dari aplikasi bank-mu untuk menguji.',
                );
              }
              return Column(
                children: [
                  for (final log in logs)
                    QuestPress(
                      onTap: () => _showFullText(log),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: Spacing.s),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.q.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: context.q.shadow,
                              offset: const Offset(0, 6),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: log.parsed
                                    ? context.q.good.withValues(alpha: 0.18)
                                    : context.q.surface2,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                log.parsed
                                    ? Icons.receipt_rounded
                                    : Icons.help_outline_rounded,
                                size: 19,
                                color: log.parsed
                                    ? context.q.good
                                    : context.q.muted,
                              ),
                            ),
                            const SizedBox(width: Spacing.s),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.title.isEmpty
                                        ? '(tanpa judul)'
                                        : log.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.qTitle(14),
                                  ),
                                  Text(
                                    '${log.packageName} · ${_time(log.postedAt)}',
                                    style: context.qSmall(11),
                                  ),
                                  Text(
                                    log.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.qSmall(12),
                                  ),
                                ],
                              ),
                            ),
                            if (log.parsed)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: context.q.good.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Tercatat',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: context.q.good,
                                  ),
                                ),
                              )
                            else
                              QuestIconButton(
                                icon: Icons.refresh_rounded,
                                tooltip: 'Parse ulang',
                                onPressed: () => _reparse(log),
                              ),
                          ],
                        ),
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
