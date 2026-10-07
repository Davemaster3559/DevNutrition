import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_type_suggester.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_activity/presentation/add_activity_screen.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/quick_log/data/quick_log_repository.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';
import 'package:opennutritracker/features/quick_log/presentation/cooking_batch_screen.dart';
import 'package:opennutritracker/features/quick_log/presentation/dev_widgets.dart';
import 'package:opennutritracker/features/quick_log/presentation/goals_screen.dart';
import 'package:opennutritracker/features/quick_log/presentation/meal_log_sheet.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/recipe_builder_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class QuickLogScreen extends StatefulWidget {
  final DateTime? day;
  const QuickLogScreen({super.key, this.day});
  @override
  State<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickItem {
  final MealEntity meal;
  final RecipeEntity? recipe;
  final IntakeEntity? recent;
  const _QuickItem(this.meal, {this.recipe, this.recent});
  String get key => meal.code ?? meal.name ?? '';
}

class _QuickLogScreenState extends State<QuickLogScreen> {
  final _repository = locator<QuickLogRepository>();
  final _search = TextEditingController();
  DevNutritionPreferences? _preferences;
  List<_QuickItem> _items = [], _recent = [];
  String _filter = 'pinned';
  String? _error;
  bool _logging = false;
  late DateTime _day;
  @override
  void initState() {
    super.initState();
    _day = widget.day ?? DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _repository.seed();
      final prefs = await _repository.preferences();
      final recipes = _repository.recipes
          .getAllRecipesDBO()
          .map(RecipeEntity.fromDBO)
          .toList();
      final foods = await _repository.savedFoods();
      final reference = await _repository.catalogue.all();
      final history =
          (await _repository.intakes.getAllIntakesDBO())
              .map(IntakeEntity.fromIntakeDBO)
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final seen = <String>{};
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
        _recent = history
            .where((i) => seen.add(i.meal.code ?? i.meal.name ?? ''))
            .take(30)
            .map((i) => _QuickItem(i.meal, recent: i))
            .toList();
        final foodKeys = foods.map((f) => f.code ?? f.name).toSet();
        _items = [
          ...foods.map((f) => _QuickItem(f)),
          ...recipes.map((r) => _QuickItem(r.toMealEntity(), recipe: r)),
          ...reference
              .where((f) => !foodKeys.contains(f.code ?? f.name))
              .map((f) => _QuickItem(f)),
        ];
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<_QuickItem> get _visible {
    if (_preferences == null) return [];
    final text = _search.text.trim().toLowerCase();
    var items = _filter == 'recent' ? _recent : _items;
    if (text.isNotEmpty) {
      final terms = text.split(RegExp(r'\s+'));
      final unique = <String>{};
      items =
          [
                ..._items.where(
                  (i) =>
                      i.recipe != null ||
                      i.meal.source == MealSourceEntity.custom,
                ),
                ..._recent,
                ..._items,
              ]
              .where(
                (i) =>
                    unique.add(i.key) &&
                    terms.every(
                      '${i.meal.name} ${i.meal.brands}'.toLowerCase().contains,
                    ),
              )
              .toList();
    } else {
      items = items
          .where(
            (i) => switch (_filter) {
              'pinned' => _preferences!.pins.contains(i.key),
              'presets' => i.recipe?.kind == 'preset',
              'recipes' => i.recipe?.kind == 'recipe',
              'foods' => i.recipe == null,
              _ => true,
            },
          )
          .toList();
      if (_filter == 'pinned') {
        items.sort(
          (a, b) => _preferences!.pins
              .indexOf(a.key)
              .compareTo(_preferences!.pins.indexOf(b.key)),
        );
      }
    }
    return items.take(80).toList();
  }

  Future<void> _oneTap(_QuickItem item) async {
    if (_logging) return;
    setState(() => _logging = true);
    try {
      final recipe = item.recipe, recent = item.recent;
      final unit = recipe?.portionUnit ?? recent?.displayUnit ?? 'serving';
      final per = recipe == null
          ? (recent?.baseAmountPerDisplayUnit ??
                item.meal.scalableServingQuantity ??
                100)
          : recipe.totalWeightG / (recipe.servingsCount ?? 1);
      final amount =
          recent?.amount ??
          per *
              (recipe == null
                  ? 1
                  : _preferences!.usualServings[recipe.id] ?? 1);
      await _repository.log(
        item.meal,
        amount,
        MealTypeSuggester.suggestFromTime(DateTime.now()),
        _day,
        displayUnit: unit,
        baseAmountPerDisplayUnit: per,
      );
      refreshNutritionScreens();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).devLogged)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).devStorageError)));
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _edit(_QuickItem item) async {
    if (item.recipe != null) {
      await Navigator.of(context).pushNamed(
        NavigationOptions.recipeBuilderRoute,
        arguments: RecipeBuilderArguments(existing: item.recipe),
      );
    } else {
      await Navigator.of(context).pushNamed(
        NavigationOptions.editMealRoute,
        arguments: EditMealScreenArguments(
          _day,
          item.meal,
          MealTypeSuggester.suggestFromTime(DateTime.now()),
          false,
          editOnly: true,
        ),
      );
    }
    await _load();
  }

  Future<void> _newRecipe(String kind) async {
    final now = DateTime.now();
    final empty = RecipeEntity(
      id: '',
      name: '',
      description: null,
      ingredients: const [],
      totalWeightG: 0,
      aggregatedNutrimentsPer100: MealNutrimentsEntity.empty(),
      createdAt: now,
      updatedAt: now,
      servingsCount: 1,
      kind: kind,
      portionUnit: kind == 'recipe' ? 'katori' : 'serving',
    );
    await Navigator.of(context).pushNamed(
      NavigationOptions.recipeBuilderRoute,
      arguments: RecipeBuilderArguments(existing: empty),
    );
    await _load();
  }

  Future<void> _searchOrScan() async {
    final food = await pickDevFood(context);
    if (food == null || !mounted) return;
    await _repository.saveFood(food);
    if (!mounted) return;
    await showDevMealLog(context, food, day: _day);
    await _load();
  }

  Future<void> _batch(bool roti) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CookingBatchScreen(roti: roti, day: _day),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = _visible;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.devQuickLog),
        actions: [
          Semantics(
            identifier: 'quick-goals',
            child: IconButton(
              icon: const Icon(Icons.tune),
              tooltip: s.devGoals,
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GoalsScreen())),
            ),
          ),
          Semantics(
            identifier: 'quick-more',
            child: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'preset' || v == 'recipe') {
                  await _newRecipe(v);
                }
                if (v == 'food') {
                  if (!context.mounted) return;
                  await Navigator.of(context).pushNamed(
                    NavigationOptions.editMealRoute,
                    arguments: EditMealScreenArguments(
                      _day,
                      MealEntity.empty(),
                      MealTypeSuggester.suggestFromTime(DateTime.now()),
                      false,
                      editOnly: true,
                    ),
                  );
                  await _load();
                }
                if (v == 'activity' && context.mounted) {
                  await Navigator.of(context).pushNamed(
                    NavigationOptions.addActivityRoute,
                    arguments: AddActivityScreenArguments(day: _day),
                  );
                  refreshNutritionScreens();
                }
                if (v == 'about' && context.mounted) {
                  showAboutDialog(
                    context: context,
                    applicationName: 'DevNutrition',
                    applicationVersion: '1.0 · OpenNutriTracker 2.4.0',
                    children: [Text(s.devAboutText)],
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'preset', child: Text(s.devNewPreset)),
                PopupMenuItem(value: 'recipe', child: Text(s.devNewRecipe)),
                PopupMenuItem(value: 'food', child: Text(s.devNewFood)),
                PopupMenuItem(value: 'activity', child: Text(s.devActivity)),
                PopupMenuItem(value: 'about', child: Text(s.devAbout)),
              ],
            ),
          ),
        ],
      ),
      body: _preferences == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    s.devQuickHint,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(s.devDietHint),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      DevButton(
                        id: 'quick-roti',
                        label: s.devRoti,
                        icon: Icons.bakery_dining,
                        onPressed: () => _batch(true),
                      ),
                      DevButton(
                        id: 'quick-rice',
                        label: s.devRice,
                        icon: Icons.rice_bowl,
                        onPressed: () => _batch(false),
                      ),
                      DevButton(
                        id: 'quick-search-scan',
                        label: s.devSearchScan,
                        icon: Icons.qr_code_scanner,
                        onPressed: _searchOrScan,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    identifier: 'quick-search',
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: s.devSearchHint,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    identifier: 'quick-filters',
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final entry in {
                          'pinned': s.devPinned,
                          'presets': s.devPresets,
                          'recipes': s.devRecipes,
                          'foods': s.devFoods,
                          'recent': s.devRecent,
                          'all': s.devAll,
                        }.entries)
                          Semantics(
                            identifier: 'quick-filter-${entry.key}',
                            child: ChoiceChip(
                              label: Text(entry.value),
                              selected: _filter == entry.key,
                              onSelected: (_) =>
                                  setState(() => _filter = entry.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_filter == 'pinned')
                    Text(
                      s.devManagePins,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (_error != null) Text(_error!),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(s.devEmpty),
                    ),
                  Semantics(
                    identifier: 'quick-meals',
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              item.meal.name ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.recipe == null
                                      ? devSource(item.meal)
                                      : item.recipe!.kind == 'preset'
                                      ? s.devPresets
                                      : '${s.devRecipes} · ${item.recipe!.portionUnit}',
                                ),
                                DevNutritionLine(
                                  meal: item.meal,
                                  amount: item.recipe == null
                                      ? item.recent?.amount ??
                                            item.meal.scalableServingQuantity ??
                                            100
                                      : item.recipe!.totalWeightG /
                                            (item.recipe!.servingsCount ?? 1) *
                                            (_preferences!.usualServings[item
                                                    .key] ??
                                                1),
                                ),
                              ],
                            ),
                            onTap: () async {
                              await showDevMealLog(
                                context,
                                item.meal,
                                recipe: item.recipe,
                                day: _day,
                              );
                              await _load();
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  tooltip: s.devOneTap,
                                  onPressed: _logging
                                      ? null
                                      : () => _oneTap(item),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'pin') {
                                      if (item.recipe == null) {
                                        await _repository.saveFood(item.meal);
                                      }
                                      await _repository.pin(item.key);
                                    }
                                    if (v == 'edit') await _edit(item);
                                    if (v == 'up') {
                                      await _repository.reorderPin(
                                        item.key,
                                        -1,
                                      );
                                    }
                                    if (v == 'down') {
                                      await _repository.reorderPin(item.key, 1);
                                    }
                                    await _load();
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'pin',
                                      child: Text(s.devPin),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(
                                        item.recipe == null
                                            ? s.devEditLabel
                                            : s.devViewRecipe,
                                      ),
                                    ),
                                    if (_preferences!.pins.contains(
                                      item.key,
                                    )) ...[
                                      PopupMenuItem(
                                        value: 'up',
                                        child: Text(s.devMoveUp),
                                      ),
                                      PopupMenuItem(
                                        value: 'down',
                                        child: Text(s.devMoveDown),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
