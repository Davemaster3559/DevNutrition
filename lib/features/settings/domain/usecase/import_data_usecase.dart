import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:opennutritracker/core/data/data_source/custom_activity_template_dbo.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/recipe_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/weight_log_dbo.dart';
import 'package:opennutritracker/core/data/repository/custom_activity_template_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/utils/csv_data_exporter.dart';
import 'package:opennutritracker/core/utils/off_micronutrient_repair.dart';
import 'package:opennutritracker/core/utils/user_image_storage.dart';
import 'package:opennutritracker/features/settings/domain/export_import_failure.dart';
import 'package:opennutritracker/features/quick_log/data/devnutrition_backup.dart';

/// Opens the system file picker for a single file of any type and resolves
/// to the pick, or to null when the user dismissed the picker.
typedef PickImportFile = Future<PlatformFile?> Function();

Future<PlatformFile?> _pickAnyFile() => FilePicker.pickFile(type: FileType.any);

class ImportDataUsecase {
  final DevNutritionBackup? devNutritionBackup;
  final Future<void> Function()? afterImport;
  final UserActivityRepository _userActivityRepository;
  final IntakeRepository _intakeRepository;
  final TrackedDayRepository _trackedDayRepository;
  final RecipeRepository _recipeRepository;
  final WeightLogRepository _weightLogRepository;
  final CustomActivityTemplateRepository _customActivityTemplateRepository;

  /// Seam for tests: `FilePicker.pickFile` is static and needs a platform
  /// channel, so the picker outcomes (#1103: cancel, a pick without a
  /// path, a pick of the wrong file) can only be driven from here.
  final PickImportFile _pickFile;

  ImportDataUsecase(
    this._userActivityRepository,
    this._intakeRepository,
    this._trackedDayRepository,
    this._recipeRepository,
    this._weightLogRepository,
    this._customActivityTemplateRepository, {
    PickImportFile pickFile = _pickAnyFile,
    this.devNutritionBackup,
    this.afterImport,
  }) : _pickFile = pickFile;

  /// Imports user activity, intake, tracked day, and (optionally) recipe,
  /// weight log or Custom activity template data from a zip file
  /// containing JSON files. Recipe, weight log and template files are
  /// treated as optional so zips exported by older versions still import.
  ///
  /// Returns true when the import completed. Throws an
  /// [ExportImportFailure] whose reason says what went wrong — including
  /// [ExportImportFailureReason.cancelled] when the user dismissed the
  /// picker, which callers should treat as "nothing happened" rather than
  /// as an error.
  Future<bool> importData(
    String userActivityJsonFileName,
    String userIntakeJsonFileName,
    String trackedDayJsonFileName,
    String recipeJsonFileName,
    String weightLogJsonFileName,
    String customActivityTemplateJsonFileName,
  ) async {
    final archive = await _pickAndDecodeArchive();

    final devFile = archive.findFile('devnutrition.json');
    final devJson = devFile == null
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(utf8.decode(devFile.content as List<int>)) as Map,
          );
    if (devJson != null) devNutritionBackup?.validate(devJson);

    // Parse every dataset before the first database write. A malformed later
    // file must not leave the active diary partly imported.
    List<T> decode<T>(
      String name,
      T Function(Map<String, dynamic>) factory, {
      bool required = false,
    }) {
      final entry = archive.findFile(name);
      if (entry == null) {
        if (required) throw _missingEntry(name);
        return <T>[];
      }
      return _decodeJsonList(entry, factory);
    }

    final activities = decode(
      userActivityJsonFileName,
      UserActivityDBO.fromJson,
      required: true,
    );
    final intakes = decode(
      userIntakeJsonFileName,
      IntakeDBO.fromJson,
      required: true,
    ).map(OffMicronutrientRepair.repairIntake).toList();
    final days = decode(
      trackedDayJsonFileName,
      TrackedDayDBO.fromJson,
      required: true,
    );
    final recipes = decode(
      recipeJsonFileName,
      RecipeDBO.fromJson,
    ).map(OffMicronutrientRepair.repairRecipe).toList();
    final weights = decode(weightLogJsonFileName, WeightLogDBO.fromJson);
    final templates = decode(
      customActivityTemplateJsonFileName,
      CustomActivityTemplateDBO.fromJson,
    );

    await _userActivityRepository.addAllUserActivityDBOs(activities);
    await _intakeRepository.addAllIntakeDBOs(intakes);
    await _trackedDayRepository.addAllTrackedDays(days);
    if (archive.findFile(recipeJsonFileName) != null) {
      await _recipeRepository.addAllRecipeDBOs(recipes);
    }
    if (archive.findFile(weightLogJsonFileName) != null) {
      await _weightLogRepository.addAllEntries(weights);
    }
    if (archive.findFile(customActivityTemplateJsonFileName) != null) {
      await _customActivityTemplateRepository.addAllTemplateDBOs(templates);
    }

    // Restore any user-attached photos — recipes under `recipe_images/`
    if (devJson != null && devNutritionBackup != null) {
      await devNutritionBackup!.restore(devJson);
    }

