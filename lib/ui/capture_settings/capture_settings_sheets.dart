import 'package:flutter/material.dart';

import '../../capture/pipeline.dart';
import '../../core/dates_id.dart';
import '../../rules/rule_set.dart';
import '../../storage/database.dart';
import '../../storage/repository.dart';
import '../../theme/quest.dart';
import '../../theme/tokens.dart';
import '../capture_simulator_sheet.dart';
import '../quest.dart';
import '../transaction_sheet.dart';
import '../unparsed_logs_sheet.dart';

/// Sheet detail izin notifikasi, optimasi baterai, Lampu Sehat, & panduan vendor.
Future<void> showSystemHealthSheet(
  BuildContext context, {
  required bool listenerEnabled,
  required DateTime? lastHeartbeat,
  required Set<String> connected,
  required Stream<CaptureLog?> latestCaptureLogStream,
  required VoidCallback onOpenListenerSettings,
  required VoidCallback onOpenBatterySettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final q = ctx.q;
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: q.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            const QuestGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.m,
                0,
                Spacing.m,
                Spacing.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kesehatan & Izin Sistem',
                      style: ctx.qTitle(16),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  Spacing.m,
                  0,
                  Spacing.m,
                  Spacing.xl,
                ),
                children: [
                  _LampuSehatDetailCard(
                    listenerEnabled: listenerEnabled,
                    lastHeartbeat: lastHeartbeat,
                    connected: connected,
                    latestCaptureLogStream: latestCaptureLogStream,
                  ),
                  const SizedBox(height: Spacing.m),
                  QuestCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        QuestListTile(
                          leading: Icon(
                            listenerEnabled
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
                            color: listenerEnabled ? q.good : q.bad,
                          ),
                          title: Text(
                            listenerEnabled
                                ? 'Akses Notifikasi Aktif'
                                : 'Akses Notifikasi Belum Aktif',
                            style: ctx.qTitle(14.5),
                          ),
                          subtitle: Text(
                            listenerEnabled
                                ? 'Ketuk untuk cek di Pengaturan Android'
                                : 'Wajib aktif agar CatatIM bisa baca notifikasi bank',
                            style: ctx.qSmall(11.5).copyWith(color: q.muted),
                          ),
                          trailing: const Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                          ),
                          onTap: onOpenListenerSettings,
                        ),
                        Divider(height: 1, thickness: 1, color: q.line),
                        QuestListTile(
                          leading: Icon(
                            Icons.battery_saver_rounded,
                            color: q.text,
                          ),
                          title: Text(
                            'Optimasi Baterai HP',
                            style: ctx.qTitle(14.5),
                          ),
                          subtitle: Text(
                            'Setel ke "Tidak Dibatasi" agar layanan tidak dimatikan',
                            style: ctx.qSmall(11.5).copyWith(color: q.muted),
                          ),
                          trailing: const Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                          ),
                          onTap: onOpenBatterySettings,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.m),
                  const _VendorGuideCard(),
                ],
              ),
            ),
          ],
          ),
        ),
      );
    },
  );
}

class _LampuSehatDetailCard extends StatelessWidget {
  const _LampuSehatDetailCard({
    required this.listenerEnabled,
    required this.lastHeartbeat,
    required this.connected,
    required this.latestCaptureLogStream,
  });

