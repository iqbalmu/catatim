import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/ocr.dart';
import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../models.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
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
    if (path == null) {
      final ImageSource? source;
      if (pickSource != null) {
        source = pickSource;
      } else {
        source = await showQuestSheet<ImageSource>(
          context,
          (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.m,
              Spacing.s,
              Spacing.m,
              Spacing.m,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pindai Struk / Bukti Transaksi',
                  style: ctx.qTitle(),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Mau pakai gambar dari mana? Nominal & pihaknya diisi otomatis.',
                  style: ctx.qSmall().copyWith(color: ctx.q.muted),
                ),
                const SizedBox(height: Spacing.m),
                QuestCard(
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: ctx.q.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: ctx.q.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: Spacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kamera', style: ctx.qTitle(14)),
                            Text(
                              'Foto langsung struk atau nota fisik',
                              style: ctx.qSmall(11.5).copyWith(color: ctx.q.muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: ctx.q.muted),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.s),
                QuestCard(
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: ctx.q.surface2,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.photo_library_rounded,
                          color: ctx.q.text,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: Spacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Galeri / Screenshot', style: ctx.qTitle(14)),
                            Text(
                              'Pilih gambar bukti transfer atau struk digital',
                              style: ctx.qSmall(11.5).copyWith(color: ctx.q.muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: ctx.q.muted),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      if (source == null) return;

      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: source,
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
          'Nggak bisa buka kamera/galeri: $e',
          icon: Icons.error_outline_rounded,
        );
        return;
      }
    }
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
  DateTime _occurredAt = DateTime.now();
  List<int> _candidateAmounts = const [];

  int? _selectedCategoryId;
  int? _selectedAccountId;

  bool _showRawText = false;
  bool _isSaving = false;

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
    OcrReceiptData? data;
    String? errorReason;
    try {
      data = await ocr.processImage(path, engine: widget.pipeline.engine);
    } catch (e) {
      debugPrint('OCR processImage error: $e');
      errorReason = e.toString();
    }

    if (!mounted) return;

    final categories = await widget.pipeline.repository.getCategories();
    final accounts = await widget.pipeline.repository.getAccounts();

    int? catId;
    if (data?.suggestedCategory != null) {
      final match = categories
          .where(
            (c) =>
                c.name.toLowerCase() == data!.suggestedCategory!.toLowerCase(),
          )
          .firstOrNull;
      catId = match?.id;
    }
    catId ??= categories.firstOrNull?.id;

    int? accId;
    if (data?.suggestedPaymentMethod != null) {
      final match = accounts
          .where(
            (a) => a.name.toLowerCase().contains(
              data!.suggestedPaymentMethod!.toLowerCase(),
            ),
          )
          .firstOrNull;
      accId = match?.id;
    }
    accId ??=
        accounts.where((a) => a.kind == AccountKind.cash).firstOrNull?.id ??
        accounts.firstOrNull?.id;

    setState(() {
      _loading = false;
      if (data != null) {
        _merchantCtrl.text = data.merchant;
        _amountCtrl.text = (data.amount != null && data.amount! > 0)
            ? data.amount.toString()
            : '';
        _rawTextCtrl.text = data.rawText;
        _direction = data.direction;
        _candidateAmounts = data.candidateAmounts;
        _occurredAt = data.occurredAt ?? DateTime.now();
        _selectedCategoryId = catId;
        _selectedAccountId = accId;
      } else {
        _merchantCtrl.text = 'Struk / Bukti';
        _amountCtrl.text = '';
        _rawTextCtrl.text = '';
        _candidateAmounts = const [];
        _selectedCategoryId = catId;
        _selectedAccountId = accId;
      }
    });

    if (errorReason != null && mounted) {
      questSnack(
        context,
        'Yah, gagal baca teks struknya: $errorReason',
        icon: Icons.warning_amber_rounded,
      );
    } else if (data == null && mounted) {
      questSnack(
        context,
        'Nominalnya nggak kebaca. Isi manual aja, atau coba foto ulang.',
        icon: Icons.info_outline_rounded,
      );
    }
  }

  Future<void> _pickNewImage() async {
    final source = await showQuestSheet<ImageSource>(
      context,
      (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.m,
          Spacing.s,
          Spacing.m,
          Spacing.m,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ganti / Foto Ulang Struk', style: ctx.qTitle()),
            const SizedBox(height: Spacing.s),
            QuestCard(
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: ctx.q.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: ctx.q.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: Spacing.m),
                  Expanded(
                    child: Text('Kamera', style: ctx.qTitle(14)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ctx.q.muted),
                ],
              ),
            ),
            const SizedBox(height: Spacing.s),
            QuestCard(
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: ctx.q.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: ctx.q.text,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: Spacing.m),
                  Expanded(
                    child: Text('Galeri', style: ctx.qTitle(14)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ctx.q.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (picked != null) {
        unawaited(_processImage(picked.path));
      }
    } catch (e) {
      if (mounted) {
        questSnack(context, 'Nggak bisa buka kamera/galeri: $e');
      }
    }
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (!mounted) return;

    setState(() {
      _occurredAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? _occurredAt.hour,
        pickedTime?.minute ?? _occurredAt.minute,
      );
    });
  }

  Future<void> _saveAsDraft() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
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
        occurredAt: _occurredAt,
        categoryId: _selectedCategoryId,
        accountId: _selectedAccountId,
      );

      if (mounted) {
        Navigator.pop(context);
        questSnack(
          context,
          'Beres! Draf struk tersimpan. Cek di Notifikasi ya!',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _recordDirectly() async {
    if (_isSaving) return;
    final amount = Money.tryParseGroup(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      questSnack(
        context,
        'Nominal harus lebih dari 0 ya.',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final merchant = _merchantCtrl.text.trim().isEmpty
          ? 'Struk / Belanja'
          : _merchantCtrl.text.trim();

      await widget.pipeline.repository.addManual(
        amount: amount,
        direction: _direction,
        kind: _direction == Direction.incoming
            ? TxKind.transfer
            : TxKind.payment,
        counterparty: merchant,
        categoryId: _selectedCategoryId,
        accountId: _selectedAccountId,
        occurredAt: _occurredAt,
      );

      if (mounted) {
        Navigator.pop(context);
        questSnack(
          context,
          'Transaksi $merchant (${Money.format(amount)}) langsung dicatat!',
          icon: Icons.check_circle_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;
    final currentAmount = Money.tryParseGroup(_amountCtrl.text.trim());

    return Scaffold(
      backgroundColor: q.bg,
      appBar: QuestHeader(
        textScale: MediaQuery.textScalerOf(context).scale(1.0),
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
              padding: const EdgeInsets.fromLTRB(Spacing.m, 0, Spacing.m, Spacing.m),
              children: [
                if (_imagePath != null && File(_imagePath!).existsSync()) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Stack(
                      children: [
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: q.surface2,
                            border: Border.all(color: q.line),
                          ),
                          child: Image.file(
                            File(_imagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: Spacing.s,
                          bottom: Spacing.s,
                          child: QuestButton(
                            label: 'Ganti Foto',
                            icon: Icons.camera_alt_rounded,
                            tone: QuestTone.secondary,
                            expanded: false,
                            onPressed: _pickNewImage,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.m),
                ] else ...[
                  QuestCard(
                    onTap: _pickNewImage,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Spacing.m,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_a_photo_rounded,
                            size: 36,
                            color: q.primary,
                          ),
                          const SizedBox(height: Spacing.s),
                          Text(
                            'Pilih atau Foto Struk',
                            style: context.qTitle(15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ketuk untuk membuka kamera atau galeri',
                            style: context.qSmall().copyWith(color: q.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.m),
                ],

                QuestCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.document_scanner_rounded,
                            color: q.primary,
                            size: 18,
                          ),
                          const SizedBox(width: Spacing.xs),
                          Text(
                            'Hasil Pindai Struk',
                            style: context.qTitle(15),
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'Koreksi bila ada angka atau nama yang keliru dibaca kamera.',
                        style: context.qSmall().copyWith(color: q.muted),
                      ),
                      const SizedBox(height: Spacing.m),

                      const QuestFieldLabel('Nama Toko / Pihak'),
                      const SizedBox(height: Spacing.xs),
                      TextField(
                        controller: _merchantCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Indomaret, Kopi Kenangan...',
                          prefixIcon: Icon(Icons.storefront_rounded),
                        ),
                      ),
                      const SizedBox(height: Spacing.m),

                      const QuestFieldLabel('Tanggal & Waktu Transaksi'),
                      const SizedBox(height: Spacing.xs),
                      Semantics(
                        button: true,
                        label:
                            'Tanggal & waktu transaksi, ${idFullDate(_occurredAt)} ${idDateTime(_occurredAt)}',
                        child: InkWell(
                        onTap: _pickDateTime,
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.m,
                            vertical: Spacing.s + 2,
                          ),
                          decoration: BoxDecoration(
                            color: q.surface,
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                            border: Border.all(color: q.line),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: q.primaryText,
                              ),
                              const SizedBox(width: Spacing.s),
                              Expanded(
                                child: Text(
                                  '${idFullDate(_occurredAt)} · ${idDateTime(_occurredAt).split(' ').last}',
                                  style: context.qTitle(13.5),
                                ),
                              ),
                              Icon(Icons.edit_rounded, size: 16, color: q.muted),
                            ],
                          ),
                        ),
                        ),
                      ),
                      const SizedBox(height: Spacing.m),

                      const QuestFieldLabel('Total Nominal (Rupiah)'),
                      const SizedBox(height: Spacing.xs),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Misal: 54000',
                          prefixIcon: Icon(Icons.payments_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),

                      if (_candidateAmounts.isNotEmpty) ...[
                        const SizedBox(height: Spacing.s),
                        Text(
                          'Angka-angka yang kebaca di struk:',
                          style: context
                              .qSmall(11.5)
                              .copyWith(color: q.muted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final amt in _candidateAmounts.take(6)) ...[
                              FilterChip(
                                label: Text(Money.format(amt)),
                                selected: currentAmount == amt,
                                onSelected: (_) {
                                  setState(() {
                                    _amountCtrl.text = amt.toString();
                                  });
                                },
                                selectedColor: q.primaryLight,
                                checkmarkColor: q.primary,
                                labelStyle: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: currentAmount == amt
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: currentAmount == amt
                                      ? q.primary
                                      : q.text,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: Spacing.m),

                      StreamBuilder<List<Category>>(
                        stream: widget.pipeline.repository.watchCategories(),
                        builder: (context, catSnap) {
                          final categories = catSnap.data ?? const <Category>[];
                          return QuestSelectField<int>(
                            value: _selectedCategoryId,
                            labelText: 'Kategori Pengeluaran',
                            sheetTitle: 'Pilih Kategori Pengeluaran',
                            prefixIcon: const Icon(Icons.category_rounded),
                            options: [
                              for (final c in categories)
                                QuestSelectOption(
                                  value: c.id,
                                  label: c.name,
                                  leading: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: SeedColors.categoryColor(c.colorIndex),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: context.q.line, width: 1.5),
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategoryId = val);
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: Spacing.m),

                      StreamBuilder<List<Account>>(
                        stream: widget.pipeline.repository.watchAccounts(),
                        builder: (context, accSnap) {
                          final accounts = accSnap.data ?? const <Account>[];
                          return QuestSelectField<int>(
                            value: _selectedAccountId,
                            labelText: 'Akun Sumber Pembayaran',
                            sheetTitle: 'Pilih Akun Sumber Pembayaran',
                            prefixIcon: const Icon(
                              Icons.account_balance_wallet_rounded,
                            ),
                            options: [
                              for (final a in accounts)
                                QuestSelectOption(
                                  value: a.id,
                                  label: a.name,
                                  subtitle: switch (a.kind) {
                                    AccountKind.bank => 'Rekening Bank',
                                    AccountKind.ewallet => 'E-Wallet',
                                    AccountKind.cash => 'Dompet Tunai',
                                  },
                                  icon: switch (a.kind) {
                                    AccountKind.bank => Icons.account_balance_rounded,
                                    AccountKind.ewallet => Icons.phone_android_rounded,
                                    AccountKind.cash => Icons.payments_outlined,
                                  },
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedAccountId = val);
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: Spacing.m),

                      Text(
                        'Arah Transaksi',
                        style: context
                            .qSmall()
                            .copyWith(color: q.muted, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: Spacing.xs),
                      QuestSegmented<Direction>(
                        selected: _direction,
                        options: const [
                          (
                            value: Direction.outgoing,
                            label: 'Pengeluaran',
                            icon: Icons.arrow_upward_rounded,
                          ),
                          (
                            value: Direction.incoming,
                            label: 'Pemasukan',
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ],
                        onChanged: (val) => setState(() => _direction = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.m),

                QuestCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        button: true,
                        toggled: _showRawText,
                        label:
                            'Teks Mentah Hasil OCR, ${_showRawText ? 'terbuka' : 'tertutup'}',
                        child: InkWell(
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
                      ),
                      if (_showRawText) ...[
                        const SizedBox(height: Spacing.s),
                        TextField(
                          controller: _rawTextCtrl,
                          maxLines: 8,
                          style: context.qBody(12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.l),

                QuestButton(
                  label: _isSaving ? 'Memproses...' : 'Langsung Catat Transaksi',
                  icon: Icons.check_circle_rounded,
                  onPressed: _isSaving ? null : _recordDirectly,
                ),
                const SizedBox(height: Spacing.s),
                QuestButton(
                  label: 'Simpan sebagai Draf Dulu',
                  icon: Icons.inbox_rounded,
                  tone: QuestTone.secondary,
                  onPressed: _isSaving ? null : _saveAsDraft,
                ),
              ],
            ),
    );
  }
}
