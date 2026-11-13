import 'package:catatim/models.dart';
import 'package:catatim/storage/database.dart';
import 'package:catatim/storage/repository.dart';
import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/laporan_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'LaporanScreen bebas overflow di layar sempit 320px + teks 1.3x dengan nominal ekstrem',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);

      await tester.runAsync(() async {
        final longAcc = await repo.addAccount(
          'Rekening Utama Bank Pembangunan Daerah Panjang Sekali',
          AccountKind.bank,
        );
        final longCat = await repo.addCategory(
          'Belanja Kebutuhan Rumah Tangga Bulanan Super Panjang',
        );
        final categories = await repo.getCategories();

        final now = DateTime.now();
        final thisMonthDay = DateTime(now.year, now.month, 1);
        final prevMonthDay = DateTime(now.year, now.month - 1, 1);

        await repo.addManual(
          amount: 45000000,
          direction: Direction.incoming,
          kind: TxKind.other,
          accountId: longAcc.id,
          categoryId: categories.first.id,
          counterparty: 'Gaji Bulan Lalu',
          occurredAt: prevMonthDay,
        );
        await repo.addManual(
          amount: 12500000,
          direction: Direction.outgoing,
          kind: TxKind.payment,
          accountId: longAcc.id,
          categoryId: longCat.id,
          counterparty: 'Belanja Bulan Lalu',
          occurredAt: prevMonthDay,
        );

        await repo.addManual(
          amount: 987654321,
          direction: Direction.incoming,
          kind: TxKind.other,
          accountId: longAcc.id,
          categoryId: categories.first.id,
          counterparty: 'Penerimaan Proyek Tahunan Perusahaan Nasional',
          occurredAt: thisMonthDay,
        );
        for (var i = 0; i < 6; i++) {
          await repo.addManual(
            amount: 45678900 * (i + 1),
            direction: Direction.outgoing,
            kind: TxKind.payment,
            accountId: longAcc.id,
            categoryId: i.isEven ? longCat.id : categories[i % categories.length].id,
            counterparty:
                'Pembayaran Tagihan Rutin Nomor $i Dengan Nama Merchant Sangat Panjang',
            occurredAt: thisMonthDay,
          );
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: LaporanScreen(repository: repo),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      void assertNoOverflow() {
        final err = tester.takeException();
        if (err != null) {
          fail(
            err is FlutterError
                ? err.diagnostics.map((d) => d.toStringDeep()).join('\n')
                : '$err',
          );
        }
      }

      assertNoOverflow();
      expect(find.text('RINGKASAN ARUS KAS'), findsOneWidget);

      // Gulir ke bagian 02 · Tren Arus Kas
      await tester.drag(find.byType(ListView).first, const Offset(0, -320));
      await tester.pumpAndSettle();
      assertNoOverflow();
      expect(find.text('TREN ARUS KAS'), findsOneWidget);

      // Gulir ke bagian 03 · Komposisi Kategori
      await tester.drag(find.byType(ListView).first, const Offset(0, -360));
      await tester.pumpAndSettle();
      assertNoOverflow();
      expect(find.text('KOMPOSISI KATEGORI'), findsOneWidget);

      // Toggle ke mode Pemasukan & kembali ke Pengeluaran
      await tester.tap(find.textContaining('Pemasukan ('));
      await tester.pumpAndSettle();
      assertNoOverflow();
      await tester.tap(find.textContaining('Pengeluaran ('));
      await tester.pumpAndSettle();
      assertNoOverflow();

      // Gulir ke bagian 04 · Pengeluaran Terbesar
      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pumpAndSettle();
      assertNoOverflow();
      expect(find.text('PENGELUARAN TERBESAR'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await db.close();
      });
    },
  );

  testWidgets(
    'LaporanScreen: Transfer masuk tidak dihitung sebagai pemasukan baru di ringkasan arus kas',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LedgerRepository(db);

      await tester.runAsync(() async {
        final bca = await repo.addAccount('BCA', AccountKind.bank);
        final gopay = await repo.addAccount('GoPay', AccountKind.ewallet);
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, 10);

        // Catat transfer internal: BCA -> GoPay 500k
        await repo.addManualTransfer(
          fromAccountId: bca.id,
          toAccountId: gopay.id,
          amount: 500000,
          occurredAt: day,
        );

        // Catat pemasukan gaji asli: 3.000.000
        await repo.addManual(
          amount: 3000000,
          direction: Direction.incoming,
          kind: TxKind.payment,
          counterparty: 'Gaji Bulanan',
          accountId: bca.id,
          occurredAt: day,
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: QuestSchemes.light(),
          home: Scaffold(
            body: LaporanScreen(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pemasukan harus Rp3.000.000, bukan Rp3.500.000 (transfer 500k tidak boleh masuk)
      expect(find.textContaining('3.000.000'), findsWidgets);
      expect(find.textContaining('3.500.000'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await db.close();
      });
    },
  );
}
