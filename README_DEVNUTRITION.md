# DevNutrition

Working Android fork of [OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker)
v2.4.0 (`8d2420f0305c96a4f798f3a111509827260f6df7`). Android 8/API 26 or newer.
The application id is `com.devnutrition.app`, separate from upstream and the
`.develop` test flavor. Existing OpenNutriTracker JSON backups can be imported.

## Install and use

Install `DevNutrition.apk` on Android, allowing installation from the chosen
file manager if Android asks. Complete the initial profile. My goals starts at
1,700 kcal, 120 g protein and 80 kg target weight; all are editable. Carbohydrate,
fat and water goals are also editable. Exercise adjustment starts OFF.
Home shows calories eaten, the chosen target, remaining calories and protein
progress. Tap the calorie gauge or My goals to edit your targets.

Home's Quick Log button and central + open pinned meals, recent meals, foods,
recipes and presets. Tap a meal to adjust its amount/day/meal type; the + on a
saved row repeats its usual amount immediately. Row menus pin, unpin, reorder
pins and edit saved foods/recipes. Search/scan opens packaged-food lookup;
local reference search and saved meals work without an account or connection.

Roti: choose atta, enter raw cups or grams, calibrate your filled cup in grams,
enter rotis produced and eaten, and optionally oil/ghee/butter per batch or roti.
Rice: choose the dry product, use cups or grams, then all/half/third/quarter,
a custom fraction (greater than 0, up to 1), or servings eaten. Give a batch a name to reuse it.
Cooked weight is unnecessary. The last flour/rice product and calibrations persist.

Recipe: add ingredients and estimate how many bowls/katori the batch makes.
Log half/one/one-and-a-half/two, small/usual/large, or any positive custom amount.
Save a usual amount such as 1.25 katori. Extra oil is a real gram addition with
recomputed nutrition. The optional mass field is an advanced override, never
required for the default workflow. A preset uses the same ingredient calculator
and can contain saved recipe snapshots. Editing a source never changes old logs.

Twelve editable presets cover the supplied shake, oats, three fruit bowls, tofu
and soya meals, and whey with water (choose 1.25 servings for 1.25 scoops).
Optional spices/sweeteners/sauces are described and can be added as ingredients.
Manufacturer/reference substitutes are explicit. Check your specific whey,
yogurt, tofu, milk and Nutrela labels before treating a proxy as your exact product.
Blank custom-food nutrients stay unknown; a recorded zero stays zero. A dash
means unknown. Daily totals add known values and warn when nutrition is incomplete.

Diary row menus edit amount, repeat, copy/move to another day/meal and delete.
Settings retains the configurable day boundary for meals after midnight.
Weight logging, history, averages, period trends and optional Health Connect remain.
DevFit integration uses Health Connect when it publishes compatible records and
Android permissions are granted; it does not require a DevFit account in this app.

## Data ownership

Settings â†’ Export data â†’ **JSON** creates the portable ZIP backup of the active
profile: logs, activities, daily totals, weights, recipes, custom foods, water,
fasting and DevNutrition goals/pins/units/usual servings. Import that ZIP on the
new installation. Reimport merges records by stable IDs. Device-specific health
and telemetry consent are not enabled by restoring a backup. Export each profile
separately. CSV is for spreadsheets and does not preserve full recipe/settings
structures. Exported ZIPs contain readable personal data; keep them private.

Local Hive storage remains AES encrypted with Android secure-storage key handling.
Ordinary updates signed with the same release key preserve data. Uninstalling
can remove the database/key: export JSON before uninstalling or moving phones.
The supplied signing key is in a separate private folder, not the source archive;
keep it for future APK updates and back it up privately.

## Build from source

Pinned Flutter 3.44.6 / Dart 3.12.2; JDK 21; Android SDK platform/build-tools 36,
NDK 28.2.13676358. Install platform tools and accept Android SDK licenses.

```sh
flutter pub get
# Copy .env.example to .env; placeholders are sufficient for local operation.
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze
flutter test
flutter test integration_test/app_boot_test.dart --flavor develop -d <android-id>
flutter build apk --debug --flavor develop
# Configure android/key.properties with your private keystore for release:
flutter build apk --release --flavor full
```

No Supabase credential is required: bundled INDB/USDA support local search;
Open Food Facts uses its public service. An optional private multi-source backend
can still be configured with real Supabase values and regenerated env code.
Anonymous error reporting remains an upstream opt-in and only starts when a
valid private reporting endpoint is configured; no advertising/analytics
SDK was added. No production credential is included in the source archive.

For this workspace, `../.tools/env.ps1` selects the downloaded toolchains/cache
paths. It is a local convenience, not a dependency of the portable source tree.

## Reference data and license

[Bundled notices](assets/data/ATTRIBUTION.txt) identify data authors, licenses,
URLs, transformations and product proxies. INDB is CC BY 4.0; USDA data are CC0.
Application code remains GPLv3. Open Food Facts data retain their separate ODbL
and image-license terms. Corresponding modified source is included with the APK.
The notices are also in About DevNutrition â†’ View licenses.

`tool/build_dev_foods.py <source-directory>` reproduces the catalogue from
`Anuvaad_INDB_2024.11.xlsx` and `sr_legacy/*.csv` (Python + openpyxl). The workbook
SHA-256 used is `c39023890f45b86b7f68578a4f740c5772234402111054c28a7a867d8dda25d9`.
The converter selects 919 foods, normalizes lipid mg to g, preserves missing
values, avoids interpreting free sugar as total sugar, and builds 12 ingredient
presets. Source CSV food IDs were checked against the original descriptions.

## Implementation and compatibility

Flutter BLoC/GetIt and the encrypted Hive repositories are retained. New optional
Hive fields extend Config (profile settings JSON), Intake (displayed measure and
conversion) and Recipe (recipe/preset kind and portion unit); generated adapters
remain backward compatible. `devnutrition.json` version 1 extends the canonical
ZIP. Food snapshots in each intake/recipe protect history from source edits.
The importer decodes all JSON datasets before writes and recalculates daily totals
from the merged logs. Local snapshots and settings use full floating-point values;
rounding is for display only. See `docs/export-format.md` for upstream schemas.

Detailed verification results accompany the deliverables in `TEST_RESULTS.txt`.
Physical barcode-camera performance and real DevFit/Health Connect transfer
require a phone with that hardware/app/data; emulator coverage is stated there.
