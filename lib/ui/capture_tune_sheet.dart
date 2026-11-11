import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import 'transaction_sheet.dart';

/// Sheet interaktif untuk memeriksa notifikasi mentah dan membuat template
/// aturan (tuning capture) tanpa coding.
class CaptureTuneSheet extends StatefulWidget {
  const CaptureTuneSheet({
    super.key,
    required this.log,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
    this.initialTemplate,
  });

  final CaptureLog log;
  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;
  final CustomTemplate? initialTemplate;

  static Future<bool?> show(
    BuildContext context, {
    required CaptureLog log,
    required LedgerRepository repository,
    required CapturePipeline pipeline,
    required RuleSet ruleSet,
    CustomTemplate? initialTemplate,
  }) {
    return showQuestSheet<bool>(
      context,
      (ctx) => CaptureTuneSheet(
        log: log,
        repository: repository,
        pipeline: pipeline,
        ruleSet: ruleSet,
        initialTemplate: initialTemplate,
      ),
    );
  }

  @override
  State<CaptureTuneSheet> createState() => _CaptureTuneSheetState();
}

class _CaptureTuneSheetState extends State<CaptureTuneSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _customKeywordController;

  late String _selectedBankId;
  late Direction _direction;
  late TxKind _kind;
  final Set<String> _selectedKeywords = <String>{};
  late final List<String> _availableTokens;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    final text = '${log.title} ${log.body}'.trim();

    // Inisialisasi token kata dari teks notifikasi
    _availableTokens = _extractTokens(text);

    final initial = widget.initialTemplate;
    if (initial != null) {
      _nameController = TextEditingController(text: initial.template.name);
      _selectedBankId = initial.bankId;
      _direction = initial.template.direction;
      _kind = initial.template.kind;
      _selectedKeywords.addAll(initial.template.matchAll);
      _selectedKeywords.addAll(initial.template.matchAny);
    } else {
      // Auto deteksi bank awal
      final detected = widget.pipeline.engine.bankFor(
        packageName: log.packageName,
        lowerText: text.toLowerCase(),
      );
      _selectedBankId =
          detected?.id ??
          (log.packageName.isNotEmpty ? 'app:${log.packageName}' : 'unknown');

      // Tebak arah & jenis awal dari teks
      final lower = text.toLowerCase();
      if (lower.contains('kredit') ||
          lower.contains('masuk') ||
          lower.contains('menerima') ||
          lower.contains('penambahan')) {
        _direction = Direction.incoming;
        _kind = TxKind.transfer;
      } else {
        _direction = Direction.outgoing;
        _kind = lower.contains('qris') || lower.contains('bayar')
            ? TxKind.payment
            : (lower.contains('top') ? TxKind.topup : TxKind.transfer);
      }

      final bankName =
          widget.ruleSet.bank(_selectedBankId)?.displayName ?? 'Transaksi';
      _nameController = TextEditingController(
        text:
            'Aturan $bankName (${_direction == Direction.incoming ? 'Masuk' : 'Keluar'})',
      );

      // Auto-pilih token yang paling deskriptif
      for (final t in _availableTokens) {
        if ([
          'debit',
          'kredit',
          'transfer',
          'qris',
          'pembayaran',
          'berhasil',
          'masuk',
          'keluar',
        ].contains(t.toLowerCase())) {
          _selectedKeywords.add(t.toLowerCase());
        }
      }
    }

    _customKeywordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customKeywordController.dispose();
    super.dispose();
  }

  List<String> _extractTokens(String text) {
    final rawTokens = text.split(RegExp(r'[\s,.:;()\/]+'));
    final seen = <String>{};
    final result = <String>[];
    for (final raw in rawTokens) {
      final clean = raw.trim().toLowerCase();
      // Lewati angka murni, tanda baca, atau kata terlalu pendek
      if (clean.length < 2) continue;
      if (RegExp(r'^\d+$').hasMatch(clean)) continue;
      if (clean.startsWith('rp')) continue;
      if (seen.add(clean)) {
        result.add(clean);
      }
    }
    return result;
  }

  void _copyRawText() {
    final text =
        'Paket: ${widget.log.packageName}\n'
        'Judul: ${widget.log.title}\n'
        'Isi: ${widget.log.body}\n'
        'Waktu: ${widget.log.postedAt.toIso8601String()}';
    Clipboard.setData(ClipboardData(text: text));
    questSnack(
      context,
      'Teks mentah disalin ke clipboard',
      icon: Icons.copy_rounded,
    );
  }

  int? _previewAmount() {
    final text = '${widget.log.title} ${widget.log.body}';
    final reg = RegExp(r'[Rr][Pp]\.?\s*([\d][\d.,]*)');
    final match = reg.firstMatch(text);
    if (match != null) {
      return Money.tryParseGroup(match.group(1));
    }
    final numReg = RegExp(r'(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?)');
    final numMatch = numReg.firstMatch(text);
    if (numMatch != null) {
      return Money.tryParseGroup(numMatch.group(1));
    }
    return null;
  }

  Future<void> _saveTemplate() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final rule = TemplateRule(
        name: _nameController.text.trim().isEmpty
            ? 'Aturan Kustom'
            : _nameController.text.trim(),
        kind: _kind,
        direction: _direction,
        matchAll: _selectedKeywords.toList(),
      );

      final customTemplate = CustomTemplate(
        id:
            widget.initialTemplate?.id ??
            'cust_${DateTime.now().millisecondsSinceEpoch}',
        bankId: _selectedBankId,
        template: rule,
        createdAt: DateTime.now(),
      );

      final created = await widget.pipeline.applyCustomTemplate(
        customTemplate,
        targetLog: widget.log,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      questSnack(
        context,
        'Template disimpan! $created draf berhasil diproses.',
        icon: Icons.check_circle_rounded,
      );
    } catch (e) {
      if (mounted) {
        questSnack(
          context,
          'Gagal menyimpan template: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _recordManual() {
    Navigator.pop(context, false);
    TransactionSheet.show(context, widget.repository);
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final log = widget.log;
    final previewAmount = _previewAmount();
    final bool matchesKeywords =
        _selectedKeywords.isEmpty ||
        _selectedKeywords.every(
          (k) => '${log.title} ${log.body}'.toLowerCase().contains(k),
        );

    // Kumpulan opsi bank: katalog + custom
    final bankOptions = <({String id, String label})>[
      for (final b in widget.ruleSet.banks)
        if (b.id != 'unknown') (id: b.id, label: b.displayName),
      (id: 'unknown', label: 'Umum / Lainnya'),
    ];

    if (!bankOptions.any((b) => b.id == _selectedBankId)) {
      bankOptions.insert(0, (
        id: _selectedBankId,
        label: _selectedBankId.replaceFirst('app:', ''),
      ));
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            Spacing.l,
            Spacing.xs,
            Spacing.l,
            Spacing.xl,
          ),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialTemplate != null
                            ? 'Edit Template Aturan'
                            : 'Detail Notifikasi & Buat Aturan',
                        style: context.qTitle(18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sesuaikan kata kunci agar notifikasi berikutnya terbaca otomatis.',
                        style: context.qSmall(12).copyWith(color: q.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: Spacing.m),

            // ── Kartu Notifikasi Asli ──
            Container(
              padding: const EdgeInsets.all(Spacing.m),
              decoration: BoxDecoration(
                color: q.surface2,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: q.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.mark_email_unread_rounded,
                        size: 16,
                        color: q.primary,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Expanded(
                        child: Text(
                          log.packageName.isEmpty
                              ? 'Sumber: Eksternal / Tempelan'
                              : log.packageName,
                          style: context
                              .qSmall(11.5)
                              .copyWith(
                                color: q.muted,
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        idDateTime(log.postedAt),
                        style: context.qSmall(11).copyWith(color: q.muted),
                      ),
                    ],
                  ),
                  if (log.title.isNotEmpty) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      log.title,
                      style: context
                          .qTitle(14)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                  const SizedBox(height: Spacing.xs),
                  SelectableText(
                    log.body,
                    style: context.qBody(13).copyWith(color: q.text),
                  ),
                  const SizedBox(height: Spacing.s),
                  Align(
                    alignment: Alignment.centerRight,
                    child: QuestButton(
                      label: 'Salin Teks Mentah',
                      icon: Icons.copy_rounded,
                      tone: QuestTone.secondary,
                      onPressed: _copyRawText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.l),

            // ── Form Pembuat Aturan ──
            Text(
              'PENGATURAN TEMPLATE',
              style: context
                  .qSmall(11.5)
                  .copyWith(color: q.muted, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: Spacing.s),

            // Nama Aturan
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nama Template Aturan',
                hintText: 'Contoh: Ollin Debit Belanja',
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.m,
                  vertical: Spacing.s,
                ),
              ),
            ),
            const SizedBox(height: Spacing.m),

            // Pilihan Bank
            DropdownButtonFormField<String>(
              initialValue: _selectedBankId,
              decoration: InputDecoration(
                labelText: 'Bank / Akun Terkait',
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.m,
                  vertical: Spacing.s,
                ),
              ),
              items: [
                for (final opt in bankOptions)
                  DropdownMenuItem(value: opt.id, child: Text(opt.label)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedBankId = val);
              },
            ),
            const SizedBox(height: Spacing.m),

            // Arah Transaksi
            Text(
              'Arah Aliran Dana',
              style: context
                  .qSmall(12)
                  .copyWith(color: q.muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.xs),
            QuestSegmented<Direction>(
              selected: _direction,
              options: const [
                (
                  value: Direction.outgoing,
                  label: 'Uang Keluar',
                  icon: Icons.arrow_upward_rounded,
                ),
                (
                  value: Direction.incoming,
                  label: 'Uang Masuk',
                  icon: Icons.arrow_downward_rounded,
                ),
              ],
              onChanged: (val) => setState(() => _direction = val),
            ),
            const SizedBox(height: Spacing.m),

            // Jenis Transaksi
            Text(
              'Jenis Transaksi',
              style: context
                  .qSmall(12)
                  .copyWith(color: q.muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.xs),
            QuestSegmented<TxKind>(
              selected: _kind,
              options: const [
                (value: TxKind.payment, label: 'Belanja', icon: null),
                (value: TxKind.transfer, label: 'Transfer', icon: null),
                (value: TxKind.topup, label: 'Top Up', icon: null),
              ],
              onChanged: (val) => setState(() => _kind = val),
            ),
            const SizedBox(height: Spacing.l),

            // ── Chip Kata Kunci Interaktif ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kata Kunci Wajib (Cocokkan Teks)',
                  style: context
                      .qSmall(12)
                      .copyWith(color: q.muted, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${_selectedKeywords.length} terpilih',
                  style: context
                      .qSmall(11.5)
                      .copyWith(color: q.primaryText, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap kata dari notifikasi di bawah ini untuk dijadikan syarat pencocokan template:',
              style: context.qSmall(11.5).copyWith(color: q.muted),
            ),
            const SizedBox(height: Spacing.s),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final token in _availableTokens) ...[
                  FilterChip(
                    label: Text(token),
                    selected: _selectedKeywords.contains(token),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedKeywords.add(token);
                        } else {
                          _selectedKeywords.remove(token);
                        }
                      });
                    },
                    selectedColor: q.primaryLight,
                    checkmarkColor: q.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedKeywords.contains(token)
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: _selectedKeywords.contains(token)
                          ? q.primary
                          : q.text,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Spacing.s),

            // Tambah Kata Kunci Manual
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customKeywordController,
                    decoration: InputDecoration(
                      hintText: 'Tambah kata kunci manual...',
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Spacing.m,
                        vertical: Spacing.s,
                      ),
                    ),
                    onSubmitted: (val) {
                      final trimmed = val.trim().toLowerCase();
                      if (trimmed.isNotEmpty) {
                        setState(() {
                          _selectedKeywords.add(trimmed);
                          _customKeywordController.clear();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Tambah Kata Kunci',
                  onPressed: () {
                    final trimmed = _customKeywordController.text
                        .trim()
                        .toLowerCase();
                    if (trimmed.isNotEmpty) {
                      setState(() {
                        _selectedKeywords.add(trimmed);
                        _customKeywordController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: Spacing.l),

            // ── Live Preview Card ──
            Container(
              padding: const EdgeInsets.all(Spacing.m),
              decoration: BoxDecoration(
                color: matchesKeywords
                    ? q.good.withValues(alpha: 0.08)
                    : q.bad.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: matchesKeywords
                      ? q.good.withValues(alpha: 0.4)
                      : q.bad.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        matchesKeywords
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        color: matchesKeywords ? q.good : q.bad,
                        size: 18,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        matchesKeywords
                            ? 'Hasil Preview: Cocok!'
                            : 'Hasil Preview: Belum Cocok',
                        style: context
                            .qTitle(13.5)
                            .copyWith(
                              color: matchesKeywords ? q.good : q.bad,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nominal Tertangkap:',
                        style: context.qSmall(12).copyWith(color: q.muted),
                      ),
                      Text(
                        previewAmount != null
                            ? Money.format(previewAmount)
                            : 'Tidak terdeteksi',
                        style: context
                            .qTitle(14)
                            .copyWith(
                              fontWeight: FontWeight.w800,
                              color: previewAmount != null ? q.text : q.bad,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Arah & Jenis:',
                        style: context.qSmall(12).copyWith(color: q.muted),
                      ),
                      Text(
                        '${_direction == Direction.incoming ? 'Masuk' : 'Keluar'} · ${_kind.name}',
                        style: context
                            .qSmall(12)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xl),

            // ── Tombol Tindakan ──
            QuestButton(
              label: _isSaving
                  ? 'Menyimpan & Memproses...'
                  : 'Simpan Template & Buat Draf',
              icon: Icons.auto_awesome_rounded,
              tone: QuestTone.primary,
              onPressed: (_isSaving || _selectedKeywords.isEmpty)
                  ? null
                  : _saveTemplate,
            ),
            const SizedBox(height: Spacing.s),
            QuestButton(
              label: 'Catat Manual Saja Tanpa Simpan Template',
              icon: Icons.edit_note_rounded,
              tone: QuestTone.secondary,
              onPressed: _recordManual,
            ),
          ],
        );
      },
    );
  }
}
