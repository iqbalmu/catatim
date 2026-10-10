import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'capture/pipeline.dart';
import 'game/progress.dart';
import 'storage/repository.dart';
import 'theme/tokens.dart';
import 'ui/home_screen.dart';

class BukuduitApp extends StatelessWidget {
  const BukuduitApp({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.progress,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final ColorScheme light;
        if (lightDynamic != null) {
          light = lightDynamic.harmonized();
        } else {
          light = ColorScheme.fromSeed(seedColor: SeedColors.seed);
        }
        final ColorScheme dark;
        if (darkDynamic != null) {
          dark = darkDynamic.harmonized();
        } else {
          dark = ColorScheme.fromSeed(
            seedColor: SeedColors.seed,
            brightness: Brightness.dark,
          );
        }
        return MaterialApp(
          title: 'Bukuduit',
          theme: ThemeData(colorScheme: light),
          darkTheme: ThemeData(colorScheme: dark),
          home: HomeScreen(
            repository: repository,
            pipeline: pipeline,
            progress: progress,
          ),
        );
      },
    );
  }
}
