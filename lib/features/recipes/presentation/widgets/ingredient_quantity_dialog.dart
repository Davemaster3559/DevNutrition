import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/features/quick_log/data/quick_log_repository.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';
import 'package:opennutritracker/features/quick_log/domain/household_measures.dart';
import 'package:opennutritracker/features/quick_log/presentation/dev_widgets.dart';

class IngredientQuantitySelection {
  final double amount;
  final String unit;
  final double? convertedAmountG;
  const IngredientQuantitySelection({
    required this.amount,
    required this.unit,
    this.convertedAmountG,
  });
}

/// Modal bottom sheet that asks for the amount + unit of an ingredient.
/// Returns an [IngredientQuantitySelection] or null if cancelled.
Future<IngredientQuantitySelection?> showIngredientQuantityDialog(
  BuildContext context, {
  required MealEntity meal,
  double? initialAmount,
  String? initialUnit,
}) {
  return showModalBottomSheet<IngredientQuantitySelection>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _IngredientQuantitySheet(
      meal: meal,
      initialAmount: initialAmount,
      initialUnit: initialUnit,
    ),
  );
}

class _IngredientQuantitySheet extends StatefulWidget {
  final MealEntity meal;
  final double? initialAmount;
  final String? initialUnit;

  const _IngredientQuantitySheet({
    required this.meal,
    this.initialAmount,
    this.initialUnit,
  });

  @override
  State<_IngredientQuantitySheet> createState() =>
      _IngredientQuantitySheetState();
}

class _IngredientQuantitySheetState extends State<_IngredientQuantitySheet> {
  late TextEditingController _amountController;
  late String _unit;
  final _calibration = TextEditingController();
  DevNutritionPreferences _preferences = const DevNutritionPreferences();
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount != null
          ? widget.initialAmount!.toString()
          : '',
    );
    _unit = widget.initialUnit ?? _defaultUnit(widget.meal);
    if (locator.isRegistered<QuickLogRepository>()) {
      locator<QuickLogRepository>().preferences().then((p) {
        if (mounted) setState(() => _preferences = p);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _calibration.dispose();
    super.dispose();
  }

  String _defaultUnit(MealEntity meal) {
    if (meal.hasServingValues) return 'serving';
    if (meal.isLiquid) return 'ml';
    return 'g';
  }

  List<DropdownMenuItem<String>> _unitItems(BuildContext context) {
    return {
      ...HouseholdMeasures.units,
      'oz',
      'fl.oz',
      _unit,
    }.map(_unitItem).toList();
  }

  DropdownMenuItem<String> _unitItem(String unit) {
    return DropdownMenuItem(
      value: unit,
      child: Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final fieldBorder = OutlineInputBorder(
      borderRadius: Dimens.borderRadiusS,
      borderSide: BorderSide(color: palette.border, width: Dimens.hairline),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Dimens.spacing24,
          Dimens.spacing24,
          Dimens.spacing24,
          Dimens.spacing16,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Dimens.radiusXL),
            topRight: Radius.circular(Dimens.radiusXL),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Dimens.spacing20),
              Text(
                widget.meal.name ?? '?',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Dimens.spacing16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+([.,]\d{0,2})?$'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: S.of(context).recipeIngredientAmountLabel,
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimens.spacing12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      itemHeight: null,
                      initialValue: _unit,
                      borderRadius: Dimens.borderRadiusM,
                      decoration: InputDecoration(
                        labelText: S.of(context).recipeIngredientUnitLabel,
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                      ),
                      items: _unitItems(context),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _unit = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.spacing24),
              if (!['g', 'kg', 'ml', 'l', 'oz', 'fl.oz'].contains(_unit) &&
                  (_unit != 'serving' ||
                      HouseholdMeasures.perUnit(
                            widget.meal,
                            _unit,
                            _preferences,
                          ) ==
                          null))
                DevNumberField(
                  id: 'ingredient-measure-calibration',
                  label: S.of(context).devBasePerUnit,
                  controller: _calibration,
                  helper: S.of(context).devCalibrationHint,
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: Dimens.spacing16,
                    ),
                    shape: Dimens.shapeM,
                  ),
                  onPressed: _onConfirm,
                  child: Text(S.of(context).addLabel),
                ),
              ),
              const SizedBox(height: Dimens.spacing8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    final raw = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = S.of(context).devPositive);
      return;
    }
    final calibration = devParse(_calibration.text);
    if (calibration != null) {
      final key = HouseholdMeasures.foodKey(widget.meal);
      _preferences = _preferences.copyWith(
        measures: {
          ..._preferences.measures,
          key: {...?_preferences.measures[key], _unit: calibration},
        },
      );
      if (locator.isRegistered<QuickLogRepository>()) {
        await locator<QuickLogRepository>().savePreferences(_preferences);
      }
    }
    final factor = HouseholdMeasures.perUnit(widget.meal, _unit, _preferences);
    final converted = factor == null
        ? ComputeRecipeNutritionUseCase().convertAmountToGrams(
            amount: amount,
            unit: _unit,
            servingQuantityG: widget.meal.servingQuantity,
          )
        : amount * factor;
    if (!mounted) return;
    if (converted == null || !converted.isFinite || converted <= 0) {
      setState(() => _error = S.of(context).devUnknownMeasure);
      return;
    }
    Navigator.of(context).pop(
      IngredientQuantitySelection(
        amount: amount,
        unit: _unit,
        convertedAmountG: converted,
      ),
    );
  }
}
