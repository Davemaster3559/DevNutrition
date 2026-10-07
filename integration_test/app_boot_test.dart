import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:opennutritracker/features/onboarding/onboarding_screen.dart';
import 'package:opennutritracker/features/onboarding/presentation/onboarding_intro_page_body.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/main.dart' as app;
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/features/quick_log/data/quick_log_repository.dart';
import 'package:opennutritracker/features/quick_log/presentation/quick_log_screen.dart';
import 'package:opennutritracker/features/quick_log/presentation/meal_log_sheet.dart';

/// Single-boot smoke for the whole first-run path. Everything here shares
/// one `app.main()` deliberately: `initLocator()` registers its GetIt
/// singletons without a re-registration guard, so a second `app.main()` in
/// the same process would throw. Keeping the checks in one boot (rather than
/// several test files) is what lets the suite run unsharded — a single
/// `flutter test integration_test/` per platform that pays the build and
/// simulator cost once.
///
/// The assertions cover three failure surfaces that cascade from that boot:
///   - boot health: `main()` finishes and lands a MaterialApp, and nothing
///     trips `FlutterError.onError` along the way. The first catches loud
///     failures (Hive can't open, secure storage can't derive its AES key,
///     Supabase init throws, a missing GetIt dependency); the second catches
///     quiet ones (a Hive type-id collision, a dropped `await` in plugin
///     init, a half-broken notification re-register) that leave something
///     half-initialised without crashing the visible screen.
///   - routing: a fresh install has no user data, so `hasUserData()` returns
///     false and the router lands on OnboardingScreen with IntroductionScreen
///     mounted (which only happens once OnboardingBloc reaches its loaded
///     state).
///   - localisation: the intl delegates load and the `appDescription` ARB
///     entry reaches the intro page body and renders, in whichever locale
///     the device is set to. On an English device the copy itself is pinned,
///     so a wording change forces this test to be updated alongside it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android daily workflows: onboarding, goals, cooking, foods, recipes, diary and trends',
    (WidgetTester tester) async {
      final caught = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        caught.add(details);
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);

      await app.main();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );

      // Boot health.
      expect(
        find.byType(MaterialApp),
        findsOneWidget,
        reason: 'app should reach a MaterialApp',
      );
      expect(
        caught,
        isEmpty,
        reason:
            'no Flutter errors should fire during boot, got: '
            '${caught.map((e) => e.exception).toList()}',
      );

      // Routing: with no user data, the first screen is onboarding.
      expect(
        find.byType(OnboardingScreen),
        findsOneWidget,
        reason: 'with no user data, the first screen should be onboarding',
      );

      // Bloc state: IntroductionScreen mounts only after the bloc reaches
      // OnboardingLoadedState.
      expect(
        find.byType(IntroductionScreen),
        findsOneWidget,
        reason: 'OnboardingBloc should transition into loaded state',
      );

      // Localisation: the delegates resolved and the appDescription ARB entry
      // reached the intro page body. Looked up for whichever locale the app
      // resolved to, so the test passes on a device set to any supported
      // language; asserting a hardcoded English string here failed on, say,
      // a German phone even though nothing was wrong.
      final introContext = tester.element(find.byType(OnboardingIntroPageBody));
      final localizedDescription = S.of(introContext).appDescription;
      expect(
        localizedDescription,
        isNotEmpty,
        reason:
            'appDescription should be translated for '
            '${S.of(introContext).localeName}',
      );
      expect(
        find.text(localizedDescription),
        findsOneWidget,
        reason: 'the localised appDescription should render on the intro page',
      );

      // On an English device, also pin the copy itself: a verbatim copy of the
      // English ARB entry, so a wording change has to be made here too. CI
      // runs English, which is where this half earns its keep.
      if (S.of(introContext).localeName.startsWith('en')) {
        const appDescriptionEn =
            'DevNutrition is a free and open-source calorie and '
            'nutrient tracker that respects your privacy.';
        expect(
          localizedDescription,
          appDescriptionEn,
          reason: 'the English appDescription copy changed',
        );
      }

      Finder id(String value) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == value,
      );
      Future<void> settle() async {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        expect(tester.takeException(), isNull);
      }

      Future<void> tapId(String value) async {
        if (id(value).evaluate().isEmpty && value != 'trends-log-weight') {
          await tester.scrollUntilVisible(
            id(value),
            value.startsWith('quick-') || value.startsWith('home-')
                ? -400
                : 400,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 40,
          );
          await settle();
        }
        if (value == 'trends-log-weight' && id(value).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            id(value),
            400,
            scrollable: find.byType(Scrollable).last,
            maxScrolls: 30,
          );
          await settle();
        }
        final target = id(value).hitTestable();
        if (target.evaluate().isEmpty) {
          await tester.ensureVisible(id(value).first);
          await settle();
        }
        expect(
          id(value).hitTestable(),
          findsWidgets,
          reason: '$value must be reachable',
        );
        await tester.tap(id(value).hitTestable().first);
        await settle();
      }

      Future<void> enterId(String value, String text) async {
        if (id(value).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            id(value),
            value == 'quick-search' ? -500 : 400,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 50,
          );
          await settle();
        }
        await tester.ensureVisible(id(value).first);
        await settle();
        final input = find.descendant(
          of: id(value).first,
          matching: find.byType(TextField),
        );
        await tester.enterText(input.first, text);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle();
      }

      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      Future<void> enterLabel(String label, String value) async {
        if (field(label).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            field(label),
            400,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 40,
          );
          await settle();
        }
        await tester.ensureVisible(field(label).first);
        await settle();
        await tester.enterText(field(label).first, value);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle();
      }

      Future<void> back() async {
        await tester.pageBack();
        await settle();
      }

      Future<void> openMeal(String name) async {
        final tile = find
            .ancestor(of: find.text(name), matching: find.byType(ListTile))
            .first;
        await tester.ensureVisible(tile);
        await settle();
        await tester.tap(tile);
        await settle();
        expect(find.byType(MealLogSheet), findsOneWidget);
      }

      final quick = locator<QuickLogRepository>();
      debugPrint('CHECKPOINT: fresh onboarding');
      await tapId('onboarding-checkbox-privacy');
      await tapId('onboarding-button');
      await tapId('onboarding-gender-genderMale');
      await tapId('onboarding-birthday-field');
      await tester.tap(find.byTooltip('Switch to input'));
      await settle();
      await tester.enterText(find.byType(TextField).last, '01/01/1990');
      await tester.tap(find.text('OK'));
      await settle();
      await tapId('onboarding-button');
      await tester.tap(find.text('cm').last);
      await settle();
      final kg = find.descendant(
        of: id('onboarding-body-weight-unit'),
        matching: find.text('kg'),
      );
      await tester.ensureVisible(kg);
      await tester.tap(kg);
      await settle();
      await enterId('onboarding-height-field', '175');
      await enterId('onboarding-weight-field', '90');
      await enterId('onboarding-target-weight-field', '80');
      await tapId('onboarding-button');
      await tapId('onboarding-activity-low');
      await tapId('onboarding-button');
      await tapId('onboarding-goal-lose');
      await tapId('onboarding-button');
      await tapId('onboarding-button');
      expect(find.text('120 g'), findsWidgets);
      await tapId('onboarding-button');
      expect(await locator<UserRepository>().hasUserData(), isTrue);
      expect((await quick.preferences()).calorieGoal, 1700);
      expect((await quick.preferences()).proteinGoal, 120);
      final acknowledge = find.text(
        S
            .of(tester.element(find.byType(Scaffold).first))
            .disclaimerAcknowledgeLabel,
      );
      if (acknowledge.evaluate().isNotEmpty) {
        await tester.tap(acknowledge);
        await settle();
      }
      await tapId('home-quick-log');
      expect(find.byType(QuickLogScreen), findsOneWidget);

      debugPrint('CHECKPOINT: editable fixed goals and seeded presets');
      await tapId('quick-goals');
      await enterId('goal-0', '1800');
      await enterId('goal-1', '125');
      await tapId('goals-save');
      expect((await quick.preferences()).calorieGoal, 1800);
      expect((await quick.preferences()).proteinGoal, 125);
      expect((await quick.preferences()).eatBackExercise, isFalse);
      for (final recipeId in [
        'dev:banana-shake',
        'dev:fruit-a',
        'dev:fruit-b',
        'dev:oats',
      ]) {
        final recipe = quick.recipes.getRecipeById(recipeId)!;
        await openMeal(recipe.name);
        await tapId('log-confirm');
      }
      expect((await quick.intakes.getAllIntakesDBO()), hasLength(4));

      debugPrint('CHECKPOINT: calibrated atta cup and per-roti logging');
      await tapId('quick-roti');
      await enterId('batch-dry-amount', '0.75');
      await enterId('batch-cup-grams', '123');
      await enterId('batch-portions-produced', '6');
      await enterId('batch-eat-amount', '2');
      await enterId('batch-save-name', 'Test atta roti');
      await tapId('batch-log');
      expect((await quick.preferences()).measures['168893']!['cup'], 123);
      final roti = (await quick.intakes.getAllIntakesDBO())
          .map(IntakeEntity.fromIntakeDBO)
          .singleWhere((i) => i.meal.name == 'Test atta roti');
      expect(roti.displayedAmount, closeTo(2, 1e-8));
      expect(roti.displayUnit, 'roti');

      debugPrint('CHECKPOINT: raw rice and one third of batch');
      await tapId('quick-rice');
      await tester.tap(
        find.descendant(of: id('batch-dry-unit'), matching: find.text('g')),
      );
      await settle();
      await enterId('batch-dry-amount', '180');
      await enterId('batch-portions-produced', '4');
      await tester.ensureVisible(find.text('1/3'));
      await tester.tap(find.text('1/3'));
      await settle();
      await enterId('batch-save-name', 'Test rice');
      await tapId('batch-log');
      final rice = (await quick.intakes.getAllIntakesDBO()).singleWhere(
        (i) => i.meal.name == 'Test rice',
      );
      expect(rice.amount, closeTo(60, 1e-8));

      debugPrint('CHECKPOINT: local reference search and normal food');
      await enterId('quick-search', 'banana');
      final banana = (await quick.catalogue.search('banana')).first;
      await openMeal(banana.name!);
      await enterId('log-amount', '120');
      await tapId('log-unit');
      await tester.tap(find.text('g').last);
      await settle();
      await tapId('log-confirm');
      await enterId('quick-search', '');

      debugPrint('CHECKPOINT: custom label create/edit');
      await tapId('quick-more');
      await tester.tap(find.text('New food / product label'));
      await settle();
      await enterLabel('Meal name', 'Test label yogurt');
      await enterLabel('Energy (kcal)', '100');
      await enterLabel('Protein', '15');
      await tapId('edit-meal-save');
      final custom = (await quick.savedFoods()).singleWhere(
        (f) => f.name == 'Test label yogurt',
      );
      expect(custom.nutriments.energyKcal100, 100);
      expect(custom.nutriments.carbohydrates100, isNull);
      await enterId('quick-search', 'Test label yogurt');
      final tile = find
          .ancestor(
            of: find.text('Test label yogurt'),
            matching: find.byType(ListTile),
          )
          .first;
      await tester.ensureVisible(tile);
      await tester.tap(
        find.descendant(
          of: tile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await settle();
      await tester.tap(find.text('Save / edit product label'));
      await settle();
      await enterLabel('Protein', '16');
      await tapId('edit-meal-save');
      expect(
        (await quick.savedFoods())
            .singleWhere((f) => f.name == 'Test label yogurt')
            .nutriments
            .proteins100,
        16,
      );
      await openMeal('Test label yogurt');
      await tapId('log-confirm');
      await enterId('quick-search', '');

      debugPrint('CHECKPOINT: curry recipe with estimated katori yield');
      await tapId('quick-more');
      await tester.tap(find.text('New recipe'));
      await settle();
      await enterLabel('Recipe name', 'Test homemade curry');
      await enterLabel('Number of portions / bowls in the batch', '4');
      await tester.ensureVisible(find.text('Add Ingredient'));
      await tester.tap(find.text('Add Ingredient'));
      await settle();
      await tester.tap(find.text('Food').last);
      await settle();
      await enterId('meal-search-field', 'kidney');
      await tester.pump(const Duration(seconds: 1));
      await settle();
      final rajma = (await quick.catalogue.all()).singleWhere(
        (f) => f.code == '173744',
      );
      final ingredient = find
          .byWidgetPredicate(
            (w) =>
                w is RichText && w.text.toPlainText().startsWith(rajma.name!),
          )
          .first;
      await tester.ensureVisible(ingredient);
      await tester.tap(ingredient);
      await settle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await settle();
      if (find.text('g').evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.text('g'),
          -250,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 20,
        );
        await settle();
      }
      await tester.tap(find.text('g').last);
      await settle();
      await tester.enterText(find.byType(TextField).last, '400');
      await tester.tap(find.text('Add').last);
      await settle();
      await tapId('recipe-builder-save');
      await enterId('quick-search', 'Test homemade curry');
      await openMeal('Test homemade curry');
      await enterId('log-amount', '1.25');
      await tapId('save-usual-serving');
      await tapId('log-confirm');
      final curry = quick.recipes.getAllRecipesDBO().singleWhere(
        (r) => r.name == 'Test homemade curry',
      );
      expect(curry.portionUnit, 'katori');
      expect((await quick.preferences()).usualServings[curry.id], 1.25);
      final historical = (await quick.intakes.getAllIntakesDBO())
          .map(IntakeEntity.fromIntakeDBO)
          .singleWhere((i) => i.meal.name == curry.name);
      final curryTile = find
          .ancestor(of: find.text(curry.name), matching: find.byType(ListTile))
          .first;
      await tester.ensureVisible(curryTile);
      await settle();
      await tester.tap(
        find.descendant(
          of: curryTile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await settle();
      await tester.tap(find.text('Edit ingredients / portions'));
      await settle();
      await enterLabel('Number of portions / bowls in the batch', '8');
      await tapId('recipe-builder-save');
      expect(quick.recipes.getRecipeById(curry.id)!.servingsCount, 8);
      expect(
        (await quick.intakes.getIntakeById(historical.id))!.totalKcal,
        historical.totalKcal,
      );
      await enterId('quick-search', '');
      await back();
      expect(find.byType(QuickLogScreen), findsNothing);

      debugPrint('CHECKPOINT: diary actions');
      Future<void> openDiaryMenu() async {
        for (
          var scroll = 0;
          id('diary-entry-menu').hitTestable().evaluate().isEmpty &&
              scroll < 30;
          scroll++
        ) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -400),
          );
          await settle();
        }
        expect(id('diary-entry-menu').hitTestable(), findsWidgets);
        await tester.tap(id('diary-entry-menu').hitTestable().first);
        await settle();
      }

      await openDiaryMenu();
      final beforeDuplicate = (await quick.intakes.getAllIntakesDBO()).length;
      await tester.tap(find.text('Log again'));
      await settle();
      expect(
        (await quick.intakes.getAllIntakesDBO()).length,
        beforeDuplicate + 1,
      );
      await openDiaryMenu();
      await tester.tap(find.text('Delete entry'));
      await settle();
      expect((await quick.intakes.getAllIntakesDBO()).length, beforeDuplicate);
      await openDiaryMenu();
      await tester.tap(find.text('Edit'));
      await settle();
      await tester.enterText(find.byType(TextField).last, '0.75');
      await tester.tap(find.text('OK'));
      await settle();
      expect(
        (await quick.intakes.getAllIntakesDBO())
            .map(IntakeEntity.fromIntakeDBO)
            .any((i) => (i.displayedAmount - .75).abs() < 1e-8),
        isTrue,
      );

      debugPrint('CHECKPOINT: weight and stored trends');
      await tapId('nav-trends');
      expect(id('trends-range-selector'), findsOneWidget);
      await tapId('trends-log-weight');
      await tester.tap(find.text('OK'));
      await settle();
      expect(await locator<WeightLogRepository>().getAllEntries(), isNotEmpty);
      await tapId('nav-home');
      expect(
        caught,
        isEmpty,
        reason: 'Android workflows should produce no Flutter errors',
      );
      debugPrint('CHECKPOINT: daily Android workflows complete');
    },
  );
}
