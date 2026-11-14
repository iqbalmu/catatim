import 'package:catatim/theme/quest.dart';
import 'package:catatim/ui/quest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresi: QuestHeader overflow 2px dengan judul+subjudul (46px konten
/// di slot 44px, temuan device: halaman Notifikasi).
void main() {
  for (final scale in <double>[1.0, 1.3, 2.0]) {
    testWidgets(
      'QuestHeader judul+subjudul @ 320px teks ${scale}x tak overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d);
        await tester.pumpWidget(
          MaterialApp(
            theme: QuestSchemes.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                appBar: QuestHeader(
                  textScale: scale,
                  title: 'Notifikasi',
                  subtitle: 'Pusat perhatian & pengingat',
                  showBack: true,
                ),
                body: const SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.pump();
        FlutterError.onError = prev;

        final overflows = errors
            .map((e) => e.exception.toString())
            .where((s) => s.contains('overflowed'))
            .toList();
        expect(overflows, isEmpty);
        expect(find.text('Notifikasi'), findsOneWidget);
      },
    );
  }
}
