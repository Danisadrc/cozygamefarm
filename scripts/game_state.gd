extends Node
## GameState — Autoload singleton for persistent game state.
##
## Owns gold, day counter, time-of-day (hour/minute with day/night cycle),
## and the player inventory: a 5-slot hotbar plus a 15-slot backpack (5x3).
## All UI reads from here; FarmManager mutates tile state but calls
## GameState for gold/day changes.

signal gold_changed(new_gold: int)
signal day_changed(new_day: int)
signal hour_changed(new_hour: int)
signal inventory_changed
signal stamina_changed(new_stamina: int)
signal quest_changed
signal quests_done

const START_GOLD := 100
const MAX_SLOTS := 5            # hotbar slots 0..4
const BACKPACK_SLOTS := 15      # backpack grid 5x3, slots 0..14
const MAX_STAMINA := 100
const ITEM_START := MAX_SLOTS   # legacy: hotbar holds tools, items live in the backpack
const ITEM_PRICES := {"fish": 25, "wood": 8, "rock": 6}
const TOOL_NAMES := {
	"hoe": "Cangkul",
	"water": "Penyiram",
	"axe": "Kapak",
	"pickaxe": "Beliung",
	"rod": "Pancingan",
}

# ---------------------------------------------------------------- village quests
# Five sequential objectives, auto-tracked. `gold` goals are checked against
# the live wallet; every other key counts events while that quest is active.
const QUESTS := [
	{
		"title": "Petani Pemula",
		"goals": {"harvest": 3, "wood": 5},
		"reward": 100,
	},
	{
		"title": "Nelayan & Peternak",
		"goals": {"fish": 2, "egg": 2},
		"reward": 150,
	},
	{
		"title": "Juru Masak & Tetangga Baik",
		"goals": {"cook": 2, "gift": 1},
		"reward": 200,
	},
	{
		"title": "Peralatan Tangguh",
		"goals": {"upgrade": 1, "harvest": 8},
		"reward": 250,
	},
	{
		"title": "Renovasi Agung Desa",
		"goals": {"gold": 600, "wood": 15, "rock": 12},
		"reward": 0,
	},
]

const GOAL_LABELS := {
	"harvest": "Panen",
	"wood": "Kayu",
	"fish": "Ikan",
	"egg": "Telur",
	"rock": "Batu",
	"gold": "Gold",
	"cook": "Masak",
	"gift": "Hadiah",
	"upgrade": "Upgrade",
}

var quest_index := 0
var quest_done := false
var quest_counts: Dictionary = {}
var _quest_checking := false

# ---------------------------------------------------------------- daily orders
# One rotating side order on the quest board. A new order is rolled every time
# the player sleeps, and the reward is paid once per day when it is delivered.
const DAILY_ORDERS := [
	{"id": "carrot", "qty": 2, "reward": 60},
	{"id": "potato", "qty": 2, "reward": 70},
	{"id": "milk", "qty": 1, "reward": 80},
	{"id": "fish", "qty": 1, "reward": 70},
	{"id": "wood", "qty": 3, "reward": 60},
	{"id": "egg", "qty": 2, "reward": 90},
	{"id": "cabbage", "qty": 1, "reward": 120},
]

var daily_order: Dictionary = {}
var daily_order_done := false

# ------------------------------------------------------------------ time

var day := 1
var hour := 8           # 0..23
var minute := 0         # 0..59
var time_scale := 1.0   # multiplier: 1.0 = 1 real second = 1 game minute

const MINUTES_PER_HOUR := 60
const SECONDS_PER_MINUTE := 60.0

var _minute_accum := 0.0

# ------------------------------------------------------------------ economy

var gold := START_GOLD
var stamina := MAX_STAMINA

# ---------------------------------------------------------------- tool levels
# Every tool starts at Lv.1 and can be upgraded once (max Lv.2) at the market.
# Lv.2 halves stamina use (rounded up); the axe and pickaxe also break their
# resource in two hits instead of three.
const TOOL_MAX_LEVEL := 2
const TOOL_UPGRADE_GOLD := 150
const TOOL_UPGRADE_WOOD := 5
const TOOL_UPGRADE_ROCK := 5
const UPGRADABLE_TOOLS := ["hoe", "water", "axe", "pickaxe"]

var hoe_level := 1
var water_level := 1
var axe_level := 1
var pickaxe_level := 1

# ---------------------------------------------------------------- statistics
# Lifetime gameplay counters (cooking / gifting), kept across sleeps and reset
# only by GameState.reset().
var cooked_count := 0
var gifts_given := 0

# ---------------------------------------------------------------- friendship
# One 0..5 heart value per villager speaker name. `gift_day` stores the day of
# the last accepted gift so each NPC only takes one present per day; comparing
# it against the live `day` clears it automatically when morning comes.
# `friendship_rewarded` remembers who already paid the first-time 3-heart bonus.
var friendship_hearts: Dictionary = {}
var gift_day: Dictionary = {}
var friendship_rewarded: Dictionary = {}

