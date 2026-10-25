import 'package:flutter/material.dart';

import '../game/progress.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import 'rencana_batas.dart';

class RencanaScreen extends StatelessWidget {
  const RencanaScreen({super.key, required this.repository, this.progress});

  final LedgerRepository repository;
  final ProgressService? progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RencanaBatas(repository: repository, progress: progress),
    );
  }
}
