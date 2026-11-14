import 'package:flutter/material.dart';

import '../../capture/capture_channel.dart';
import '../../theme/quest.dart';
import '../../theme/tokens.dart';
import '../quest.dart';

/// Bottom sheet terpadu 1 layar untuk meminta izin akses notifikasi Android.
///
/// Menggabungkan ringkasan privasi & cara kerja (syarat kebijakan data Google
/// Play) dengan langkah bernomor yang ramah dan pemantauan otomatis saat user
/// kembali dari Pengaturan sistem (`AppLifecycleState.resumed`).
///
/// Mengembalikan `true` bila izin sudah aktif (baik sejak awal maupun setelah
/// user kembali dari Pengaturan), dan `false` bila user menutup sheet sebelum
/// izin aktif.
class NotificationPermissionSheet extends StatefulWidget {
  const NotificationPermissionSheet({
    super.key,
    required this.channel,
    this.bankName,
    this.cancelLabel = 'Nanti Saja',
    this.onCancel,
  });

  final CaptureChannel channel;

  /// Nama bank/e-wallet/app bila dipicu dari koneksi spesifik; null bila
  /// dipicu dari banner izin umum.
  final String? bankName;

  /// Label tombol batal/kembali di sebelah kiri.
  final String cancelLabel;

  /// Callback opsional untuk tombol kiri (default: tutup sheet dengan `false`).
  final VoidCallback? onCancel;

  /// Tampilkan bottom sheet panduan izin notifikasi dan tunggu hingga selesai.
  static Future<bool> show(
    BuildContext context, {
    required CaptureChannel channel,
    String? bankName,
    String cancelLabel = 'Nanti Saja',
  }) async {
    final alreadyEnabled = await channel.isListenerEnabled();
    if (alreadyEnabled) return true;
    if (!context.mounted) return false;

    final granted = await showQuestSheet<bool>(
      context,
      (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.xs,
          Spacing.m,
          MediaQuery.viewInsetsOf(ctx).bottom + Spacing.m,
        ),
        child: NotificationPermissionSheet(
          channel: channel,
          bankName: bankName,
          cancelLabel: cancelLabel,
        ),
      ),
    );
    return granted == true;
  }

  @override
  State<NotificationPermissionSheet> createState() =>
      _NotificationPermissionSheetState();
}

class _NotificationPermissionSheetState
    extends State<NotificationPermissionSheet>
    with WidgetsBindingObserver {
  bool _openedSettings = false;
  bool _returnedWithoutPermission = false;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAfterResume();
    }
  }

  Future<void> _checkPermissionAfterResume() async {
    final enabled = await widget.channel.isListenerEnabled();
    if (!mounted) return;
    if (enabled) {
      Navigator.of(context).pop(true);
    } else if (_openedSettings) {
      setState(() => _returnedWithoutPermission = true);
    }
  }

  Future<void> _openSettings() async {
    setState(() {
      _openedSettings = true;
      _returnedWithoutPermission = false;
    });
    await widget.channel.openListenerSettings();
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final targetName = widget.bankName;
    final hasBank = targetName != null && targetName.trim().isNotEmpty;

    final title = hasBank
        ? 'Hubungkan $targetName'
        : 'Aktifkan Izin Baca Notifikasi';
    final subtitle = hasBank
        ? 'Agar transaksi $targetName bisa dicatat otomatis dari notifikasi.'
        : 'Diperlukan agar CatatIM bisa menangkap notifikasi transaksi bank dan e-walletmu.';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: q.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: hasBank
                    ? Text(
                        targetName.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: q.primaryText,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      )
                    : Icon(
                        Icons.notifications_active_rounded,
                        color: q.primaryText,
                        size: 22,
                      ),
              ),
              const SizedBox(width: Spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.qTitle()),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.qSmall(12.5).copyWith(color: q.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.m),

          if (_returnedWithoutPermission) ...[
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: q.warnTint,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: q.warn.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: q.warn, size: 19),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Izinnya belum aktif',
                          style: context.qTitle(13).copyWith(color: q.warn),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Yuk cari CatatIM di daftar Akses Notifikasi lalu nyalakan saklarnya, setelah itu kembali ke sini.',
                          style: context.qSmall().copyWith(color: q.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.m),
          ],

          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: q.surface2.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: q.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jaminan Privasi & Cara Kerja', style: context.qTitle(13)),
                const SizedBox(height: Spacing.xs),
                _PrivacyFactRow(
                  icon: Icons.edit_note_rounded,
                  text: hasBank
                      ? 'Notifikasi transaksi $targetName diubah jadi draf catatan untuk kamu tinjau.'
                      : 'Hanya membaca notifikasi dari bank atau e-wallet yang kamu hubungkan.',
                ),
                const _PrivacyFactRow(
                  icon: Icons.lock_rounded,
                  text:
                      '100% diproses offline di HP ini. Data terenkripsi dan tidak pernah dikirim ke server mana pun.',
                ),
                const _PrivacyFactRow(
                  icon: Icons.link_off_rounded,
                  text:
                      'Bebas diputus atau dimatikan kapan saja dari pengaturan.',
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),

          Text(
            'Cara mengaktifkan (3 langkah cepat):',
            style: context.qTitle(13.5),
          ),
          const SizedBox(height: Spacing.xs),
          const _PermissionStepRow(
            number: '1',
            text: 'Ketuk tombol "Buka Pengaturan" di bawah.',
          ),
          const _PermissionStepRow(
            number: '2',
            text:
                'Cari aplikasi CatatIM, lalu nyalakan saklar akses notifikasinya.',
          ),
          _PermissionStepRow(
            number: '3',
            text: hasBank
                ? 'Kembali ke sini, $targetName langsung tersambung otomatis.'
                : 'Kembali ke sini, capture langsung siap digunakan.',
          ),
          const SizedBox(height: Spacing.m),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: QuestButton(
                  label: widget.cancelLabel,
                  tone: QuestTone.secondary,
                  onPressed:
                      widget.onCancel ?? () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: Spacing.s),
              Expanded(
                flex: 3,
                child: QuestButton(
                  label: _returnedWithoutPermission
                      ? 'Buka Pengaturan Lagi'
                      : 'Buka Pengaturan',
                  icon: Icons.settings_rounded,
                  onPressed: _openSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivacyFactRow extends StatelessWidget {
  const _PrivacyFactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: q.primaryText),
          const SizedBox(width: Spacing.s),
          Expanded(
            child: Text(
              text,
              style: context.qSmall().copyWith(color: q.body, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionStepRow extends StatelessWidget {
  const _PermissionStepRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: q.primaryLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                color: q.primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: Spacing.s),
          Expanded(child: Text(text, style: context.qBody(13))),
        ],
      ),
    );
  }
}
