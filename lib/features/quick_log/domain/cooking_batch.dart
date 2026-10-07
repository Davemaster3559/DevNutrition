import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

/// Nutrition comes only from the dry ingredients and added fat. The mass is
/// an internal scaling basis, never a claim about the cooked batch's weight.
class CookingBatch {
  static RecipeEntity create({
    required String id,
    required String name,
    required MealEntity dryFood,
    required double dryGrams,
    required int portions,
    required String portionUnit,
    MealEntity? fat,
    double fatGrams = 0,
    bool fatPerPortion = false,
  }) {
    if (!dryGrams.isFinite ||
        dryGrams <= 0 ||
        portions <= 0 ||
        !fatGrams.isFinite ||
        fatGrams < 0) {
      throw ArgumentError('Invalid batch quantity');
    }
    final ingredients = [
      RecipeIngredientEntity(
        snapshotMeal: dryFood,
        amount: dryGrams,
        unit: 'g',
        convertedAmountG: dryGrams,
      ),
      if (fat != null && fatGrams > 0)
        RecipeIngredientEntity(
          snapshotMeal: fat,
          amount: fatGrams * (fatPerPortion ? portions : 1),
          unit: 'g',
          convertedAmountG: fatGrams * (fatPerPortion ? portions : 1),
        ),
    ];
    final nutrition = ComputeRecipeNutritionUseCase().compute(ingredients);
    final now = DateTime.now();
    return RecipeEntity(
      id: id,
      name: name,
      description:
          'Dry ingredients only; water contributes no energy. Yield: $portions $portionUnit. No cooked weight required.',
      ingredients: ingredients,
      totalWeightG: nutrition.totalWeightG,
      aggregatedNutrimentsPer100: nutrition.perHundredG,
      createdAt: now,
      updatedAt: now,
      servingsCount: portions,
      portionUnit: portionUnit,
    );
  }
}
