# DevNutrition - Codex Product Goal

## Mission

Build a complete, usable personal nutrition and calorie tracking app called **DevNutrition**, using the latest stable OpenNutriTracker codebase as the starting point.

This is not a prototype, mockup, phase-one exercise, or planning task. The goal is a working Android app that can be installed and used every day.

Start from:

- App: https://github.com/simonoppowa/OpenNutriTracker
- Food backend, if needed: https://github.com/simonoppowa/OpenNutriTracker-Backend

Read the upstream repository's `AGENTS.md`, `GettingStarted.md`, architecture, data model, existing tests, and food backend documentation before making major structural changes.

Preserve useful upstream functionality instead of rebuilding solved problems. Modify, extend, simplify, or replace parts of the upstream product when that produces a better result for the goal below.

You have authority to make normal engineering and product decisions yourself. Do not stop to ask for approval for ordinary implementation choices. Inspect the code, understand failures, fix them, retest, and continue.

You may internally sequence the work however you want, but do not stop at an arbitrary "V1", "phase", scaffold, plan, or partial implementation. Continue until the defined daily-use workflows work end to end.

Do not create a maze of artificial validators, gates, or brittle acceptance scripts. Use the repository's normal build/analyze/test workflow and add only high-value tests for logic that genuinely needs protection.

If something in this document conflicts with assumptions inherited from OpenNutriTracker, this document is the product goal and should win unless doing so would create a serious technical, security, licensing, or data-integrity problem.

---

# 1. Who this app is for

This is initially a **single-user personal nutrition app** for Dev.

Important real-world behavior:

- Dev is vegetarian and does not eat eggs or meat.
- Dev cooks his own Indian food.
- His food repeats frequently.
- He wants accurate-enough calorie and protein tracking without turning cooking into a laboratory exercise.
- He is willing to measure the inputs where measurement is useful, such as atta, dry rice, whey, milk, yogurt, tofu, soya chunks, and calorie-dense ingredients.
- He does **not** want to weigh an entire cooked pot of sabji/curry and then weigh every final serving.
- For curries, dals, and sabjis, good recipe-based estimates and simple portion choices are preferred.
- For roti and rice, raw ingredient measurement is useful and should be easy.
- Repeated meals from his diet plan should already exist as presets.
- Logging should become faster over time, not more complicated.
- The app should feel purpose-built around this workflow, not like a generic database search screen.

The core philosophy is:

**Measure what materially benefits from measuring. Estimate what does not. Preset everything repetitive.**

---

# 2. Current goal defaults

The app must make all goals editable. Do not permanently hard-code these values into nutrition logic.

Seed the initial profile with:

- Daily calorie target: **about 1,700 kcal**
- Daily protein target: **120 g**
- Goal weight: **80 kg**

The 1,300 kcal diet plan described later is an **older aggressive-cut meal plan and recipe source**, not the current long-term calorie target. Its meals should be imported as reusable presets, but DevNutrition must not force a 1,300 kcal daily budget.

Allow calorie, protein, carbohydrate, fat, water, and body-weight goals to be edited normally.

---

# 3. Keep the useful OpenNutriTracker foundation

Reuse the parts of OpenNutriTracker that are already good, including where practical:

- calorie and macro diary
- meal sections
- custom foods
- reusable recipes
- food search
- Open Food Facts support
- barcode scanning
- food detail and nutrient information
- favourites / recent food behavior
- weight tracking
- trends
- local storage and privacy
- import/export and backup
- configurable diary day boundary
- Health Connect support where useful
- existing clean architecture, BLoC/state patterns, dependency injection, local storage, and generated models unless a change is justified

The upstream app currently uses Flutter/Dart, clean architecture, `flutter_bloc`, `get_it`, and encrypted Hive local storage. Work with the existing architecture rather than casually replacing it.

Keep the product account-free unless a technical requirement genuinely demands otherwise.

The personal diary and custom recipes should remain usable even when the internet is unavailable.

---

