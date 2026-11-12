import 'package:bukuduit/game/progress.dart';
import 'package:bukuduit/models.dart';
import 'package:bukuduit/storage/database.dart';
import 'package:bukuduit/storage/repository.dart';
import 'package:bukuduit/theme/quest.dart';
import 'package:bukuduit/ui/transaction_tile.dart';
import 'package:bukuduit/ui/transaksi_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TransaksiScreen: merender flattened list dengan header hari & transaksi individual', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LedgerRepository(db);
    final progress = ProgressService(repository: repo);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10, 0);
    final yesterday = today.subtract(const Duration(days: 1));

    final acc = await repo.addAccount('BCA', AccountKind.bank);
    final categories = await repo.getCategories();
    final catMakan = categories.firstWhere((c) => c.name == 'Makanan');
    final catGaji = categories.firstWhere((c) => c.name == 'Gaji');

    // Hari 1: 2 transaksi
    await repo.addManual(
      accountId: acc.id,
      categoryId: catGaji.id,
      amount: 4000000,
      direction: Direction.incoming,
      occurredAt: today,
      kind: TxKind.other,
      counterparty: 'Transfer Masuk Klien',
    );
    await repo.addManual(
      accountId: acc.id,
      categoryId: catMakan.id,
      amount: 50000,
      direction: Direction.outgoing,
      occurredAt: today,
      kind: TxKind.payment,
      counterparty: 'Makan Siang',
    );

    // Hari 2: 1 transaksi
    await repo.addManual(
      accountId: acc.id,
      categoryId: catMakan.id,
      amount: 35000,
      direction: Direction.outgoing,
      occurredAt: yesterday,
      kind: TxKind.payment,
      counterparty: 'Kopi Pagi',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransaksiScreen(
            repository: repo,
            progress: progress,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi keberadaan TransactionDayHeader individual
    expect(find.byType(TransactionDayHeader), findsNWidgets(2));

    // Verifikasi keberadaan TransactionTile individual
    expect(find.byType(TransactionTile), findsNWidgets(3));

    // Verifikasi teks transaksi
    expect(find.text('Transfer Masuk Klien'), findsOneWidget);
    expect(find.text('Makan Siang'), findsOneWidget);
    expect(find.text('Kopi Pagi'), findsOneWidget);

    // Verifikasi ringkasan pemasukan & pengeluaran bulanan.
    // Tanda arah digambar terpisah dari nominal sebagai marker minimalis,
    // jadi tidak lagi menyatu dalam satu string.
    expect(find.text('Rp4.000.000'), findsNWidgets(2));
    expect(find.text('Rp85.000'), findsOneWidget);
    expect(find.text('+'), findsWidgets);
    expect(find.text('−'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  });

  testWidgets(
    'TransaksiScreen: daftar > 8 transaksi semua terbungkus animasi berurut dari atas ke bawah',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);
      final progress = ProgressService(repository: repo);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12, 0);

      final acc = await repo.addAccount('BCA', AccountKind.bank);
      final categories = await repo.getCategories();
      final cat = categories.first;

      // Buat 12 transaksi di hari yang sama sehingga flatItems ada 1 day header + 12 tile = 13 items
      for (var i = 0; i < 12; i++) {
        await repo.addManual(
          accountId: acc.id,
          categoryId: cat.id,
          amount: 10000 + i * 1000,
          direction: Direction.outgoing,
          occurredAt: today.subtract(Duration(minutes: i * 5)),
          kind: TxKind.payment,
          counterparty: 'Item Belanja $i',
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransaksiScreen(
              repository: repo,
              progress: progress,
            ),
          ),
        ),
      );
      // Pump initial frame agar StreamBuilder mendapat data
      await tester.pump();

      // Verifikasi seluruh 12 transaksi + 1 header ter-render dalam viewport
      expect(find.byType(TransactionTile), findsNWidgets(12));

      // Verifikasi bahwa item ke-8, 9, 10, dst (yang dulu di-skip karena if (i >= 8))
      // kini semuanya berada di dalam QuestTabEnter
      final tile11 = find.widgetWithText(TransactionTile, 'Item Belanja 11');
      expect(tile11, findsOneWidget);
      expect(
        find.ancestor(of: tile11, matching: find.byType(QuestTabEnter)),
        findsOneWidget,
      );

      // Verifikasi urutan animasi:
      // Di 360ms:
      // Item 0 (index 5 -> delay 325ms) sudah mulai memudar masuk,
      // sedangkan item 11 (index 16 -> delay 1040ms, di bawah dekat navbar)
      // masih menunggu giliran (opacity == 0.0), TIDAK langsung tampil!
      await tester.pump(const Duration(milliseconds: 360));

      // Dapatkan Opacity widget di dalam QuestTabEnter untuk item 0 vs item 11
      final tile0 = find.widgetWithText(TransactionTile, 'Item Belanja 0');
      final opacityTile0 = tester.widget<FadeTransition>(
        find.descendant(
          of: find.ancestor(of: tile0, matching: find.byType(QuestTabEnter)).first,
          matching: find.byType(FadeTransition),
        ).first,
      );
      final opacityTile11 = tester.widget<FadeTransition>(
        find.descendant(
          of: find.ancestor(of: tile11, matching: find.byType(QuestTabEnter)).first,
          matching: find.byType(FadeTransition),
        ).first,
      );

      // Item 0 sudah mulai muncul
      expect(opacityTile0.opacity.value, greaterThan(0.0));
      // Item 11 di bawah dekat navbar masih antre (belum langsung tampil)
      expect(opacityTile11.opacity.value, equals(0.0));

      await tester.pumpAndSettle();

      // Setelah animasi selesai, semua item ber-opacity 1.0
      final finalOpacityTile11 = tester.widget<FadeTransition>(
        find.descendant(
          of: find.ancestor(of: tile11, matching: find.byType(QuestTabEnter)).first,
          matching: find.byType(FadeTransition),
        ).first,
      );
      expect(finalOpacityTile11.opacity.value, equals(1.0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await db.close();
    },
  );
}
