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
# Three sequential objectives, auto-tracked. `gold` goals are checked against
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
		"title": "Renovasi Desa",
		"goals": {"gold": 400, "wood": 10, "rock": 8},
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
}

var quest_index := 0
var quest_done := false
var quest_counts: Dictionary = {}
var _quest_checking := false

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
## the backpack, and quest 1 of 3 untouched.
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
	day_changed.emit(day)


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
		return "Terima kasih sudah merenovasi desa! Sekarang nikmati hari-hari tenang di ladang."
	match quest_index:
		0:
			return "Papan Misi di dekat pasar mencari petani baru: panen 3 tanaman dan kumpulkan 5 kayu."
		1:
			return "Ikan di kolam sedang banyak! Papan Misi minta 2 ikan segar dan 2 telur dari kandang."
		2:
			return "Warga mengumpulkan 400 G, 10 kayu, dan 8 batu untuk merenovasi desa. Papan Misi menunggu di dekat pasar!"
	return ""