# 4. DevNutrition identity

Rebrand the user-facing application as **DevNutrition**.

Update normal app identity where safe:

- display name
- launcher/app labels
- internal branding strings
- app icon only if a clean replacement can be produced without blocking the project
- package/application identifiers if doing so does not unnecessarily destabilize build/install behavior

Do not waste time on elaborate branding before the actual nutrition workflow is working.

A clean Material interface consistent with the existing app is fine. The priority is speed and usability.

---

# 5. Home screen and daily diary

The home screen must answer the important questions immediately:

- calories eaten / calorie target
- protein eaten / protein target
- remaining calories
- optionally carbs and fat without overwhelming the screen
- current weight and trend if useful
- quick access to logging

The daily diary should be easy to understand and edit.

Support sensible meal sections such as:

- Breakfast
- Lunch
- Dinner
- Snacks / Other

A logged item must be easy to:

- edit amount
- duplicate
- move to another meal
- delete
- re-log on another day

Recent and frequently used foods should become easy to re-log.

Do not reward or punish the user with unnecessary streak mechanics.

---

# 6. Quick Log should be central

Most days Dev should not need to search the whole food database.

Create a prominent **Quick Log / Your Foods / Your Meals** experience showing:

- saved meal presets
- favourites
- recent foods
- recently cooked/common Indian recipes
- common roti/rice choices

A typical day should be loggable largely through a few taps.

Example quick items:

- Banana Whey Shake
- Overnight Oats
- Fruit Bowl A
- Fruit Bowl B
- Whey + Water
- 1 Roti / 2 Rotis
- Rice
- common curry/sabji recipes

Allow pinning/reordering favourites.

---

# 7. Roti workflow

Roti should have a purpose-built workflow because the raw atta is what Dev wants to measure.

The workflow should support:

1. Choose flour / atta product.
2. Enter dry atta using convenient measures:
   - 1/4 cup
   - 1/2 cup
   - 3/4 cup
   - 1 cup
   - 1 1/4 cup
   - 1 1/2 cup
   - custom cups
   - grams
3. Enter how many rotis were made.
4. Optionally add ghee/oil/butter used for the batch or per roti.
5. The app calculates nutrition for the whole batch and per roti.
6. Log the number of rotis eaten.

## Cup calibration

Support a simple per-ingredient household measure calibration.

Example:

`Dev's 1 cup atta = ___ g`

Dev can weigh his normal filled cup once. From that point on he can use cup fractions without weighing flour every time.

Do not invent a permanent universal grams-per-cup value for his atta when a user calibration is available.

The same household-measure system should be reusable for other ingredients.

---

# 8. Rice workflow

Rice should prioritize the **dry/raw rice amount**, because that is easy to measure consistently.

Support:

- 1/4 cup dry
- 1/2 cup dry
- 3/4 cup dry
- 1 cup dry
- custom cups
- grams

Allow the user to indicate how much of the cooked batch was eaten using the simplest useful method, for example:

- all
- 1/2 batch
- 1/3 batch
- 1/4 batch
- custom fraction
- servings if the user has divided it into portions

Do not require cooked rice weighing as the normal workflow.

Allow different rice products, including the user's usual basmati/Sella rice, and save the last/default choice.

---

# 9. Curries, dals, and sabjis

This is deliberately **not** a final-cooked-weight tracking system.

For foods such as:

- rajma
- chole
- dals
- kadhi
- paneer dishes
- soya curries
- mixed sabji
- aloo gobi
- bhindi
- other homemade Indian curries/sabjis

use normal recipe nutrition calculations.

A recipe can contain ingredients and quantities, but when logging a serving Dev should be able to use simple estimates such as:

- 1/2 katori
- 1 katori
- 1 1/2 katori
- 2 katori
- small
- usual
- large
- custom serving/fraction

Support editing the recipe whenever his cooking changes.

## Cooking richness

Because oil/ghee and calorie-dense ingredients can materially change a curry, make them easy to represent.

