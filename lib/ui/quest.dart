import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../theme/quest.dart';
import '../theme/tokens.dart';

/// Komponen visual khas CatatIM Quest: kartu papan-peraga, tombol chunky,
/// chip game, header custom, nav custom. Satu-satunya tempat gaya visual
/// didefinisikan agar tidak ada default Material yang bocor.

// Dipecah ke part files (audit I-01) — satu library, semua nama tetap.
part 'quest/controls.dart';
part 'quest/card.dart';
part 'quest/segmented.dart';
part 'quest/surfaces.dart';
part 'quest/nav.dart';
part 'quest/list.dart';
part 'quest/sheet.dart';
part 'quest/feedback.dart';
part 'quest/keypad.dart';
part 'quest/select.dart';
