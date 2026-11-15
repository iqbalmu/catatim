import 'package:catatim/models.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/ui/bon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Bon bon({
  DateTime? occurredAt,
  DateTime? dueDate,
  DateTime? settledAt,
}) => Bon(
  id: 1,
  uuid: 'u1',
  person: 'Budi',
  amount: 50000,
  direction: BonDirection.lent,
  occurredAt: occurredAt ?? DateTime(2026, 11, 1, 9),
  dueDate: dueDate,
  settledAt: settledAt,
  createdAt: DateTime(2026, 11, 1, 9),
);

DateTime day(int offsetFromNov15) => DateTime(2026, 11, 15 + offsetFromNov15);
final hariIni = DateTime(2026, 11, 15, 12);

void main() {
  group('bonNeedsBadge', () {
    test('lunas tidak pernah ditandai', () {
      expect(
        bonNeedsBadge(
          bon(settledAt: hariIni, occurredAt: DateTime(2026, 1, 1, 9)),
          now: hariIni,
        ),
        isFalse,
      );
    });

    test('tanpa due date: umur >30 hari ditandai', () {
      expect(
        bonNeedsBadge(bon(occurredAt: DateTime(2026, 10, 1, 9)), now: hariIni),
        isTrue,
      );
      expect(
        bonNeedsBadge(bon(occurredAt: DateTime(2026, 11, 10, 9)), now: hariIni),
        isFalse,
      );
    });

    test('due date hari ini masih aman, kemarin lewat', () {
      expect(bonNeedsBadge(bon(dueDate: day(0)), now: hariIni), isFalse);
      expect(bonNeedsBadge(bon(dueDate: day(-1)), now: hariIni), isTrue);
      expect(bonNeedsBadge(bon(dueDate: day(3)), now: hariIni), isFalse);
    });

    test('due date menang atas umur 30 hari', () {
      // Bon tua (60 hari) tapi due date masih jauh → tidak ditandai.
      expect(
        bonNeedsBadge(
          bon(occurredAt: DateTime(2026, 9, 15, 9), dueDate: day(5)),
          now: hariIni,
        ),
        isFalse,
      );
    });
  });

  group('bonDueChip', () {
    test('lunas / tanpa due date → null', () {
      expect(bonDueChip(bon(settledAt: hariIni), Colors.orange, Colors.red, now: hariIni), isNull);
      expect(bonDueChip(bon(), Colors.orange, Colors.red), isNull);
    });

    test('lewat 1 hari dan lewat beberapa hari', () {
      final lewatSatu = bonDueChip(bon(dueDate: day(-1)), Colors.orange, Colors.red, now: hariIni);
      expect(lewatSatu!.label, 'Lewat 1 hari');
      expect(lewatSatu.color, Colors.red);
      final lewatTiga = bonDueChip(bon(dueDate: day(-3)), Colors.orange, Colors.red, now: hariIni);
      expect(lewatTiga!.label, 'Lewat 3 hari');
    });

    test('hari ini warna peringatan, mendatang netral', () {
      final hariIniChip = bonDueChip(bon(dueDate: day(0)), Colors.orange, Colors.red, now: hariIni);
      expect(hariIniChip!.label, 'Jatuh tempo hari ini');
      expect(hariIniChip.color, Colors.orange);
      final mendatang = bonDueChip(bon(dueDate: day(2)), Colors.orange, Colors.red, now: hariIni);
      expect(mendatang!.label, 'Jatuh tempo 17 Nov');
      expect(mendatang.color, isNull);
    });
  });
}
