import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/pipeline.dart';
import '../core/budget.dart';
import '../game/progress.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'bank_accounts_screen.dart';
import 'bon_screen.dart';
import 'draft_inbox_sheet.dart';
import 'ocr_screen.dart';
import 'quest.dart';
import 'unparsed_logs_sheet.dart';

/// Satu item perhatian di layar Notifikasi.
class _NotifItem {
  const _NotifItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// Layar Notifikasi: Pusat Peringatan & Perhatian Sistem
///
/// Murni untuk hal-hal yang membutuhkan atensi pengguna:
/// - Peringatan plafon anggaran (over/warning)
/// - Pengingat bon/hutang piutang yang menua
/// - Status izin listener notifikasi HP
/// - Format notifikasi belum dikenali (mode belajar)
/// - Jembatan cepat ke Kotak Masuk Draf bila ada draf menunggu
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    this.progress,
    this.onOpenAnggaran,
    this.onOpenBon,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService? progress;
  final RuleSet ruleSet;

  /// Tutup layar ini lalu alih ke tab Rencana / Bon.
  final VoidCallback? onOpenAnggaran;
  final VoidCallback? onOpenBon;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final Future<bool> _listenerEnabled =
      widget.pipeline.channel.isListenerEnabled();

  LedgerRepository get _repo => widget.repository;

