import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

/// Publisher-sourced reference foods bundled with the application.
class LocalFoodCatalogue {
  Future<List<MealEntity>>? _foods;

  Future<List<MealEntity>> all() => _foods ??= _load();

  Future<List<MealEntity>> _load() async {
    final data =
        jsonDecode(await rootBundle.loadString('assets/data/dev_foods.json'))
            as List;
    return data
        .map(
          (row) => MealEntity.fromMealDBO(
            MealDBO.fromJson(Map<String, dynamic>.from(row as Map)),
          ),
        )
        .toList();
  }

  Future<List<MealEntity>> search(String query) async {
    final terms = query.toLowerCase().trim().split(RegExp(r'\s+'));
    final matches = (await all()).where((food) {
      final text = '${food.name} ${food.brands}'.toLowerCase();
      return terms.every(text.contains);
    }).toList();
    matches.sort((a, b) {
      final indian = (a.backendSource == 'indb' ? 0 : 1).compareTo(
        b.backendSource == 'indb' ? 0 : 1,
      );
      return indian != 0 ? indian : (a.name ?? '').compareTo(b.name ?? '');
    });
    return matches.take(60).toList();
  }
}
