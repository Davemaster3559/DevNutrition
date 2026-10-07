import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/recipe_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/data_source/weight_log_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/fasting_session_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/physical_activity_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_gender_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/custom_activity_template_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/features/quick_log/data/devnutrition_backup.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/quick_log/data/local_food_catalogue.dart';
import 'package:opennutritracker/features/quick_log/data/quick_log_repository.dart';
import 'package:opennutritracker/features/quick_log/domain/cooking_batch.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';
import 'package:opennutritracker/features/quick_log/domain/household_measures.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:opennutritracker/features/settings/domain/usecase/import_data_usecase.dart';
import 'package:opennutritracker/features/settings/domain/export_import_failure.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../helpers/fake_hive_db_provider.dart';
import '../helpers/hive_test_setup.dart';

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String directory;
  _Paths(this.directory);
  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
}

final class _PickedFile extends PlatformFile {
  _PickedFile(String path, int size) : uri = Uri.file(path);
  @override
  final Uri uri;
  @override
  String get name => 'backup.zip';
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => File(path!).lengthSync();
  @override
  Future<int> length() => File(path!).length();
  @override
  Future<Uint8List> readAsBytes() => File(path!).readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() => File(path!).openRead().cast();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerHiveAdaptersOnce();
  late Directory directory;
  late List<int> key;
  late FakeHiveDBProvider db;
  late QuickLogRepository quick;
  late TrackedDayRepository days;
  late UserActivityRepository activities;
  late PathProviderPlatform originalPaths;

