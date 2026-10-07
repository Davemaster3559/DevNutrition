import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/utils/calc/day_boundary_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/quick_log/data/quick_log_repository.dart';
import 'package:opennutritracker/features/quick_log/domain/devnutrition_preferences.dart';
import 'package:opennutritracker/features/quick_log/presentation/dev_widgets.dart';
import 'package:opennutritracker/generated/l10n.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _repository = locator<QuickLogRepository>();
  final _controllers = List.generate(6, (_) => TextEditingController());
  DevNutritionPreferences? _preferences;
  bool _eatBack = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _repository.preferences();
    final config = await _repository.config.getConfig();
    if (!mounted) return;
    setState(() {
      _preferences = prefs;
      _eatBack = prefs.eatBackExercise;
      final values = [
        prefs.calorieGoal,
        prefs.proteinGoal,
        prefs.carbGoal,
        prefs.fatGoal,
        prefs.goalWeightKg,
        (config.dailyWaterGoalMl ?? 2000).toDouble(),
      ];
      for (var i = 0; i < values.length; i++) {
        _controllers[i].text = devNumber(values[i]);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final numbers = _controllers.map((c) => devParse(c.text)).toList();
    if (numbers.any((n) => n == null) ||
        numbers[5]! < 100 ||
        numbers[5]! > 10000) {
      setState(() => _error = S.of(context).devPositive);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final p = _preferences!.copyWith(
        calorieGoal: numbers[0],
        proteinGoal: numbers[1],
        carbGoal: numbers[2],
        fatGoal: numbers[3],
        goalWeightKg: numbers[4],
        eatBackExercise: _eatBack,
      );
      await _repository.savePreferences(p);
      await _repository.config.setConfigDailyWaterGoalMl(numbers[5]!.round());
      final users = locator<UserRepository>();
      if (await users.hasUserData()) {
        final user = await users.getUserData();
        user.targetWeightKg = p.goalWeightKg;
        await users.updateUserData(user);
      }
      final config = await _repository.config.getConfig();
      final today = DayBoundaryCalc.currentLogicalDayLabel(
        config.dayStartOffsetHours ?? 0,
        config.dayStartOffsetMinutes ?? 0,
      );
      await _repository.reconcile(today);
      await _repository.trackedDays.updateDayCalorieGoal(
        today,
        await _repository.calorieGoal.getKcalGoal(),
      );
      await _repository.trackedDays.updateDayMacroGoals(
        today,
        carbsGoal: p.carbGoal,
        fatGoal: p.fatGoal,
        proteinGoal: p.proteinGoal,
      );
      refreshNutritionScreens();
      locator<ProfileBloc>().add(LoadProfileEvent());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).devGoalsSaved)));
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labels = [
      s.devCalories,
      s.devProtein,
      s.devCarbs,
      s.devFat,
      s.devWeight,
      s.devWater,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.devGoals)),
      body: _preferences == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(s.devGoalsHelp),
                const SizedBox(height: 12),
                for (var i = 0; i < labels.length; i++)
                  DevNumberField(
                    id: 'goal-$i',
                    label: labels[i],
                    controller: _controllers[i],
                  ),
                Semantics(
                  identifier: 'exercise-food-budget',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.devExerciseToggle),
                    subtitle: Text(s.devExerciseHelp),
                    value: _eatBack,
                    onChanged: (v) => setState(() => _eatBack = v),
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                DevButton(
                  id: 'goals-save',
                  label: s.devSave,
                  icon: Icons.check,
                  filled: true,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
    );
  }
}
