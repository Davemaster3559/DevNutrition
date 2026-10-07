import 'dart:convert';

/// Profile-specific settings stored inside the existing encrypted config box.
class DevNutritionPreferences {
  final double calorieGoal;
  final double proteinGoal;
  final double carbGoal;
  final double fatGoal;
  final double goalWeightKg;
  final bool eatBackExercise;
  final bool seeded;
  final List<String> pins;
  final Map<String, Map<String, double>> measures;
  final Map<String, double> usualServings;
  final String? flourCode;
  final String? riceCode;

  const DevNutritionPreferences({
    this.calorieGoal = 1700,
    this.proteinGoal = 120,
    this.carbGoal = 180,
    this.fatGoal = 55,
    this.goalWeightKg = 80,
    this.eatBackExercise = false,
    this.seeded = false,
    this.pins = const [],
    this.measures = const {},
    this.usualServings = const {},
    this.flourCode,
    this.riceCode,
  });

  factory DevNutritionPreferences.decode(String? value) => value == null
      ? const DevNutritionPreferences()
      : DevNutritionPreferences.fromJson(
          Map<String, dynamic>.from(jsonDecode(value) as Map),
        );

  factory DevNutritionPreferences.fromJson(Map<String, dynamic> json) {
    if (json['version'] != null && json['version'] != 1) {
      throw const FormatException('Unsupported DevNutrition settings version');
    }
    double positive(dynamic value, double fallback) =>
        value is num && value.isFinite && value > 0
        ? value.toDouble()
        : fallback;
    final measures = <String, Map<String, double>>{};
    for (final entry in (json['measures'] as Map? ?? {}).entries) {
      measures[entry.key as String] = {
        for (final unit in (entry.value as Map).entries)
          if (unit.value is num &&
              (unit.value as num).isFinite &&
              (unit.value as num) > 0)
            unit.key as String: (unit.value as num).toDouble(),
      };
    }
    return DevNutritionPreferences(
      calorieGoal: positive(json['calorieGoal'], 1700),
      proteinGoal: positive(json['proteinGoal'], 120),
      carbGoal: positive(json['carbGoal'], 180),
      fatGoal: positive(json['fatGoal'], 55),
      goalWeightKg: positive(json['goalWeightKg'], 80),
      eatBackExercise: json['eatBackExercise'] == true,
      seeded: json['seeded'] == true,
      pins: List<String>.from(json['pins'] as List? ?? []),
      measures: measures,
      usualServings: {
        for (final entry in (json['usualServings'] as Map? ?? {}).entries)
          if (entry.value is num &&
              (entry.value as num).isFinite &&
              (entry.value as num) > 0)
            entry.key as String: (entry.value as num).toDouble(),
      },
      flourCode: json['flourCode'] as String?,
      riceCode: json['riceCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'calorieGoal': calorieGoal,
    'proteinGoal': proteinGoal,
    'carbGoal': carbGoal,
    'fatGoal': fatGoal,
    'goalWeightKg': goalWeightKg,
    'eatBackExercise': eatBackExercise,
    'seeded': seeded,
    'pins': pins,
    'measures': measures,
    'usualServings': usualServings,
    'flourCode': flourCode,
    'riceCode': riceCode,
  };

  String encode() => jsonEncode(toJson());

  DevNutritionPreferences copyWith({
    double? calorieGoal,
    double? proteinGoal,
    double? carbGoal,
    double? fatGoal,
    double? goalWeightKg,
    bool? eatBackExercise,
    bool? seeded,
    List<String>? pins,
    Map<String, Map<String, double>>? measures,
    Map<String, double>? usualServings,
    String? flourCode,
    String? riceCode,
  }) => DevNutritionPreferences(
    calorieGoal: calorieGoal ?? this.calorieGoal,
    proteinGoal: proteinGoal ?? this.proteinGoal,
    carbGoal: carbGoal ?? this.carbGoal,
    fatGoal: fatGoal ?? this.fatGoal,
    goalWeightKg: goalWeightKg ?? this.goalWeightKg,
    eatBackExercise: eatBackExercise ?? this.eatBackExercise,
    seeded: seeded ?? this.seeded,
    pins: pins ?? this.pins,
    measures: measures ?? this.measures,
    usualServings: usualServings ?? this.usualServings,
    flourCode: flourCode ?? this.flourCode,
    riceCode: riceCode ?? this.riceCode,
  );
}