  Future<void> open() async {
    Future<Box<T>> box<T>(String name) =>
        Hive.openBox<T>(name, encryptionCipher: HiveAesCipher(key));
    db = FakeHiveDBProvider(
      appConfigBox: await box<ConfigDBO>('app'),
      configBox: await box<ConfigDBO>('config'),
      userBox: await box<UserDBO>('user'),
      intakeBox: await box<IntakeDBO>('intakes'),
      userActivityBox: await box<UserActivityDBO>('activities'),
      trackedDayBox: await box<TrackedDayDBO>('days'),
      customMealBox: await box<MealDBO>('foods'),
      recipeBox: await box<RecipeDBO>('recipes'),
      weightLogBox: await box<WeightLogDBO>('weights'),
      waterIntakeBox: await box<WaterIntakeDBO>('water'),
      fastingBox: await box<FastingSessionDBO>('fasting'),
      customActivityTemplateBox: await box<CustomActivityTemplateDBO>(
        'templates',
      ),
    );
    final config = ConfigDataSource(db);
    await config.initializeConfig();
    days = TrackedDayRepository(TrackedDayDataSource(db));
    activities = UserActivityRepository(UserActivityDataSource(db));
    final configRepo = ConfigRepository(config);
    quick = QuickLogRepository(
      config,
      CustomMealDataSource(db),
      RecipeRepository(RecipeDataSource(db)),
      IntakeRepository(IntakeDataSource(db)),
      AddTrackedDayUsecase(days, configRepo),
      GetKcalGoalUsecase(
        UserRepository(UserDataSource(db)),
        configRepo,
        activities,
      ),
      GetMacroGoalUsecase(configRepo),
      LocalFoodCatalogue(),
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('devnutrition_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    Hive.init(directory.path);
    key = Hive.generateSecureKey();
    await open();
    await UserDataSource(db).saveUserData(
      UserDBO(
        birthday: DateTime(1990),
        heightCM: 175,
        weightKG: 90,
        gender: UserGenderDBO.male,
        goal: UserWeightGoalDBO.loseWeight,
        pal: UserPALDBO.lowActive,
      ),
    );
    await quick.seed();
  });
  tearDown(() async {
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  test(
    'seeded meals calculate from snapshots; whey unknown macros stay null',
    () async {
      expect(quick.recipes.getAllRecipesDBO(), hasLength(12));
      await quick.seed();
      expect(quick.recipes.getAllRecipesDBO(), hasLength(12));
      final whey = quick.recipes.getRecipeById('dev:whey-water')!;
      final entry = await quick.log(
        whey.toMealEntity(),
        whey.totalWeightG * 1.25,
        IntakeTypeEntity.snack,
        DateTime(2026, 10, 7),
      );
      expect(entry.totalKcal, closeTo(147 * 1.25, 1e-8));
      expect(entry.totalProteinsGram, closeTo(25 * 1.25, 1e-8));
      expect(entry.meal.nutriments.carbohydrates100, isNull);
      for (final id in [
        'dev:banana-shake',
        'dev:oats',
        'dev:fruit-a',
        'dev:fruit-b',
      ]) {
        final recipe = quick.recipes.getRecipeById(id)!;
        final expectedKcal = recipe.ingredients.fold<double>(
          0,
          (sum, i) =>
              sum +
              i.convertedAmountG *
                  i.snapshotMeal.nutriments.energyKcal100! /
                  100,
        );
        final logged = await quick.log(
          recipe.toMealEntity(),
          recipe.totalWeightG,
          IntakeTypeEntity.breakfast,
          DateTime(2026, 10, 7),
        );
        expect(logged.totalKcal, closeTo(expectedKcal, 1e-8));
      }
      expect((await quick.preferences()).calorieGoal, 1700);
      expect((await quick.preferences()).proteinGoal, 120);
    },
  );

  test(
    'calibrated cups, raw batches, per-roti fat and exact rice thirds',
    () async {
      final foods = {for (final f in await quick.catalogue.all()) f.code!: f};
      const prefs = DevNutritionPreferences(
        measures: {
          '168893': {'cup': 123},
          '168877': {'cup': 180},
        },
      );
      final flour = foods['168893']!,
          rice = foods['168877']!,
          oil = foods['171413']!;
      expect(HouseholdMeasures.convert(flour, 1, '1/4 cup', prefs), 30.75);
      expect(HouseholdMeasures.convert(rice, .75, 'cup', prefs), 135);
      expect(HouseholdMeasures.perUnit(flour, 'bowl', prefs), isNull);
      expect(
        () => HouseholdMeasures.convert(flour, 1, 'bowl', prefs),
        throwsArgumentError,
      );
      expect(
        () => HouseholdMeasures.convert(flour, double.nan, 'g', prefs),
        throwsArgumentError,
      );
      final roti = CookingBatch.create(
        id: 'roti',
        name: 'Atta roti',
        dryFood: flour,
        dryGrams: 123 * .75,
        portions: 6,
        portionUnit: 'roti',
        fat: oil,
        fatGrams: 2,
        fatPerPortion: true,
      );
      final expected =
          92.25 * flour.nutriments.energyKcal100! / 100 +
          12 * oil.nutriments.energyKcal100! / 100;
      final entry = await quick.log(
        roti.toMealEntity(),
        roti.totalWeightG / 6 * 2,
        IntakeTypeEntity.lunch,
        DateTime(2026, 10, 7),
        displayUnit: 'roti',
        baseAmountPerDisplayUnit: roti.totalWeightG / 6,
      );
      expect(entry.totalKcal, closeTo(expected / 3, 1e-8));
      expect(entry.displayedAmount, closeTo(2, 1e-10));
      final batch = CookingBatch.create(
        id: 'rice',
        name: 'Dry rice batch',
        dryFood: rice,
        dryGrams: 180,
        portions: 4,
        portionUnit: 'serving',
      );
      final third = await quick.log(
        batch.toMealEntity(),
        batch.totalWeightG / 3,
        IntakeTypeEntity.dinner,
        DateTime(2026, 10, 7),
      );
      expect(
        third.totalKcal,
        closeTo(rice.nutriments.energyKcal100! * .6, 1e-8),
      );
    },
  );

  test(
    'move/delete and late shift totals preserve historical recipe snapshots',
    () async {
      await quick.config.setConfigDayStartOffsetHours(6);
      final original = quick.recipes.getRecipeById('dev:fruit-a')!;
      final log = await quick.log(
        original.toMealEntity(),
        original.totalWeightG,
        IntakeTypeEntity.snack,
        DateTime(2026, 10, 8, 2),
      );
      final day = (await days.getTrackedDay(DateTime(2026, 10, 7)))!;
      expect(day.caloriesTracked, closeTo(log.totalKcal, 1e-8));
      await quick.recipes.saveRecipe(
        original.copyWith(
          name: 'Changed recipe',
          aggregatedNutrimentsPer100: const MealNutrimentsEntity(
            energyKcal100: 900,
            carbohydrates100: 10,
            fat100: 90,
            proteins100: 5,
            sugars100: null,
            saturatedFat100: null,
            fiber100: null,
          ),
        ),
      );
      expect(
        (await quick.intakes.getIntakeById(log.id))!.meal.name,
        original.name,
      );
      expect(
        (await quick.intakes.getIntakeById(log.id))!.totalKcal,
        log.totalKcal,
      );
      await quick.move(log, DateTime(2026, 10, 9), IntakeTypeEntity.lunch);
      expect(
        (await days.getTrackedDay(DateTime(2026, 10, 7)))!.caloriesTracked,
        0,
      );
      expect(
        (await days.getTrackedDay(DateTime(2026, 10, 9)))!.caloriesTracked,
        closeTo(log.totalKcal, 1e-8),
      );
      await quick.delete((await quick.intakes.getIntakeById(log.id))!);
      expect(
        (await days.getTrackedDay(DateTime(2026, 10, 9)))!.caloriesTracked,
        0,
      );
    },
  );

  test(
    'workout stays separate from fixed food goals unless explicitly enabled',
    () async {
      final day = DateTime(2026, 10, 7);
      await activities.addAllUserActivityDBOs([
        UserActivityDBO(
          'workout',
          30,
          350,
          day,
          PhysicalActivityDBO(
            'walk',
            'Walking',
            'Test workout',
            3,
            [],
            PhysicalActivityTypeDBO.sport,
          ),
        ),
      ]);
      await quick.reconcile(day);
      await quick.trackedDays.increaseDayCalorieGoal(day, 350);
      await quick.trackedDays.increaseDayMacroGoals(day, proteinAmount: 20);
      expect(await quick.calorieGoal.getKcalGoal(day: day), 1700);
      expect((await days.getTrackedDay(day))!.calorieGoal, 1700);
      expect((await days.getTrackedDay(day))!.proteinGoal, 120);
      await quick.savePreferences(
        (await quick.preferences()).copyWith(eatBackExercise: true),
      );
      expect(await quick.calorieGoal.getKcalGoal(day: day), 2050);
    },
  );

  test(
    'encrypted restart and real ZIP import restore personal structures idempotently',
    () async {
      await quick.savePreferences(
        (await quick.preferences()).copyWith(
          calorieGoal: 1800,
          proteinGoal: 130,
          goalWeightKg: 80,
          measures: {
            '168893': {'cup': 123, 'katori': 55},
          },
          usualServings: {'dev:fruit-a': 1.25},
          flourCode: '168893',
          riceCode: '169707',
        ),
      );
      final recipe = quick.recipes.getRecipeById('dev:fruit-a')!;
      final log = await quick.log(
        recipe.toMealEntity(),
        recipe.totalWeightG * 1.25,
        IntakeTypeEntity.lunch,
        DateTime(2026, 10, 7),
        displayUnit: 'katori',
        baseAmountPerDisplayUnit: recipe.totalWeightG,
      );
      await quick.saveFood((await quick.catalogue.all()).first);
      await db.waterIntakeBox.add(
        WaterIntakeDBO(id: 'water-1', dateTime: log.dateTime, amountMl: 250),
      );
      await Hive.close();
      await open();
      expect((await quick.preferences()).measures['168893']!['cup'], 123);
      expect(
        (await quick.intakes.getIntakeById(log.id))!.displayedAmount,
        1.25,
      );
      final backup = DevNutritionBackup(db);
      final weights = WeightLogRepository(WeightLogDataSource(db));
      final templates = CustomActivityTemplateRepository(
        CustomActivityTemplateDataSource(db),
      );
      final exporter = ExportDataUsecase(
        activities,
        quick.intakes,
        days,
        quick.recipes,
        quick.customFoods,
        weights,
        templates,
        devNutritionBackup: backup,
      );
      final archive = await exporter.assembleArchive(
        format: ExportFormat.json,
        userActivityJsonFileName: 'user_activity.json',
        userIntakeJsonFileName: 'user_intake.json',
        trackedDayJsonFileName: 'user_tracked_day.json',
        recipeJsonFileName: 'user_recipes.json',
        weightLogJsonFileName: 'weight_log.json',
        customActivityTemplateJsonFileName: 'custom_activity_templates.json',
      );
      expect(archive.findFile('devnutrition.json'), isNotNull);
      final bytes = ZipEncoder().encode(archive);
      final file = File('${directory.path}/backup.zip');
      await file.writeAsBytes(bytes);
      for (final box in [
        db.intakeBox,
        db.recipeBox,
        db.trackedDayBox,
        db.configBox,
        db.userBox,
        db.customMealBox,
        db.waterIntakeBox,
      ]) {
        await box.clear();
      }
      await db.waterIntakeBox.add(
        WaterIntakeDBO(
          id: 'local-water',
          dateTime: log.dateTime,
          amountMl: 500,
        ),
      );
      final importer = ImportDataUsecase(
        activities,
        quick.intakes,
        days,
        quick.recipes,
        weights,
        templates,
        devNutritionBackup: backup,
        pickFile: () async => _PickedFile(file.path, bytes.length),
      );
      Future<void> restore() async {
        expect(
          await importer.importData(
            'user_activity.json',
            'user_intake.json',
            'user_tracked_day.json',
            'user_recipes.json',
            'weight_log.json',
            'custom_activity_templates.json',
          ),
          isTrue,
        );
      }

      await restore();
      await restore();
      expect(db.intakeBox.length, 1);
      expect(db.recipeBox.length, 12);
      expect(db.waterIntakeBox.length, 2);
      expect(
        db.waterIntakeBox.values.singleWhere((w) => w.id == 'water-1').amountMl,
        250,
      );
      expect(
        db.waterIntakeBox.values
            .singleWhere((w) => w.id == 'local-water')
            .amountMl,
        500,
      );
      expect((await quick.preferences()).calorieGoal, 1800);
      expect((await quick.preferences()).usualServings[recipe.id], 1.25);
      expect((await quick.preferences()).pins, contains('dev:banana-shake'));
      expect((await quick.preferences()).riceCode, '169707');
      expect(
        (await quick.intakes.getIntakeById(log.id))!.totalKcal,
        closeTo(log.totalKcal, 1e-8),
      );
      expect(
        (await quick.intakes.getIntakeById(log.id))!.displayUnit,
        'katori',
      );
      final restored =
          jsonDecode(jsonEncode(backup.snapshot())) as Map<String, dynamic>;
      (restored['user'] as List).first['value']['weightKG'] = 'broken';
      final before = db.waterIntakeBox.length;
      await expectLater(backup.restore(restored), throwsA(isA<TypeError>()));
      expect(db.waterIntakeBox.length, before);

      final malformed = Archive();
      for (final entry in archive.files) {
        if (entry.name == 'user_recipes.json') {
          malformed.addFile(
            ArchiveFile.string(entry.name, '["invalid recipe"]'),
          );
        } else if (entry.name == 'user_intake.json') {
          final rows =
              jsonDecode(utf8.decode(entry.content as List<int>)) as List;
          rows.add({
            ...rows.first as Map<String, dynamic>,
            'id': 'must-not-import',
          });
          malformed.addFile(ArchiveFile.string(entry.name, jsonEncode(rows)));
        } else {
          malformed.addFile(entry);
        }
      }
      await file.writeAsBytes(ZipEncoder().encode(malformed));
      await expectLater(
        importer.importData(
          'user_activity.json',
          'user_intake.json',
          'user_tracked_day.json',
          'user_recipes.json',
          'weight_log.json',
          'custom_activity_templates.json',
        ),
        throwsA(isA<ExportImportFailure>()),
      );
      expect(
        db.intakeBox.length,
        1,
        reason: 'invalid later files cause no partial writes',
      );
    },
  );
}
