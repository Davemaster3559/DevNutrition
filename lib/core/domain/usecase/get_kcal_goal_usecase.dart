import 'package:collection/collection.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';

class GetKcalGoalUsecase {
  final UserRepository _userRepository;
  final ConfigRepository _configRepository;
  final UserActivityRepository _userActivityRepository;

  GetKcalGoalUsecase(
    this._userRepository,
    this._configRepository,
    this._userActivityRepository,
  );

  Future<double> getKcalGoal({
    UserEntity? userEntity,
    double? totalKcalActivitiesParam,
    double? kcalUserAdjustment,
    DateTime? day,
  }) async {
    final user = userEntity ?? await _userRepository.getUserData();
    final config = await _configRepository.getConfig();
    if (config.devNutritionJson != null) {
      final preferences = DevNutritionPreferences.decode(
        config.devNutritionJson,
      );
      if (!preferences.eatBackExercise) return preferences.calorieGoal;
    }
    final totalKcalActivities =
        totalKcalActivitiesParam ??
        (await _userActivityRepository.getAllUserActivityByDate(
          // #586: the query takes a day label, so "today" has to be
          // resolved through the boundary first. A raw DateTime.now()
          // here asks for the wall-clock date, which between midnight
          // and the boundary is a different day than the one Home's
          // activity list shows — the goal would silently drop those
          // burned calories.
          day ??
              DayBoundaryCalc.currentLogicalDayLabel(
                config.dayStartOffsetHours,
                config.dayStartOffsetMinutes,
              ),
          dayStartOffsetHours: config.dayStartOffsetHours,
          dayStartOffsetMinutes: config.dayStartOffsetMinutes,
        )).map((activity) => activity.burnedKcal).toList().sum;
    if (config.devNutritionJson != null) {
      return DevNutritionPreferences.decode(
            config.devNutritionJson,
          ).calorieGoal +
          totalKcalActivities;
    }
    return CalorieGoalCalc.getTotalKcalGoal(
      user,
      totalKcalActivities,
      kcalUserAdjustment: config.userKcalAdjustment,
      caloriesTaperEnabled: user.caloriesTaperEnabled,
    );
  }
}
