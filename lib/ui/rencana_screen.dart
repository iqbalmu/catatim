import 'package:flutter/material.dart';

import '../game/progress.dart';
import '../storage/repository.dart';
import 'rencana_batas.dart';

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target & Gamifikasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: Color(0xFF161924),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Target batas pengeluaran & level saver',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7C8BA0),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RencanaBatas(repository: widget.repository, progress: widget.progress),
    );
  }
}
