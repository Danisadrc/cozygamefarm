extends Node
## DataRegistry — Autoload singleton for crop and item definitions.
##
## Stores 13 crop definitions from assets/crops/ with their growth stages,
## seed/produce info, and pricing. Provides lookup helpers used by FarmManager
## and UI systems.

const CROP_DIR := "res://assets/crops/"

# ---------------------------------------------------------------- crop table

var crops: Dictionary = {
	"beetroot": {
		"name": "Bit",
		"seed_name": "Bibit Bit",
		"seed_price": 20,
		"sell_price": 40,
		"stages": 6,          # number of growth stages (_00 .. _05)
		"stage_paths": [
			"beetroot_00.png", "beetroot_01.png", "beetroot_02.png",
			"beetroot_03.png", "beetroot_04.png", "beetroot_05.png",
		],
	},
	"cabbage": {
		"name": "Kubis",
		"seed_name": "Bibit Kubis",
		"seed_price": 25,
		"sell_price": 50,
		"stages": 6,
		"stage_paths": [
			"cabbage_00.png", "cabbage_01.png", "cabbage_02.png",
			"cabbage_03.png", "cabbage_04.png", "cabbage_05.png",
		],
	},
	"carrot": {
		"name": "Wortel",
		"seed_name": "Bibit Wortel",
		"seed_price": 10,
		"sell_price": 20,
		"stages": 6,
		"stage_paths": [
			"carrot_00.png", "carrot_01.png", "carrot_02.png",
			"carrot_03.png", "carrot_04.png", "carrot_05.png",
		],
	},
	"cauliflower": {
		"name": "Kembang Kol",
		"seed_name": "Bibit Kembang Kol",
		"seed_price": 30,
		"sell_price": 60,
		"stages": 6,
		"stage_paths": [
			"cauliflower_00.png", "cauliflower_01.png", "cauliflower_02.png",
			"cauliflower_03.png", "cauliflower_04.png", "cauliflower_05.png",
		],
	},
	"kale": {
		"name": "Kale",
		"seed_name": "Bibit Kale",
		"seed_price": 15,
		"sell_price": 35,
		"stages": 6,
		"stage_paths": [
			"kale_00.png", "kale_01.png", "kale_02.png",
			"kale_03.png", "kale_04.png", "kale_05.png",
		],
	},
	"parsnip": {
		"name": "Parsnip",
		"seed_name": "Bibit Parsnip",
		"seed_price": 10,
		"sell_price": 25,
		"stages": 6,
		"stage_paths": [
			"parsnip_00.png", "parsnip_01.png", "parsnip_02.png",
			"parsnip_03.png", "parsnip_04.png", "parsnip_05.png",
		],
	},
	"potato": {
		"name": "Kentang",
		"seed_name": "Bibit Kentang",
		"seed_price": 15,
		"sell_price": 30,
		"stages": 6,
		"stage_paths": [
			"potato_00.png", "potato_01.png", "potato_02.png",
			"potato_03.png", "potato_04.png", "potato_05.png",
		],
	},
	"pumpkin": {
		"name": "Labu",
		"seed_name": "Bibit Labu",
		"seed_price": 35,
		"sell_price": 70,
		"stages": 6,
		"stage_paths": [
			"pumpkin_00.png", "pumpkin_01.png", "pumpkin_02.png",
			"pumpkin_03.png", "pumpkin_04.png", "pumpkin_05.png",
		],
	},
	"radish": {
		"name": "Lobak",
		"seed_name": "Bibit Lobak",
		"seed_price": 12,
		"sell_price": 25,
		"stages": 6,
		"stage_paths": [
			"radish_00.png", "radish_01.png", "radish_02.png",
			"radish_03.png", "radish_04.png", "radish_05.png",
		],
	},
	"sunflower": {
		"name": "Bunga Matahari",
		"seed_name": "Bibit Bunga Matahari",
		"seed_price": 20,
		"sell_price": 45,
		"stages": 6,
		"stage_paths": [
			"sunflower_00.png", "sunflower_01.png", "sunflower_02.png",
			"sunflower_03.png", "sunflower_04.png", "sunflower_05.png",
		],
	},
	"wheat": {
		"name": "Gandum",
		"seed_name": "Bibit Gandum",
		"seed_price": 8,
		"sell_price": 18,
		"stages": 6,
		"stage_paths": [
			"wheat_00.png", "wheat_01.png", "wheat_02.png",
			"wheat_03.png", "wheat_04.png", "wheat_05.png",
		],
	},
}