  void _openBankAccounts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BankAccountsScreen(
          repository: _repo,
          pipeline: widget.pipeline,
          ruleSet: widget.ruleSet,
        ),
      ),
    );
  }

  void _goTo(VoidCallback? navigate) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    navigate?.call();
  }

  Future<void> _handleUnread(int count, Set<String> connected) async {
    await UnparsedLogsSheet.show(
      context,
      repository: _repo,
      pipeline: widget.pipeline,
      ruleSet: widget.ruleSet,
    );
  }

  Future<void> _showPasteDialog() async {
    final controller = TextEditingController();
    final text = await showQuestDialog<String>(
      context,
      title: 'Tempel Teks',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tempel pesan notifikasi, SMS, atau email transaksi di sini. '
            'Bukuduit akan membacanya menjadi draf di Kotak Masuk.',
            style: context.qBody(13),
          ),
          const SizedBox(height: Spacing.m),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Contoh:\nTransfer masuk Rp150.000 dari BUDI...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(Spacing.s),
            ),
          ),
        ],
      ),
      actions: [
        QuestButton(
          label: 'Batal',
          tone: QuestTone.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        QuestButton(
          label: 'Proses',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context, controller.text),
        ),
      ],
    );

    if (text == null || text.trim().isEmpty || !mounted) return;
    final ok = await widget.pipeline.submitPastedText(text);
    if (!mounted) return;
    questSnack(
      context,
      ok ? 'Teks berhasil diproses ke Kotak Masuk Draf!' : 'Gagal memproses teks.',
      icon: ok
          ? Icons.check_circle_outline_rounded
          : Icons.error_outline_rounded,
    );
  }

  Future<void> _showOcrOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(Spacing.m),
        decoration: BoxDecoration(
          color: context.q.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const QuestGrabber(),
              const SizedBox(height: Spacing.s),
              Text('Pindai Struk / Bukti Transaksi', style: context.qTitle(16)),
              const SizedBox(height: Spacing.xs),
              Text(
                'Teks struk akan dipindai secara offline di perangkat.',
                style: context.qSmall(12).copyWith(color: context.q.muted),
              ),
              const SizedBox(height: Spacing.m),
              QuestListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Ambil Foto Kamera'),
                subtitle: const Text('Arahkan kamera ke struk/nota pembayaran'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              QuestListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text(
                  'Gunakan foto struk atau screenshot bukti transfer',
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    await OcrScreen.start(
      context,
      pipeline: widget.pipeline,
      pickSource: source,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Scaffold(
      backgroundColor: q.bg,
      appBar: QuestHeader(
        title: 'Notifikasi',
        subtitle: 'Pusat perhatian & pengingat',
        showBack: true,
        actions: [
          QuestIconButton(
            icon: Icons.document_scanner_rounded,
            tooltip: 'Foto Struk (OCR)',
            onPressed: _showOcrOptions,
          ),
          QuestIconButton(
            icon: Icons.content_paste_rounded,
            tooltip: 'Tempel Teks',
            onPressed: _showPasteDialog,
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _listenerEnabled,
        builder: (context, listenerSnap) {
          final enabled = listenerSnap.data ?? false;
          return StreamBuilder<Set<String>>(
            stream: _repo.watchConnectedBanks(),
            builder: (context, connSnap) {
              final connected = connSnap.data ?? const <String>{};
              return StreamBuilder<List<Draft>>(
                stream: _repo.watchDrafts(),
                builder: (context, draftSnap) {
                  final drafts = draftSnap.data ?? const <Draft>[];
                  return StreamBuilder<List<CaptureLog>>(
                    stream: _repo.watchCaptureLog(),
                    builder: (context, logSnap) {
                      final unread = (logSnap.data ?? const <CaptureLog>[])
                          .where((l) => !l.parsed)
                          .length;
                      return StreamBuilder<List<Bon>>(
                        stream: _repo.watchBons(),
                        builder: (context, bonSnap) {
                          final bons = bonSnap.data ?? const <Bon>[];
                          final aging = bons
                              .where(
                                (b) =>
                                    b.settledAt == null &&
                                    bonNeedsBadge(b.occurredAt),
                              )
                              .length;
                          final summary = widget.progress?.latest;
                          final level = summary?.snapshot.worstLevel;
                          final critical = summary?.snapshot.criticalLine;

                          final items = [
                            if (drafts.isNotEmpty)
                              _NotifItem(
                                icon: Icons.inbox_rounded,
                                color: q.primary,
                                title:
                                    '${drafts.length} draf transaksi menunggu keputusan',
                                subtitle:
                                    'Ketuk untuk membuka kotak masuk transaksi',
                                onTap: () => DraftInboxSheet.show(
                                  context,
                                  repository: _repo,
                                  pipeline: widget.pipeline,
                                  ruleSet: widget.ruleSet,
                                  progress: widget.progress,
                                ),
                              ),
                            if (connected.isNotEmpty && !enabled)
                              _NotifItem(
                                icon: Icons.notifications_off_rounded,
                                color: q.bad,
                                title: 'Izin baca notifikasi belum nyala',
                                subtitle:
                                    'Nyalakan agar draf transaksi otomatis masuk',
                                onTap: _openBankAccounts,
                              ),
                            if (unread > 0)
                              _NotifItem(
                                icon: Icons.help_outline_rounded,
                                color: q.warn,
                                title:
                                    '$unread notifikasi belum dikenali formatnya',
                                subtitle:
                                    'Ketuk untuk melatih pola bank atau catat manual',
                                onTap: () => _handleUnread(unread, connected),
                              ),
                            if (level == BudgetLevel.over)
                              _NotifItem(
                                icon: Icons.warning_amber_rounded,
                                color: q.bad,
                                title:
                                    'Batas ${critical?.label ?? 'harian'} terlampaui',
                                subtitle:
                                    'Yuk cek batas pengeluaranmu di Anggaran',
                                onTap: () => _goTo(widget.onOpenAnggaran),
                              )
                            else if (level == BudgetLevel.warning)
                              _NotifItem(
                                icon: Icons.error_outline_rounded,
                                color: q.warn,
                                title:
                                    'Batas ${critical?.label ?? 'harian'} '
                                    'mendekati plafon',
                                subtitle:
                                    'Yuk cek batas pengeluaranmu di Anggaran',
                                onTap: () => _goTo(widget.onOpenAnggaran),
                              ),
                            if (aging > 0)
                              _NotifItem(
                                icon: Icons.handshake_outlined,
                                color: q.bad,
                                title:
                                    '$aging bon lebih dari 30 hari belum lunas',
                                subtitle: 'Ingatkan dirimu atau tandai lunas',
                                onTap: () => _goTo(widget.onOpenBon),
                              ),
                          ];

                          if (items.isEmpty) {
                            return ListView(
                              padding: const EdgeInsets.all(Spacing.m),
                              children: [
                                QuestEmpty(
                                  title: 'Tidak ada notifikasi',
                                  hint:
                                      'Semua aman — anggaran terkendali dan sistem berjalan baik.',
                                ),
                              ],
                            );
                          }

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(
                              Spacing.m,
                              Spacing.s,
                              Spacing.m,
                              Spacing.m,
                            ),
                            children: [
                              const QuestEnter(
                                index: 0,
                                child: QuestSectionHeader(
                                  title: 'Perlu perhatian',
                                ),
                              ),
                              for (var i = 0; i < items.length; i++)
                                QuestEnter(
                                  index: 1 + i,
                                  child: _AttentionTile(item: items[i]),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.item});

  final _NotifItem item;

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return QuestPress(
      onTap: item.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.s),
        padding: Insets.tile,
        decoration: BoxDecoration(
          color: q.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: q.line.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: q.shadow,
              offset: const Offset(0, 4),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 19, color: item.color),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.qTitle(14)),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: context.qSmall(11.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: q.muted),
          ],
        ),
      ),
    );
  }
}