A recipe may optionally expose a simple cooking-style choice such as:

- Light
- Normal
- Rich

if that can be implemented cleanly. It should correspond to meaningful ingredient differences, especially oil/ghee/cream/cashews/paneer, rather than fake precision.

Do not force this concept where it makes the UI worse.

## Usual serving

Allow Dev to save a usual serving for a recipe.

Example:

`Rajma -> usual serving = 1.25 katori`

Then the logger can offer:

- Small
- Usual
- Large
- Custom

The exact multiplier can be editable or sensibly derived.

The goal is repeatable estimates, not pretending a bowl of curry has laboratory precision.

---

# 10. Recipes and meal presets

There should be a distinction between:

- an ingredient/food
- a recipe
- a reusable meal preset

A **recipe** calculates nutrition from ingredients.

A **meal preset** can contain one or more foods/recipes in the amounts Dev typically eats.

Examples:

- Banana Whey Shake
- Fruit Bowl A
- Fruit Bowl B
- Tofu Tikka Bowl
- Soya Masala Bowl
- Rice + Rajma + Dahi
- 2 Rotis + Sabji

Logging a preset should remain editable after insertion.

If the underlying recipe later changes, handle past diary entries safely. Historical diary data should not silently change.

---

# 11. Seed Dev's existing meals

Prepopulate the app with the following personal recipes/presets.

Nutrition should be calculated from actual ingredient/product nutrition when possible. The estimated calorie ranges below are useful references, not a reason to hard-code incorrect totals.

## A. Banana Whey Shake

- 300 ml 3.5% milk
- 1 medium banana
- 1 scoop Revolution Nutrition whey
- known whey reference: 147 kcal, 25 g protein per scoop

Historical estimate:
- about 440 to 445 kcal
- about 35 to 36 g protein

No added sugar.

## B. Overnight Oats

- 60 g rolled oats
- 10 g chia seeds
- 5 g milled flaxseed
- 10 to 15 g dried cranberries
- 1 scoop whey
- 200 ml 3.25% milk
- optional prebiotic
- optional cinnamon or cocoa

This should be a saved reusable meal.

## C. Fruit Bowl A - Peach & Berry

- 200 g Oikos Pro Vanilla 0% Greek yogurt
- 1 medium peach
- 100 g strawberries
- 1/2 kiwi
- 100 g watermelon
- 40 g grapes
- 50 g blueberries
- optional 2 to 4 drops stevia/monk-fruit
- optional pinch cinnamon

## D. Fruit Bowl B - Apple, Citrus & Melon

- 200 g Oikos Pro Vanilla 0% Greek yogurt
- 1/2 Granny Smith apple
- 1 small orange
- 1 plum
- 100 g cantaloupe
- 75 g strawberries
- 40 g grapes
- optional 2 to 4 drops stevia/monk-fruit
- optional pinch cinnamon

Allow the apple type to be changed. Ambrosia is also used and has previously been treated as an interchangeable choice when portion size is maintained.

## E. Older General Fruit + Yogurt Bowl

Keep this as another preset because it was part of the older plan:

- 200 g Oikos Pro High Protein Greek Yogurt, Vanilla, 0%
- 1/2 apple
- 1/2 kiwi
- 1 plum
- 1 medium orange
- about 50 g melon
- about 50 g watermelon
- about 30 g grapes

Historical estimate:
- about 340 to 360 kcal
- about 23 to 26 g protein

## F. Tofu Tikka Bowl

- 200 g extra-firm tofu
- 100 g bell pepper
- 75 g onion
- 100 g grape tomatoes
- 60 g dahi, around 3.25 to 3.5%
- 15 g light sour cream, 5%
- 1/2 tsp garam/tikka masala
- 1/2 tsp cumin
- 1/2 tsp garlic powder
- chilli and salt to taste
- lemon after cooking

## G. Nutrela Soya Chunk Masala Bowl

