import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';
import 'package:bukuduit/ui/transaksi_screen.dart';

void main() {
  test('matchesQuery mencocokkan pihak, kategori, bank, nominal', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LedgerRepository(db);
    await repo.addManual(
      amount: 25000,
      direction: Direction.outgoing,
      kind: TxKind.payment,
      counterparty: 'Kopi Kenangan',
    );
    final rows = await repo.watchRecentWithCategory().first;
    final item = rows.single;

    expect(matchesQuery(item, ''), isTrue);
    expect(matchesQuery(item, 'kopi'), isTrue);
    expect(matchesQuery(item, 'KENANGAN'), isTrue);
    expect(matchesQuery(item, 'pembayaran'), isTrue); // label jenis
    expect(matchesQuery(item, 'manual'), isTrue); // bankId + source
    expect(matchesQuery(item, '25000'), isTrue);
    expect(matchesQuery(item, 'sate'), isFalse);

    await db.close();
  });
}
