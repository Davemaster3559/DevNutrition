import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/home/presentation/widgets/dashboard_widget.dart';
import 'package:opennutritracker/features/quick_log/data/quick_log_repository.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';
import 'package:opennutritracker/features/quick_log/presentation/goals_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

class _FakeConfig extends Fake implements ConfigDataSource {
  @override
  Future<ConfigDBO> getConfig() async => ConfigDBO.empty();
}

class _FakeQuickLog extends Fake implements QuickLogRepository {
  @override
  ConfigDataSource get config => _FakeConfig();
  @override
  Future<DevNutritionPreferences> preferences() async =>
      const DevNutritionPreferences();
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => EnergyUnitProvider(usesKilojoules: false),
    child: MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  setUp(() {
    locator.registerSingleton<QuickLogRepository>(_FakeQuickLog());
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  testWidgets(
    'kcal gauge exposes a semantic tap action that opens the goal screen '
    '(regression: excludeSemantics stripped the GestureDetector tap, so '
    'screen readers announced a button that could not be activated)',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(500, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          const DashboardWidget(
            totalKcalSupplied: 800,
            totalKcalBurned: 200,
            totalKcalDaily: 2500,
            totalKcalLeft: 1900,
            totalCarbsIntake: 100,
            totalFatsIntake: 30,
            totalProteinsIntake: 60,
            totalCarbsGoal: 375,
            totalFatsGoal: 69,
            totalProteinsGoal: 93,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gaugeFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.identifier == 'home-kcal-gauge',
      );
      expect(gaugeFinder, findsOneWidget);

      final node = tester.getSemantics(gaugeFinder);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason:
            'excludeSemantics drops the GestureDetector\'s tap action, '
            'so the Semantics node must register its own onTap',
      );

      // Activate the node the way TalkBack/VoiceOver do — via the semantic
      // action, not a pointer tap.
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();

      expect(find.byType(GoalsScreen), findsOneWidget);
      expect(find.text('1700'), findsOneWidget);

      semanticsHandle.dispose();
    },
  );
}