- 60 g dry Nutrela soya chunks
- 100 g bell pepper
- 100 g tomatoes
- 50 g onion
- 60 g dahi
- 15 g light sour cream, 5%
- 1/2 tsp cumin
- 1/2 tsp garam masala
- 1/2 tsp garlic powder
- chilli and salt to taste

The soya quantity is measured dry.

## H. Spicy Nutrela Dahi Chaat

- 35 g dry Nutrela soya chunks
- 150 g plain 0% Greek yogurt
- 100 g cucumber
- 75 g tomato
- 35 g onion
- cilantro and green chilli
- 1/2 tsp roasted cumin
- 1/2 tsp chaat masala
- chilli, salt, lemon and Tabasco to taste
- fruit side: 1 medium peach + 100 g strawberries

The soya quantity is measured dry.

## I. Crispy Tofu Salad

- 200 g extra-firm tofu
- 60 g baby spinach
- 90 g romaine lettuce
- 150 g cucumber
- 90 g grape tomatoes
- 75 g bell pepper
- 60 g dahi
- 15 g light sour cream, 5%
- Tabasco, lemon, salt and black pepper to taste

## J. Spicy Tofu Yogurt Chaat

- 150 g extra-firm tofu
- 150 g plain 0% Greek yogurt
- 100 g cucumber
- 75 g tomato
- 35 g onion
- cilantro and green chilli
- 1/2 tsp chaat masala
- 1/2 tsp roasted cumin
- chilli, salt, lemon and Tabasco to taste
- fruit side: 100 g cantaloupe + 75 g blueberries + 50 g strawberries

## K. Crispy Chilli Nutrela Soya Bowl

- 50 g dry Nutrela soya chunks
- 100 g bell pepper
- 50 g onion
- 100 g tomatoes
- 60 g dahi
- 15 g light sour cream, 5%
- 1 tsp soy sauce
- Tabasco/chilli sauce to taste
- 1/2 tsp garlic powder
- black pepper and salt
- optional 8 g cornstarch

The soya quantity is measured dry.

## L. Whey + Water

- 1 scoop Revolution Nutrition whey
- water

Known reference:
- about 147 kcal
- about 25 g protein

Also support a 1.25 scoop option.

---

# 12. Food search strategy

The food search should feel relevant to Dev rather than polluted by thousands of near-duplicate entries.

Prioritize results approximately in this order:

1. Dev's favourites and saved foods
2. Dev's saved recipes and meal presets
3. recent foods
4. Indian food/reference data
5. relevant packaged foods / Open Food Facts
6. general reference databases

Do not blindly duplicate the same food from many databases at the top.

Make source/provenance visible enough that the user can tell whether a result came from:

- personal/custom data
- Open Food Facts
- USDA/FDC
- INDB
- another source

but do not clutter the default logging screen with database implementation details.

---

# 13. Indian food data

Indian food support matters, but it should serve the real workflow rather than becoming the entire project.

The OpenNutriTracker backend already has a canonical multi-source model and import tooling for **Anuvaad INDB**.

Investigate the cleanest reliable way to make INDB useful in DevNutrition.

Acceptable implementation strategies include, based on engineering judgement:

- load INDB into a DevNutrition-controlled/self-hosted Supabase backend
- integrate it through the existing backend architecture
- include a legally compliant local/reference subset if that produces a simpler and more reliable personal app

Do not invent nutrition data.

Respect dataset licensing and attribution requirements.

Do not let a difficult backend deployment block the whole app. Personal recipes, custom foods, packaged-food search, diary logging, and the core Indian cooking workflows must still work.

If INDB cannot reasonably be made live without credentials or an external account, complete everything else, leave a clean integration path, and report the exact external dependency at the end.

---

# 14. Household measures

Indian/home cooking needs units beyond grams.

Support useful units where they make sense:

- gram
- kilogram
- ml
- litre
- teaspoon
- tablespoon
- cup
- 1/4 cup
- 1/2 cup
- 3/4 cup
- piece
- roti
- katori
- bowl
- glass
- ladle
- serving

