import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

class ComputeRecipeNutritionResult {
  final MealNutrimentsEntity perHundredG;
  final double totalWeightG;

  const ComputeRecipeNutritionResult({
    required this.perHundredG,
    required this.totalWeightG,
  });
}

class ComputeRecipeNutritionUseCase {
  // Treat a serving as the snapshot meal's serving weight in grams.
  // Treat 1 ml ≈ 1 g per the v1 simplification (see plan §3, decision 3).
  // Returns null when the unit can't be converted (e.g. a "serving" unit
  // on an ingredient that has no servingQuantity).
  double? convertAmountToGrams({
    required double amount,
    required String unit,
    double? servingQuantityG,
  }) {
    switch (unit) {
      case 'g':
      case 'gml':
      case 'g/ml':
        return amount;
      case 'ml':
      case 'l':
      case 'cl':
      case 'dl':
        if (unit == 'l') return amount * 1000;
        if (unit == 'cl') return amount * 10;
        if (unit == 'dl') return amount * 100;
        return amount;
      case 'kg':
        return amount * 1000;
      case 'mg':
        return amount / 1000;
      case 'oz':
        return UnitCalc.ozToG(amount);
      case 'fl oz':
      case 'fl.oz':
        return UnitCalc.flOzToMl(amount);
      case 'serving':
        if (servingQuantityG == null || servingQuantityG <= 0) return null;
        return amount * servingQuantityG;
      default:
        return null;
    }
  }

  ComputeRecipeNutritionResult compute(
    List<RecipeIngredientEntity> ingredients, {
    double? totalWeightOverride,
  }) {
    if (ingredients.isEmpty) {
      return ComputeRecipeNutritionResult(
        perHundredG: MealNutrimentsEntity.empty(),
        totalWeightG: 0,
      );
    }

    final totalWeightG =
        totalWeightOverride ??
        ingredients.fold<double>(0, (sum, i) => sum + i.convertedAmountG);

    if (totalWeightG <= 0) {
      return ComputeRecipeNutritionResult(
        perHundredG: MealNutrimentsEntity.empty(),
        totalWeightG: 0,
      );
    }

    // For every nutrient field: sum (value100 ?? 0) × convertedAmountG / 100
    // across ingredients, but track whether *every* ingredient had a non-null
    // value for that field. If any did not, the recipe field stays null too —
    // that preserves the existing UI behaviour of hiding unknown micros.
    final acc = _NutrientAccumulator();
    for (final ingredient in ingredients) {
      acc.addFrom(
        ingredient.snapshotMeal.nutriments,
        ingredient.convertedAmountG,
      );
    }

    final per = acc.toEntityPerHundredG(totalWeightG);

    return ComputeRecipeNutritionResult(
      perHundredG: per,
      totalWeightG: totalWeightG,
    );
  }
}

/// Single-pass accumulator for the 24 nutrient fields tracked on
/// [MealNutrimentsEntity]. Each field has a running sum and a flag for
/// "did every ingredient carry a value for this field?". A missing value
/// leaves the complete recipe nutrient unknown instead of understating it.
class _NutrientAccumulator {
  double _energyKcal = 0, _carbs = 0, _fat = 0, _protein = 0;
  double _sugars = 0, _satFat = 0, _fiber = 0;
  double _monoFat = 0, _polyFat = 0, _transFat = 0, _cholesterol = 0;
  double _sodium = 0, _potassium = 0, _magnesium = 0, _calcium = 0;
  double _iron = 0, _zinc = 0, _phosphorus = 0;
  double _vitA = 0, _vitC = 0, _vitD = 0, _vitB6 = 0, _vitB12 = 0, _niacin = 0;

  bool _hasEnergy = true, _hasCarbs = true, _hasFat = true, _hasProtein = true;
  bool _hasSugars = true, _hasSatFat = true, _hasFiber = true;
  bool _hasMonoFat = true,
      _hasPolyFat = true,
      _hasTransFat = true,
      _hasCholesterol = true;
  bool _hasSodium = true,
      _hasPotassium = true,
      _hasMagnesium = true,
      _hasCalcium = true;
  bool _hasIron = true, _hasZinc = true, _hasPhosphorus = true;
  bool _hasVitA = true, _hasVitC = true, _hasVitD = true;
  bool _hasVitB6 = true, _hasVitB12 = true, _hasNiacin = true;

