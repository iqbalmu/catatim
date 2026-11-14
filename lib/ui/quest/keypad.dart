part of '../quest.dart';

/// Keypad numerik kustom bergaya Quest: tombol chunky, haptic feedback,
/// dan pintasan nominal (000, C, Backspace, Simpan).
///
/// Dirancang untuk bottom sheet pencatatan transaksi agar tidak memicu
/// soft keyboard Android yang sering menggeser layout layar secara kasar.
class QuestKeypad extends StatelessWidget {
  const QuestKeypad({
    super.key,
    required this.amount,
    required this.onChanged,
    required this.onSave,
    this.maxDigits = 12,
    this.saveLabel = 'Simpan',
  });

  /// Nilai nominal rupiah saat ini.
  final int amount;

  /// Callback perubahan nominal saat tombol angka/hapus ditekan.
  final ValueChanged<int> onChanged;

  /// Aksi simpan saat tombol 'Simpan' ditekan (hanya aktif jika [amount] > 0).
  final VoidCallback? onSave;

  /// Batas digit nominal (default 12 digit = ≤ Rp999.999.999.999).
  final int maxDigits;

  /// Label pada tombol simpan (mis. 'Simpan' atau 'Catat').
  final String saveLabel;

  void _appendDigit(int digit) {
    final next = amount == 0 ? digit : amount * 10 + digit;
    if (next.toString().length > maxDigits) return;
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  void _backspace() {
    if (amount == 0) return;
    HapticFeedback.selectionClick();
    onChanged(amount ~/ 10);
  }

  void _appendThousands() {
    if (amount == 0) return;
    final next = amount * 1000;
    if (next.toString().length > maxDigits) return;
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  void _clear() {
    if (amount == 0) return;
    HapticFeedback.selectionClick();
    onChanged(0);
  }

  Widget _keyCell(
    BuildContext context, {
    String? label,
    IconData? icon,
    String? tooltip,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    int flex = 1,
  }) {
    final q = context.q;
    final cell = Container(
      height: 50,
      decoration: BoxDecoration(
        color: q.surface2,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: q.line),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: 20, color: q.text)
          : Text(
              label!,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: q.text,
              ),
            ),
    );
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xs),
        child: Semantics(
          button: true,
          label: tooltip ?? label,
          child: QuestPress(
            onTap: onTap,
            onLongPress: onLongPress,
            child: cell,
          ),
        ),
      ),
    );
  }

  Widget _saveCell(BuildContext context) {
    final q = context.q;
    final enabled = amount > 0 && onSave != null;
    final fg = enabled ? q.onPrimary : q.muted;
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xs),
        child: Semantics(
          button: true,
          enabled: enabled,
          label: saveLabel,
          child: QuestPress(
            onTap: enabled ? onSave : null,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: enabled ? q.primarySolid : q.surface2,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                boxShadow: enabled ? q.cardShadow : null,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 20, color: fg),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    saveLabel,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _keyCell(context, label: '1', onTap: () => _appendDigit(1)),
            _keyCell(context, label: '2', onTap: () => _appendDigit(2)),
            _keyCell(context, label: '3', onTap: () => _appendDigit(3)),
            _keyCell(
              context,
              icon: Icons.backspace_outlined,
              tooltip: 'Hapus satu digit',
              onTap: _backspace,
              onLongPress: _clear,
            ),
          ],
        ),
        Row(
          children: [
            _keyCell(context, label: '4', onTap: () => _appendDigit(4)),
            _keyCell(context, label: '5', onTap: () => _appendDigit(5)),
            _keyCell(context, label: '6', onTap: () => _appendDigit(6)),
            _keyCell(
              context,
              label: '000',
              tooltip: 'Tambah tiga nol',
              onTap: _appendThousands,
            ),
          ],
        ),
        Row(
          children: [
            _keyCell(context, label: '7', onTap: () => _appendDigit(7)),
            _keyCell(context, label: '8', onTap: () => _appendDigit(8)),
            _keyCell(context, label: '9', onTap: () => _appendDigit(9)),
            _keyCell(
              context,
              label: 'C',
              tooltip: 'Kosongkan nominal',
              onTap: _clear,
            ),
          ],
        ),
        Row(
          children: [
            _keyCell(
              context,
              label: '0',
              flex: 2,
              onTap: () => _appendDigit(0),
            ),
            _saveCell(context),
          ],
        ),
      ],
    );
  }
}