Household units need ingredient-specific conversions where necessary.

Do not pretend "1 cup" universally has the same weight for every ingredient.

Allow custom conversions/calibration.

---

# 15. Product-specific foods and barcode use

Packaged foods should still behave like a normal modern calorie tracker.

Important examples include:

- Revolution Nutrition whey
- Oikos Pro yogurt
- milk
- tofu
- packaged soya chunks
- sauces
- snacks
- other packaged foods

Keep barcode scanning.

Allow a scanned product to be favourited and reused.

Allow label nutrition to override a generic database entry when Dev knows the exact product he bought.

Make editing or creating a custom packaged food straightforward.

---

# 16. Exercise and DevFit

DevNutrition should coexist with **DevFit**, not duplicate it.

If Health Connect integration is already present or can be cleanly used:

- allow workout/activity information from DevFit or other sources to be visible
- allow weight/body data integration where appropriate
- keep the integration optional
- handle missing permission gracefully

## Critical rule: do not automatically eat back exercise calories

The user's food goal is the food goal.

If a workout burns an estimated 350 kcal, do **not** automatically transform a 1,700 kcal target into 2,050 kcal.

Activity calories may be shown separately for context.

If an "adjust target from exercise" feature remains from upstream, default it OFF and make the behavior explicit.

Never let watch/machine calorie estimates silently increase the eating budget.

---

# 17. Diary day boundary and shift compatibility

Keep or improve OpenNutriTracker's configurable diary day boundary.

A person who eats after midnight should be able to assign that meal to the intended nutrition day without fighting the calendar.

Do not hard-code one specific work schedule. Make the setting simple and persistent.

---

# 18. Weight and trends

Keep weight logging and useful trends.

Prioritize trends that help with a fat-loss goal:

- body-weight history
- rolling/weekly trend if feasible
- calorie average
- protein average
- adherence to chosen target
- simple period selection

Avoid noisy or pseudo-scientific analytics.

Do not make one high-calorie day look like catastrophic failure.

---

# 19. Nutrition calculations

Nutrition math must be trustworthy.

High-value logic that deserves explicit testing includes:

- quantity scaling
- household unit conversion
- per-serving recipe calculations
- roti batch -> per-roti calculations
- rice batch fraction calculations
- meal preset totals
- recipe edits and historical diary behavior
- macro totals
- persistence/import-export of the new custom structures

Do not round internally too early.

Display sensible human-readable rounding while retaining accurate stored values.

Unknown nutrient values should remain unknown rather than silently becoming zero when the upstream schema treats them as nullable.

---

# 20. Historical integrity

A diary entry represents what was logged at that time.

If a saved recipe changes next week, historical days should not silently recalculate unless the user explicitly requests that behavior.

Use snapshots/versioned values or another robust approach consistent with the existing architecture.

This matters for meaningful calorie trends.

---

# 21. Offline behavior, privacy, and data ownership

Preserve the local-first/private spirit of OpenNutriTracker.

At minimum, when offline the user should still be able to:

- open the app
- view the diary
- log saved/custom foods
- log saved recipes and presets
- use roti/rice calculators
- edit/delete existing logs
- view stored trends

Remote food search obviously may need connectivity.

Keep import/export working and extend the format cleanly for any new DevNutrition data structures.

Do not lose existing user data during ordinary app updates/migrations.

Do not add advertising or analytics SDKs.

---

# 22. User experience standard

The app must be comfortable to use every day on Android.

Priorities:

1. few taps
2. clear numbers
3. fast repeat logging
4. sensible defaults
5. editable when needed
6. no fake precision
7. no unnecessary data-entry burden

Avoid designing screens that require the user to understand the underlying database model.

Do not bury Quick Log, recipes, roti, or rice under several menus.

Use the upstream app's visual language unless there is a reason to improve it.

Make interactive elements accessible and follow the upstream `AGENTS.md` semantics conventions for new widgets.

---

