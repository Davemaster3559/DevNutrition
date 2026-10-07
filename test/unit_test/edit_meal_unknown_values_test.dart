import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/edit_meal/presentation/bloc/edit_meal_bloc.dart';
import '../helpers/fake_hive_db_provider.dart';

void main() {
  late EditMealBloc bloc;
  setUp(() {
    final db = FakeHiveDBProvider();
    final config = ConfigRepository(ConfigDataSource(db));
    bloc = EditMealBloc(
      GetConfigUsecase(config),
      CustomMealDataSource(db),
      config,
    );
  });
  tearDown(() => bloc.close());

  test(
    'label override preserves unedited nutrients and supports clearing a value',
    () {
      const original = MealEntity(
        code: '3017620422003',
        name: 'Original label',
        url: null,
        mealQuantity: '100',
        mealUnit: 'g',
        servingQuantity: 50,
        servingUnit: 'g',
        servingSize: '50 g',
        source: MealSourceEntity.off,
        nutriments: MealNutrimentsEntity(
          energyKcal100: 100,
          carbohydrates100: 10,
          fat100: 3,
          proteins100: 5,
          sugars100: 4,
          saturatedFat100: 1,
          fiber100: 2,
          vitaminC100: 6,
        ),
      );
      final edited = bloc.createNewMealEntity(
        original,
        'My exact label',
        '',
        '100',
        '50',
        '50',
        'g',
        '60',
        '5',
        '1.5',
        '3',
        sugarsText: '',
        saturatedFatText: '.5',
      );
      expect(edited.source, MealSourceEntity.custom);
      expect(edited.code, original.code);
      expect(edited.nutriments.energyKcal100, 120);
      expect(edited.nutriments.sugars100, isNull);
      expect(edited.nutriments.fiber100, 2);
      expect(edited.nutriments.vitaminC100, 6);
      expect(edited.nutriments.saturatedFat100, 1);
    },
  );

  test(
    'incomplete label keeps blank macros unknown and explicit zero distinct',
    () {
      final meal = bloc.createNewMealEntity(
        MealEntity.empty(),
        'Whey',
        '',
        '37',
        '37',
        '37',
        'g',
        '147',
        '',
        '0',
        '25',
      );
      expect(meal.nutriments.energyKcal100, closeTo(147 / 37 * 100, 1e-9));
      expect(meal.nutriments.carbohydrates100, isNull);
      expect(meal.nutriments.fat100, 0);
      expect(meal.nutriments.proteins100, closeTo(25 / 37 * 100, 1e-9));
      expect(meal.source, MealSourceEntity.custom);
    },
  );
}