# ------------------------------------------------------------------ inventory
# Each slot is a Dictionary:
#   tool slot:    {"type": "tool", "tool": "hoe"|"water", "name": "Cangkul", "count": 0}
#   seed slot:    {"type": "seed", "crop": "<id>", "name": "...", "count": N}
#   produce slot: {"type": "produce", "crop": "<id>", "name": "...", "count": N}
#   empty slot:   {"type": "", "tool": "", "crop": "", "name": "", "count": 0}
# The hotbar holds the five tools; everything else starts in the backpack.
var hotbar: Array[Dictionary] = _default_hotbar()
var backpack: Array[Dictionary] = _default_backpack()

var selected_slot := 0


## The five starting hotbar slots: one slot per main tool.
func _default_hotbar() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for entry in [["hoe", "Cangkul"], ["water", "Penyiram"], ["axe", "Kapak"],
			["pickaxe", "Beliung"], ["rod", "Pancingan"]]:
		slots.append({
			"type": "tool",
			"tool": String(entry[0]),
			"crop": "",
			"name": String(entry[1]),
			"count": 0,
		})
	return slots


## The fifteen starting backpack slots: carrot + potato seeds in the first two,
## the rest empty and ready for harvests / gathered materials.
func _default_backpack() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for _i in BACKPACK_SLOTS:
		slots.append(_empty_slot())
	slots[0] = {"type": "seed", "tool": "", "crop": "carrot",
		"name": "Bibit Wortel", "count": 5}
	slots[1] = {"type": "seed", "tool": "", "crop": "potato",
		"name": "Bibit Kentang", "count": 5}
	return slots


func _empty_slot() -> Dictionary:
	return {"type": "", "tool": "", "crop": "", "name": "", "count": 0}


# ------------------------------------------------------------------ lifecycle

func _ready() -> void:
	set_process(true)
	gold_changed.connect(_on_gold_changed_for_quest)


func _process(delta: float) -> void:
	_advance_time(delta)


## Put a brand-new game back on the table: starting gold / day / 06:00 clock /
## full stamina, the five default tools in the hotbar, carrot + potato seeds in
## the backpack, and quest 1 of 5 untouched.
## Called by the title screen's "Mulai Bermain" button, and safe to call at any
## point because every value is replaced rather than adjusted.
func reset() -> void:
	gold = START_GOLD
	day = 1
	hour = 6
	minute = 0
	_minute_accum = 0.0
	time_scale = 1.0
	stamina = MAX_STAMINA
	selected_slot = 0
	hotbar = _default_hotbar()
	backpack = _default_backpack()

	quest_index = 0
	quest_done = false
	quest_counts.clear()
	_quest_checking = false

	cooked_count = 0
	gifts_given = 0
	friendship_hearts.clear()
	gift_day.clear()
	friendship_rewarded.clear()

	hoe_level = 1
	water_level = 1
	axe_level = 1
	pickaxe_level = 1

	daily_order.clear()
	daily_order_done = false
	roll_daily_order()

	# Tell any live UI (the HUD survives a scene change only in theory, but a
	# reset from inside the world should still repaint everything).
	gold_changed.emit(gold)
	day_changed.emit(day)
	hour_changed.emit(hour)
	stamina_changed.emit(stamina)
	inventory_changed.emit()
	quest_changed.emit()


# ------------------------------------------------------------------ time API

func _advance_time(delta: float) -> void:
	# The clock stops at 23:59: a new day only starts when the player sleeps,
	# so day_changed can never fire twice in one cycle.
	if hour >= 23 and minute >= 59:
		return
	_minute_accum += delta * time_scale
	while _minute_accum >= 1.0:
		_minute_accum -= 1.0
		minute += 1
		if minute >= MINUTES_PER_HOUR:
			minute = 0
			hour += 1
			if hour >= 24:
				hour = 23
				minute = MINUTES_PER_HOUR - 1
				hour_changed.emit(hour)
				break
			hour_changed.emit(hour)


func _next_day() -> void:
	day += 1
	roll_daily_order()
	day_changed.emit(day)


## Instantly move the clock (used by the F1 demo menu). The day, crops and
## daily order are untouched, so this only changes the light and clock labels.
func set_clock(hour_value: int, minute_value := 0) -> void:
	hour = clampi(hour_value, 0, 23)
	minute = clampi(minute_value, 0, MINUTES_PER_HOUR - 1)
	_minute_accum = 0.0
	hour_changed.emit(hour)


## Called by sleep zone interaction — fast-forwards to next morning.
func sleep_until_morning() -> void:
	hour = 6
	minute = 0
	refill_stamina()
	_next_day()
	hour_changed.emit(hour)


