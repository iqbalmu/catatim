part of '../home_cards.dart';

/// Banner Draf Notifikasi Bank Aktif: Tampil otomatis bila ada capture bank menunggu konfirmasi

class DraftAttentionBanner extends StatefulWidget {
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

  @override
  State<DraftAttentionBanner> createState() => _DraftAttentionBannerState();
}

class _DraftAttentionBannerState extends State<DraftAttentionBanner> {
  LedgerRepository get repository => widget.repository;
  RuleSet get ruleSet => widget.ruleSet;
  ProgressService get progress => widget.progress;
  CapturePipeline get pipeline => widget.pipeline;
  VoidCallback get onOpenAnggaran => widget.onOpenAnggaran;
  VoidCallback get onOpenBon => widget.onOpenBon;

  late final Stream<List<Draft>> _draftsStream;

  @override
  void initState() {
    super.initState();
    _draftsStream = widget.repository.watchDrafts();
  }

  @override
  void didUpdateWidget(covariant DraftAttentionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _draftsStream = widget.repository.watchDrafts();
    }
  }

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
      stream: _draftsStream,
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
                      final partitioned =
                          LedgerRepository.partitionDrafts(drafts);
                      final hasPair = partitioned.pairs.isNotEmpty;

                      final String titleText;
                      final String subtitleText;
                      Widget? amountWidget;
                      VoidCallback onTap;

                      if (hasPair && drafts.length == 2) {
                        final pair = partitioned.pairs.first;
                        final fromBank = _bankName(pair.outDraft.bankId);
                        final toBank = _bankName(pair.inDraft.bankId);
                        titleText = 'Transfer Antar Akun Terdeteksi';
                        subtitleText = '$fromBank → $toBank · Pindah saldo';
                        amountWidget = QuestMoney(
                          amount: pair.amount,
                          alignment: Alignment.centerRight,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: q.text,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        );
                        onTap = () => Navigator.push(
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
                            );
                      } else if (drafts.length == 1) {
                        final draft = drafts.first;
                        final isIncoming =
                            draft.direction == Direction.incoming;
                        final bank = _bankName(draft.bankId);
                        final party = (draft.counterparty != null &&
                                draft.counterparty!.trim().isNotEmpty)
                            ? draft.counterparty!.trim()
                            : null;
                        titleText = 'Transaksi Bank Terdeteksi';
                        subtitleText =
                            '$bank${party != null ? ' · $party' : ''}';
                        amountWidget = QuestMoney(
                          amount: draft.amount,
                          tone: isIncoming
                              ? MoneyTone.incoming
                              : MoneyTone.outgoing,
                          alignment: Alignment.centerRight,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: isIncoming ? q.good : q.bad,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        );
                        onTap = () => TransactionSheet.show(
                              context,
                              repository,
                              draft: draft,
                              progress: progress,
                            );
                      } else {
                        titleText =
                            '${drafts.length} Transaksi Bank Terdeteksi';
                        subtitleText = 'Ketuk untuk tinjau & selesaikan';
                        amountWidget = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: q.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${drafts.length} draf',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: q.primaryDeep,
                            ),
                          ),
                        );
                        onTap = () => Navigator.push(
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
                            );
                      }

                      return Padding(
                        key: const ValueKey('draft-banner-on'),
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.m,
                          Spacing.s,
                          Spacing.m,
                          0,
                        ),
                        child: Semantics(
                          button: true,
                          label: '$titleText. $subtitleText',
                          child: QuestCard(
                            color: q.primaryLight,
                            border: Border.all(
                              color: q.primary.withValues(alpha: 0.25),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shadow: null,
                            onTap: onTap,
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: q.primarySolid,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.cell,
                                    ),
                                  ),
                                  child: Icon(
                                    hasPair
                                        ? Icons.swap_horiz_rounded
                                        : Icons.bolt_rounded,
                                    color: q.onPrimary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: Spacing.s),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        titleText,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: q.primaryDeep,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        subtitleText,
                                        style: context.qSmall(11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Spacing.s),
                                amountWidget,
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: q.primaryDeep,
                                  size: 19,
                                ),
                              ],
                            ),
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
