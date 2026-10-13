import 'package:flutter/material.dart';

import '../storage/repository.dart';
import '../theme/quest.dart';
import 'quest.dart';
import 'rencana_batas.dart';

/// Layar Anggaran (legacy, dihapus di Plan 05): pembungkus segmen
/// Batas dengan header + tombol kembali.
class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key, required this.repository});

  final LedgerRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Anggaran',
        subtitle: 'Alokasi dana & batas pengeluaran',
        showBack: true,
      ),
      body: RencanaBatas(repository: repository),
    );
  }
}
