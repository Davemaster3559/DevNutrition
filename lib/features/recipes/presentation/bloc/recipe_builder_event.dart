part of 'recipe_builder_bloc.dart';

sealed class RecipeBuilderEvent extends Equatable {
  const RecipeBuilderEvent();

  @override
  List<Object?> get props => [];
}

class UpdateRecipePortionEvent extends RecipeBuilderEvent {
  final String kind;
  final String portionUnit;
  const UpdateRecipePortionEvent(this.kind, this.portionUnit);
  @override
  List<Object?> get props => [kind, portionUnit];
}

class InitializeBuilderEvent extends RecipeBuilderEvent {
  final RecipeEntity? existing;
  const InitializeBuilderEvent({this.existing});

  @override
  List<Object?> get props => [existing];
}

class UpdateNameEvent extends RecipeBuilderEvent {
  final String name;
  const UpdateNameEvent(this.name);

  @override
  List<Object?> get props => [name];
}

class UpdateDescriptionEvent extends RecipeBuilderEvent {
  final String description;
  const UpdateDescriptionEvent(this.description);

  @override
  List<Object?> get props => [description];
}

class UpdateServingsCountEvent extends RecipeBuilderEvent {
  final int? servingsCount;
  const UpdateServingsCountEvent(this.servingsCount);

  @override
  List<Object?> get props => [servingsCount];
}

class UpdateTagsEvent extends RecipeBuilderEvent {
  final List<String> tags;
  const UpdateTagsEvent(this.tags);

  @override
  List<Object?> get props => [tags];
}

class AddIngredientEvent extends RecipeBuilderEvent {
  final double? convertedAmountG;
  final MealEntity meal;
  final double amount;
  final String unit;
  const AddIngredientEvent({
    this.convertedAmountG,
    required this.meal,
    required this.amount,
    required this.unit,
  });

  @override
  List<Object?> get props => [meal, amount, unit, convertedAmountG];
}

class UpdateIngredientEvent extends RecipeBuilderEvent {
  final double? convertedAmountG;
  final int index;
  final double amount;
  final String unit;
  const UpdateIngredientEvent({
    this.convertedAmountG,
    required this.index,
    required this.amount,
    required this.unit,
  });

  @override
  List<Object?> get props => [index, amount, unit, convertedAmountG];
}

class RemoveIngredientEvent extends RecipeBuilderEvent {
  final int index;
  const RemoveIngredientEvent(this.index);

  @override
  List<Object?> get props => [index];
}

class UpdateTotalWeightEvent extends RecipeBuilderEvent {
  final double totalWeightG;
  const UpdateTotalWeightEvent(this.totalWeightG);

  @override
  List<Object?> get props => [totalWeightG];
}

class SaveRecipeEvent extends RecipeBuilderEvent {
  const SaveRecipeEvent();
}

class UpdateImagePathEvent extends RecipeBuilderEvent {
  // Relative slug under the app documents directory, or null to clear.
  final String? imagePath;
  const UpdateImagePathEvent(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}
