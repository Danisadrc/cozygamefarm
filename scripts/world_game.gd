extends Node2D
## World — Main game scene controller.
##
## Wires FarmManager into the scene tree, owns the HUD reference, drives the
## day/night CanvasModulate and exposes the interaction / tool / zone entry
## points that world_player.gd calls via get_parent().

const HUD_SCRIPT := preload("res://scripts/hud.gd")
const FARM_MANAGER_SCRIPT := preload("res://scripts/farming/farm_manager.gd")

# Smooth sky colours keyed by hour [0..24]. Linear-interpolated per frame.
const SKY_KEYS := [
	[0.0, Color(0.55, 0.52, 0.72)],   # deep night (violet)
	[5.0, Color(0.55, 0.52, 0.72)],
	[6.5, Color(1.0, 0.84, 0.70)],    # dawn (warm)
	[8.0, Color(1.0, 1.0, 1.0)],      # full day
	[16.0, Color(1.0, 1.0, 1.0)],
	[18.0, Color(1.0, 0.78, 0.60)],   # dusk (warm)
	[20.0, Color(0.55, 0.52, 0.72)],  # night
	[24.0, Color(0.55, 0.52, 0.72)],
]

var player: CharacterBody2D
var soil: TileMapLayer
var farm: Node2D
var hud
var overlay: Node2D
var canvas_mod: CanvasModulate

var busy := false
var shop_open := false
var _last_grown := 0


func _ready() -> void:
	player = get_node_or_null("Player") as CharacterBody2D
	soil = get_node_or_null("FarmSoilLayer") as TileMapLayer
	canvas_mod = get_node_or_null("CanvasModulate") as CanvasModulate

	_create_farm_manager()
	_create_hud()
	farm.remove_placeholder_crops()

	GameState.day_changed.connect(_on_day_changed)

	hud.toast("Selamat datang! Cangkul tanah (1), tanam bibit (3-6), lalu siram (2).", 4.5)


func _process(_delta: float) -> void:
	if canvas_mod != null:
		canvas_mod.color = _sky_color(GameState.hour_float())


# ================================================================ construction

func _create_farm_manager() -> void:
	farm = FARM_MANAGER_SCRIPT.new()
	farm.name = "FarmManager"
	add_child(farm)
	farm.setup(self, soil, player)
	overlay = farm.overlay


func _create_hud() -> void:
	hud = HUD_SCRIPT.new()
	add_child(hud)
	hud.setup(self)
	farm.set_hud(hud)


# ================================================================ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if hud != null and hud.is_confirm_open():
				hud.close_confirm()
				get_viewport().set_input_as_handled()
			elif shop_open:
				close_shop()
				get_viewport().set_input_as_handled()


# ================================================================ player callbacks

func on_zone_changed(zone: String) -> void:
	if shop_open or busy or (hud != null and hud.is_confirm_open()):
		hud.hide_prompt()
		return
	var text := _prompt_for(zone)
	if text == "":
		hud.hide_prompt()
	else:
		hud.show_prompt(text)


func _prompt_for(zone: String) -> String:
	match zone:
		"sleep":
			return "[E] Tidur"
		"ship":
			return "[E] Jual Hasil Panen"
		"shop":
			return "[E] Beli Bibit"
	return ""


func select_slot(index: int) -> void:
	GameState.select_slot(index)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)


func cycle_slot(step: int) -> void:
	GameState.cycle_slot(step)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)


# ================================================================ interaction

func interact(zone: String) -> void:
	if busy or shop_open or zone == "" or (player != null and player.is_busy()):
		return
	match zone:
		"sleep":
			_ask_sleep()
		"ship":
			_sell_all()
		"shop":
			_open_shop()


func use_tool(cell: Vector2i) -> void:
	if busy or shop_open or player == null or player.is_busy():
		return
	var item: Dictionary = GameState.get_selected()
	farm.use_tool(cell, item)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)


func mouse_action(mouse_world: Vector2) -> void:
	if busy or shop_open or player == null or player.is_busy():
		return
	var cell := soil.local_to_map(soil.to_local(mouse_world))
	var player_cell := soil.local_to_map(soil.to_local(player.global_position))
	if farm._is_mature(cell) and absi(cell.x - player_cell.x) + absi(cell.y - player_cell.y) <= 2:
		farm.harvest(cell)
	else:
		use_tool(player.front_cell())


# ================================================================ sleep

func _ask_sleep() -> void:
	if player != null:
		player.input_locked = true
	hud.hide_prompt()
	hud.open_confirm("Tidur dan lanjut ke hari berikutnya?", _do_sleep)


func _do_sleep() -> void:
	if busy:
		return
	busy = true
	if player != null:
		player.input_locked = true
	hud.hide_prompt()

	var fade_in: Tween = hud.fade_to(1.0, 0.35)
	await fade_in.finished

	# Reset clock to 06:00 and advance the calendar. Emitting day_changed runs
	# _on_day_changed() which grows watered crops and resets the water flags.
	GameState.sleep_until_morning()

	if player != null:
		player.global_position = Vector2(424, 258)
		player.facing = Vector2i.DOWN
		player.queue_redraw()

	await get_tree().create_timer(0.3).timeout

	var msg := "Hari ke-%d. " % GameState.day
	if _last_grown > 0:
		msg += "%d tanaman tumbuh." % _last_grown
	else:
		msg += "Tanaman butuh disiram sebelum tidur."
	hud.toast(msg, 3.0)

	var fade_out: Tween = hud.fade_to(0.0, 0.35)
	await fade_out.finished
	if player != null:
		player.input_locked = false
	busy = false


func _on_day_changed(_new_day: int) -> void:
	_last_grown = farm.on_day_changed()
	hud.set_day(GameState.day)
	hud.set_gold(GameState.gold)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)


# ================================================================ selling / shop

func _sell_all() -> void:
	var total := GameState.sell_all_produce()
	if total == 0:
		hud.toast("Belum ada hasil panen. Panen tanaman matang dulu.")
		return
	hud.set_gold(GameState.gold)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	hud.pop_gold(total)
	hud.toast("Menjual hasil panen: +%d G" % total, 2.6)


func _open_shop() -> void:
	shop_open = true
	if player != null:
		player.input_locked = true
	hud.hide_prompt()
	hud.open_shop(GameState.gold)


func close_shop() -> void:
	if not shop_open:
		return
	shop_open = false
	if player != null:
		player.input_locked = false
	hud.close_shop()
	if player != null:
		on_zone_changed(player.current_zone)


func buy_seed(id: String) -> void:
	if not shop_open:
		return
	var price := DataRegistry.crop_seed_price(id)
	if not GameState.spend_gold(price):
		hud.toast("Gold tidak cukup untuk membeli bibit ini.")
		return
	var slot := GameState.find_or_add_seed(id)
	if slot == -1:
		hud.toast("Tidak ada slot kosong untuk bibit!")
		return
	GameState.hotbar[slot]["count"] = int(GameState.hotbar[slot]["count"]) + 1
	GameState.inventory_changed.emit()
	hud.set_gold(GameState.gold)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	hud.refresh_shop(GameState.gold)
	hud.toast("Bibit %s +1  (-%d G)" % [DataRegistry.crop_seed_name(id), price], 1.8)


# ================================================================ lighting

func _sky_color(h: float) -> Color:
	for i in range(SKY_KEYS.size() - 1):
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var t := (h - float(a[0])) / (float(b[0]) - float(a[0]))
			return (a[1] as Color).lerp(b[1] as Color, t)
	return SKY_KEYS[0][1]