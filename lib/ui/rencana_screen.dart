import 'package:flutter/material.dart';

import '../game/progress.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import 'quest.dart';
import 'rencana_batas.dart';

class RencanaScreen extends StatelessWidget {
  const RencanaScreen({super.key, required this.repository, this.progress});

  final LedgerRepository repository;
  final ProgressService? progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Anggaran',
        showBack: true,
      ),
      body: RencanaBatas(repository: repository, progress: progress),
    );
  }
}
