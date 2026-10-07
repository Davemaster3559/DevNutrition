import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/utils/calc/macro_calc.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';

class GetMacroGoalUsecase {
  final ConfigRepository _configRepository;

  GetMacroGoalUsecase(this._configRepository);

  Future<double> getCarbsGoal(double totalCalorieGoal) async {
    final config = await _configRepository.getConfig();
    final userCarbGoal = config.userCarbGoalPct;
    if (config.devNutritionJson != null) {
      return DevNutritionPreferences.decode(config.devNutritionJson).carbGoal;
    }

    return MacroCalc.getTotalCarbsGoal(
      totalCalorieGoal,
      userCarbsGoal: userCarbGoal,
    );
  }

  Future<double> getFatsGoal(double totalCalorieGoal) async {
    final config = await _configRepository.getConfig();
    final userFatGoal = config.userFatGoalPct;
    if (config.devNutritionJson != null) {
      return DevNutritionPreferences.decode(config.devNutritionJson).fatGoal;
    }

    return MacroCalc.getTotalFatsGoal(
      totalCalorieGoal,
      userFatsGoal: userFatGoal,
    );
  }

  Future<double> getProteinsGoal(double totalCalorieGoal) async {
    final config = await _configRepository.getConfig();
    final userProteinGoal = config.userProteinGoalPct;
    if (config.devNutritionJson != null) {
      return DevNutritionPreferences.decode(
        config.devNutritionJson,
      ).proteinGoal;
    }

    return MacroCalc.getTotalProteinsGoal(
      totalCalorieGoal,
      userProteinsGoal: userProteinGoal,
    );
  }
}