    // Restore any user-attached photos — recipes under `recipe_images/`
    // and custom meals under `meal_images/`. Each archive entry's name
    // already matches the relative slug we stored on the matching DBO,
    // so we just write the bytes back into the right private documents
    // subdirectory. Anything outside those known prefixes is skipped by
    // the sanitiser, so a hostile zip can't escape into other folders.
    final recipeDir = await UserImageStorage.ensureDirectory(
      UserImageKind.recipe,
    );
    final mealDir = await UserImageStorage.ensureDirectory(UserImageKind.meal);
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final sanitized = UserImageStorage.sanitizeRelative(entry.name);
      if (sanitized == null) continue;
      final parts = sanitized.split('/');
      final targetDir = parts[0] == UserImageKind.recipe.subdir
          ? recipeDir
          : mealDir;
      final destPath = '${targetDir.path}/${parts[1]}';
      final destFile = File(destPath);
      await destFile.writeAsBytes(entry.content as List<int>, flush: true);
    }

    await afterImport?.call();
    return true;
  }

  /// Symmetric CSV counterpart to [importData]. Reads a zip produced by
  /// `ExportDataUsecase.exportData(format: ExportFormat.csv)` and feeds
  /// each CSV through the matching `parse...FromCsv` helper on
  /// [CsvDataExporter]. Recipes, photos, the weight log and Custom
  /// activity templates are intentionally not handled here — CSV export
  /// omits them by design (nested or binary shapes don't flatten
  /// cleanly), so a CSV-only round trip does not restore them. A user
  /// who needs them in their backup should choose the JSON format
  /// instead.
  Future<bool> importDataCsv({
    String userActivityCsvFileName = 'user_activity.csv',
    String userIntakeCsvFileName = 'user_intake.csv',
    String trackedDayCsvFileName = 'user_tracked_day.csv',
  }) async {
    final archive = await _pickAndDecodeArchive();

    final activityFile = archive.findFile(userActivityCsvFileName);
    if (activityFile != null) {
      final dbos = _decodeCsv(
        activityFile,
        CsvDataExporter.parseUserActivitiesFromCsv,
      );
      await _userActivityRepository.addAllUserActivityDBOs(dbos);
    } else {
      throw _missingEntry(userActivityCsvFileName);
    }

    final intakeFile = archive.findFile(userIntakeCsvFileName);
    if (intakeFile != null) {
      // Same pre-#775 scaling as the JSON leg: a CSV without the
      // `meal_data_version` column came from a build that wrote raw grams.
      final dbos = _decodeCsv(
        intakeFile,
        CsvDataExporter.parseIntakesFromCsv,
      ).map(OffMicronutrientRepair.repairIntake).toList();
      await _intakeRepository.addAllIntakeDBOs(dbos);
    } else {
      throw _missingEntry(userIntakeCsvFileName);
    }

    final trackedDayFile = archive.findFile(trackedDayCsvFileName);
    if (trackedDayFile != null) {
      final dbos = _decodeCsv(
        trackedDayFile,
        CsvDataExporter.parseTrackedDaysFromCsv,
      );
      await _trackedDayRepository.addAllTrackedDays(dbos);
    } else {
      throw _missingEntry(trackedDayCsvFileName);
    }

    return true;
  }

  /// Lets the user pick a file and decodes it as a zip.
  ///
  /// The ways this can fall short are kept apart (#1103): a dismissed
  /// picker is [ExportImportFailureReason.cancelled], which is not an
  /// error. A pick the plugin could not hand back as a path, a file that
  /// cannot be read, and bytes the zip decoder rejects are all
  /// [ExportImportFailureReason.unreadableOrWrongFormat]. Note that the
  /// decoder accepts a plain `.csv` as an *empty* archive rather than
  /// rejecting it — that case is caught by [_missingEntry] instead.
  Future<Archive> _pickAndDecodeArchive() async {
    final result = await _pickFile();
    if (result == null) {
      throw const ExportImportFailure(
        ExportImportFailureReason.cancelled,
        'The user dismissed the file picker',
      );
    }
    final path = result.path;
    if (path == null) {
      throw ExportImportFailure(
        ExportImportFailureReason.unreadableOrWrongFormat,
        'The file picker returned "${result.name}" without a readable path',
      );
    }

    final zipBytes = await ExportImportFailure.guard(
      ExportImportFailureReason.unreadableOrWrongFormat,
      'Could not read the picked file $path',
      () => File(path).readAsBytes(),
    );
    return ExportImportFailure.guardSync(
      ExportImportFailureReason.unreadableOrWrongFormat,
      'The picked file $path is not a zip archive',
      () => ZipDecoder().decodeBytes(zipBytes),
    );
  }

  /// A zip that decodes but lacks a required entry is some other zip, not
  /// an OpenNutriTracker backup.
  ExportImportFailure _missingEntry(String entryName) => ExportImportFailure(
    ExportImportFailureReason.unreadableOrWrongFormat,
    'Required entry $entryName not found in the archive',
  );

  /// Decodes one archive entry holding a JSON array of [T] objects. A
  /// decode or `fromJson` failure is reported as wrong format rather than
  /// escaping as a bare `FormatException` / `TypeError`.
  List<T> _decodeJsonList<T>(
    ArchiveFile entry,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return ExportImportFailure.guardSync(
      ExportImportFailureReason.unreadableOrWrongFormat,
      'Could not parse ${entry.name}',
      () {
        final jsonString = utf8.decode(entry.content as List<int>);
        return (jsonDecode(jsonString) as List)
            .cast<Map<String, dynamic>>()
            .map(fromJson)
            .toList();
      },
    );
  }

  /// CSV counterpart of [_decodeJsonList].
  List<T> _decodeCsv<T>(ArchiveFile entry, List<T> Function(String) parse) {
    return ExportImportFailure.guardSync(
      ExportImportFailureReason.unreadableOrWrongFormat,
      'Could not parse ${entry.name}',
      () => parse(utf8.decode(entry.content as List<int>)),
    );
  }
}
