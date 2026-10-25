import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/pipeline.dart';
import '../core/dates_id.dart';
import '../core/money.dart';
import '../game/progress.dart';
import '../models.dart';
import '../rules/rule_set.dart';
import '../storage/database.dart';
import '../storage/repository.dart';
import 'account_detail_screen.dart';
import 'add_account_sheet.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Bon tua: belum lunas dan umur kalender (today − occurredAt) > 30 hari.
bool bonNeedsBadge(DateTime occurredAt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
  return today.difference(day).inDays > 30;
}

/// Palet warna design system
class _FintechColors {
  static const surface = Colors.white;
  static const border = Color(0x0A000000);
  static const textPrimary = Color(0xFF161924);
  static const textSecondary = Color(0xFF7C8BA0);
  static const textMuted = Color(0xFF9AA8BC);

  static const lilacBg = Color(0xFFE9D8FD);
  static const lilacText = Color(0xFF6B46C1);
  static const purple = Color(0xFF8B5CF6);

  static const green = Color(0xFF10B981);
  static const greenBg = Color(0xFFDEF7EC);
  static const greenText = Color(0xFF03543F);

  static const red = Color(0xFFEF4444);
  static const redBg = Color(0xFFFDE8E8);
  static const redText = Color(0xFF9B1C1C);

  static const amberBg = Color(0xFFFEF3C7);
  static const amberText = Color(0xFFB45309);
}

/// Wadah kartu fintech
BoxDecoration _cardDeco({double radius = 24}) => BoxDecoration(
      color: _FintechColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _FintechColors.border, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A2B3A4A),
          offset: Offset(0, 8),
          blurRadius: 24,
          spreadRadius: -2,
        ),
      ],
    );

/// Tab 4: Hub Bon & Akun Bank
/// Menggabungkan pencatatan utang-piutang (utilitas murni tanpa gamifikasi)
/// dan pengelolaan koneksi notifikasi bank/e-wallet dalam satu alur yang jelas.
class BonTab extends StatefulWidget {
  const BonTab({
    super.key,
    required this.repository,
    this.pipeline,
    this.ruleSet,
    this.progress,
  });

  final LedgerRepository repository;
  final CapturePipeline? pipeline;
  final RuleSet? ruleSet;
  final ProgressService? progress;

  @override
  State<BonTab> createState() => _BonTabState();
}

class _BonTabState extends State<BonTab> {
  late final Stream<List<Bon>> _bons;

  /// 0 = Bon Utang-Piutang, 1 = Akun & Notifikasi Bank
  int _selectedHubSegment = 0;

  /// Filter bon: 0 = Belum Lunas, 1 = Sudah Lunas
  int _selectedBonFilter = 0;

  @override
  void initState() {
    super.initState();
    _bons = widget.repository.watchBons();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          topPadding + 10,
          20,
          96 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // Header Judul Layar
          const Text(
            'Bon & Akun',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: _FintechColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Utilitas utang-piutang & otomatisasi notifikasi bank',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _FintechColors.textSecondary,
            ),
          ),

          const SizedBox(height: 16),