# ---------------------------------------------------------------- item table
# Non-crop items that can sit in the hotbar and be sold / eaten: animal
# products and gathered materials. Crops keep their own table above.

var items: Dictionary = {
	"egg": {
		"name": "Telur",
		"sell_price": 35,
		"stamina": 25,
		"icon": "egg.png",
	},
	"milk": {
		"name": "Susu",
		"sell_price": 50,
		"stamina": 35,
		"icon": "milk.png",
	},
	"fish": {
		"name": "Ikan",
		"sell_price": 25,
		"stamina": 20,
		"icon": "fish.png",
	},
	"wood": {
		"name": "Kayu",
		"sell_price": 8,
		"stamina": 0,
		"icon": "wood.png",
	},
	"rock": {
		"name": "Batu",
		"sell_price": 6,
		"stamina": 0,
		"icon": "rock.png",
	},
}

# ---------------------------------------------------------------- helpers

func get_crop_ids() -> Array:
	return crops.keys()


func get_crop(id: String) -> Dictionary:
	return crops.get(id, {})


func crop_name(id: String) -> String:
	var c: Dictionary = crops.get(id, {})
	return String(c.get("name", id))


func crop_seed_name(id: String) -> String:
	var c: Dictionary = crops.get(id, {})
	return String(c.get("seed_name", "Bibit " + crop_name(id)))


func crop_sell_price(id: String) -> int:
	var c: Dictionary = crops.get(id, {})
	return int(c.get("sell_price", 0))


func crop_seed_price(id: String) -> int:
	var c: Dictionary = crops.get(id, {})
	return int(c.get("seed_price", 0))


func crop_stage_count(id: String) -> int:
	var c: Dictionary = crops.get(id, {})
	return int(c.get("stages", 6))


func crop_stage_texture(id: String, stage: int) -> Texture2D:
	var c: Dictionary = crops.get(id, {})
	if c.is_empty():
		return null
	var paths: Array = c.get("stage_paths", [])
	var idx := clampi(stage, 0, paths.size() - 1)
	if idx < 0 or idx >= paths.size():
		return null
	var path: String = CROP_DIR + String(paths[idx])
	return load(path)


# ---------------------------------------------------------------- item helpers

func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	var it: Dictionary = items.get(id, {})
	return String(it.get("name", id))


func item_sell_price(id: String) -> int:
	var it: Dictionary = items.get(id, {})
	return int(it.get("sell_price", 0))


## Stamina restored when eaten. 0 means "not a stamina item".
func item_stamina(id: String) -> int:
	var it: Dictionary = items.get(id, {})
	return int(it.get("stamina", 0))


func item_icon(id: String) -> Texture2D:
	var it: Dictionary = items.get(id, {})
	if it.is_empty():
		return null
	var file := String(it.get("icon", ""))
	if file == "":
		return null
	return load(CROP_DIR + file)


# ---------------------------------------------------------------- shop data

func get_shop_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id in crops:
		var c: Dictionary = crops[id]
		entries.append({
			"id": id,
			"crop": id,
			"name": String(c.get("seed_name", "Bibit " + crop_name(id))),
			"price": int(c.get("seed_price", 0)),
			"sell": int(c.get("sell_price", 0)),
		})
	return entries