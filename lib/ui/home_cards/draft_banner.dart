part of '../home_cards.dart';

/// Banner Draf Notifikasi Bank Aktif: Tampil otomatis bila ada capture bank menunggu konfirmasi

class DraftAttentionBanner extends StatelessWidget {
  const DraftAttentionBanner({
    super.key,
    required this.repository,
    required this.ruleSet,
    required this.progress,
    required this.pipeline,
    required this.onOpenAnggaran,
    required this.onOpenBon,
  });

  final LedgerRepository repository;
  final RuleSet ruleSet;
  final ProgressService progress;
  final CapturePipeline pipeline;
  final VoidCallback onOpenAnggaran;
  final VoidCallback onOpenBon;

  String _bankName(String bankId) {
    if (bankId == 'paste') return 'Tempelan / Struk';
    final known = ruleSet.bank(bankId)?.displayName;
    if (known != null) return known;
    return bankId.startsWith('app:') ? bankId.substring(4) : bankId;
  }

  @override
  Widget build(BuildContext context) {
    final q = context.q;

    return StreamBuilder<List<Draft>>(
      stream: repository.watchDrafts(),
      builder: (context, snapshot) {
        final drafts = snapshot.data ?? const [];
        return AnimatedSize(
          duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
              ? Duration.zero
              : QuestMotion.medium,
          curve: QuestMotion.easeOut,
          alignment: Alignment.topCenter,
          child: QuestSwap(
            child: drafts.isEmpty
                ? const SizedBox(
                    key: ValueKey('draft-banner-empty'),
                    width: double.infinity,
                  )
                : Builder(
                    builder: (context) {
                      final draft = drafts.first;
                      final isIncoming = draft.direction == Direction.incoming;
                      final bank = _bankName(draft.bankId);
                      final party =
                          (draft.counterparty != null &&
                              draft.counterparty!.trim().isNotEmpty)
                          ? draft.counterparty!.trim()
                          : null;
                      return Padding(
                        key: const ValueKey('draft-banner-on'),
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.m,
                          Spacing.s,
                          Spacing.m,
                          0,
                        ),
                        child: QuestCard(
                          color: q.primaryLight,
                          border: Border.all(
                            color: q.primary.withValues(alpha: 0.2),
                          ),
                          shadow: null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Banner
                              Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: q.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.bolt_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.s),
                                  Expanded(
                                    child: Text(
                                      drafts.length == 1
                                          ? 'Transaksi Bank Terdeteksi'
                                          : '${drafts.length} Transaksi Bank Terdeteksi',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: q.primaryDeep,
                                      ),
                                    ),
                                  ),
                                  if (drafts.length > 1)
                                    InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => NotificationScreen(
                                            repository: repository,
                                            pipeline: pipeline,
                                            ruleSet: ruleSet,
                                            progress: progress,
                                            onOpenAnggaran: onOpenAnggaran,
                                            onOpenBon: onOpenBon,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Lihat Semua (${drafts.length}) →',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: q.primaryDeep,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: Spacing.s),

                              // Draft Details Box
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: q.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.tile,
                                  ),
                                  border: Border.all(color: q.line),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isIncoming
                                            ? SeedColors.incomingTint
                                            : SeedColors.outgoingTint,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.cell,
                                        ),
                                      ),
                                      child: Icon(
                                        isIncoming
                                            ? Icons.arrow_downward_rounded
                                            : Icons.arrow_upward_rounded,
                                        color: isIncoming ? q.good : q.bad,
                                        size: 19,
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.s),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bank,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: q.text,
                                            ),
                                          ),
                                          if (party != null)
                                            Text(
                                              party,
                                              style: context.qSmall(11.5),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.s),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 130,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: QuestMoney(
                                          amount: draft.amount,
                                          prefix: isIncoming ? '+' : '−',
                                          alignment: Alignment.centerRight,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: isIncoming ? q.good : q.bad,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: Spacing.s),

                              // Inline Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: QuestButton(
                                      label: 'Konfirmasi & Catat',
                                      icon: Icons.check_rounded,
                                      onPressed: () => TransactionSheet.show(
                                        context,
                                        repository,
                                        draft: draft,
                                        progress: progress,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.s),
                                  Expanded(
                                    flex: 2,
                                    child: QuestButton(
                                      label: 'Abaikan',
                                      tone: QuestTone.secondary,
                                      onPressed: () async {
                                        await repository.discardDraft(draft.id);
                                        if (context.mounted) {
                                          questSnack(
                                            context,
                                            'Draf transaksi diabaikan.',
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
