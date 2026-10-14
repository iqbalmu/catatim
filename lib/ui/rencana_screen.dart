import 'dart:async';

import 'package:flutter/material.dart';

import '../core/money.dart';
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
    this.onSegmentChanged,
    this.headerActions = const [],
  });

  final LedgerRepository repository;

  /// Agar Beranda (hero pace/streak) ikut segar setelah Sisihkan;
  /// diisi Plan 5 saat nav bawah memasang layar ini.
  final ProgressService? progress;
  final RencanaSegment initialSegment;

  /// Dilaporkan setiap segmen berganti — dipakai shell agar deep-link
  /// Beranda → Batas selalu sinkron meski user sempat pindah segmen manual.
  final ValueChanged<RencanaSegment>? onSegmentChanged;

  /// Aksi header global dari shell (lonceng + ⋯) — sama di semua tab.
  final List<Widget> headerActions;

  /// Label FAB per segmen.
  static String fabLabelFor(RencanaSegment segment) => switch (segment) {
    RencanaSegment.batas => 'Jenis',
    RencanaSegment.target => 'Sisihkan',
  };

  @override
  State<RencanaScreen> createState() => _RencanaScreenState();
}

enum RencanaSegment { batas, target }

class _RencanaScreenState extends State<RencanaScreen> {
  late RencanaSegment _segment = widget.initialSegment;

  @override
  void didUpdateWidget(covariant RencanaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tap berulang dari Beranda membangun ulang widget dengan
    // initialSegment baru — sinkronkan segmen agar pindah.
    if (widget.initialSegment != oldWidget.initialSegment) {
      _segment = widget.initialSegment;
    }
  }

  void _setSegment(RencanaSegment s) {
    if (s == _segment) return;
    setState(() => _segment = s);
    widget.onSegmentChanged?.call(s);
  }

  /// FAB Sisihkan: tanpa pos → dialog ＋Target; satu pos → sheet langsung;
  /// banyak pos → pemilih pos dulu lalu sheet.
  Future<void> _sisihkanFlow() async {
    final targets = await widget.repository.watchTargets().first;
    if (!mounted) return;
    if (targets.isEmpty) {
      return showAddTargetFlow(context, widget.repository);
    }
    TargetWithProgress chosen;
    if (targets.length == 1) {
      chosen = targets.single;
    } else {
      final picked = await _askTargetChoice(targets);
      if (picked == null || !mounted) return;
      chosen = picked;
    }
    if (!mounted) return;
    await SisihkanSheet.show(
      context,
      widget.repository,
      chosen,
      progress: widget.progress,
    );
  }

  Future<TargetWithProgress?> _askTargetChoice(
    List<TargetWithProgress> targets,
  ) {
    return showQuestSheet<TargetWithProgress>(
      context,
      (context) => Padding(
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
            Text('Sisihkan ke pos', style: context.qTitle(18)),
            const SizedBox(height: Spacing.s),
            for (final t in targets)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.s),
                child: QuestPress(
                  onTap: () => Navigator.pop(context, t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.q.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: context.q.shadow,
                          offset: const Offset(0, 6),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.target.name,
                            style: context
                                .qBody(15)
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${Money.format(t.deposited)} / '
                          '${Money.format(t.target.goalAmount)}',
                          style: context.qSmall().copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.q.bg,
      appBar: QuestHeader(
        title: 'Rencana',
        subtitle: 'Batas & target keuangan',
        actions: widget.headerActions,
      ),
      // FAB milik tab ini (bukan shell): label + aksi mengikuti segmen.
      // Padding bawah agar melayang di atas navbar floating.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 72 + MediaQuery.paddingOf(context).bottom,
        ),
        child: switch (_segment) {
          RencanaSegment.batas => QuestFab(
            label: RencanaScreen.fabLabelFor(_segment),
            icon: Icons.add_rounded,
            onTap: () => showAddJenisFlow(context, widget.repository),
          ),
          RencanaSegment.target => QuestFab(
            label: RencanaScreen.fabLabelFor(_segment),
            icon: Icons.savings_outlined,
            onTap: _sisihkanFlow,
          ),
        },
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
              onChanged: _setSegment,
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
