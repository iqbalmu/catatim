import 'package:flutter/material.dart';

import '../storage/database.dart';
import '../storage/repository.dart';
import '../theme/tokens.dart';
import 'quest.dart';

/// Baris chip filter akun horizontal — murni memfilter. Tambah/ubah/hapus
/// akun ada di [AccountManageScreen], bukan di sini.
class AccountFilter extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: repository.watchAccounts(),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <Account>[];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              QuestChip(
                label: 'Semua',
                selected: selectedId == null,
                onTap: () => onChanged(null),
              ),
              for (final a in accounts) ...[
                const SizedBox(width: Spacing.s),
                QuestChip(
                  label: a.name,
                  selected: selectedId == a.id,
                  onTap: () => onChanged(selectedId == a.id ? null : a.id),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