  final bool listenerEnabled;
  final DateTime? lastHeartbeat;
  final Set<String> connected;
  final Stream<CaptureLog?> latestCaptureLogStream;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return StreamBuilder<CaptureLog?>(
      stream: latestCaptureLogStream,
      builder: (context, snapshot) {
        final latestLog = snapshot.data;
        final now = DateTime.now();
        final hasConnected = connected.isNotEmpty;
        final daysSinceCapture = latestLog != null
            ? now.difference(latestLog.postedAt).inDays
            : null;
        final isStale =
            hasConnected &&
            ((daysSinceCapture != null && daysSinceCapture >= 7) ||
                (latestLog == null &&
                    lastHeartbeat != null &&
                    now.difference(lastHeartbeat!).inDays >= 7));

        final Color statusColor;
        final String statusTitle;
        final String statusDesc;
        final IconData statusIcon;

        if (!listenerEnabled) {
          statusColor = q.bad;
          statusTitle = 'Tidak aktif';
          statusDesc = 'Akses notifikasi belum diaktifkan di Android.';
          statusIcon = Icons.error_outline_rounded;
        } else if (isStale) {
          statusColor = q.warn;
          statusTitle = 'Perlu diperiksa';
          statusDesc =
              'Belum ada notifikasi masuk selama ${daysSinceCapture ?? '>7'} hari. Layanan mungkin dimatikan oleh penghemat baterai.';
          statusIcon = Icons.warning_amber_rounded;
        } else if (lastHeartbeat == null && latestLog == null) {
          statusColor = q.primary;
          statusTitle = 'Menunggu';
          statusDesc = 'Aktif. Menunggu notifikasi transaksi pertama.';
          statusIcon = Icons.hourglass_empty_rounded;
        } else {
          statusColor = q.good;
          statusTitle = 'Berjalan normal';
          statusDesc = 'Notifikasi bank terbaca normal.';
          statusIcon = Icons.check_circle_outline_rounded;
        }

        return QuestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 19),
                  ),
                  const SizedBox(width: Spacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: context
                              .qTitle(14.5)
                              .copyWith(color: statusColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusDesc,
                          style: context.qSmall().copyWith(color: q.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.m),
              _metricRow(
                q,
                'Aktivitas terakhir',
                lastHeartbeat != null
                    ? idTimeAgo(lastHeartbeat!, now)
                    : 'Belum tercatat',
              ),
              Divider(height: Spacing.m, color: q.line.withValues(alpha: 0.4)),
              _metricRow(
                q,
                'Notifikasi terakhir',
                latestLog != null
                    ? '${latestLog.packageName.split('.').last} • ${idTimeAgo(latestLog.postedAt, now)}'
                    : 'Belum ada',
              ),
              Divider(height: Spacing.m, color: q.line.withValues(alpha: 0.4)),
              _metricRow(
                q,
                'Bank terhubung',
                hasConnected
                    ? '${connected.length} bank aktif'
                    : 'Belum ada bank terhubung',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricRow(QuestPalette q, String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: q.muted,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: q.text,
          ),
        ),
      ],
    );
  }
}

