import 'package:flutter/material.dart';

import '../capture/pipeline.dart';
import '../capture/simulator.dart';
import '../core/money.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/repository.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Sheet interaktif Simulator & Pengujian Notifikasi Bank (M3).
class CaptureSimulatorSheet extends StatefulWidget {
  const CaptureSimulatorSheet({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.ruleSet,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final RuleSet ruleSet;

  static Future<void> show(
    BuildContext context, {
    required LedgerRepository repository,
    required CapturePipeline pipeline,
    required RuleSet ruleSet,
  }) {
    return showQuestSheet<void>(
      context,
      (ctx) => CaptureSimulatorSheet(
        repository: repository,
        pipeline: pipeline,
        ruleSet: ruleSet,
      ),
    );
  }

  @override
  State<CaptureSimulatorSheet> createState() => _CaptureSimulatorSheetState();
}

class _CaptureSimulatorSheetState extends State<CaptureSimulatorSheet> {
  int _tabIndex = 0; // 0 = Dry Run, 1 = Batch
  CaptureScenario? _selectedScenario;

  late final TextEditingController _packageCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  SimulationEvaluation? _currentEvaluation;
  int _trackedDraftCount = 0;
  bool _isInjecting = false;
  bool _isCleaning = false;

  BatchSimulationReport? _batchReport;
  bool _isRunningBatch = false;

  @override
  void initState() {
    super.initState();
    _selectedScenario = kSimulatorPresets.first;
    _packageCtrl = TextEditingController(text: _selectedScenario!.packageName);
    _titleCtrl = TextEditingController(text: _selectedScenario!.title);
    _bodyCtrl = TextEditingController(text: _selectedScenario!.body);

    _packageCtrl.addListener(_evaluateCurrent);
    _titleCtrl.addListener(_evaluateCurrent);
    _bodyCtrl.addListener(_evaluateCurrent);

    _evaluateCurrent();
    _refreshTrackedDrafts();
  }

  @override
  void dispose() {
    _packageCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _evaluateCurrent() {
    final eval = NotificationSimulator.evaluate(
      engine: widget.pipeline.engine,
      packageName: _packageCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      scenario: _selectedScenario,
    );
    setState(() {
      _currentEvaluation = eval;
    });
  }

  Future<void> _refreshTrackedDrafts() async {
    final count = await NotificationSimulator.countTrackedDrafts(widget.repository);
    if (mounted) {
      setState(() => _trackedDraftCount = count);
    }
  }

  void _applyScenario(CaptureScenario scenario) {
    setState(() {
      _selectedScenario = scenario;
      _packageCtrl.text = scenario.packageName;
      _titleCtrl.text = scenario.title;
      _bodyCtrl.text = scenario.body;
    });
  }

  Future<void> _runBatchTest() async {
    if (_isRunningBatch) return;
    setState(() => _isRunningBatch = true);

    await Future<void>.delayed(const Duration(milliseconds: 150));
    final report = NotificationSimulator.runBatch(engine: widget.pipeline.engine);

    if (mounted) {
      setState(() {
        _batchReport = report;
        _isRunningBatch = false;
      });
    }
  }

  Future<void> _injectEndToEnd() async {
    if (_isInjecting) return;
    setState(() => _isInjecting = true);

    try {
      final pkg = _packageCtrl.text.trim();
      final title = _titleCtrl.text.trim();
      final body = _bodyCtrl.text.trim();

      final draftId = await NotificationSimulator.injectEndToEnd(
        pipeline: widget.pipeline,
        repository: widget.repository,
        packageName: pkg,
        title: title,
        body: body,
      );

      await _refreshTrackedDrafts();

      if (!mounted) return;
      if (draftId != null) {
        questSnack(
          context,
          'Berhasil didorong ke antrean! Draf #$draftId telah dibuat.',
          icon: Icons.check_circle_rounded,
        );
      } else {
        questSnack(
          context,
          'Notifikasi diproses (diabaikan atau dianggap duplikat).',
          icon: Icons.info_outline_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        questSnack(
          context,
          'Gagal mendorong notifikasi: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isInjecting = false);
    }
  }

  Future<void> _cleanupSimulatedData() async {
    if (_isCleaning) return;
    setState(() => _isCleaning = true);

    try {
      final deleted = await NotificationSimulator.cleanupSimulatedData(
        widget.repository,
      );
      await _refreshTrackedDrafts();

      if (!mounted) return;
      questSnack(
        context,
        deleted > 0
            ? '$deleted draf simulasi berhasil dibersihkan.'
            : 'Tidak ada data simulasi yang tersisa.',
        icon: Icons.delete_sweep_rounded,
      );
    } catch (e) {
      if (mounted) {
        questSnack(
          context,
          'Gagal membersihkan data: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isCleaning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            Spacing.l,
            Spacing.xs,
            Spacing.l,
            Spacing.xl,
          ),
          children: [
            // Grabber & Header
            const Center(child: QuestGrabber()),
            const SizedBox(height: Spacing.s),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Simulator & Validasi Capture',
                        style: context.qTitle(18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Uji rule parser & kirim simulasi notifikasi (M3)',
                        style: context.qSmall(12).copyWith(color: q.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: Spacing.m),

            // Tab Segmented Control
            QuestSegmented<int>(
              options: const [
                (value: 0, label: 'Uji Interaktif', icon: Icons.science_rounded),
                (value: 1, label: 'Batch Test (Semua)', icon: Icons.fact_check_rounded),
              ],
              selected: _tabIndex,
              onChanged: (val) {
                setState(() => _tabIndex = val);
                if (val == 1 && _batchReport == null) {
                  _runBatchTest();
                }
              },
            ),
            const SizedBox(height: Spacing.l),

            if (_tabIndex == 0) ...[
              _buildInteractiveView(context),
            ] else ...[
              _buildBatchView(context),
            ],
          ],
        );
      },
    );
  }

  Widget _buildInteractiveView(BuildContext context) {
    final q = context.q;
    final eval = _currentEvaluation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset selector bar
        Text(
          'Pilih Preset Skenario',
          style: context.qSmall(12).copyWith(
            fontWeight: FontWeight.w700,
            color: q.muted,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final scenario in kSimulatorPresets) ...[
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: QuestChip(
                    label: scenario.name,
                    selected: _selectedScenario?.id == scenario.id,
                    onTap: () => _applyScenario(scenario),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.l),

        // Live Breakdown / Result Card
        if (eval != null) _buildEvaluationCard(context, eval),
        const SizedBox(height: Spacing.l),

        // Editable Input Fields
        Text(
          'Data Notifikasi',
          style: context.qSmall(12).copyWith(
            fontWeight: FontWeight.w700,
            color: q.muted,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        QuestCard(
          padding: const EdgeInsets.all(Spacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const QuestFieldLabel('Package Name'),
              const SizedBox(height: Spacing.xs),
              TextField(
                controller: _packageCtrl,
                style: context.qBody(13),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.apps_rounded, size: 18),
                ),
              ),
              const SizedBox(height: Spacing.m),
              const QuestFieldLabel('Judul Notifikasi (Title)'),
              const SizedBox(height: Spacing.xs),
              TextField(
                controller: _titleCtrl,
                style: context.qBody(13),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.title_rounded, size: 18),
                ),
              ),
              const SizedBox(height: Spacing.m),
              const QuestFieldLabel('Isi Notifikasi (Body)'),
              const SizedBox(height: Spacing.xs),
              TextField(
                controller: _bodyCtrl,
                maxLines: 3,
                style: context.qBody(13),
                decoration: const InputDecoration(
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(Icons.message_rounded, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.l),

        // Action Buttons
        QuestButton(
          label: _isInjecting
              ? 'Mendorong ke Pipeline...'
              : 'Kirim ke Antrean Nyata (End-to-End)',
          icon: Icons.send_rounded,
          tone: QuestTone.primary,
          onPressed: _isInjecting ? null : _injectEndToEnd,
        ),
        const SizedBox(height: Spacing.s),

        if (_trackedDraftCount > 0)
          QuestButton(
            label: _isCleaning
                ? 'Membersihkan...'
                : 'Bersihkan Data Uji Coba ($_trackedDraftCount draf)',
            icon: Icons.delete_sweep_rounded,
            tone: QuestTone.secondary,
            onPressed: _isCleaning ? null : _cleanupSimulatedData,
          ),
      ],
    );
  }

  Widget _buildEvaluationCard(BuildContext context, SimulationEvaluation eval) {
    final q = context.q;

    final (badgeLabel, badgeColor, badgeBg, dotColor) = switch ((
      eval.parsed,
      eval.isFallbackGuess,
      eval.passedExpectation,
    )) {
      (true, _, true) => (
        'Match Terverifikasi',
        q.good,
        q.incomingTint,
        q.good,
      ),
      (true, _, false) => (
        'Mismatched Skenario',
        q.bad,
        q.outgoingTint,
        q.bad,
      ),
      (false, true, _) => (
        'Mode Tebak Cerdas',
        q.warn,
        q.warnTint,
        q.warn,
      ),
      (false, false, true) => (
        'Tepat Diabaikan (Aman)',
        q.primary,
        q.primaryLight,
        q.primary,
      ),
      (false, false, false) => (
        'Tidak Dikenali',
        q.muted,
        q.surface2,
        null,
      ),
    };

    return QuestCard(
      variant: QuestCardVariant.hero,
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              QuestStatusBadge(
                label: badgeLabel,
                color: badgeColor,
                bgColor: badgeBg,
                dotColor: dotColor,
              ),
              const Spacer(),
              if (eval.bankName != null)
                Text(
                  eval.bankName!,
                  style: context.qSmall(12).copyWith(
                        color: q.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.m),

          // Nominal & Arah
          if (eval.amount != null && eval.amount! > 0) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  Money.format(eval.amount!),
                  style: context.qDisplay(24).copyWith(
                        color: eval.direction == Direction.incoming
                            ? q.good
                            : q.text,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  eval.direction == Direction.incoming ? 'Masuk' : 'Keluar',
                  style: context.qSmall(12).copyWith(
                        color: eval.direction == Direction.incoming
                            ? q.good
                            : q.bad,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.s),
          ],

          // Detail Pills
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: [
              if (eval.templateName != null)
                _buildMiniPill(context, Icons.rule_rounded, 'Aturan: ${eval.templateName}'),
              if (eval.kind != null)
                _buildMiniPill(context, Icons.category_rounded, 'Jenis: ${eval.kind!.name}'),
              if (eval.counterparty != null && eval.counterparty!.isNotEmpty)
                _buildMiniPill(context, Icons.person_rounded, eval.counterparty!),
            ],
          ),
          const SizedBox(height: Spacing.s),

          // Message
          Text(
            eval.message,
            style: context.qSmall(12).copyWith(
                  color: eval.passedExpectation ? q.muted : q.bad,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPill(BuildContext context, IconData icon, String text) {
    final q = context.q;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: q.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: q.muted),
          const SizedBox(width: 4),
          Text(
            text,
            style: context.qSmall(11.5).copyWith(color: q.text),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchView(BuildContext context) {
    final q = context.q;
    final report = _batchReport;

    if (_isRunningBatch || report == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.xl),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ringkasan Batch Card
        QuestCard(
          variant: QuestCardVariant.hero,
          padding: const EdgeInsets.all(Spacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${report.passed} / ${report.total} Lolos',
                    style: context.qTitle(20).copyWith(
                          color: report.isAllPassed ? q.good : q.bad,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  QuestStatusBadge(
                    label: report.isAllPassed ? '100% Lulus' : 'Ada Ketidakcocokan',
                    color: report.isAllPassed ? q.good : q.bad,
                    bgColor: report.isAllPassed
                        ? q.incomingTint
                        : q.outgoingTint,
                    dotColor: report.isAllPassed ? q.good : q.bad,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Tingkat kelulusan preset: ${report.passRate.toStringAsFixed(1)}%',
                style: context.qSmall(12).copyWith(color: q.muted),
              ),
              const SizedBox(height: Spacing.m),
              QuestButton(
                label: 'Jalankan Ulang Seluruh Preset',
                icon: Icons.refresh_rounded,
                tone: QuestTone.secondary,
                onPressed: _runBatchTest,
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.l),

        Text(
          'Rincian Hasil Skenario',
          style: context.qSmall(12).copyWith(
            fontWeight: FontWeight.w700,
            color: q.muted,
          ),
        ),
        const SizedBox(height: Spacing.xs),

        for (final item in report.evaluations) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.s),
            child: QuestCard(
              padding: const EdgeInsets.all(Spacing.m),
              onTap: () {
                if (item.scenario != null) {
                  _applyScenario(item.scenario!);
                  setState(() => _tabIndex = 0);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.scenario?.name ?? item.title,
                          style: context.qTitle(14),
                        ),
                      ),
                      QuestStatusBadge(
                        label: item.passedExpectation ? 'Lolos' : 'Gagal',
                        color: item.passedExpectation ? q.good : q.bad,
                        bgColor: item.passedExpectation
                            ? q.incomingTint
                            : q.outgoingTint,
                        dotColor: item.passedExpectation ? q.good : q.bad,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.qSmall(12).copyWith(color: q.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message,
                    style: context.qSmall(11).copyWith(
                          color: item.passedExpectation ? q.muted : q.bad,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