## 0..1 progress within the current day (for UI sky modulation).
func day_progress() -> float:
	return (hour * 60.0 + minute) / (24.0 * 60.0)


## Decimal hour, e.g. 6.5 for 06:30 (used for smooth lighting gradients).
func hour_float() -> float:
	return float(hour) + float(minute) / 60.0


## Clock string, 24h "HH:MM".
func time_string() -> String:
	return "%02d:%02d" % [hour, minute]


## Phase of day for the HUD label.
func phase_name() -> String:
	if hour >= 5 and hour < 12:
		return "Pagi"
	if hour >= 12 and hour < 16:
		return "Siang"
	if hour >= 16 and hour < 20:
		return "Sore"
	return "Malam"


## True when the sun is down (20:00 .. 06:00).
func is_night() -> bool:
	return hour >= 20 or hour < 6


# ------------------------------------------------------------------ gold

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# ------------------------------------------------------------------ stamina

func spend_stamina(amount: int) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	stamina_changed.emit(stamina)
	return true


func restore_stamina(amount: int) -> void:
	stamina = mini(stamina + amount, MAX_STAMINA)
	stamina_changed.emit(stamina)


func refill_stamina() -> void:
	stamina = MAX_STAMINA
	stamina_changed.emit(stamina)


# ------------------------------------------------------------------ tool levels

func tool_level(tool: String) -> int:
	match tool:
		"hoe":
			return hoe_level
		"water":
			return water_level
		"axe":
			return axe_level
		"pickaxe":
			return pickaxe_level
	return 1


func set_tool_level(tool: String, level: int) -> void:
	var value := clampi(level, 1, TOOL_MAX_LEVEL)
	match tool:
		"hoe":
			hoe_level = value
		"water":
			water_level = value
		"axe":
			axe_level = value
		"pickaxe":
			pickaxe_level = value


func tool_upgraded(tool: String) -> bool:
	return tool_level(tool) >= TOOL_MAX_LEVEL


## True when the tool can still be upgraded and the wallet + materials allow it.
func can_upgrade_tool(tool: String) -> bool:
	if tool_upgraded(tool):
		return false
	return gold >= TOOL_UPGRADE_GOLD \
		and count_item("wood") >= TOOL_UPGRADE_WOOD \
		and count_item("rock") >= TOOL_UPGRADE_ROCK


## Pay the market price and raise the tool one level. Returns false untouched.
func upgrade_tool(tool: String) -> bool:
	if not can_upgrade_tool(tool):
		return false
	if not spend_gold(TOOL_UPGRADE_GOLD):
		return false
	remove_item("wood", TOOL_UPGRADE_WOOD)
	remove_item("rock", TOOL_UPGRADE_ROCK)
	set_tool_level(tool, tool_level(tool) + 1)
	inventory_changed.emit()
	quest_event("upgrade", 1)
	return true


## Stamina paid for one tool swing: Lv.2 spends half (rounded up).
func tool_stamina_cost(tool: String, base_cost: int) -> int:
	if tool_level(tool) >= TOOL_MAX_LEVEL:
		return int((base_cost + 1) / 2)
	return base_cost


## Hits needed to fell a tree / crack a boulder (Lv.2 axe/pickaxe = 2 hits).
func resource_hits_required(kind: String) -> int:
	var tool := "axe" if kind == "tree" else "pickaxe"
	return 2 if tool_upgraded(tool) else 3


## Every upgradeable tool with its level, for the market's Upgrade tab.
func tool_upgrade_rows() -> Array:
	var out: Array = []
	for tool in UPGRADABLE_TOOLS:
		out.append({
			"tool": tool,
			"name": String(TOOL_NAMES.get(tool, tool)),
			"level": tool_level(tool),
			"max": TOOL_MAX_LEVEL,
			"maxed": tool_upgraded(tool),
			"can": can_upgrade_tool(tool),
		})
	return out


# ------------------------------------------------------------------ inventory

func select_slot(index: int) -> void:
	selected_slot = clampi(index, 0, MAX_SLOTS - 1)


func cycle_slot(step: int) -> void:
	selected_slot = posmod(selected_slot + step, MAX_SLOTS)


func get_selected() -> Dictionary:
	return hotbar[selected_slot]


## The slot array for a zone name ("hotbar" / "backpack"). Arrays are
## references, so mutating the result mutates the real inventory.
func _zone_slots(zone: String) -> Array[Dictionary]:
	if zone == "backpack":
		return backpack
	return hotbar


func get_slot(zone: String, index: int) -> Dictionary:
	var slots := _zone_slots(zone)
	if index < 0 or index >= slots.size():
		return {}
	return slots[index]


## True for a slot that can be claimed by a new item. Tool slots are never
## empty even though their count is 0 (they are permanent equipment).
func is_slot_empty(item: Dictionary) -> bool:
	if item.is_empty():
		return true
	var kind := String(item.get("type", ""))
	if kind == "":
		return true
	if kind == "tool":
		return false
	return int(item.get("count", 0)) <= 0


