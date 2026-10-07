import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_type_suggester.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/quick_log/data/quick_log_repository.dart';
import 'package:opennutritracker/features/quick_log/domain/cooking_batch.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';
import 'package:opennutritracker/features/quick_log/presentation/dev_widgets.dart';
import 'package:opennutritracker/generated/l10n.dart';

class CookingBatchScreen extends StatefulWidget {
  final bool roti;
  final DateTime day;
  const CookingBatchScreen({super.key, required this.roti, required this.day});
  @override
  State<CookingBatchScreen> createState() => _CookingBatchScreenState();
}

class _CookingBatchScreenState extends State<CookingBatchScreen> {
  final _repository = locator<QuickLogRepository>();
  final _dry = TextEditingController(text: '1');
  final _cup = TextEditingController();
  final _portions = TextEditingController();
  final _eat = TextEditingController();
  final _fraction = TextEditingController();
  final _fat = TextEditingController(text: '0');
  final _name = TextEditingController();
  DevNutritionPreferences? _preferences;
  List<MealEntity> _foods = [];
  MealEntity? _product;
  String _dryUnit = 'cup';
  String _fatCode = 'none';
  bool _fatPerRoti = false, _saving = false;
  String? _error;
  late IntakeTypeEntity _type;
  @override
  void initState() {
    super.initState();
    _type = MealTypeSuggester.suggestFromTime(DateTime.now());
    _portions.text = widget.roti ? '8' : '4';
    _eat.text = widget.roti ? '2' : '1';
    _load();
  }

  Future<void> _load() async {
    final preferences = await _repository.preferences();
    final foods = [
      ...await _repository.savedFoods(),
      ...await _repository.catalogue.all(),
    ];
    final code = widget.roti
        ? preferences.flourCode ?? '168893'
        : preferences.riceCode ?? '168877';
    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _foods = foods;
      _product = foods.firstWhere(
        (f) => f.code == code,
        orElse: () => foods.firstWhere(
          (f) => f.code == (widget.roti ? '168893' : '168877'),
        ),
      );
      _cup.text =
          preferences.measures[_product!.code]?['cup']?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    for (final c in [_dry, _cup, _portions, _eat, _fat, _name, _fraction]) {
      c.dispose();
    }
    super.dispose();
  }

  RecipeEntity? get _batch {
    final dry = devParse(_dry.text), cup = devParse(_cup.text);
    final portions = int.tryParse(_portions.text);
    final fat = _fat.text.trim().isEmpty
        ? 0.0
        : double.tryParse(_fat.text.replaceAll(',', '.'));
    if (_product == null ||
        dry == null ||
        portions == null ||
        portions <= 0 ||
        fat == null ||
        !fat.isFinite ||
        fat < 0 ||
        (_dryUnit == 'cup' && cup == null)) {
      return null;
    }
    return CookingBatch.create(
      id: IdGenerator.getUniqueID(),
      name: _name.text.trim().isEmpty
          ? (widget.roti ? S.of(context).devRoti : S.of(context).devRice)
          : _name.text.trim(),
      dryFood: _product!,
      dryGrams: dry * (_dryUnit == 'cup' ? cup! : 1),
      portions: portions,
      portionUnit: widget.roti ? 'roti' : 'serving',
      fat: _fatCode == 'none'
          ? null
          : _foods.firstWhere((f) => f.code == _fatCode),
      fatGrams: fat,
      fatPerPortion: widget.roti && _fatPerRoti,
    );
  }

  Future<void> _persistChoices() async {
    final key = _product!.code ?? _product!.name!;
    final cup = devParse(_cup.text);
    final current = await _repository.preferences();
    final preferences = current.copyWith(
      flourCode: widget.roti ? key : null,
      riceCode: widget.roti ? null : key,
      measures: {
        ...current.measures,
        if (cup != null) key: {...?current.measures[key], 'cup': cup},
      },
    );
    await _repository.savePreferences(preferences);
    _preferences = preferences;
  }

