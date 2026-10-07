import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/quick_log/data/local_food_catalogue.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';
import 'package:synchronized/synchronized.dart';

class QuickLogRepository {
  final ConfigDataSource config;
  final CustomMealDataSource customFoods;
  final RecipeRepository recipes;
  final IntakeRepository intakes;
  final AddTrackedDayUsecase trackedDays;
  final GetKcalGoalUsecase calorieGoal;
  final GetMacroGoalUsecase macroGoals;
  final LocalFoodCatalogue catalogue;
  final _writes = Lock();

  QuickLogRepository(
    this.config,
    this.customFoods,
    this.recipes,
    this.intakes,
    this.trackedDays,
    this.calorieGoal,
    this.macroGoals,
    this.catalogue,
  );

  Future<DevNutritionPreferences> preferences() async =>
      DevNutritionPreferences.decode(
        (await config.getConfig()).devNutritionJson,
      );

  Future<void> savePreferences(DevNutritionPreferences value) =>
      config.setDevNutritionJson(value.encode());

  Future<void> seed() async {
    final preferences = await this.preferences();
    if (preferences.seeded) return;
    final foods = {for (final food in await catalogue.all()) food.code!: food};
    final seeds =
        jsonDecode(await rootBundle.loadString('assets/data/dev_recipes.json'))
            as List;
    for (final row in seeds.cast<Map<String, dynamic>>()) {
      if (recipes.getRecipeById(row['id'] as String) != null) continue;
      final ingredients = (row['ingredients'] as List).map((item) {
        final meal = foods[item['code']]!;
        final amount = (item['amount'] as num).toDouble();
        return RecipeIngredientEntity(
          snapshotMeal: meal,
          amount: amount,
          unit: meal.mealUnit ?? 'g',
          convertedAmountG: amount,
        );
      }).toList();
      final nutrition = ComputeRecipeNutritionUseCase().compute(ingredients);
      final now = DateTime.now();
      await recipes.saveRecipe(
        RecipeEntity(
          id: row['id'],
          name: row['name'],
          description: row['description'],
          ingredients: ingredients,
          totalWeightG: nutrition.totalWeightG,
          aggregatedNutrimentsPer100: nutrition.perHundredG,
          createdAt: now,
          updatedAt: now,
          servingsCount: row['servings'] ?? 1,
          kind: row['kind'] ?? 'preset',
          portionUnit: row['portionUnit'] ?? 'serving',
          tags: const ['vegetarian', 'Dev'],
        ),
      );
    }
    await savePreferences(
      preferences.copyWith(
        seeded: true,
        pins: [
          ...preferences.pins,
          for (final id in [
            'dev:banana-shake',
            'dev:oats',
            'dev:fruit-a',
            'dev:fruit-b',
            'dev:whey-water',
          ])
            if (!preferences.pins.contains(id)) id,
        ],
      ),
    );
  }

  Future<List<MealEntity>> savedFoods() async =>
      customFoods.getAllCustomMeals().map(MealEntity.fromMealDBO).toList();

  Future<void> saveFood(MealEntity food) =>
      customFoods.saveCustomMeal(MealDBO.fromMealEntity(food));

  Future<void> reorderPin(String key, int direction) async {
    final prefs = await preferences();
    final pins = [...prefs.pins];
    final index = pins.indexOf(key), target = pins.indexOf(key) + direction;
    if (index < 0 || target < 0 || target >= pins.length) return;
    pins.removeAt(index);
    pins.insert(target, key);
    await savePreferences(prefs.copyWith(pins: pins));
  }

  Future<void> move(IntakeEntity entry, DateTime day, IntakeTypeEntity type) =>
      _writes.synchronized(() async {
        await intakes.updateIntake(entry.id, {
          'dateTime': day,
          'type': IntakeTypeDBO.fromIntakeTypeEntity(type),
        });
        await reconcile(entry.dateTime);
        await reconcile(day);
      });

  Future<void> delete(IntakeEntity entry) => _writes.synchronized(() async {
    await intakes.deleteIntake(entry);
    await reconcile(entry.dateTime);
  });

  Future<void> pin(String key) async {
    final prefs = await preferences();
    final pins = [...prefs.pins];
    if (pins.contains(key)) {
      pins.remove(key);
    } else {
      pins.add(key);
    }
    await savePreferences(prefs.copyWith(pins: pins));
  }

  Future<IntakeEntity> log(
    MealEntity meal,
    double baseAmount,
    IntakeTypeEntity type,
    DateTime day, {
    String? displayUnit,
    double? baseAmountPerDisplayUnit,
  }) => _writes.synchronized(() async {
    if (!baseAmount.isFinite || baseAmount <= 0) {
      throw ArgumentError('Enter a positive amount.');
    }
    final entry = IntakeEntity(
      id: IdGenerator.getUniqueID(),
      unit: meal.mealUnit ?? 'g',
      amount: baseAmount,
      type: type,
      meal: meal,
      dateTime: day,
      displayUnit: displayUnit,
      baseAmountPerDisplayUnit: baseAmountPerDisplayUnit,
    );
    await intakes.addIntake(entry);
    await reconcile(day);
    return entry;
  });

  Future<void> reconcile(DateTime moment) async {
    final settings = await config.getConfig();
    // Bare midnights are upstream's explicit nutrition-day labels.
    final day =
        moment.hour == 0 &&
            moment.minute == 0 &&
            moment.second == 0 &&
            moment.millisecond == 0 &&
            moment.microsecond == 0
        ? DateTime(moment.year, moment.month, moment.day)
        : DayBoundaryCalc.logicalDayOfMinutes(
            moment,
            (settings.dayStartOffsetHours ?? 0) * 60 +
                (settings.dayStartOffsetMinutes ?? 0),
          );
    final offset =
        (settings.dayStartOffsetHours ?? 0) * 60 +
        (settings.dayStartOffsetMinutes ?? 0);
    final entries = (await intakes.getAllIntakesDBO())
        .where(
          (i) => DayBoundaryCalc.isMomentInLogicalDayMinutes(
            day,
            i.dateTime,
            offset,
          ),
        )
        .map(IntakeEntity.fromIntakeDBO)
        .toList();
    if (!await trackedDays.hasTrackedDay(day)) {
      final kcal = await calorieGoal.getKcalGoal(day: day);
      await trackedDays.addNewTrackedDay(
        day,
        kcal,
        await macroGoals.getCarbsGoal(kcal),
        await macroGoals.getFatsGoal(kcal),
        await macroGoals.getProteinsGoal(kcal),
      );
    }
    await trackedDays.reconcileDayTracked(
      day,
      entries.fold(0, (s, i) => s + i.totalKcal),
      entries.fold(0, (s, i) => s + i.totalCarbsGram),
      entries.fold(0, (s, i) => s + i.totalFatsGram),
      entries.fold(0, (s, i) => s + i.totalProteinsGram),
    );
  }
}