## Stack identity: tools never stack, seeds stack per crop, produce per crop.
func _stack_key(item: Dictionary) -> String:
	if is_slot_empty(item):
		return ""
	match String(item.get("type", "")):
		"seed":
			return "seed:" + String(item.get("crop", ""))
		"produce":
			return "produce:" + String(item.get("crop", ""))
	return ""


func _same_stack(a: Dictionary, b: Dictionary) -> bool:
	var key := _stack_key(a)
	return key != "" and key == _stack_key(b)


## First slot holding a stack with `key`, searched hotbar then backpack.
## Returns {"zone": String, "index": int}, or {} when absent.
func _find_stack(key: String) -> Dictionary:
	if key == "":
		return {}
	for zone in ["hotbar", "backpack"]:
		var slots := _zone_slots(zone)
		for i in slots.size():
			if _stack_key(slots[i]) == key:
				return {"zone": zone, "index": i}
	return {}


func _find_empty_slot(zone: String) -> int:
	var slots := _zone_slots(zone)
	for i in slots.size():
		if is_slot_empty(slots[i]):
			return i
	return -1


## Add a produce / material item. Stacks with an identical item first, then
## claims an empty hotbar slot (0..4), then an empty backpack slot (0..14).
## Returns true if added.
func add_item(id: String, display: String, qty: int = 1) -> bool:
	if qty <= 0:
		return false
	var loc := _find_stack("produce:" + id)
	if not loc.is_empty():
		var stacked := get_slot(String(loc["zone"]), int(loc["index"]))
		stacked["count"] = int(stacked["count"]) + qty
		inventory_changed.emit()
		return true
	for zone in ["hotbar", "backpack"]:
		var index := _find_empty_slot(zone)
		if index == -1:
			continue
		var slots := _zone_slots(zone)
		slots[index] = {
			"type": "produce", "tool": "", "crop": id,
			"name": display, "count": qty,
		}
		inventory_changed.emit()
		return true
	return false


## Add seeds, stacking with the same crop first (hotbar then backpack).
## Returns true if added.
func add_seed(crop_id: String, qty: int = 1) -> bool:
	if qty <= 0:
		return false
	var loc := _find_stack("seed:" + crop_id)
	if not loc.is_empty():
		var stacked := get_slot(String(loc["zone"]), int(loc["index"]))
		stacked["count"] = int(stacked["count"]) + qty
		inventory_changed.emit()
		return true
	for zone in ["hotbar", "backpack"]:
		var index := _find_empty_slot(zone)
		if index == -1:
			continue
		var slots := _zone_slots(zone)
		slots[index] = {
			"type": "seed", "tool": "", "crop": crop_id,
			"name": DataRegistry.crop_seed_name(crop_id), "count": qty,
		}
		inventory_changed.emit()
		return true
	return false


func can_add_seed(crop_id: String) -> bool:
	if not _find_stack("seed:" + crop_id).is_empty():
		return true
	return _find_empty_slot("hotbar") != -1 or _find_empty_slot("backpack") != -1


## Legacy helper kept for older callers: returns the hotbar index of a seed
## stack (or a newly claimed hotbar slot), or -1. Prefer add_seed().
func find_or_add_seed(crop_id: String) -> int:
	var loc := _find_stack("seed:" + crop_id)
	if not loc.is_empty():
		return int(loc["index"]) if String(loc["zone"]) == "hotbar" else -1
	var index := _find_empty_slot("hotbar")
	if index == -1:
		return -1
	hotbar[index] = {
		"type": "seed", "tool": "", "crop": crop_id,
		"name": DataRegistry.crop_seed_name(crop_id), "count": 0,
	}
	return index


## Move or merge items between the hotbar and the backpack. Identical stacks
## merge into the destination; everything else is swapped. Returns true when
## something changed.
func swap_slots(from_zone: String, from_idx: int, to_zone: String,
		to_idx: int) -> bool:
	var from_slots := _zone_slots(from_zone)
	var to_slots := _zone_slots(to_zone)
	if from_idx < 0 or from_idx >= from_slots.size():
		return false
	if to_idx < 0 or to_idx >= to_slots.size():
		return false
	if from_zone == to_zone and from_idx == to_idx:
		return false
	var a: Dictionary = from_slots[from_idx]
	var b: Dictionary = to_slots[to_idx]
	if not is_slot_empty(a) and not is_slot_empty(b) and _same_stack(a, b):
		b["count"] = int(b["count"]) + int(a["count"])
		from_slots[from_idx] = _empty_slot()
	else:
		from_slots[from_idx] = b
		to_slots[to_idx] = a
	inventory_changed.emit()
	return true


