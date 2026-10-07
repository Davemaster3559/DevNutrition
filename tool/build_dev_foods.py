"""Build the bundled catalogue from INDB 2024.11 and USDA SR Legacy CSVs.

Usage: python tool/build_dev_foods.py <source-directory>
The directory contains Anuvaad_INDB_2024.11.xlsx and sr_legacy/*.csv.
Requires openpyxl. Raw downloads are deliberately not shipped in the app.
"""
import csv
import json
import math
from pathlib import Path
import re
import sys

import openpyxl

root = Path(sys.argv[1])
out = Path(__file__).resolve().parents[1] / "assets/data"
out.mkdir(parents=True, exist_ok=True)
keys = ["energyKcal100", "carbohydrates100", "fat100", "proteins100", "sugars100", "saturatedFat100", "fiber100", "monounsaturatedFat100", "polyunsaturatedFat100", "transFat100", "cholesterol100", "sodium100", "potassium100", "magnesium100", "calcium100", "iron100", "zinc100", "phosphorus100", "vitaminA100", "vitaminC100", "vitaminD100", "vitaminB6100", "vitaminB12100", "niacin100"]
ids = [1008, 1005, 1004, 1003, 2000, 1258, 1079, 1292, 1293, 1257, 1253, 1093, 1092, 1090, 1087, 1089, 1095, 1091, 1106, 1162, 1114, 1175, 1178, 1167]
def number(x):
    try:
        v = float(x)
        return v if math.isfinite(v) and v >= 0 else None
    except (TypeError, ValueError):
        return None

def food(code, name, nutrients, *, source="fdc", origin="fdc_sr_legacy", serving=100, label="100 g", unit="g", brands=None, url=None):
    return dict(code=code, name=name, brands=brands, thumbnailImageUrl=None, mainImageUrl=None, url=url,
                mealQuantity="100", mealUnit=unit, servingQuantity=serving, servingUnit=unit,
                servingSize=label, nutriments={k: nutrients.get(k) for k in keys}, source=source,
                backendSource=origin, dataVersion=1)

selected = {
    168893: ("Atta / whole wheat flour, dry", 100, "100 g"),
    168877: ("Basmati rice, raw (long-grain reference)", 100, "100 g raw"),
    169707: ("Sella / parboiled rice, raw (reference)", 100, "100 g raw"),
    171265: ("Milk, whole 3.25% (reference)", 100, "100 ml"),
    173944: ("Banana, raw", 118, "1 medium banana"),
    169705: ("Oats, rolled, dry", 100, "100 g"),
    170554: ("Chia seeds", 100, "100 g"),
    169414: ("Flax seeds", 100, "100 g"),
    171723: ("Cranberries, dried, sweetened", 100, "100 g"),
    170894: ("Greek yogurt, plain 0% (reference)", 100, "100 g"),
    172475: ("Tofu, firm / extra-firm reference", 100, "100 g"),
    169928: ("Peach, raw", 150, "1 medium peach"),
    168153: ("Kiwi, raw", 69, "1 medium kiwi"),
    174683: ("Grapes, raw", 100, "100 g"),
    171711: ("Blueberries, raw", 100, "100 g"),
    167765: ("Watermelon, raw", 100, "100 g"),
    168203: ("Apple, Granny Smith, raw", 167, "1 medium apple"),
    171688: ("Apple, raw (Ambrosia reference)", 182, "1 medium apple"),
    169097: ("Orange, raw", 96, "1 small orange"),
    169949: ("Plum, raw", 66, "1 medium plum"),
    167762: ("Strawberries, raw", 100, "100 g"),
    169092: ("Cantaloupe / muskmelon, raw", 100, "100 g"),
    170108: ("Bell pepper, raw", 100, "100 g"),
    170000: ("Onion, raw", 100, "100 g"),
    170457: ("Tomato, raw", 100, "100 g"),
    168409: ("Cucumber with peel, raw", 100, "100 g"),
    168462: ("Spinach, raw", 100, "100 g"),
    169247: ("Romaine lettuce, raw", 100, "100 g"),
    171284: ("Dahi / plain whole-milk yogurt (reference)", 100, "100 g"),
    173412: ("Ghee / butter oil, anhydrous", 5, "1 tsp (5 g estimate)"),
    173410: ("Butter, salted", 5, "1 tsp (5 g estimate)"),
    171413: ("Olive oil", 4.5, "1 tsp (4.5 g)"),
    170923: ("Cumin seed / ground cumin", 2.1, "1 tsp (2.1 g estimate)"),
    171325: ("Garlic powder", 3.1, "1 tsp (3.1 g)"),
    173744: ("Rajma / kidney beans, dry", 100, "100 g dry"),
    173756: ("Chickpeas / chole, dry", 100, "100 g dry"),
    172420: ("Lentils / masoor dal, dry", 100, "100 g dry"),
    174277: ("Soy sauce (shoyu)", 5.3, "1 tsp (5.3 g)"),
    167747: ("Lemon juice, raw", 5, "1 tsp (5 g estimate)"),
    169698: ("Cornstarch", 100, "100 g"),
}
nutrients = {str(i): {} for i in selected}
with (root / 'sr_legacy/food_nutrient.csv').open(encoding='utf-8') as f:
    for row in csv.DictReader(f):
        target = nutrients.get(row['fdc_id'])
        nid = int(row['nutrient_id'])
        if target is not None and nid in ids:
            target[keys[ids.index(nid)]] = number(row['amount'])
