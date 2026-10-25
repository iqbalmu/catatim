import 'package:flutter/material.dart';

import '../game/progress.dart';
import '../storage/repository.dart';
import 'rencana_batas.dart';
import '../theme/quest.dart';

/// Layar Rencana: akar tab (tanpa tombol kembali) berisi Batas
/// (eks Anggaran). [progress] opsional — sumber maskot meter, chip
/// streak, dan chip progres mingguan (mockup v2.1).
class RencanaScreen extends StatefulWidget {
  const RencanaScreen({super.key, required this.repository, this.progress});

  final LedgerRepository repository;
  final ProgressService? progress;

  @override
  State<RencanaScreen> createState() => RencanaScreenState();
}

class RencanaScreenState extends State<RencanaScreen> {
  /// Aksi tombol + tengah navbar — Jenis.
  void openPrimaryAction() {
    showAddJenisFlow(context, widget.repository);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anggaran',
              style: context.qTitle(20),
            ),
            const SizedBox(height: 2),
            Text(
              'Kontrol batas pengeluaran & alokasi kategori',
              style: context.qSmall(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Jenis Anggaran',
            onPressed: () => showAddJenisFlow(context, widget.repository),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RencanaBatas(repository: widget.repository, progress: widget.progress),
    );
  }
}