## Stamina restored by eating a slot, or 0 when it is not food.
func eat_gain(item: Dictionary) -> int:
	if String(item.get("type", "")) != "produce":
		return 0
	var id := String(item.get("crop", ""))
	if id == "":
		return 0
	if not DataRegistry.get_crop(id).is_empty():
		return 20
	return DataRegistry.item_stamina(id)


## Eat one item from a slot. Returns the stamina gained (0 = not edible / full).
func eat_slot(zone: String, index: int) -> int:
	var item := get_slot(zone, index)
	if is_slot_empty(item):
		return 0
	var gain := eat_gain(item)
	if gain <= 0 or stamina >= MAX_STAMINA:
		return 0
	item["count"] = int(item["count"]) - 1
	if int(item["count"]) <= 0:
		var slots := _zone_slots(zone)
		slots[index] = _empty_slot()
	restore_stamina(gain)
	inventory_changed.emit()
	return gain


## Throw away one unit of a seed / produce stack. Tools are never discarded.
func discard_one(zone: String, index: int) -> bool:
	var item := get_slot(zone, index)
	if is_slot_empty(item):
		return false
	var kind := String(item.get("type", ""))
	if kind != "seed" and kind != "produce":
		return false
	item["count"] = int(item["count"]) - 1
	if int(item["count"]) <= 0:
		var slots := _zone_slots(zone)
		slots[index] = _empty_slot()
	inventory_changed.emit()
	return true


# ---------------------------------------------------------------- cooking

## Total units of one produce / material id across the hotbar and backpack.
func count_item(id: String) -> int:
	var total := 0
	for zone in ["hotbar", "backpack"]:
		for slot in _zone_slots(zone):
			if String(slot.get("type", "")) == "produce" \
					and String(slot.get("crop", "")) == id:
				total += int(slot.get("count", 0))
	return total


## Take `qty` units of an item out of the inventory (hotbar first).
## Returns true when the whole amount was removed.
func remove_item(id: String, qty: int) -> bool:
	if qty <= 0:
		return true
	var remaining := qty
	for zone in ["hotbar", "backpack"]:
		var slots := _zone_slots(zone)
		for i in slots.size():
			var slot: Dictionary = slots[i]
			if String(slot.get("type", "")) != "produce" \
					or String(slot.get("crop", "")) != id:
				continue
			var have := int(slot.get("count", 0))
			var take := mini(have, remaining)
			if take <= 0:
				continue
			remaining -= take
			slot["count"] = have - take
			if int(slot["count"]) <= 0:
				slots[i] = _empty_slot()
			if remaining <= 0:
				inventory_changed.emit()
				return true
	if remaining < qty:
		inventory_changed.emit()
	return false


## True when every ingredient for a recipe is in the bag right now.
func can_cook(recipe_id: String) -> bool:
	var recipe := DataRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for id in ingredients.keys():
		if count_item(String(id)) < int(ingredients[id]):
			return false
	return true


## Consume the ingredients and put one cooked dish in the bag. Returns false
## (leaving the inventory untouched) when the player is short of anything.
func cook(recipe_id: String) -> bool:
	var recipe := DataRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	var ingredients: Dictionary = recipe.get("ingredients", {})
	if not can_cook(recipe_id):
		return false
	for id in ingredients.keys():
		remove_item(String(id), int(ingredients[id]))
	if not add_item(recipe_id, DataRegistry.item_name(recipe_id)):
		# The bag could not hold the dish: give the ingredients back.
		for id in ingredients.keys():
			add_item(String(id), DataRegistry.ingredient_name(String(id)),
				int(ingredients[id]))
		return false
	cooked_count += 1
	inventory_changed.emit()
	return true


# ---------------------------------------------------------------- gifting

const GIFT_IDS := ["fish", "egg", "milk"]


## Only harvests, animal products and cooked dishes are presentable.
func is_giftable(item: Dictionary) -> bool:
	if String(item.get("type", "")) != "produce" or int(item.get("count", 0)) <= 0:
		return false
	var id := String(item.get("crop", ""))
	if id == "":
		return false
	if not DataRegistry.get_crop(id).is_empty():
		return true
	if id in GIFT_IDS:
		return true
	return DataRegistry.is_food(id)


func item_display_name(id: String) -> String:
	if not DataRegistry.get_crop(id).is_empty():
		return DataRegistry.crop_name(id)
	return DataRegistry.item_name(id)


## The giftable item currently held in the selected hotbar slot, or {}.
func selected_gift() -> Dictionary:
	var item: Dictionary = get_selected()
	if not is_giftable(item):
		return {}
	return {
		"id": String(item.get("crop", "")),
		"name": item_display_name(String(item.get("crop", ""))),
	}


## Remove one unit of the held gift. Returns {"id","name"} or {}.
func consume_selected_gift() -> Dictionary:
	var gift := selected_gift()
	if gift.is_empty():
		return {}
	var item: Dictionary = get_selected()
	item["count"] = int(item["count"]) - 1
	if int(item["count"]) <= 0:
		hotbar[selected_slot] = _empty_slot()
	inventory_changed.emit()
	return gift