foods = [food(str(i), name, nutrients[str(i)], serving=serving, label=label,
              unit='ml' if i == 171265 else 'g', url=f'https://fdc.nal.usda.gov/food-details/{i}/nutrients')
         for i, (name, serving, label) in selected.items()]

# INDB is a reference for Indian prepared dishes; values are per 100 g.
# Free sugar is NOT total sugar. Lipids in mg are converted to grams.
nonveg = re.compile(r'\b(egg|eggs|chicken|mutton|lamb|beef|pork|fish|prawn|prawns|shrimp|crab|crabs|meat|chops|liver|duck|turkey|bacon|ham|sausage|salami|tuna|salmon|sardine|anchovy|gelatin|souffle|omelette|omelet)\b', re.I)
book = openpyxl.load_workbook(root / 'Anuvaad_INDB_2024.11.xlsx', read_only=True, data_only=True)
rows = book.active.iter_rows(values_only=True)
header = next(rows)
mapping = {'energyKcal100':'energy_kcal','carbohydrates100':'carb_g','fat100':'fat_g','proteins100':'protein_g',
           'fiber100':'fibre_g','saturatedFat100':'sfa_mg','monounsaturatedFat100':'mufa_mg',
           'polyunsaturatedFat100':'pufa_mg','cholesterol100':'cholesterol_mg','sodium100':'sodium_mg',
           'potassium100':'potassium_mg','magnesium100':'magnesium_mg','calcium100':'calcium_mg','iron100':'iron_mg',
           'zinc100':'zinc_mg','phosphorus100':'phosphorus_mg','vitaminA100':'vita_ug','vitaminC100':'vitc_mg',
           'vitaminB6100':'vitb6_mg','niacin100':'vitb3_mg'}
for row in rows:
    r = dict(zip(header, row))
    if not r.get('food_code') or nonveg.search(str(r['food_name'])):
        continue
    n = {k:number(r.get(v)) for k,v in mapping.items()}
    for k in ['saturatedFat100','monounsaturatedFat100','polyunsaturatedFat100']:
        if n[k] is not None: n[k] /= 1000
    d2, d3 = number(r.get('vitd2_ug')), number(r.get('vitd3_ug'))
    n['vitaminD100'] = d2+d3 if d2 is not None and d3 is not None else None
    kcal, portion = n['energyKcal100'], number(r.get('unit_serving_energy_kcal'))
    grams = portion / kcal * 100 if kcal and portion else None
    foods.append(food('indb:'+r['food_code'], r['food_name'], n, origin='indb', serving=grams,
                      label=f"{r.get('servings_unit') or 'reference serving'} (~{grams:.0f} g)" if grams is not None else '100 g reference; household serving unknown',
                      brands='Anuvaad INDB 2024.11 · reference estimate', url='https://www.anuvaad.org.in/indian-nutrient-databank/'))

def label(code, name, portion, values, url, *, unit='g', brand='Product label reference'):
    foods.append(food(code, name, {k:v/portion*100 for k,v in values.items()}, source='custom', origin='label',
                      serving=portion, label=f'1 serving ({portion:g} {unit})', unit=unit, brands=brand, url=url))
label('dev:whey', 'Revolution High Whey · 1 scoop = 147 kcal / 25 g protein',37,
      dict(energyKcal100=147,proteins100=25), 'https://revolution-nutrition.com/product/high-whey',
      brand='Revolution · 37 g heaping scoop; other nutrients unknown until label entered')
label('dev:oikos', 'Oikos Pro vanilla yogurt (Canadian label reference)',115,
      dict(energyKcal100=80,proteins100=13,carbohydrates100=5,fat100=1,sugars100=3,saturatedFat100=.5,
           transFat100=0,fiber100=0,cholesterol100=10,sodium100=45,potassium100=175,calcium100=250,iron100=0),
      'https://www.oikos.ca/fr/oikos-pro/yogourts-proteines-a-la-vanille',brand='Oikos Pro · verify your 0% tub; this label has 1 g fat per 115 g')
label('dev:soya', 'Nutrela dry soya chunks (generic soya reference; verify packet)',100,
      dict(energyKcal100=345,proteins100=52,carbohydrates100=33,fat100=.5,fiber100=13),
      'https://provedaindia.com/images/module/Soya-Chunks.pdf',brand='Soya reference from Proveda; replace with your Nutrela label')
# Carton fat is known from the requested meal. Other milk values are an
# explicit whole-milk reference rather than a fabricated manufacturer label.
base = next(f for f in foods if f['code']=='171265')
milk = json.loads(json.dumps(base)); milk.update(code='dev:milk35',name='Milk 3.5% (whole-milk reference estimate)',
    brands='3.25% USDA proxy; replace with your 3.5% carton label')
