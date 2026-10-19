import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'capture/pipeline.dart';
import 'game/progress.dart';
import 'rules/rule_set.dart';
import 'storage/repository.dart';
import 'theme/quest.dart';
import 'ui/home_screen.dart';

class BukuduitApp extends StatelessWidget {
  const BukuduitApp({
    super.key,
    required this.repository,
    required this.pipeline,
    required this.progress,
    required this.ruleSet,
  });

  final LedgerRepository repository;
  final CapturePipeline pipeline;
  final ProgressService progress;
  final RuleSet ruleSet;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bukuduit',
      locale: const Locale('id'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id')],
      theme: QuestSchemes.light(),
      darkTheme: QuestSchemes.dark(),
      home: HomeScreen(
        repository: repository,
        pipeline: pipeline,
        progress: progress,
        ruleSet: ruleSet,
      ),
    );
  }
}
