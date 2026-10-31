import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/ocr.dart';
import '../capture/pipeline.dart';
import '../core/money.dart';
import '../models.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Layar pratinjau dan koreksi hasil pembacaan OCR struk / nota / bukti transfer.
class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key, required this.pipeline, this.initialImagePath});

  final CapturePipeline pipeline;
  final String? initialImagePath;

  /// Buka alur OCR dengan memilih sumber gambar (kamera / galeri) atau path yang sudah ada.
  static Future<void> start(
    BuildContext context, {
    required CapturePipeline pipeline,
    String? imagePath,
    ImageSource? pickSource,
  }) async {
    String? path = imagePath;
    if (path == null && pickSource != null) {
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: pickSource,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 90,
        );
        if (picked == null) return;
        path = picked.path;
      } catch (e) {
        if (!context.mounted) return;
        questSnack(
          context,
          'Tidak dapat membuka kamera/galeri: $e',
          icon: Icons.error_outline_rounded,
        );
        return;
      }
    }
    if (path == null) return;
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OcrScreen(pipeline: pipeline, initialImagePath: path),
      ),
    );
  }

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  bool _loading = true;
  String? _imagePath;
  final _merchantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _rawTextCtrl = TextEditingController();
  Direction _direction = Direction.outgoing;
  bool _showRawText = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.initialImagePath;
    if (_imagePath != null) {
      _processImage(_imagePath!);
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _rawTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _processImage(String path) async {
    setState(() {
      _loading = true;
      _imagePath = path;
    });

    final ocr = const OcrService();
    final data = await ocr.processImage(path, engine: widget.pipeline.engine);

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (data != null) {
        _merchantCtrl.text = data.merchant;
        _amountCtrl.text = (data.amount != null && data.amount! > 0)
            ? data.amount.toString()
            : '';
        _rawTextCtrl.text = data.rawText;
        _direction = data.direction;
      } else {
        _merchantCtrl.text = 'Struk / Bukti';
        _amountCtrl.text = '';
        _rawTextCtrl.text = '';
      }
    });
  }

  Future<void> _saveAsDraft() async {
    final amount = Money.tryParseGroup(_amountCtrl.text.trim()) ?? 0;
    final merchant = _merchantCtrl.text.trim().isEmpty
        ? 'Struk / Bukti'
        : _merchantCtrl.text.trim();
    final body = _rawTextCtrl.text.trim().isEmpty
        ? merchant
        : _rawTextCtrl.text.trim();

    await widget.pipeline.submitManualDraft(
      title: merchant,
      body: body,
      amount: amount,
      direction: _direction,
      bankId: 'paste',
      bankName: merchant,
    );
    if (mounted) {
      Navigator.pop(context);
      questSnack(
        context,
        'Draf transaksi struk berhasil disimpan — periksa di Notifikasi!',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    return Scaffold(
      backgroundColor: q.bg,
      appBar: const QuestHeader(
        title: 'Pindai Struk / Bukti',
        subtitle: 'On-device OCR · 100% Offline',
        showBack: true,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: Spacing.m),
                  Text(
                    'Mengenali teks dari struk di perangkat...',
                    style: context.qBody(13).copyWith(color: q.muted),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(Spacing.m),
              children: [
                if (_imagePath != null && File(_imagePath!).existsSync()) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: q.surface2,
                        border: Border.all(color: q.line),
                      ),
                      child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: Spacing.m),
                ],

                QuestCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Hasil Pembacaan Cerdas', style: context.qTitle(15)),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'Koreksi bila ada angka atau nama yang keliru dibaca kamera.',
                        style: context.qSmall(12).copyWith(color: q.muted),
                      ),
                      const SizedBox(height: Spacing.m),

                      // Nama Toko / Merchant
                      TextField(
                        controller: _merchantCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nama Toko / Pihak',
                          prefixIcon: Icon(Icons.storefront_rounded),
                        ),
                      ),
                      const SizedBox(height: Spacing.m),

                      // Nominal
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total Nominal (Rupiah)',
                          hintText: 'Misal: 54000',
                          prefixIcon: Icon(Icons.payments_rounded),
                        ),
                      ),
                      const SizedBox(height: Spacing.m),

                      // Arah
                      Row(
                        children: [
                          Expanded(
                            child: QuestButton(
                              label: 'Pengeluaran',
                              icon: Icons.arrow_upward_rounded,
                              tone: _direction == Direction.outgoing
                                  ? QuestTone.danger
                                  : QuestTone.secondary,
                              onPressed: () => setState(
                                () => _direction = Direction.outgoing,
                              ),
                            ),
                          ),
                          const SizedBox(width: Spacing.s),
                          Expanded(
                            child: QuestButton(
                              label: 'Pemasukan',
                              icon: Icons.arrow_downward_rounded,
                              tone: _direction == Direction.incoming
                                  ? QuestTone.primary
                                  : QuestTone.secondary,
                              onPressed: () => setState(
                                () => _direction = Direction.incoming,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.m),

                // Collapsible raw OCR text
                QuestCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: () =>
                            setState(() => _showRawText = !_showRawText),
                        child: Row(
                          children: [
                            Icon(
                              _showRawText
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: q.muted,
                            ),
                            const SizedBox(width: Spacing.xs),
                            Expanded(
                              child: Text(
                                'Teks Mentah Hasil OCR',
                                style: context.qTitle(13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showRawText) ...[
                        const SizedBox(height: Spacing.s),
                        TextField(
                          controller: _rawTextCtrl,
                          maxLines: 8,
                          style: context.qBody(12),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.all(Spacing.s),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.l),

                QuestButton(
                  label: 'Simpan sebagai Draf',
                  icon: Icons.check_rounded,
                  onPressed: _saveAsDraft,
                ),
              ],
            ),
    );
  }
}