func hearts_for(name: String) -> int:
	return clampi(int(friendship_hearts.get(name, 0)), 0, 5)


## +1 heart, capped at five. Returns the new value.
func add_heart(name: String) -> int:
	var value := mini(hearts_for(name) + 1, 5)
	friendship_hearts[name] = value
	return value


func gifted_today(name: String) -> bool:
	return int(gift_day.get(name, -1)) == day


func can_gift_today(name: String) -> bool:
	return not gifted_today(name)


func record_gift(name: String) -> void:
	gift_day[name] = day
	gifts_given += 1


## True exactly once, when this NPC first reaches the 3-heart milestone.
func claim_three_heart_reward(name: String) -> bool:
	if hearts_for(name) < 3 or friendship_rewarded.has(name):
		return false
	friendship_rewarded[name] = true
	return true


## Everything the backpack info panel needs for one slot ({} when empty).
func slot_info(zone: String, index: int) -> Dictionary:
	var item := get_slot(zone, index)
	if is_slot_empty(item):
		return {}
	var kind := String(item.get("type", ""))
	var id := String(item.get("crop", ""))
	if kind == "tool":
		id = String(item.get("tool", ""))
	var display := String(item.get("name", ""))
	if display == "":
		if kind == "tool":
			display = String(TOOL_NAMES.get(id, "Alat"))
		else:
			display = DataRegistry.crop_name(id)
	var sell := 0
	if kind == "produce":
		sell = sell_price(id)
	var stamina := eat_gain(item)
	return {
		"zone": zone,
		"index": index,
		"type": kind,
		"id": id,
		"name": display,
		"count": int(item.get("count", 0)),
		"sell": sell,
		"stamina": stamina,
		"edible": stamina > 0,
		"discardable": kind != "tool",
	}


## Convenience wrapper used by FarmManager when harvesting a crop.
func add_produce(crop_id: String, qty: int = 1) -> bool:
	return add_item(crop_id, DataRegistry.crop_name(crop_id), qty)


## Sell price for any sellable item id (crops and items from DataRegistry,
## legacy materials from ITEM_PRICES).
func sell_price(id: String) -> int:
	var p := DataRegistry.crop_sell_price(id)
	if p > 0:
		return p
	p = DataRegistry.item_sell_price(id)
	if p > 0:
		return p
	return int(ITEM_PRICES.get(id, 0))


## Sell every produce/material stack in both zones. Returns gold earned.
func sell_all_produce() -> int:
	var total := 0
	for zone in ["hotbar", "backpack"]:
		var slots := _zone_slots(zone)
		for i in slots.size():
			var item: Dictionary = slots[i]
			if String(item.get("type", "")) != "produce":
				continue
			var amount := int(item["count"])
			if amount <= 0:
				continue
			var crop := String(item["crop"])
			if crop == "":
				continue
			total += amount * sell_price(crop)
			slots[i] = _empty_slot()
	if total > 0:
		add_gold(total)
		inventory_changed.emit()
	return total


# ---------------------------------------------------------------- daily orders

## Roll the next side order. Tries a few times to avoid repeating yesterday's.
func roll_daily_order() -> void:
	daily_order_done = false
	var previous := String(daily_order.get("id", ""))
	var pick: Dictionary = DAILY_ORDERS[randi_range(0, DAILY_ORDERS.size() - 1)]
	for _i in 6:
		if String(pick.get("id", "")) != previous:
			break
		pick = DAILY_ORDERS[randi_range(0, DAILY_ORDERS.size() - 1)]
	daily_order = pick.duplicate()


## Everything the quest board needs for the side order.
func daily_order_progress() -> Dictionary:
	if daily_order.is_empty():
		return {}
	var id := String(daily_order.get("id", ""))
	var need := int(daily_order.get("qty", 1))
	var have := mini(count_item(id), need)
	return {
		"id": id,
		"label": DataRegistry.ingredient_name(id),
		"qty": need,
		"have": have,
		"reward": int(daily_order.get("reward", 0)),
		"done": daily_order_done,
		"ready": not daily_order_done and have >= need,
	}


func can_submit_daily_order() -> bool:
	if daily_order.is_empty() or daily_order_done:
		return false
	return count_item(String(daily_order.get("id", ""))) >= int(daily_order.get("qty", 1))


## Deliver today's order: take the items, pay the reward. {} when not possible.
func submit_daily_order() -> Dictionary:
	if not can_submit_daily_order():
		return {}
	var id := String(daily_order.get("id", ""))
	var qty := int(daily_order.get("qty", 1))
	var reward := int(daily_order.get("reward", 0))
	remove_item(id, qty)
	daily_order_done = true
	add_gold(reward)
	return {
		"id": id,
		"label": DataRegistry.ingredient_name(id),
		"qty": qty,
		"reward": reward,
	}


