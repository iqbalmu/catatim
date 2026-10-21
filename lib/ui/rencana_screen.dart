import 'package:flutter/material.dart';

import '../game/progress.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import 'quest.dart';
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
      backgroundColor: context.q.bg,
      appBar: QuestHeader(
        title: 'Rencana',
        subtitle: 'Atur batas belanjamu',
      ),
      // Tombol + tinggal di tengah navbar — tanpa FAB melayang di tab ini.
      body: RencanaBatas(repository: widget.repository, progress: widget.progress),
    );
  }
}