  Future<void> _save({required bool log}) async {
    final batch = _batch, eat = devParse(_eat.text);
    final fraction = devParse(_fraction.text);
    if (batch == null ||
        (log &&
            (eat == null ||
                (_fraction.text.isNotEmpty &&
                    (fraction == null || fraction > 1))))) {
      setState(() => _error = S.of(context).devPositive);
      return;
    }
    if (log && eat! > batch.servingsCount!) {
      setState(() => _error = S.of(context).devFatTooMuch);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _persistChoices();
      if (_name.text.trim().isNotEmpty || !log) {
        await _repository.recipes.saveRecipe(batch);
      }
      if (log) {
        final per = batch.totalWeightG / batch.servingsCount!;
        await _repository.log(
          batch.toMealEntity(),
          per * eat!,
          _type,
          widget.day,
          displayUnit: batch.portionUnit,
          baseAmountPerDisplayUnit: per,
        );
        refreshNutritionScreens();
        if (mounted) Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).devSavedBatch)));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = S.of(context).devStorageError;
        });
      }
    }
  }

  Future<void> _chooseProduct() async {
    final product = await pickDevFood(context);
    if (product == null || !mounted) return;
    await _repository.saveFood(product);
    if (!mounted) return;
    setState(() {
      _product = product;
      _foods = [product, ..._foods.where((f) => f.code != product.code)];
      _cup.text =
          _preferences!.measures[product.code]?['cup']?.toString() ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_preferences == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final batch = _batch;
    return Scaffold(
      appBar: AppBar(title: Text(widget.roti ? s.devRoti : s.devRice)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(s.devBatchHelp),
          const SizedBox(height: 12),
          Semantics(
            identifier: 'batch-product',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.roti ? s.devFlour : s.devRiceProduct),
              subtitle: Text(
                _product!.name ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.swap_horiz),
              onTap: _chooseProduct,
            ),
          ),
          Text(s.devProductHelp, style: Theme.of(context).textTheme.bodySmall),
          DevNumberField(
            id: 'batch-dry-amount',
            label: s.devDryAmount,
            controller: _dry,
            onChanged: (_) => setState(() {}),
          ),
          Semantics(
            identifier: 'batch-dry-unit',
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cup', label: Text('cup')),
                ButtonSegment(value: 'g', label: Text('g')),
              ],
              selected: {_dryUnit},
              onSelectionChanged: (v) => setState(() => _dryUnit = v.first),
            ),
          ),
          if (_dryUnit == 'cup') ...[
            const SizedBox(height: 8),
            Semantics(
              identifier: 'batch-cup-fractions',
              child: Wrap(
                spacing: 6,
                children: [
                  for (final n in [.25, .5, .75, 1.0, 1.25, 1.5])
                    Semantics(
                      identifier: 'batch-cup-${(n * 100).round()}',
                      child: ActionChip(
                        label: Text('${devNumber(n)} cup'),
                        onPressed: () =>
                            setState(() => _dry.text = devNumber(n)),
                      ),
                    ),
                ],
              ),
            ),
            DevNumberField(
              id: 'batch-cup-grams',
              label: s.devCupWeight,
              controller: _cup,
              helper: s.devCalibrationHint,
              onChanged: (_) => setState(() {}),
            ),
          ],
          DevNumberField(
            id: 'batch-portions-produced',
            label: widget.roti ? s.devMadeRotis : s.devRiceServings,
            controller: _portions,
            onChanged: (_) => setState(() {}),
          ),
          Semantics(
            identifier: 'batch-fat-product',
            child: DropdownButtonFormField<String>(
              initialValue: _fatCode,
              decoration: InputDecoration(labelText: s.devFatProduct),
              items: [
                DropdownMenuItem(value: 'none', child: Text(s.devNone)),
                DropdownMenuItem(value: '171413', child: Text(s.devOil)),
                DropdownMenuItem(value: '173412', child: Text(s.devGhee)),
                DropdownMenuItem(value: '173410', child: Text(s.devButter)),
              ],
              onChanged: (v) => setState(() => _fatCode = v!),
            ),
          ),
          if (_fatCode != 'none') ...[
            DevNumberField(
              id: 'batch-fat-grams',
              label: s.devFatAmount,
              controller: _fat,
              onChanged: (_) => setState(() {}),
            ),
            if (widget.roti)
              Semantics(
                identifier: 'batch-fat-per-roti',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.devPerRoti),
                  subtitle: Text(s.devFatMode),
                  value: _fatPerRoti,
                  onChanged: (v) => setState(() => _fatPerRoti = v),
                ),
              ),
          ],
          if (batch != null) ...[
            const Divider(),
            Text(
              s.devBatchTotal,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            DevNutritionLine(
              meal: batch.toMealEntity(),
              amount: batch.totalWeightG,
            ),
            Text(
              s.devPerPortion,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            DevNutritionLine(
              meal: batch.toMealEntity(),
              amount: batch.totalWeightG / batch.servingsCount!,
            ),
            Text(
              s.devNutritionKnown,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!widget.roti)
            Semantics(
              identifier: 'rice-batch-fraction',
              child: Wrap(
                spacing: 6,
                children: [
                  for (final fraction in [1.0, .5, 1 / 3, .25])
                    Semantics(
                      identifier: 'rice-fraction-${(fraction * 100).round()}',
                      child: ActionChip(
                        label: Text(
                          fraction == 1
                              ? s.devWholeBatch
                              : fraction == .5
                              ? '1/2'
                              : fraction == .25
                              ? '1/4'
                              : '1/3',
                        ),
                        onPressed: () => setState(() {
                          _fraction.clear();
                          _eat.text =
                              ((int.tryParse(_portions.text) ?? 1) * fraction)
                                  .toString();
                        }),
                      ),
                    ),
                ],
              ),
            ),
          if (!widget.roti)
            DevNumberField(
              id: 'rice-custom-fraction',
              label: s.devRiceFraction,
              controller: _fraction,
              onChanged: (v) {
                final fraction = devParse(v),
                    portions = int.tryParse(_portions.text);
                if (fraction != null && fraction <= 1 && portions != null) {
                  setState(() => _eat.text = devInput(fraction * portions));
                }
              },
            ),
          DevNumberField(
            id: 'batch-eat-amount',
            label: widget.roti ? s.devEatRotis : s.devEatServings,
            controller: _eat,
            onChanged: (_) => setState(() => _fraction.clear()),
          ),
          Semantics(
            identifier: 'batch-meal-type',
            child: DropdownButtonFormField<IntakeTypeEntity>(
              initialValue: _type,
              decoration: InputDecoration(labelText: s.devType),
              items: IntakeTypeEntity.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            identifier: 'batch-save-name',
            child: TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: s.devBatchName,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          DevButton(
            id: 'batch-save-recipe',
            label: s.devSave,
            icon: Icons.bookmark_add_outlined,
            onPressed: _saving ? null : () => _save(log: false),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          DevButton(
            id: 'batch-log',
            label: s.devLog,
            icon: Icons.check,
            filled: true,
            onPressed: _saving ? null : () => _save(log: true),
          ),
        ],
      ),
    );
  }
}
