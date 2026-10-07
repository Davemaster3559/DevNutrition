import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_ingredient_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_type_suggester.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/quick_log/data/quick_log_repository.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';
import 'package:opennutritracker/features/quick_log/domain/household_measures.dart';
import 'package:opennutritracker/features/quick_log/presentation/dev_widgets.dart';
import 'package:opennutritracker/generated/l10n.dart';

Future<bool?> showDevMealLog(
  BuildContext context,
  MealEntity meal, {
  RecipeEntity? recipe,
  DateTime? day,
  IntakeTypeEntity? type,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => MealLogSheet(
    meal: meal,
    recipe: recipe,
    day: day ?? DateTime.now(),
    type: type,
  ),
);

class MealLogSheet extends StatefulWidget {
  final MealEntity meal;
  final RecipeEntity? recipe;
  final DateTime day;
  final IntakeTypeEntity? type;
  const MealLogSheet({
    super.key,
    required this.meal,
    this.recipe,
    required this.day,
    this.type,
  });
  @override
  State<MealLogSheet> createState() => _MealLogSheetState();
}

class _MealLogSheetState extends State<MealLogSheet> {
  final _repository = locator<QuickLogRepository>();
  final _amount = TextEditingController(text: '1');
  final _oil = TextEditingController();
  DevNutritionPreferences? _preferences;
  MealEntity? _oilFood;
  late IntakeTypeEntity _type;
  late DateTime _day;
  String _unit = 'serving';
  String? _error;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _type = widget.type ?? MealTypeSuggester.suggestFromTime(DateTime.now());
    _day = widget.day;
    _load();
  }

  Future<void> _load() async {
    final prefs = await _repository.preferences();
    final oil = (await _repository.catalogue.all()).firstWhere(
      (m) => m.code == '171413',
    );
    if (!mounted) return;
    setState(() {
      _preferences = prefs;
      _oilFood = oil;
      _unit =
          widget.recipe?.portionUnit ??
          (widget.meal.scalableServingQuantity == null
              ? widget.meal.mealUnit ?? 'g'
              : 'serving');
      _amount.text = widget.recipe != null
          ? devInput(prefs.usualServings[widget.recipe!.id] ?? 1)
          : (_unit == 'serving' ? '1' : '100');
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _oil.dispose();
    super.dispose();
  }

  double? get _factor {
    if (widget.recipe != null &&
        (_unit == widget.recipe!.portionUnit || _unit == 'serving')) {
      return widget.recipe!.totalWeightG / (widget.recipe!.servingsCount ?? 1);
    }
    return HouseholdMeasures.perUnit(widget.meal, _unit, _preferences!);
  }

  double? get _baseAmount {
    final a = devParse(_amount.text), f = _factor;
    return a == null || f == null ? null : a * f;
  }

  (MealEntity, double)? get _preview {
    final amount = _baseAmount;
    final oil = _extraOil;
    if (amount == null || oil == null) return null;
    if (oil == 0) return (widget.meal, amount);
    final result = ComputeRecipeNutritionUseCase().compute([
      RecipeIngredientEntity(
        snapshotMeal: widget.meal,
        amount: amount,
        unit: 'g',
        convertedAmountG: amount,
      ),
      RecipeIngredientEntity(
        snapshotMeal: _oilFood!,
        amount: oil,
        unit: 'g',
        convertedAmountG: oil,
      ),
    ]);
    final meal = MealEntity(
      code: widget.meal.code,
      name: '${widget.meal.name} (+${devNumber(oil)} g oil)',
      url: widget.meal.url,
      mealQuantity: '${result.totalWeightG}',
      mealUnit: 'g',
      servingQuantity: result.totalWeightG / devParse(_amount.text)!,
      servingUnit: 'g',
      servingSize: _unit,
      nutriments: result.perHundredG,
      source: MealSourceEntity.recipe,
    );
    return (meal, result.totalWeightG);
  }

  double? get _extraOil {
    if (_oil.text.trim().isEmpty) return 0;
    final value = double.tryParse(_oil.text.trim().replaceAll(',', '.'));
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  Future<void> _calibrate() async {
    final value = TextEditingController(
      text: _factor == null ? '' : devInput(_factor!),
    );
    final answer = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${S.of(ctx).devCalibrate}: $_unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.of(ctx).devCalibrationHint),
            DevNumberField(
              id: 'measure-calibration',
              label: S.of(ctx).devBasePerUnit,
              controller: value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              final n = devParse(value.text);
              if (n != null) Navigator.of(ctx).pop(n);
            },
            child: Text(S.of(ctx).devSave),
          ),
        ],
      ),
    );
    // The dialog's route owns its text field until the dismissal animation ends.
    if (answer == null || !mounted) return;
    final key = HouseholdMeasures.foodKey(widget.meal);
    final current = await _repository.preferences();
    final prefs = current.copyWith(
      measures: {
        ...current.measures,
        key: {...?current.measures[key], _unit: answer},
      },
    );
    await _repository.savePreferences(prefs);
    if (mounted) setState(() => _preferences = prefs);
  }

  Future<void> _saveUsual() async {
    final amount = devParse(_amount.text);
    if (widget.recipe == null || amount == null || _factor == null) return;
    final perServing =
        widget.recipe!.totalWeightG / (widget.recipe!.servingsCount ?? 1);
    final prefs = _preferences!.copyWith(
      usualServings: {
        ..._preferences!.usualServings,
        widget.recipe!.id: amount * _factor! / perServing,
      },
    );
    await _repository.savePreferences(prefs);
    if (mounted) setState(() => _preferences = prefs);
  }

  Future<void> _log() async {
    final amount = _baseAmount;
    if (amount == null) {
      setState(
        () => _error = _factor == null
            ? S.of(context).devUnknownMeasure
            : S.of(context).devPositive,
      );
      return;
    }
    final extraOil = _extraOil;
    if (extraOil == null) {
      setState(() => _error = S.of(context).devPositive);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final (meal, totalAmount) = _preview!;
      await _repository.log(
        meal,
        totalAmount,
        _type,
        _day,
        displayUnit: _unit,
        baseAmountPerDisplayUnit: totalAmount / devParse(_amount.text)!,
      );
      refreshNutritionScreens();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = S.of(context).devStorageError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_preferences == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final units = {
      if (widget.recipe != null) widget.recipe!.portionUnit,
      ...HouseholdMeasures.units,
    }.toList();
    final usual = widget.recipe == null
        ? 1.0
        : _preferences!.usualServings[widget.recipe!.id] ?? 1;
    final preview = _preview;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.meal.name ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('${s.devSource}: ${devSource(widget.meal)}'),
            if (widget.meal.brands != null) Text(widget.meal.brands!),
            DevNumberField(
              id: 'log-amount',
              label: s.devQuantity,
              controller: _amount,
              onChanged: (_) => setState(() {}),
            ),
            Semantics(
              identifier: 'log-unit',
              child: DropdownButtonFormField<String>(
                key: ValueKey(_unit),
                initialValue: _unit,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.devUnit),
                items: units
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _unit = v!),
              ),
            ),
            if (widget.recipe != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final n in [.5, 1.0, 1.25, 1.5, 2.0])
                    Semantics(
                      identifier: 'log-portion-${(n * 100).round()}',
                      child: ActionChip(
                        label: Text(devNumber(n)),
                        onPressed: () => setState(() {
                          _amount.text = devNumber(n);
                          _unit = widget.recipe!.portionUnit;
                        }),
                      ),
                    ),
                  Semantics(
                    identifier: 'log-portion-small',
                    child: ActionChip(
                      label: Text(s.devSmall),
                      onPressed: () => setState(() {
                        _amount.text = devInput(usual * .5);
                        _unit = widget.recipe!.portionUnit;
                      }),
                    ),
                  ),
                  Semantics(
                    identifier: 'log-portion-usual',
                    child: ActionChip(
                      label: Text(s.devUsual),
                      onPressed: () => setState(() {
                        _amount.text = devInput(usual);
                        _unit = widget.recipe!.portionUnit;
                      }),
                    ),
                  ),
                  Semantics(
                    identifier: 'log-portion-large',
                    child: ActionChip(
                      label: Text(s.devLarge),
                      onPressed: () => setState(() {
                        _amount.text = devInput(usual * 1.5);
                        _unit = widget.recipe!.portionUnit;
                      }),
                    ),
                  ),
                ],
              ),
              DevButton(
                id: 'save-usual-serving',
                label: s.devMyUsual,
                icon: Icons.bookmark_outline,
                onPressed: _saveUsual,
              ),
              DevNumberField(
                id: 'extra-oil',
                label: s.devExtraOil,
                controller: _oil,
                helper: s.devExtraOilHelp,
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (widget.recipe == null ||
                ![widget.recipe!.portionUnit, 'serving'].contains(_unit))
              DevButton(
                id: 'calibrate-measure',
                label: s.devCalibrate,
                icon: Icons.straighten,
                onPressed: _calibrate,
              ),
            if (widget.meal.isLiquid)
              Text(
                s.devLiquidMeasures,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (preview != null)
              DevNutritionLine(meal: preview.$1, amount: preview.$2),
            Text(
              s.devNutritionPartial,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Semantics(
              identifier: 'log-meal-type',
              child: DropdownButtonFormField<IntakeTypeEntity>(
                initialValue: _type,
                decoration: InputDecoration(labelText: s.devType),
                items: IntakeTypeEntity.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t.name[0].toUpperCase() + t.name.substring(1),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
            ),
            DevButton(
              id: 'log-choose-day',
              label: '${s.devDay}: ${_day.year}-${_day.month}-${_day.day}',
              icon: Icons.calendar_month,
              onPressed: () async {
                final day = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (day != null && mounted) setState(() => _day = day);
              },
            ),
            if (widget.recipe?.description != null)
              Semantics(
                identifier: 'log-ingredient-notes',
                child: ExpansionTile(
                  title: Text(s.devIngredientNotes),
                  children: [
                    Text(widget.recipe!.description!),
                    for (final ingredient in widget.recipe!.ingredients)
                      ListTile(
                        dense: true,
                        title: Text(ingredient.snapshotMeal.name ?? ''),
                        trailing: Text(
                          '${devNumber(ingredient.amount)} ${ingredient.unit}',
                        ),
                      ),
                  ],
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            DevButton(
              id: 'log-confirm',
              label: s.devLog,
              icon: Icons.check,
              filled: true,
              onPressed: _saving ? null : _log,
            ),
          ],
        ),
      ),
    );
  }
}