class _VendorGuideCard extends StatelessWidget {
  const _VendorGuideCard();

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const PageStorageKey('vendor_guide_expansion_tile'),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: q.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.phone_android_rounded,
              color: q.primary,
              size: 18,
            ),
          ),
          title: Text('Panduan Khusus per Merk HP', style: context.qTitle(14)),
          subtitle: Text(
            'Xiaomi, Samsung, OPPO, Realme, & Vivo',
            style: context.qSmall(11.5).copyWith(color: q.muted),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            Spacing.m,
            0,
            Spacing.m,
            Spacing.m,
          ),
          children: [
            Divider(height: 1, thickness: 1, color: q.line),
            const SizedBox(height: Spacing.s),
            _vendorItem(
              context,
              q,
              brand: 'Xiaomi / POCO / Redmi (MIUI / HyperOS)',
              steps: const [
                'Buka Info Aplikasi CatatIM → aktifkan "Mulai Otomatis" (Autostart).',
                'Di Penghemat Baterai → pilih "Tidak Ada Pembatasan".',
                'Buka Recent Apps → tekan & tahan kartu CatatIM → tap ikon "Gembok".',
              ],
            ),
            const SizedBox(height: Spacing.m),
            _vendorItem(
              context,
              q,
              brand: 'Samsung (One UI)',
              steps: const [
                'Buka Pengaturan HP → Aplikasi → CatatIM → Baterai.',
                'Pilih opsi "Tidak Dibatasi" (Unrestricted).',
                'Pastikan CatatIM tidak ada di daftar "Sleeping Apps".',
              ],
            ),
            const SizedBox(height: Spacing.m),
            _vendorItem(
              context,
              q,
              brand: 'OPPO & Realme (ColorOS / Realme UI)',
              steps: const [
                'Info Aplikasi CatatIM → Penggunaan Baterai → izinkan "Aktivitas di Latar Belakang" & "Mulai Otomatis".',
                'Buka Recent Apps → tap titik tiga di kartu CatatIM → pilih "Kunci" (Lock).',
              ],
            ),
            const SizedBox(height: Spacing.m),
            _vendorItem(
              context,
              q,
              brand: 'Vivo & iQOO (Funtouch OS / OriginOS)',
              steps: const [
                'Pengaturan HP → Baterai → Konsumsi Daya Latar Belakang Tinggi → izinkan CatatIM.',
                'Di Pengaturan Aplikasi / Izin → aktifkan "Mulai Otomatis".',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vendorItem(
    BuildContext context,
    QuestPalette q, {
    required String brand,
    required List<String> steps,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          brand,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: q.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: q.muted,
                  ),
                ),
                Expanded(
                  child: Text(
                    steps[i],
                    style: context.qSmall(11.5).copyWith(height: 1.3),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Sheet alat diagnostik, pemulihan, simulator, & duplikat yang diabaikan.
Future<void> showDiagnosticsSheet(
  BuildContext context, {
  required LedgerRepository repository,
  required CapturePipeline pipeline,
  required RuleSet ruleSet,
  required Set<String> connected,
  required Stream<List<CaptureLog>> ignoredDuplicatesStream,
  required Future<void> Function(Set<String> connectedBanks) onReparseLogs,
  required Future<void> Function() onPullActiveNotifications,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final q = ctx.q;
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: q.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            const QuestGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.m,
                0,
                Spacing.m,
                Spacing.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Alat Diagnostik & Pemulihan',
                      style: ctx.qTitle(16),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  Spacing.m,
                  0,
                  Spacing.m,
                  Spacing.xl,
                ),
                children: [
                  QuestCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        QuestListTile(
                          leading: Icon(
                            Icons.refresh_rounded,
                            color: q.primary,
                          ),
                          title: Text(
                            'Pindai Ulang Notifikasi Lampau',
                            style: ctx.qTitle(14.5),
                          ),
                          subtitle: Text(
                            'Coba proses ulang notifikasi yang belum terbaca',
                            style: ctx.qSmall(11.5),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            onReparseLogs(connected);
                          },
                        ),
                        Divider(height: 1, thickness: 1, color: q.line),
                        QuestListTile(
                          leading: Icon(
                            Icons.download_rounded,
                            color: q.primary,
                          ),
                          title: Text(
                            'Tarik Notifikasi yang Masih Tayang',
                            style: ctx.qTitle(14.5),
                          ),
                          subtitle: Text(
                            'Tarik notifikasi bank di bar status saat ini',
                            style: ctx.qSmall(11.5),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            onPullActiveNotifications();
                          },
                        ),
                        Divider(height: 1, thickness: 1, color: q.line),
                        QuestListTile(
                          leading: Icon(
                            Icons.mark_email_unread_rounded,
                            color: q.text,
                          ),
                          title: Text(
                            'Log Notifikasi Belum Terbaca',
                            style: ctx.qTitle(14.5),
                          ),
                          subtitle: Text(
                            'Lihat notifikasi mentah yang gagal terbaca',
                            style: ctx.qSmall(11.5),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            UnparsedLogsSheet.show(
                              context,
                              repository: repository,
                              pipeline: pipeline,
                              ruleSet: ruleSet,
                            );
                          },
                        ),
                        Divider(height: 1, thickness: 1, color: q.line),
                        QuestListTile(
                          leading: Icon(Icons.science_rounded, color: q.accent),
                          title: Text(
                            'Simulator & Validasi Notifikasi',
                            style: ctx.qTitle(14.5),
                          ),
                          subtitle: Text(
                            'Uji coba parsing format notifikasi tanpa transaksi nyata',
                            style: ctx.qSmall(11.5),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            CaptureSimulatorSheet.show(
                              context,
                              repository: repository,
                              pipeline: pipeline,
                              ruleSet: ruleSet,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<List<CaptureLog>>(
                    stream: ignoredDuplicatesStream,
                    builder: (context, dupSnap) {
                      final dups = dupSnap.data ?? const <CaptureLog>[];
                      if (dups.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: Spacing.m),
                          const QuestSectionHeader(
                            title: 'Duplikat yang Diabaikan',
                          ),
                          Text(
                            'Geser ke kiri untuk hapus dari daftar abaikan.',
                            style: context.qSmall().copyWith(color: q.muted),
                          ),
                          const SizedBox(height: Spacing.xs),
                          QuestCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (var i = 0; i < dups.length; i++) ...[
                                  Dismissible(
                                    key: ValueKey('ignored-dup-${dups[i].id}'),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) =>
                                        repository.deleteCaptureLog(dups[i].id),
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(
                                        right: Spacing.m,
                                      ),
                                      decoration: BoxDecoration(
                                        color: q.bad.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.card,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: q.bad,
                                      ),
                                    ),
                                    child: QuestListTile(
                                      leading: Icon(
                                        Icons.copy_rounded,
                                        color: q.muted,
                                        size: 19,
                                      ),
                                      title: Text(
                                        dups[i].body,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.qTitle(14),
                                      ),
                                      subtitle: Text(
                                        '${idDateTime(dups[i].postedAt)} · ${dups[i].packageName}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: q.muted,
                                        ),
                                      ),
                                      onTap: () => TransactionSheet.show(
                                        context,
                                        repository,
                                      ),
                                    ),
                                  ),
                                  if (i < dups.length - 1)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: q.line,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      );
    },
  );
}

/// Sheet pilih app terpasang untuk Mode Belajar.
class AppPickerSheet extends StatefulWidget {
  const AppPickerSheet({
    super.key,
    required this.apps,
    required this.connected,
  });

  final List<({String package, String label})> apps;
  final List<({String package, String label})> connected;

  @override
  State<AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<AppPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final lower = _query.toLowerCase();
    final filtered = widget.apps
        .where(
          (a) =>
              a.label.toLowerCase().contains(lower) ||
              a.package.toLowerCase().contains(lower),
        )
        .toList();
    final connectedPkgs = widget.connected.map((c) => c.package).toSet();
    final bottomInset = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset.bottom),
      child: Container(
        height: (MediaQuery.sizeOf(context).height * 0.75 - bottomInset.bottom)
            .clamp(180.0, double.infinity),
        decoration: BoxDecoration(
          color: q.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          bottom: bottomInset.bottom == 0,
          child: Column(
            children: [
            const QuestGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.m,
                0,
                Spacing.m,
                Spacing.s,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hubungkan App', style: context.qTitle(15)),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Pilih app bank/e-wallet. Notifikasinya bakal jadi draf '
                    'yang kamu putuskan.',
                    style: context.qSmall().copyWith(color: q.muted),
                  ),
                  const SizedBox(height: Spacing.s),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama app…',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada app yang cocok.',
                        style: context.qSmall().copyWith(color: q.muted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final app = filtered[i];
                        final isOn = connectedPkgs.contains(app.package);
                        return QuestListTile(
                          onTap: () => Navigator.pop(context, app),
                          leading: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isOn ? q.incomingTint : q.surface2,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              app.label.characters.first.toUpperCase(),
                              style: TextStyle(
                                color: isOn ? q.good : q.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(app.label, style: context.qTitle(13.5)),
                          subtitle: Text(
                            app.package,
                            style: context.qSmall(10).copyWith(color: q.muted),
                          ),
                          trailing: isOn
                              ? Icon(
                                  Icons.link_rounded,
                                  size: 18,
                                  color: q.good,
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 22,
                                ),
                        );
                      },
                    ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
