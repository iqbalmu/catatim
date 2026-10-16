import 'dart:async';

import 'package:flutter/material.dart';

import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Baris chip filter akun horizontal — murni memfilter. Tambah/ubah/hapus
/// akun ada di [AccountManageScreen], bukan di sini.
class AccountFilter extends StatefulWidget {
  const AccountFilter({
    super.key,
    required this.repository,
    required this.selectedId,
    required this.onChanged,
  });

  final LedgerRepository repository;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  State<AccountFilter> createState() => _AccountFilterState();
}

class _AccountFilterState extends State<AccountFilter> {
  // Disematkan sekali agar rebuild tak subscribe ulang (anti-kedip).
  late final Stream<List<Account>> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = widget.repository.watchAccounts();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: _accounts,
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <Account>[];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              QuestChip(
                label: 'Semua',
                selected: widget.selectedId == null,
                onTap: () => widget.onChanged(null),
              ),
              for (final a in accounts) ...[
                const SizedBox(width: Spacing.s),
                QuestChip(
                  label: a.name,
                  selected: widget.selectedId == a.id,
                  onTap: () => widget.onChanged(
                    widget.selectedId == a.id ? null : a.id,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
