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

const START_GOLD := 100
const MAX_SLOTS := 8

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

# ------------------------------------------------------------------ inventory
# Each slot is a Dictionary:
#   tool slot:    {"type": "tool", "tool": "hoe"|"water", "name": "Cangkul", "count": 0}
#   seed slot:    {"type": "seed", "crop": "<id>", "name": "...", "count": N}
#   produce slot: {"type": "produce", "crop": "<id>", "name": "...", "count": N}
var hotbar: Array[Dictionary] = [
	{"type": "tool", "tool": "hoe",   "name": "Cangkul",  "count": 0},
	{"type": "tool", "tool": "water", "name": "Penyiram", "count": 0},
	{"type": "seed", "crop": "carrot",    "name": "Bibit Wortel",   "count": 5},
	{"type": "seed", "crop": "potato",    "name": "Bibit Kentang",  "count": 5},
	{"type": "seed", "crop": "beetroot",  "name": "Bibit Bit",      "count": 5},
	{"type": "seed", "crop": "cabbage",   "name": "Bibit Kubis",    "count": 5},
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
	_minute_accum += delta * time_scale
	while _minute_accum >= 1.0:
		_minute_accum -= 1.0
		minute += 1
		if minute >= MINUTES_PER_HOUR:
			minute -= MINUTES_PER_HOUR
			hour += 1
			if hour >= 24:
				hour = 0
				_next_day()
			hour_changed.emit(hour)


func _next_day() -> void:
	day += 1
	day_changed.emit(day)


## Called by sleep zone interaction — fast-forwards to next morning.
func sleep_until_morning() -> void:
	hour = 6
	minute = 0
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


# ------------------------------------------------------------------ inventory

func select_slot(index: int) -> void:
	selected_slot = clampi(index, 0, MAX_SLOTS - 1)


func cycle_slot(step: int) -> void:
	selected_slot = posmod(selected_slot + step, MAX_SLOTS)


func get_selected() -> Dictionary:
	return hotbar[selected_slot]


## Find a seed slot for `crop_id` with space, or create one.
## Returns the slot index, or -1 if no room.
func find_or_add_seed(crop_id: String) -> int:
	# existing seed slot of same crop
	for i in range(2, 6):
		if String(hotbar[i]["crop"]) == crop_id:
			return i
	# empty seed slot (slot 2..5) — reuse a produce slot only as last resort
	for i in range(2, 6):
		if int(hotbar[i]["count"]) <= 0:
			hotbar[i]["crop"] = crop_id
			hotbar[i]["name"] = DataRegistry.crop_seed_name(crop_id)
			hotbar[i]["count"] = 0
			return i
	return -1


## Add produce to slots 6..7 (stackable), or first empty.
## Returns true if added.
func add_produce(crop_id: String, qty: int = 1) -> bool:
	for i in [6, 7]:
		if String(hotbar[i]["crop"]) == crop_id and int(hotbar[i]["count"]) > 0:
			hotbar[i]["count"] = int(hotbar[i]["count"]) + qty
			inventory_changed.emit()
			return true
	for i in [6, 7]:
		if int(hotbar[i]["count"]) <= 0:
			hotbar[i]["crop"] = crop_id
			hotbar[i]["name"] = DataRegistry.crop_name(crop_id)
			hotbar[i]["count"] = qty
			inventory_changed.emit()
			return true
	return false


## Sell all produce in slots 6..7. Returns gold earned.
func sell_all_produce() -> int:
	var total := 0
	for i in [6, 7]:
		var item: Dictionary = hotbar[i]
		var amount := int(item["count"])
		if amount <= 0:
			continue
		var crop := String(item["crop"])
		total += amount * DataRegistry.crop_sell_price(crop)
		item["crop"] = ""
		item["name"] = ""
		item["count"] = 0
	if total > 0:
		add_gold(total)
		inventory_changed.emit()
	return total