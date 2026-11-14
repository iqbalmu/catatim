import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

var disposeCountPage1 = 0;

void main() {
  testWidgets('Inactive tabs preserve state during flight and are not disposed', (tester) async {
    disposeCountPage1 = 0;
    await tester.pumpWidget(
      const MaterialApp(
        home: _TestContainer(),
      ),
    );
    expect(find.text('Page 0'), findsOneWidget);

    // Switch to tab 1
    await tester.tap(find.text('Go to 1'));
    await tester.pumpAndSettle();
    expect(find.text('Page 1 count: 0'), findsOneWidget);

    // Increment counter on Page 1
    await tester.tap(find.text('Increment Page 1'));
    await tester.pump();
    expect(find.text('Page 1 count: 1'), findsOneWidget);

    // Switch to tab 0
    await tester.tap(find.text('Go to 0'));
    await tester.pumpAndSettle();
    expect(find.text('Page 0'), findsOneWidget);

    // Switch to tab 2 (Page 1 is neither 'from' nor 'to')
    await tester.tap(find.text('Go to 2'));
    // In the middle of animation
    await tester.pump(const Duration(milliseconds: 100));
    expect(disposeCountPage1, 0, reason: 'Page 1 must NOT be disposed during flight between 0 and 2');

    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsOneWidget);
    expect(disposeCountPage1, 0, reason: 'Page 1 must NOT be disposed after flight lands');

    // Return to Page 1
    await tester.tap(find.text('Go to 1'));
    await tester.pumpAndSettle();
    // Counter on Page 1 must still be 1!
    expect(find.text('Page 1 count: 1'), findsOneWidget);
    expect(disposeCountPage1, 0);
  });

  testWidgets('Rapid tab switches do not crash or leave inconsistent state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _TestContainer(),
      ),
    );

    // Rapid taps: 1 -> 2 -> 0 without pumpAndSettle
    await tester.tap(find.text('Go to 1'));
    await tester.pump(const Duration(milliseconds: 30));

    await tester.tap(find.text('Go to 2'));
    await tester.pump(const Duration(milliseconds: 30));

    await tester.tap(find.text('Go to 0'));
    await tester.pumpAndSettle();

    expect(find.text('Page 0'), findsOneWidget);
  });
}

class _TestContainer extends StatefulWidget {
  const _TestContainer();

  @override
  State<_TestContainer> createState() => _TestContainerState();
}

class _TestContainerState extends State<_TestContainer> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _index = 0),
                child: const Text('Go to 0'),
              ),
              ElevatedButton(
                onPressed: () => setState(() => _index = 1),
                child: const Text('Go to 1'),
              ),
              ElevatedButton(
                onPressed: () => setState(() => _index = 2),
                child: const Text('Go to 2'),
              ),
            ],
          ),
          Expanded(
            child: _TestTabView(
              index: _index,
              children: const [
                Text('Page 0'),
                _StatefulPage1(),
                Text('Page 2'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatefulPage1 extends StatefulWidget {
  const _StatefulPage1();

  @override
  State<_StatefulPage1> createState() => _StatefulPage1State();
}

class _StatefulPage1State extends State<_StatefulPage1> {
  int counter = 0;

  @override
  void dispose() {
    disposeCountPage1++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Page 1 count: $counter'),
        ElevatedButton(
          onPressed: () => setState(() => counter++),
          child: const Text('Increment Page 1'),
        ),
      ],
    );
  }
}

class _TestTabView extends StatefulWidget {
  const _TestTabView({required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<_TestTabView> createState() => _TestTabViewState();
}

class _TestTabViewState extends State<_TestTabView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final List<GlobalKey> _pageKeys = List.generate(
    widget.children.length,
    (_) => GlobalKey(),
  );

  int _shown = 0;
  ({int from, int to})? _flight;
  Animation<Offset> _outgoingSlide = const AlwaysStoppedAnimation(Offset.zero);
  Animation<Offset> _incomingSlide = const AlwaysStoppedAnimation(Offset.zero);

  @override
  void initState() {
    super.initState();
    _shown = widget.index;
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          final flight = _flight;
          if (flight != null) _shown = flight.to;
          _flight = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TestTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      final target = widget.index;
      final from = _flight?.to ?? _shown;
      if (target != from && target >= 0 && target < widget.children.length) {
        final isForward = target > from;
        _flight = (from: from, to: target);
        _outgoingSlide = Tween<Offset>(
          begin: Offset.zero,
          end: Offset(isForward ? -1.0 : 1.0, 0),
        ).animate(_curved);
        _incomingSlide = Tween<Offset>(
          begin: Offset(isForward ? 1.0 : -1.0, 0),
          end: Offset.zero,
        ).animate(_curved);
        _controller.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      for (var i = 0; i < widget.children.length; i++)
        KeyedSubtree(key: _pageKeys[i], child: widget.children[i]),
    ];
    final flight = _flight;
    if (flight == null) {
      return IndexedStack(
        index: _shown,
        children: pages,
      );
    }
    return Stack(
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (i != flight.from && i != flight.to)
            Offstage(
              child: pages[i],
            ),
        SlideTransition(position: _outgoingSlide, child: pages[flight.from]),
        SlideTransition(position: _incomingSlide, child: pages[flight.to]),
      ],
    );
  }
}