# ---------------------------------------------------------------- village quests

func current_quest() -> Dictionary:
	if quest_done or quest_index < 0 or quest_index >= QUESTS.size():
		return {}
	return QUESTS[quest_index]


func quest_title() -> String:
	return String(current_quest().get("title", ""))


func quest_reward() -> int:
	return int(current_quest().get("reward", 0))


func quest_goal_value(kind: String) -> int:
	if kind == "gold":
		return gold
	return int(quest_counts.get(kind, 0))


## One row per goal: {"label", "have", "need", "done"}.
func quest_progress() -> Array:
	var out: Array = []
	var q := current_quest()
	if q.is_empty():
		return out
	var goals: Dictionary = q.get("goals", {})
	for kind in goals.keys():
		var need := int(goals[kind])
		var have := mini(quest_goal_value(String(kind)), need)
		out.append({
			"label": String(GOAL_LABELS.get(kind, kind)),
			"have": have,
			"need": need,
			"done": have >= need,
		})
	return out


func quest_progress_text() -> String:
	var parts: Array[String] = []
	for p in quest_progress():
		parts.append("%s %d/%d" % [p["label"], int(p["have"]), int(p["need"])])
	return " • ".join(parts)


## Record gameplay progress for the active quest. Kinds with no matching goal
## (e.g. fishing during quest 1) are ignored.
func quest_event(kind: String, amount := 1) -> void:
	if quest_done or _quest_checking or amount <= 0:
		return
	var q := current_quest()
	if q.is_empty():
		return
	var goals: Dictionary = q.get("goals", {})
	if not goals.has(kind):
		return
	quest_counts[kind] = int(quest_counts.get(kind, 0)) + amount
	quest_changed.emit()
	_check_quest()


func _check_quest() -> void:
	if quest_done or _quest_checking:
		return
	var q := current_quest()
	if q.is_empty():
		return
	var goals: Dictionary = q.get("goals", {})
	for kind in goals.keys():
		if quest_goal_value(String(kind)) < int(goals[kind]):
			return

	# Every goal is met: pay the reward, advance, and cascade if the next
	# quest is already satisfied (e.g. a gold goal after a reward).
	_quest_checking = true
	var reward := int(q.get("reward", 0))
	if reward > 0:
		gold += reward
		gold_changed.emit(gold)
	quest_index += 1
	quest_counts.clear()
	if quest_index >= QUESTS.size():
		quest_done = true
	_quest_checking = false

	quest_changed.emit()
	if quest_done:
		quests_done.emit()
	else:
		_check_quest()


func _on_gold_changed_for_quest(_new_gold: int) -> void:
	if quest_done or _quest_checking:
		return
	if current_quest().get("goals", {}).has("gold"):
		quest_changed.emit()
		_check_quest()


## Flavour text for the villager, tied to the active quest.
func quest_hint() -> String:
	if quest_done:
		return "Cozy Valley sudah makmur! Terima kasih, petani. Sekarang nikmati hari-hari tenang di ladang."
	match quest_index:
		0:
			return "Papan Misi di dekat pasar mencari petani baru: panen 3 tanaman dan kumpulkan 5 kayu."
		1:
			return "Ikan di kolam sedang banyak! Papan Misi minta 2 ikan segar dan 2 telur dari kandang."
		2:
			return "Warga ingin mencicipi masakanmu. Masak 2 hidangan di api unggun dan beri 1 hadiah ke warga."
		3:
			return "Alat yang tajam membuat kerja ringan. Upgrade 1 alat di Kios Pasar, lalu panen total 8 tanaman."
		4:
			return "Renovasi agung dimulai! Kumpulkan 600 G, 15 kayu, dan 12 batu untuk membuat desa makmur."
	return ""


# ------------------------------------------------------------------ demo cheats

## Demo helper: add exactly the missing stock for today's side order, nothing
## more. The player still presses "Serahkan Pesanan" on the board to turn it in.
func cheat_stock_daily_order() -> Dictionary:
	if daily_order.is_empty():
		return {}
	var id := String(daily_order.get("id", ""))
	var display := DataRegistry.ingredient_name(id)
	var need := int(daily_order.get("qty", 1))
	var have := count_item(id)
	if daily_order_done:
		return {"id": id, "label": display, "qty": need, "have": have,
			"added": 0, "done": true}
	var missing := maxi(need - have, 0)
	var added := 0
	if missing > 0 and add_item(id, display, missing):
		added = missing
	return {
		"id": id,
		"label": display,
		"qty": need,
		"have": count_item(id),
		"added": added,
		"done": false,
	}


