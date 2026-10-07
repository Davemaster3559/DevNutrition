import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';
import 'package:hive_ce/hive.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/water_intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/fasting_session_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';

/// Additional local datasets in the existing canonical ZIP. The active
/// profile is portable; Android keystore keys and remote credentials are not.
class DevNutritionBackup {
  final HiveDBProvider db;
  DevNutritionBackup(this.db);

  Map<String, dynamic> snapshot() {
    List<Map<String, dynamic>> entries<T>(
      Box<T> box,
      Map<String, dynamic> Function(T) encode,
    ) => box
        .toMap()
        .entries
        .map((e) => <String, dynamic>{'key': e.key, 'value': encode(e.value)})
        .toList();
    return {
      'version': 1,
      'appConfig': entries(db.appConfigBox, (v) => v.toJson()),
      'profileConfig': entries(db.configBox, (v) => v.toJson()),
      'user': entries(db.userBox, (v) => v.toJson()),
      'water': entries(db.waterIntakeBox, (v) => v.toJson()),
      'fasting': entries(db.fastingBox, (v) => v.toJson()),
      'foods': db.customMealBox.values.map((v) => v.toJson()).toList(),
    };
  }

  /// Validate the extension before the importer changes any diary records.
  void validate(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported DevNutrition backup version');
    }
    void rows<T>(String name, T Function(Map<String, dynamic>) factory) {
      for (final row in json[name] as List) {
        if (row['key'] is! String && row['key'] is! int) {
          throw const FormatException('Invalid backup record key');
        }
        factory(Map<String, dynamic>.from(row['value'] as Map));
      }
    }

    rows('appConfig', ConfigDBO.fromJson);
    rows('profileConfig', (row) {
      final config = ConfigDBO.fromJson(row);
      DevNutritionPreferences.decode(config.devNutritionJson);
      return config;
    });
    rows('user', UserDBO.fromJson);
    rows('water', WaterIntakeDBO.fromJson);
    rows('fasting', FastingSessionDBO.fromJson);
    for (final row in json['foods'] as List) {
      MealDBO.fromJson(Map<String, dynamic>.from(row as Map));
    }
  }

  Future<void> restore(Map<String, dynamic> json) async {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported DevNutrition backup version');
    }
    Map<dynamic, T> decode<T>(
      String name,
      T Function(Map<String, dynamic>) factory,
    ) => {
      for (final row in (json[name] as List))
        row['key']: factory(Map<String, dynamic>.from(row['value'] as Map)),
    };
    // Decode every dataset before the first write.
    final app = decode('appConfig', ConfigDBO.fromJson);
    final profile = decode('profileConfig', ConfigDBO.fromJson);
    final users = decode('user', UserDBO.fromJson);
    final water = decode('water', WaterIntakeDBO.fromJson);
    final fasting = decode('fasting', FastingSessionDBO.fromJson);
    final foods = (json['foods'] as List)
        .map((r) => MealDBO.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    // Consent is device-local. Restoring nutrition never opts a new device
    // into telemetry or health import. An explicit settings action can do so.
    for (final config in app.values) {
      config.hasAcceptedSendAnonymousData = false;
    }
    for (final config in profile.values) {
      config.healthImportEnabled = false;
    }
    await db.appConfigBox.putAll(app);
    await db.configBox.putAll(profile);
    await db.userBox.putAll(users);
    // Auto-increment Hive keys belong to each installation. Merge histories
    // by the stable record id so a different local row at key 0 survives.
    for (final record in water.values) {
      final existing = db.waterIntakeBox.values.where((v) => v.id == record.id);
      if (existing.isEmpty) {
        await db.waterIntakeBox.add(record);
      } else {
        await db.waterIntakeBox.put(existing.first.key, record);
      }
    }
    for (final record in fasting.values) {
      final existing = db.fastingBox.values.where((v) => v.id == record.id);
      if (existing.isEmpty) {
        await db.fastingBox.add(record);
      } else {
        await db.fastingBox.put(existing.first.key, record);
      }
    }
    final source = CustomMealDataSource(db);
    for (final food in foods) {
      await source.saveCustomMeal(food);
    }
  }
}