          // Segmented Control Utama: [Bon Utang-Piutang] | [Akun & Notifikasi]
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _hubSegmentButton(0, '🤝 Bon Utang-Piutang'),
                _hubSegmentButton(1, '🏦 Akun & Notifikasi'),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Konten Segmen Aktif
          if (_selectedHubSegment == 0)
            _buildBonSection()
          else
            _buildBankAccountsSection(),
        ],
      ),
    );
  }

  Widget _hubSegmentButton(int index, String label) {
    final active = _selectedHubSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedHubSegment = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? _FintechColors.lilacBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active
                  ? _FintechColors.lilacText
                  : _FintechColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEGMEN 1: BON UTANG-PIUTANG (UTILITAS BERSIH - TANPA GAMIFIKASI)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildBonSection() {
    return StreamBuilder<List<Bon>>(
      stream: _bons,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final bons = snapshot.data ?? const <Bon>[];
        var piutang = 0;
        var utang = 0;
        for (final b in bons) {
          if (b.settledAt != null) continue;
          if (b.direction == BonDirection.lent) {
            piutang += b.amount;
          } else {
            utang += b.amount;
          }
        }

        final open = [for (final b in bons) if (b.settledAt == null) b];
        final done = [for (final b in bons) if (b.settledAt != null) b];
        final currentList = _selectedBonFilter == 0 ? open : done;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kartu Ringkasan Piutang vs Utang
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDeco(radius: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _FintechColors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'PIUTANG',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: _FintechColors.greenText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Money.format(piutang),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _FintechColors.textPrimary,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'orang berutang padamu',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _FintechColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDeco(radius: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _FintechColors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'UTANG',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: _FintechColors.redText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Money.format(utang),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _FintechColors.textPrimary,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'kamu berutang',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _FintechColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tombol Cepat Tambah Bon
            ElevatedButton.icon(
              onPressed: () => BonSheet.show(context, widget.repository),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Catat Bon Baru',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _FintechColors.textPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Filter Status Bon: [Belum Lunas (X)] | [Riwayat Lunas (Y)]
            Row(
              children: [
                _bonFilterChip(0, 'Belum Lunas (${open.length})'),
                const SizedBox(width: 8),
                _bonFilterChip(1, 'Sudah Lunas (${done.length})'),
              ],
            ),

            const SizedBox(height: 12),

            // Daftar Bon
            if (currentList.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: _cardDeco(radius: 20),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.handshake_outlined,
                          size: 22,
                          color: _FintechColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _selectedBonFilter == 0
                            ? 'Tidak ada bon yang belum lunas'
                            : 'Belum ada riwayat bon lunas',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _FintechColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Semua urusan utang-piutangmu tertata rapi.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _FintechColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final bon in currentList)
                _CleanBonTile(
                  bon: bon,
                  repository: widget.repository,
                ),
          ],
        );
      },
    );
  }

  Widget _bonFilterChip(int index, String label) {
    final active = _selectedBonFilter == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedBonFilter = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _FintechColors.textPrimary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? _FintechColors.textPrimary : const Color(0x0A000000),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? Colors.white : _FintechColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SEGMEN 2: AKUN & NOTIFIKASI BANK OTOMATIS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildBankAccountsSection() {
    final pipeline = widget.pipeline;
    final ruleSet = widget.ruleSet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Status Izin Notification Listener Android
        if (pipeline != null)
          FutureBuilder<bool>(
            future: pipeline.channel.isListenerEnabled(),
            builder: (context, snap) {
              final enabled = snap.data ?? false;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDeco(radius: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: enabled
                            ? _FintechColors.greenBg
                            : _FintechColors.amberBg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        enabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_outlined,
                        size: 20,
                        color: enabled
                            ? _FintechColors.green
                            : _FintechColors.amberText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enabled
                                ? 'Pembaca Notifikasi Aktif'
                                : 'Izin Notifikasi Belum Aktif',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: _FintechColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            enabled
                                ? 'Bukuduit otomatis membaca notifikasi bank terhubung.'
                                : 'Aktifkan izin akses notifikasi agar Bukuduit bisa mencatat otomatis.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _FintechColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await pipeline.channel.openListenerSettings();
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: enabled
                            ? const Color(0xFFF1F5F9)
                            : _FintechColors.purple,
                        foregroundColor: enabled
                            ? _FintechColors.textPrimary
                            : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        enabled ? 'Ubah' : 'Aktifkan',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 16),

        // 2. Kotak Masuk Draf Notifikasi yang Menunggu Konfirmasi
        StreamBuilder<List<Draft>>(
          stream: widget.repository.watchDrafts(),
          builder: (context, draftSnap) {
            final drafts = draftSnap.data ?? const <Draft>[];
            if (drafts.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _FintechColors.lilacBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _FintechColors.purple.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.mark_email_unread_rounded,
                        size: 16,
                        color: _FintechColors.lilacText,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${drafts.length} Draf Transaksi Menunggu Konfirmasi',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _FintechColors.lilacText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final draft in drafts)
                    _DraftReviewTile(
                      draft: draft,
                      pipeline: pipeline,
                      repository: widget.repository,
                    ),
                ],
              ),
            );
          },
        ),

        // 3. Daftar Akun & Saldo
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daftar Akun',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _FintechColors.textPrimary,
              ),
            ),
            if (pipeline != null && ruleSet != null)
              TextButton.icon(
                onPressed: () => AddAccountSheet.show(
                  context,
                  repository: widget.repository,
                  pipeline: pipeline,
                  ruleSet: ruleSet,
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Tambah Akun',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        StreamBuilder<List<Account>>(
          stream: widget.repository.watchAccounts(),
          builder: (context, accSnap) {
            final accounts = accSnap.data ?? const <Account>[];
            if (accounts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDeco(radius: 18),
                child: const Center(
                  child: Text(
                    'Belum ada akun.',
                    style: TextStyle(color: _FintechColors.textMuted),
                  ),
                ),
              );
            }

            return StreamBuilder<Map<int, int>>(
              stream: widget.repository.watchAccountBalances(),
              builder: (context, balSnap) {
                final balances = balSnap.data ?? const <int, int>{};
                return Column(
                  children: [
                    for (final acc in accounts)
                      _AccountTile(
                        account: acc,
                        balance: balances[acc.id] ?? acc.openingBalance,
                        onTap: () {
                          if (pipeline != null && ruleSet != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AccountDetailScreen(
                                  repository: widget.repository,
                                  pipeline: pipeline,
                                  ruleSet: ruleSet,
                                  accountId: acc.id,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                );
              },
            );
          },
        ),

        const SizedBox(height: 20),

        // 4. Katalog Koneksi Bank & E-Wallet (Toggle On/Off)
        if (ruleSet != null) ...[
          const Text(
            'Koneksi Bank & E-Wallet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _FintechColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih bank yang ingin kamu hubungkan ke notifikasi otomatis.',
            style: TextStyle(
              fontSize: 11.5,
              color: _FintechColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          StreamBuilder<Set<String>>(
            stream: widget.repository.watchConnectedBanks(),
            builder: (context, connSnap) {
              final connected = connSnap.data ?? const <String>{};

              return Container(
                decoration: _cardDeco(radius: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    for (var i = 0; i < ruleSet.banks.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                      _BankToggleRow(
                        bank: ruleSet.banks[i],
                        isConnected: connected.contains(ruleSet.banks[i].id),
                        onToggle: (val) async {
                          HapticFeedback.selectionClick();
                          await widget.repository.setBankConnected(
                            ruleSet.banks[i].id,
                            val,
                          );
                          if (val) {
                            await widget.repository.ensureBankAccount(
                              bankId: ruleSet.banks[i].id,
                              name: ruleSet.banks[i].displayName,
                              kind: AccountKind.bank,
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-KOMPONEN SEGMEN BON
// ─────────────────────────────────────────────────────────────────────────────

class _CleanBonTile extends StatelessWidget {
  const _CleanBonTile({required this.bon, required this.repository});

  final Bon bon;
  final LedgerRepository repository;

  String _ageLabel(DateTime occurredAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
    final days = today.difference(start).inDays;
    if (days <= 0) return 'hari ini';
    if (days < 14) return '$days hari';
    if (days < 60) return '${days ~/ 7} minggu';
    return '${(days / 30).round()} bulan';
  }

  @override
  Widget build(BuildContext context) {
    final lent = bon.direction == BonDirection.lent;
    final settled = bon.settledAt != null;
    final initial = bon.person.trim().isEmpty
        ? '?'
        : bon.person.trim()[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDeco(radius: 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => BonSheet.show(context, repository, existing: bon),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar Inisial
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lent
                        ? _FintechColors.greenBg
                        : _FintechColors.redBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: lent
                          ? _FintechColors.greenText
                          : _FintechColors.redText,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Nama & Keterangan
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bon.person,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: settled
                              ? _FintechColors.textMuted
                              : _FintechColors.textPrimary,
                          decoration: settled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lent ? 'Dipinjamkan' : 'Dipinjam'} • ${_ageLabel(bon.occurredAt)} • ${idDayMonth(bon.occurredAt)}'
                        '${bon.note != null && bon.note!.isNotEmpty ? ' • ${bon.note!}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _FintechColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Nominal & Aksi 1-tap Lunasi
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${lent ? '+' : '−'}${Money.format(bon.amount)}',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: settled
                            ? _FintechColors.textMuted
                            : lent
                                ? _FintechColors.green
                                : _FintechColors.red,
                        fontFeatures: _tabular,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (settled)
                      Text(
                        'Lunas ${idDayMonth(bon.settledAt!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _FintechColors.textMuted,
                        ),
                      )
                    else
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          repository.updateBon(
                            bon.id,
                            BonsCompanion(settledAt: Value(DateTime.now())),
                          );
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _FintechColors.greenBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '✓ Lunasi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _FintechColors.greenText,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-KOMPONEN SEGMEN AKUN & NOTIFIKASI
// ─────────────────────────────────────────────────────────────────────────────

class _DraftReviewTile extends StatelessWidget {
  const _DraftReviewTile({
    required this.draft,
    required this.pipeline,
    required this.repository,
  });

  final Draft draft;
  final CapturePipeline? pipeline;
  final LedgerRepository repository;

  @override
  Widget build(BuildContext context) {
    final incoming = draft.direction == Direction.incoming;
    final title = (draft.counterparty != null && draft.counterparty!.isNotEmpty)
        ? draft.counterparty!
        : draft.kind.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: incoming ? _FintechColors.greenBg : _FintechColors.redBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              incoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 18,
              color: incoming ? _FintechColors.green : _FintechColors.red,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _FintechColors.textPrimary,
                  ),
                ),
                Text(
                  '${incoming ? '+' : '−'}${Money.format(draft.amount)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: incoming ? _FintechColors.green : _FintechColors.textPrimary,
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: _FintechColors.green),
            tooltip: 'Konfirmasi',
            onPressed: () async {
              HapticFeedback.lightImpact();
              await repository.confirmDraft(
                draft,
                amount: draft.amount,
                direction: draft.direction,
                kind: draft.kind,
                counterparty: draft.counterparty,
                categoryId: draft.categoryId,
                accountId: draft.accountId,
                occurredAt: draft.occurredAt,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: _FintechColors.textMuted),
            tooltip: 'Abaikan',
            onPressed: () async {
              HapticFeedback.lightImpact();
              await repository.discardDraft(draft.id);
            },
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.balance,
    required this.onTap,
  });

  final Account account;
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _cardDeco(radius: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    size: 19,
                    color: _FintechColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _FintechColors.textPrimary,
                        ),
                      ),
                      Text(
                        account.bankId != null ? 'Terhubung' : 'Manual',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _FintechColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Money.format(balance),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _FintechColors.textPrimary,
                    fontFeatures: _tabular,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: _FintechColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BankToggleRow extends StatelessWidget {
  const _BankToggleRow({
    required this.bank,
    required this.isConnected,
    required this.onToggle,
  });

  final BankRules bank;
  final bool isConnected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isConnected ? _FintechColors.lilacBg : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 18,
              color: isConnected ? _FintechColors.lilacText : _FintechColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bank.displayName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _FintechColors.textPrimary,
                  ),
                ),
                Text(
                  isConnected ? 'Notifikasi aktif' : 'Dinonaktifkan',
                  style: TextStyle(
                    fontSize: 11,
                    color: isConnected ? _FintechColors.green : _FintechColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isConnected,
            activeTrackColor: _FintechColors.purple,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL SHEET TAMBAH / UBAH BON
// ─────────────────────────────────────────────────────────────────────────────

/// Modal Sheet pencatatan Bon
class BonSheet extends StatefulWidget {
  const BonSheet({
    super.key,
    required this.repository,
    this.existing,
  });

  final LedgerRepository repository;
  final Bon? existing;

  static Future<void> show(
    BuildContext context,
    LedgerRepository repository, {
    Bon? existing,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BonSheet(
        repository: repository,
        existing: existing,
      ),
    );
  }

  @override
  State<BonSheet> createState() => _BonSheetState();
}

class _BonSheetState extends State<BonSheet> {
  late final TextEditingController _personCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late BonDirection _direction;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _personCtrl = TextEditingController(text: e?.person ?? '');
    _amountCtrl = TextEditingController(
      text: e != null ? Money.format(e.amount).replaceAll('Rp', '') : '',
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _direction = e?.direction ?? BonDirection.lent;
    _date = e?.occurredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final person = _personCtrl.text.trim();
    final amount = Money.tryParseGroup(_amountCtrl.text) ?? 0;
    if (person.isEmpty || amount <= 0) return;

    if (widget.existing != null) {
      await widget.repository.updateBon(
        widget.existing!.id,
        BonsCompanion(
          person: Value(person),
          amount: Value(amount),
          direction: Value(_direction),
          occurredAt: Value(_date),
          note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
        ),
      );
    } else {
      await widget.repository.addBon(
        person: person,
        amount: amount,
        direction: _direction,
        occurredAt: _date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.existing != null ? 'Ubah Catatan Bon' : 'Catat Bon Baru',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _FintechColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Selector Jenis Bon: Dipinjamkan (Piutang) vs Dipinjam (Utang)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _direction = BonDirection.lent),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _direction == BonDirection.lent
                            ? _FintechColors.green
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Dipinjamkan (Piutang)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _direction == BonDirection.lent
                              ? Colors.white
                              : _FintechColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _direction = BonDirection.borrowed),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _direction == BonDirection.borrowed
                            ? _FintechColors.red
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Dipinjam (Utang)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _direction == BonDirection.borrowed
                              ? Colors.white
                              : _FintechColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Input Nama Pihak
          TextField(
            controller: _personCtrl,
            decoration: InputDecoration(
              labelText: 'Nama Pihak (Orang / Teman)',
              labelStyle: const TextStyle(fontSize: 13, color: _FintechColors.textSecondary),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Input Nominal
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              prefixText: 'Rp ',
              labelText: 'Nominal',
              labelStyle: const TextStyle(fontSize: 13, color: _FintechColors.textSecondary),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Input Catatan (opsional)
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: 'Catatan (Opsional)',
              labelStyle: const TextStyle(fontSize: 13, color: _FintechColors.textSecondary),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Tombol Simpan
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _FintechColors.textPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Simpan Catatan Bon',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
