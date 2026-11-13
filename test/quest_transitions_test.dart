import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catatim/theme/quest.dart';

void main() {
  testWidgets('QuestPageTransitionsBuilder pushes and pops with parallax and without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _ParallaxQuestPageTransitionsBuilder(),
            },
          ),
        ),
        home: const Scaffold(
          body: Center(child: Text('Screen A')),
        ),
      ),
    );

    expect(find.text('Screen A'), findsOneWidget);

    // Push Screen B
    final context = tester.element(find.text('Screen A'));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Screen B')),
        ),
      ),
    );

    await tester.pump(); // Start push transition
    await tester.pump(const Duration(milliseconds: 100)); // Halfway

    // Check positions during transition: Screen B should be sliding in (>0 offset)
    // Screen A should be slightly shifted to the left (<0 offset)
    final aPos = tester.getTopLeft(find.text('Screen A'));
    final bPos = tester.getTopLeft(find.text('Screen B'));
    expect(aPos.dx, lessThan(400)); // shifted left from center
    expect(bPos.dx, greaterThan(0)); // entering from right

    // Complete push
    await tester.pumpAndSettle();
    expect(find.text('Screen B'), findsOneWidget);

    // Pop Screen B
    final bContext = tester.element(find.text('Screen B'));
    Navigator.pop(bContext);

    await tester.pump(); // Start pop transition
    await tester.pump(const Duration(milliseconds: 100)); // Halfway
    expect(find.text('Screen A'), findsOneWidget);
    expect(find.text('Screen B'), findsOneWidget);

    // Complete pop
    await tester.pumpAndSettle();
    expect(find.text('Screen A'), findsOneWidget);
    expect(find.text('Screen B'), findsNothing);
  });

  testWidgets(
    'reduce motion: QuestPageTransitionsBuilder memotong instan (audit M-01)',
    (tester) async {
      Widget buildApp({required bool reduced}) => MaterialApp(
            key: ValueKey('reduced-$reduced'),
            theme: ThemeData(
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: QuestPageTransitionsBuilder(),
                },
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('Screen A'))),
          );

      // Kontrol: normal → transisi slide hadir.
      await tester.pumpWidget(buildApp(reduced: false));
      Navigator.push(
        tester.element(find.text('Screen A')),
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('Screen B'))),
        ),
      );
      await tester.pump();
      expect(find.byType(SlideTransition), findsWidgets);
      await tester.pumpAndSettle();

      // Reduce motion → tanpa slide/parallax; halaman langsung tampil.
      await tester.pumpWidget(buildApp(reduced: true));
      Navigator.push(
        tester.element(find.text('Screen A')),
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('Screen B'))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SlideTransition), findsNothing);
      expect(find.text('Screen B'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class _ParallaxQuestPageTransitionsBuilder extends PageTransitionsBuilder {
  const _ParallaxQuestPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slideIn = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).chain(CurveTween(curve: QuestMotion.easeOut));

    final parallaxOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.25, 0),
    ).chain(CurveTween(curve: QuestMotion.easeOut));

    return SlideTransition(
      position: secondaryAnimation.drive(parallaxOut),
      child: SlideTransition(
        position: animation.drive(slideIn),
        child: child,
      ),
    );
  }
}
