import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/trends/presentation/bloc/trends_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/food_search_tab_view.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

String devNumber(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
String devInput(double value) =>
    value.toString().replaceFirst(RegExp(r'\.0$'), '');
double? devParse(String value) {
  final n = double.tryParse(value.trim().replaceAll(',', '.'));
  return n != null && n.isFinite && n > 0 ? n : null;
}

void refreshNutritionScreens() {
  if (locator.isRegistered<HomeBloc>()) {
    locator<HomeBloc>().add(const LoadItemsEvent());
  }
  if (locator.isRegistered<DiaryBloc>()) {
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
  }
  if (locator.isRegistered<CalendarDayBloc>()) {
    locator<CalendarDayBloc>().add(const RefreshCalendarDayEvent());
  }
  if (locator.isRegistered<TrendsBloc>()) {
    locator<TrendsBloc>().add(const LoadTrendsEvent());
  }
}

class DevNumberField extends StatelessWidget {
  final String id;
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? helper;
  const DevNumberField({
    super.key,
    required this.id,
    required this.label,
    required this.controller,
    this.onChanged,
    this.helper,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Semantics(
      identifier: id,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      ),
    ),
  );
}

class DevButton extends StatelessWidget {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  const DevButton({
    super.key,
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    identifier: id,
    child: filled
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          ),
  );
}

class DevNutritionLine extends StatelessWidget {
  final MealEntity meal;
  final double amount;
  const DevNutritionLine({super.key, required this.meal, required this.amount});
  @override
  Widget build(BuildContext context) {
    String value(double? n) => n == null ? '—' : devNumber(n * amount / 100);
    final n = meal.nutriments;
    return Text(
      '${value(n.energyKcal100)} kcal  ·  P ${value(n.proteins100)} g  ·  C ${value(n.carbohydrates100)} g  ·  F ${value(n.fat100)} g',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

Future<MealEntity?> pickDevFood(BuildContext context) =>
    Navigator.of(context).push<MealEntity>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: Text(S.of(ctx).devPickFood)),
          body: FoodSearchTabView(
            onMealSelected: (meal) => Navigator.of(ctx).pop(meal),
            onBarcodePressed: () async {
              final result = await Navigator.of(ctx).pushNamed(
                NavigationOptions.scannerRoute,
                arguments: ScannerScreenArguments.pick(),
              );
              if (result is MealEntity && ctx.mounted) {
                Navigator.of(ctx).pop(result);
              }
            },
          ),
        ),
      ),
    );

String devSource(MealEntity meal) => switch (meal.backendSource) {
  'indb' => 'Anuvaad INDB · reference estimate',
  'fdc_sr_legacy' => 'USDA SR Legacy · reference',
  'label' => 'Product label reference',
  _ => switch (meal.source) {
    MealSourceEntity.custom => 'My food / product label',
    MealSourceEntity.recipe => 'My recipe / meal preset',
    MealSourceEntity.off => 'Open Food Facts',
    _ => meal.backendSource ?? 'Reference food',
  },
};
