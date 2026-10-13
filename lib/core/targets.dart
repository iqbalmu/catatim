/// Engine laju setoran target (murni, tanpa dependensi Flutter/drift).
library;

/// Hasil perhitungan laju setoran.
typedef TargetPace = ({int? perMonth, int percent});

/// Laju setoran bulanan menuju target.
///
/// - [percent] = progres tabungan terhadap goal (0–100).
/// - [perMonth] null bila [deadline] null, sudah lewat, atau target tercapai;
///   selain itu ceil((goal - saved) / bulanSisa), bulan dihitung dari bulan
///   `now` sampai bulan `deadline` inklusif (min 1).
TargetPace targetPace({
  required int goal,
  required int saved,
  DateTime? deadline,
  DateTime? now,
}) {
  final percent = goal <= 0 ? 0 : ((saved / goal) * 100).clamp(0, 100).round();
  final now_ = now ?? DateTime.now();
  final bulanSisa = deadline == null || !deadline.isAfter(now_) || saved >= goal
      ? null
      : (deadline.year - now_.year) * 12 + deadline.month - now_.month + 1;
  return (
    perMonth: bulanSisa == null
        ? null
        : ((goal - saved) / bulanSisa).ceil(),
    percent: percent,
  );
}