  void addFrom(MealNutrimentsEntity n, double convertedAmountG) {
    final ratio = convertedAmountG / 100;

    if (n.energyKcal100 == null) _hasEnergy = false;
    _energyKcal += (n.energyKcal100 ?? 0) * ratio;

    if (n.carbohydrates100 == null) _hasCarbs = false;
    _carbs += (n.carbohydrates100 ?? 0) * ratio;

    if (n.fat100 == null) _hasFat = false;
    _fat += (n.fat100 ?? 0) * ratio;

    if (n.proteins100 == null) _hasProtein = false;
    _protein += (n.proteins100 ?? 0) * ratio;

    if (n.sugars100 == null) _hasSugars = false;
    _sugars += (n.sugars100 ?? 0) * ratio;

    if (n.saturatedFat100 == null) _hasSatFat = false;
    _satFat += (n.saturatedFat100 ?? 0) * ratio;

    if (n.fiber100 == null) _hasFiber = false;
    _fiber += (n.fiber100 ?? 0) * ratio;

    if (n.monounsaturatedFat100 == null) _hasMonoFat = false;
    _monoFat += (n.monounsaturatedFat100 ?? 0) * ratio;

    if (n.polyunsaturatedFat100 == null) _hasPolyFat = false;
    _polyFat += (n.polyunsaturatedFat100 ?? 0) * ratio;

    if (n.transFat100 == null) _hasTransFat = false;
    _transFat += (n.transFat100 ?? 0) * ratio;

    if (n.cholesterol100 == null) _hasCholesterol = false;
    _cholesterol += (n.cholesterol100 ?? 0) * ratio;

    if (n.sodium100 == null) _hasSodium = false;
    _sodium += (n.sodium100 ?? 0) * ratio;

    if (n.potassium100 == null) _hasPotassium = false;
    _potassium += (n.potassium100 ?? 0) * ratio;

    if (n.magnesium100 == null) _hasMagnesium = false;
    _magnesium += (n.magnesium100 ?? 0) * ratio;

    if (n.calcium100 == null) _hasCalcium = false;
    _calcium += (n.calcium100 ?? 0) * ratio;

    if (n.iron100 == null) _hasIron = false;
    _iron += (n.iron100 ?? 0) * ratio;

    if (n.zinc100 == null) _hasZinc = false;
    _zinc += (n.zinc100 ?? 0) * ratio;

    if (n.phosphorus100 == null) _hasPhosphorus = false;
    _phosphorus += (n.phosphorus100 ?? 0) * ratio;

    if (n.vitaminA100 == null) _hasVitA = false;
    _vitA += (n.vitaminA100 ?? 0) * ratio;

    if (n.vitaminC100 == null) _hasVitC = false;
    _vitC += (n.vitaminC100 ?? 0) * ratio;

    if (n.vitaminD100 == null) _hasVitD = false;
    _vitD += (n.vitaminD100 ?? 0) * ratio;

    if (n.vitaminB6100 == null) _hasVitB6 = false;
    _vitB6 += (n.vitaminB6100 ?? 0) * ratio;

    if (n.vitaminB12100 == null) _hasVitB12 = false;
    _vitB12 += (n.vitaminB12100 ?? 0) * ratio;

    if (n.niacin100 == null) _hasNiacin = false;
    _niacin += (n.niacin100 ?? 0) * ratio;
  }

  MealNutrimentsEntity toEntityPerHundredG(double totalWeightG) {
    double? norm(double sum, bool allPresent) =>
        allPresent ? sum * 100 / totalWeightG : null;

    return MealNutrimentsEntity(
      energyKcal100: norm(_energyKcal, _hasEnergy),
      carbohydrates100: norm(_carbs, _hasCarbs),
      fat100: norm(_fat, _hasFat),
      proteins100: norm(_protein, _hasProtein),
      sugars100: norm(_sugars, _hasSugars),
      saturatedFat100: norm(_satFat, _hasSatFat),
      fiber100: norm(_fiber, _hasFiber),
      monounsaturatedFat100: norm(_monoFat, _hasMonoFat),
      polyunsaturatedFat100: norm(_polyFat, _hasPolyFat),
      transFat100: norm(_transFat, _hasTransFat),
      cholesterol100: norm(_cholesterol, _hasCholesterol),
      sodium100: norm(_sodium, _hasSodium),
      potassium100: norm(_potassium, _hasPotassium),
      magnesium100: norm(_magnesium, _hasMagnesium),
      calcium100: norm(_calcium, _hasCalcium),
      iron100: norm(_iron, _hasIron),
      zinc100: norm(_zinc, _hasZinc),
      phosphorus100: norm(_phosphorus, _hasPhosphorus),
      vitaminA100: norm(_vitA, _hasVitA),
      vitaminC100: norm(_vitC, _hasVitC),
      vitaminD100: norm(_vitD, _hasVitD),
      vitaminB6100: norm(_vitB6, _hasVitB6),
      vitaminB12100: norm(_vitB12, _hasVitB12),
      niacin100: norm(_niacin, _hasNiacin),
    );
  }
}