foods.append(milk)
label('dev:sour5', 'Dairyland sour cream 5% (label reference)',30,
      dict(energyKcal100=35,fat100=1.5,saturatedFat100=1,transFat100=0,carbohydrates100=3,
           fiber100=0,sugars100=3,proteins100=2,cholesterol100=5,sodium100=30,potassium100=75,calcium100=50,iron100=0),
      'https://www.dairyland.ca/en/products/sour-cream/5-sour-cream',brand='Dairyland · per 30 ml label; 1 ml ≈ 1 g estimate for recipes')
(out/'dev_foods.json').write_text(json.dumps(foods,ensure_ascii=False,separators=(',',':')),encoding='utf-8')

recipes=[]
def preset(id,name,items,notes=''):
    recipes.append(dict(id='dev:'+id,name=name,kind='preset',servings=1,portionUnit='serving',
      description=notes+' Ingredient weights and nutrition are editable. Fruit pieces use USDA edible-weight estimates; product references should be checked against your labels. No added oil is assumed.',
      ingredients=[dict(code=str(code),amount=amount) for code,amount in items]))
preset('banana-shake','Dev banana protein shake',[('dev:milk35',300),(173944,118),('dev:whey',37)],'300 ml 3.5% milk, 1 medium banana, 1 scoop Revolution whey (147 kcal / 25 g protein).')
preset('oats','Dev protein overnight oats',[(169705,60),(170554,10),(169414,5),(171723,12.5),('dev:whey',37),(171265,200)],'Cranberries use the midpoint 12.5 g of your 10–15 g range. Optional prebiotic, cinnamon and cocoa can be added with their actual amounts.')
preset('fruit-a','Dev Fruit Bowl A',[('dev:oikos',200),(169928,150),(167762,100),(168153,34.5),(167765,100),(174683,40),(171711,50)],'1 medium peach and 1/2 kiwi. Optional sweetener and cinnamon.')
preset('fruit-b','Dev Fruit Bowl B',[('dev:oikos',200),(168203,83.5),(169097,96),(169949,66),(169092,100),(167762,75),(174683,40)],'1/2 Granny Smith apple, 1 small orange, 1 plum. Swap the apple for Ambrosia in the editor.')
preset('fruit-old','Dev fruit bowl · older version',[('dev:oikos',200),(168203,83.5),(168153,34.5),(169949,66),(169097,131),(169092,50),(167765,50),(174683,30)],'Older meal option only; this does not change your daily goals.')
preset('tofu-tikka','Dev air-fryer tofu tikka',[(172475,200),(170108,100),(170000,75),(170457,100),(171284,60),('dev:sour5',15),('indb:BFP001',1),(170923,1.05),(171325,1.55)],'1/2 tsp each garam/tikka masala, cumin and garlic powder (gram estimates). Add lemon, chilli and salt to taste; weigh meaningful additions.')
preset('soya-masala','Dev soya tomato dahi masala',[('dev:soya',60),(170108,100),(170457,100),(170000,50),(171284,60),('dev:sour5',15),(170923,1.05),('indb:BFP001',1),(171325,1.55)],'Soya is measured DRY before soaking. 1/2 tsp each cumin, garam masala and garlic powder.')
preset('soya-chaat','Dev spicy soya dahi chaat',[('dev:soya',35),(170894,150),(168409,100),(170457,75),(170000,35),(170923,1.05),('indb:BFP002',1),(169928,150),(167762,100)],'With 1 medium peach and 100 g strawberries. Cilantro, green chilli, lemon, black pepper and salt to taste. 1/2 tsp cumin and chaat masala.')
preset('tofu-salad','Dev crispy tofu salad',[(172475,200),(168462,60),(169247,90),(168409,150),(170457,90),(170108,75),(171284,60),('dev:sour5',15)],'With dahi and 5% sour cream dressing. Add soy/chilli sauce, lemon and garlic with their actual amounts.')
preset('tofu-chaat','Dev tofu yogurt chaat',[(172475,150),(170894,150),(168409,100),(170457,75),(170000,35),('indb:BFP002',1),(170923,1.05),(169092,100),(171711,75),(167762,50)],'With cantaloupe, blueberries and strawberries; 1/2 tsp chaat masala and cumin.')
preset('chilli-soya','Dev crispy chilli soya',[('dev:soya',50),(170108,100),(170000,50),(170457,100),(171284,60),('dev:sour5',15),(174277,5.3),(171325,1.55)],'1 tsp soy sauce and 1/2 tsp garlic powder. Optional 8 g cornstarch can be added in the editor.')
preset('whey-water','Dev whey with water',[('dev:whey',37)],'1 scoop = 147 kcal / 25 g protein. Use 1.25 servings for 1.25 scoops. Water adds no calories.')
(out/'dev_recipes.json').write_text(json.dumps(recipes,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Wrote {len(foods)} foods and {len(recipes)} presets')
