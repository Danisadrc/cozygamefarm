extends Node
## GameState — Autoload singleton for persistent game state.
##
## Owns gold, day counter, time-of-day (hour/minute with day/night cycle),
## and the player inventory / hotbar (8 slots).
## All UI reads from here; FarmManager mutates tile state but calls
## GameState for gold/day changes.

signal gold_changed(new_gold: int)
signal day_changed(new_day: int)
signal hour_changed(new_hour: int)
signal inventory_changed
signal stamina_changed(new_stamina: int)

const START_GOLD := 100
const MAX_SLOTS := 10
const MAX_STAMINA := 100
const ITEM_START := 5   # slots 0..4 hold tools; 5.. hold items (seeds / produce / materials)
const ITEM_PRICES := {"fish": 25, "wood": 8, "rock": 6, "egg": 15}

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
var hotbar: Array[Dictionary] = [
	{"type": "tool", "tool": "hoe",     "name": "Cangkul",   "count": 0},
	{"type": "tool", "tool": "water",   "name": "Penyiram",  "count": 0},
	{"type": "tool", "tool": "axe",     "name": "Kapak",     "count": 0},
	{"type": "tool", "tool": "pickaxe", "name": "Beliung",   "count": 0},
	{"type": "tool", "tool": "rod",     "name": "Pancingan", "count": 0},
	{"type": "seed", "crop": "carrot", "name": "Bibit Wortel",  "count": 5},
	{"type": "seed", "crop": "potato", "name": "Bibit Kentang", "count": 5},
	{"type": "produce", "crop": "", "name": "", "count": 0},
	{"type": "produce", "crop": "", "name": "", "count": 0},
	{"type": "produce", "crop": "", "name": "", "count": 0},
]

var selected_slot := 0


# ------------------------------------------------------------------ lifecycle

func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_advance_time(delta)


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


## Find a seed slot for `crop_id`, or claim the first free item slot.
## Returns the slot index, or -1 if no room.
func find_or_add_seed(crop_id: String) -> int:
	for i in range(ITEM_START, MAX_SLOTS):
		if String(hotbar[i].get("type", "")) == "seed" and String(hotbar[i]["crop"]) == crop_id:
			return i
	for i in range(ITEM_START, MAX_SLOTS):
		if int(hotbar[i]["count"]) <= 0:
			hotbar[i]["type"] = "seed"
			hotbar[i]["crop"] = crop_id
			hotbar[i]["name"] = DataRegistry.crop_seed_name(crop_id)
			hotbar[i]["count"] = 0
			return i
	return -1


## Add an item (produce, fish, wood, rock, egg…) to the item slots.
## Stacks with a matching item, otherwise claims the first empty slot.
## Returns true if added.
func add_item(id: String, display: String, qty: int = 1) -> bool:
	for i in range(ITEM_START, MAX_SLOTS):
		var it: Dictionary = hotbar[i]
		if String(it.get("type", "")) == "produce" and String(it["crop"]) == id and int(it["count"]) > 0:
			it["count"] = int(it["count"]) + qty
			inventory_changed.emit()
			return true
	for i in range(ITEM_START, MAX_SLOTS):
		var it: Dictionary = hotbar[i]
		if int(it["count"]) <= 0:
			it["type"] = "produce"
			it["crop"] = id
			it["name"] = display
			it["count"] = qty
			inventory_changed.emit()
			return true
	return false


## Convenience wrapper used by FarmManager when harvesting a crop.
func add_produce(crop_id: String, qty: int = 1) -> bool:
	return add_item(crop_id, DataRegistry.crop_name(crop_id), qty)


## Sell price for any sellable item id (crops from DataRegistry, materials/fish
## from ITEM_PRICES).
func sell_price(id: String) -> int:
	var p := DataRegistry.crop_sell_price(id)
	if p > 0:
		return p
	return int(ITEM_PRICES.get(id, 0))


## Sell every produce/material item in the item slots. Returns gold earned.
func sell_all_produce() -> int:
	var total := 0
	for i in range(ITEM_START, MAX_SLOTS):
		var item: Dictionary = hotbar[i]
		var amount := int(item["count"])
		if amount <= 0:
			continue
		if String(item.get("type", "")) != "produce":
			continue
		var crop := String(item["crop"])
		if crop == "":
			continue
		total += amount * sell_price(crop)
		item["crop"] = ""
		item["name"] = ""
		item["count"] = 0
	if total > 0:
		add_gold(total)
		inventory_changed.emit()
	return total