import 'package:bukuduit/core/targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 1, 15);

  test('perMonth = ceil((goal-saved)/bulanSisa), percent 40', () {
    final r = targetPace(
      goal: 10000000,
      saved: 4000000,
      deadline: DateTime(2026, 6, 10),
      now: now,
    );
    expect(r.perMonth, 1000000); // 6jt / 6 bulan (Jan–Jun inklusif)
    expect(r.percent, 40);
  });

  test('tanpa deadline → perMonth null', () {
    final r = targetPace(goal: 10000000, saved: 4000000, now: now);
    expect(r.perMonth, isNull);
    expect(r.percent, 40);
  });

  test('tercapai → perMonth null, percent 100', () {
    final r = targetPace(
      goal: 10000000,
      saved: 10000000,
      deadline: DateTime(2026, 7, 10),
      now: now,
    );
    expect(r.perMonth, isNull);
    expect(r.percent, 100);
  });

  test('deadline sudah lewat → perMonth null', () {
    final r = targetPace(
      goal: 10000000,
      saved: 4000000,
      deadline: DateTime(2025, 12, 31),
      now: now,
    );
    expect(r.perMonth, isNull);
    expect(r.percent, 40);
  });

  test('saved 0 → ceil(goal/bulanSisa)', () {
    final r = targetPace(
      goal: 10000000,
      saved: 0,
      deadline: DateTime(2026, 3, 1),
      now: now,
    );
    expect(r.perMonth, 3333334); // ceil(10jt / 3 bulan: Jan–Mar inklusif)
    expect(r.percent, 0);
  });
}