# 23. Migration and upstream compatibility

This is a fork/custom product, so perfect upstream compatibility is not the goal.

However:

- do not recklessly rewrite working architecture
- preserve data migrations
- keep generated Hive/JSON files in sync
- follow the repository's code generation rules
- retain GPLv3 notices and other required attribution
- preserve third-party dataset attribution
- document meaningful deviations from upstream

If a future upstream merge remains practical, that is a bonus, not a requirement.

---

# 24. Development process

Work autonomously.

A good execution pattern is:

1. Inspect the repository and run the current app/tests.
2. Understand existing recipe, custom-food, diary, goal, Health Connect, food-search, and storage models.
3. Create a coherent implementation plan for yourself.
4. Implement the product goal.
5. Run code generation as needed.
6. Build.
7. Run static analysis.
8. Run existing tests.
9. Add focused tests for new nutrition math/persistence.
10. Exercise the major flows on an emulator/device when available.
11. Fix failures and UX problems.
12. Repeat until the app is usable.

Use the repo's normal commands such as `just build`, `flutter analyze`, `just test`, `just ci`, and the documented Flutter/FVM setup as appropriate.

Do not spend the project writing planning documents instead of the application.

Do not stop after compiling if obvious end-to-end behavior is still broken.

---

# 25. Completion criteria

The project is not complete merely because code exists.

Before declaring completion, demonstrate that the resulting app can actually do the following:

1. Launch as DevNutrition on Android.
2. Create/use the initial profile and editable calorie/protein goals.
3. Show daily calorie and protein progress.
4. Search and log a normal food.
5. Scan/log a packaged food if barcode functionality is available in the test environment.
6. Create/edit a custom food.
7. Create/edit a normal recipe.
8. Log a curry/sabji using an estimated household serving without final-pot weighing.
9. Create a roti batch from atta in cups/grams, divide it by number of rotis, and log rotis eaten.
10. Create a rice batch from dry rice and log a fraction/serving of the cooked batch.
11. Save/use a calibrated household measure.
12. Log the seeded Banana Whey Shake.
13. Log Fruit Bowl A.
14. Log Fruit Bowl B.
15. Log the seeded overnight oats.
16. Re-log a recent/pinned meal quickly.
17. Restart the app and retain all relevant diary/custom recipe/settings data.
18. Edit/delete a logged item correctly.
19. Preserve historical logged nutrition when a source recipe later changes.
20. Export/import data without losing the DevNutrition-specific structures.
21. Keep exercise calories from automatically increasing the food budget.
22. Work for saved foods/recipes while offline.
23. Pass the relevant existing tests/static analysis/build checks, except for any clearly documented upstream/environmental issue that is unrelated to the changes.

If a physical-device-only feature cannot be tested in the current environment, test as much of its logic as possible and state exactly what still needs device verification.

---

# 26. Final deliverables

When the work is actually complete, provide:

- the working source tree/repository
- a successful Android build
- preferably an installable APK artifact
- any required setup instructions that remain
- a concise summary of what changed
- a concise list of anything that is still externally blocked
- the exact tests/builds that were run and their result

Do not give a long aspirational roadmap as a substitute for finished work.

If an external secret/account/credential is truly required, do not sit idle waiting for it. Finish everything that does not depend on that credential and leave the remaining step cleanly isolated.

---

# 27. Product judgement

This document describes the intended behavior, not every implementation detail.

Use engineering judgement.

You are allowed to:

- improve a workflow when you find a simpler way to achieve the same goal
- reuse existing upstream mechanisms instead of duplicating them
- refactor code needed to implement the product cleanly
- fix upstream bugs encountered in the affected areas
- create sensible data models/migrations
- make UI decisions consistent with the stated priorities
- choose the least fragile way to integrate Indian food data

You are not allowed to quietly drop difficult requirements and still call the project complete.

The end result should feel like a calorie tracker designed around Dev's actual cooking and diet, with Indian home food treated naturally and repeated meals taking seconds to log.