## Demo helper: stock every campfire recipe (two servings each) so the cooking
## panel can be shown without gathering first. Returns what was added.
func cheat_stock_cooking(multiplier := 2) -> Dictionary:
	var need: Dictionary = {}
	for recipe in DataRegistry.get_food_recipes():
		var ingredients: Dictionary = recipe.get("ingredients", {})
		for id in ingredients.keys():
			need[id] = int(need.get(id, 0)) + int(ingredients[id]) * multiplier
	var added: Dictionary = {}
	var failed: Array[String] = []
	for id in need.keys():
		var item_id := String(id)
		var missing := maxi(int(need[id]) - count_item(item_id), 0)
		if missing <= 0:
			continue
		var display := DataRegistry.ingredient_name(item_id)
		if add_item(item_id, display, missing):
			added[item_id] = missing
		else:
			failed.append(display)
	return {"added": added, "failed": failed}


## Demo helper: satisfy the active main quest. Item goals receive only the
## missing stock; harvest / cook / gift / upgrade goals record the matching
## progress so the quest can advance immediately.
func cheat_finish_current_quest() -> Dictionary:
	if quest_done:
		return {}
	var q := current_quest()
	if q.is_empty():
		return {}
	var before := quest_index
	var title := String(q.get("title", ""))
	var reward := int(q.get("reward", 0))
	var goals: Dictionary = q.get("goals", {})
	var added: Dictionary = {}
	var failed: Array[String] = []
	var gold_missing := 0
	for kind in goals.keys():
		if quest_done:
			break
		var goal := String(kind)
		var need := int(goals[kind])
		var have := mini(quest_goal_value(goal), need)
		var missing := need - have
		if missing <= 0:
			continue
		if goal == "gold":
			gold_missing = maxi(gold_missing, missing)
			continue
		_cheat_grant_goal(goal, missing, added, failed)
	if gold_missing > 0 and not quest_done:
		add_gold(gold_missing)
		added["gold"] = int(added.get("gold", 0)) + gold_missing
	if not quest_done:
		_check_quest()
	return {
		"title": title,
		"before": before,
		"after": quest_index,
		"reward": reward,
		"added": added,
		"failed": failed,
		"done": quest_done,
	}


## Demo helper: run cheat_finish_current_quest() until the 5-stage chain ends.
func cheat_finish_all_quests() -> Dictionary:
	var added: Dictionary = {}
	var failed: Array[String] = []
	var stages := 0
	var safety := 0
	while not quest_done and safety < QUESTS.size() + 2:
		safety += 1
		var before := quest_index
		var result := cheat_finish_current_quest()
		if result.is_empty():
			break
		stages += 1
		_merge_cheat_counts(added, result.get("added", {}))
		for label in result.get("failed", []):
			if not failed.has(String(label)):
				failed.append(String(label))
		if quest_done or quest_index <= before:
			break
	return {
		"stages": stages,
		"added": added,
		"failed": failed,
		"done": quest_done,
		"gold": gold,
	}


func _cheat_grant_goal(kind: String, amount: int, added: Dictionary,
		failed: Array[String]) -> void:
	match kind:
		"harvest":
			var crop := "carrot"
			var crop_name := DataRegistry.crop_name(crop)
			if add_item(crop, crop_name, amount):
				added[crop] = int(added.get(crop, 0)) + amount
			else:
				failed.append(crop_name)
			quest_event("harvest", amount)
		"cook":
			var dish := "omelette"
			var dish_name := DataRegistry.item_name(dish)
			var dish_missing := maxi(amount - count_item(dish), 0)
			if dish_missing > 0:
				if add_item(dish, dish_name, dish_missing):
					added[dish] = int(added.get(dish, 0)) + dish_missing
				else:
					failed.append(dish_name)
			cooked_count += amount
			quest_event("cook", amount)
		"gift":
			var gift := "fish"
			var gift_name := DataRegistry.item_name(gift)
			var gift_missing := maxi(amount - count_item(gift), 0)
			if gift_missing > 0:
				if add_item(gift, gift_name, gift_missing):
					added[gift] = int(added.get(gift, 0)) + gift_missing
				else:
					failed.append(gift_name)
			gifts_given += amount
			quest_event("gift", amount)
		"upgrade":
			var upgraded := 0
			for tool in UPGRADABLE_TOOLS:
				if upgraded >= amount:
					break
				if not tool_upgraded(String(tool)):
					set_tool_level(String(tool), TOOL_MAX_LEVEL)
					upgraded += 1
			if upgraded > 0:
				added["upgrade"] = int(added.get("upgrade", 0)) + upgraded
			quest_event("upgrade", amount)
		_:
			var display := DataRegistry.ingredient_name(kind)
			var missing := maxi(amount - count_item(kind), 0)
			if missing > 0:
				if add_item(kind, display, missing):
					added[kind] = int(added.get(kind, 0)) + missing
				else:
					failed.append(display)
			quest_event(kind, amount)


func _merge_cheat_counts(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = int(target.get(key, 0)) + int(source[key])
