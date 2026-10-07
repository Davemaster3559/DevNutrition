import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';

class HouseholdMeasures {
  static const units = [
    'g',
    'kg',
    'ml',
    'l',
    'tsp',
    'tbsp',
    'cup',
    '1/4 cup',
    '1/2 cup',
    '3/4 cup',
    'piece',
    'roti',
    'katori',
    'bowl',
    'glass',
    'ladle',
    'serving',
  ];

  static String foodKey(MealEntity meal) => meal.code ?? meal.name ?? '';

  /// Returns the food's base amount (g or ml); a household conversion is
  /// always attached to this food, never an assumed universal cup weight.
  static double? perUnit(
    MealEntity meal,
    String unit,
    DevNutritionPreferences preferences,
  ) {
    final calibrated = preferences.measures[foodKey(meal)] ?? {};
    if (calibrated.containsKey(unit)) return calibrated[unit];
    if (meal.isLiquid && !calibrated.containsKey('cup')) {
      final metricVolume = {
        'tsp': 5.0,
        'tbsp': 15.0,
        'cup': 250.0,
        '1/4 cup': 62.5,
        '1/2 cup': 125.0,
        '3/4 cup': 187.5,
      };
      if (metricVolume.containsKey(unit)) return metricVolume[unit];
    }
    if (unit == 'piece' &&
        RegExp(
          r'^1 (medium|small|large|piece|fruit)',
        ).hasMatch(meal.servingSize ?? '')) {
      return meal.scalableServingQuantity;
    }
    if ((unit == 'tsp' || unit == 'tbsp') &&
        (meal.servingSize ?? '').startsWith('1 $unit')) {
      return meal.scalableServingQuantity;
    }
    switch (unit) {
      case 'g':
      case 'ml':
        return 1;
      case 'kg':
      case 'l':
        return 1000;
      case 'serving':
        return meal.scalableServingQuantity;
      case '1/4 cup':
        return calibrated['cup'] == null ? null : calibrated['cup']! / 4;
      case '1/2 cup':
        return calibrated['cup'] == null ? null : calibrated['cup']! / 2;
      case '3/4 cup':
        return calibrated['cup'] == null ? null : calibrated['cup']! * .75;
      case 'tbsp':
        return calibrated['cup'] == null ? null : calibrated['cup']! / 16;
      case 'tsp':
        return calibrated['cup'] == null ? null : calibrated['cup']! / 48;
      default:
        return null;
    }
  }

  static double convert(
    MealEntity meal,
    double amount,
    String unit,
    DevNutritionPreferences preferences,
  ) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Enter a positive amount.');
    }
    final factor = perUnit(meal, unit, preferences);
    if (factor == null || !factor.isFinite || factor <= 0) {
      throw ArgumentError('Calibrate $unit for ${meal.name} first.');
    }
    return amount * factor;
  }
}
