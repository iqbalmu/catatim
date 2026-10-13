import 'package:flutter/material.dart';

import '../game/progress.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';
import 'rencana_batas.dart';
import 'rencana_target.dart';

/// Layar Rencana: akar tab (tanpa tombol kembali) dengan segmen
/// Batas (default) dan Target. Segmen Batas = eks Anggaran.
class RencanaScreen extends StatefulWidget {
  const RencanaScreen({
    super.key,
    required this.repository,
    this.progress,
    this.initialSegment = RencanaSegment.batas,
  });

  final LedgerRepository repository;

  /// Agar Beranda (hero pace/streak) ikut segar setelah Sisihkan;
  /// diisi Plan 5 saat nav bawah memasang layar ini.
  final ProgressService? progress;
  final RencanaSegment initialSegment;

  /// Label FAB per segmen — dipakai Plan 5 (nav bawah) agar tidak menebak.
  static String fabLabelFor(RencanaSegment segment) => switch (segment) {
    RencanaSegment.batas => '＋Batas',
    RencanaSegment.target => '＋Target',
  };

  @override
  State<RencanaScreen> createState() => _RencanaScreenState();
}

enum RencanaSegment { batas, target }

class _RencanaScreenState extends State<RencanaScreen> {
  late RencanaSegment _segment = widget.initialSegment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: const QuestHeader(
        title: 'Rencana',
        subtitle: 'Batas & target keuangan',
      ),
      // Kolom non-scroll: konten segmen (Batas) yang menggulir — pola
      // shell Rekap.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.m,
              Spacing.s,
              Spacing.m,
              0,
            ),
            child: QuestSegmented<RencanaSegment>(
              selected: _segment,
              onChanged: (s) => setState(() => _segment = s),
              options: const [
                (value: RencanaSegment.batas, label: 'Batas', icon: null),
                (value: RencanaSegment.target, label: 'Target', icon: null),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),
          Expanded(
            child: switch (_segment) {
              RencanaSegment.batas => RencanaBatas(
                repository: widget.repository,
              ),
              RencanaSegment.target => RencanaTarget(
                repository: widget.repository,
                progress: widget.progress,
              ),
            },
          ),
        ],
      ),
    );
  }
}
