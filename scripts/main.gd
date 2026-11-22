extends Node2D

const FarmPlot := preload("res://scripts/farm_plot.gd")
const PLANTS_TEX := preload("res://assets/plants/PNG/Plants.png")
const TILES_TEX := preload("res://assets/farm_kit/2 Standart/5 Tiles/TileSet.png")
const CHICKEN_TEX := preload("res://assets/farm_kit/2 Standart/2 Animals/Chicken_idle.png")

const PLOT_SIZE := 56.0
const COLS := 3
const ROWS := 2
const SPACING := Vector2(78, 80)
const GAME_TIME := 90.0
const WIN_COINS := 100

const TREE_BIG := Rect2(261, 14, 52, 66)
const TREE_MEDIUM := Rect2(202, 29, 38, 51)
const TREE_SMALL := Rect2(161, 42, 27, 36)
const TUFT := Rect2(9, 371, 11, 10)
const FLOWER := Rect2(96, 8, 8, 8)

var coins := 0
var time_left := GAME_TIME
var running := true
var plots: Array = []
var _toast_tween: Tween

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $World/Player
@onready var coins_label: Label = $UI/Coins
@onready var timer_label: Label = $UI/Timer
@onready var toast: Label = $UI/Toast
@onready var overlay: ColorRect = $UI/Overlay
@onready var result_label: Label = $UI/Overlay/Result


func _ready() -> void:
	_spawn_decor()
	_spawn_plots()
	_spawn_chickens()
	_update_hud()
	_show_toast("Panen bunga matahari! Kumpulkan 100 koin", 2.5)


func _spawn_plots() -> void:
	var origin := Vector2(-SPACING.x, -50.0)
	for row in ROWS:
		for col in COLS:
			var plot = FarmPlot.new()
			plot.position = origin + Vector2(col * SPACING.x, row * SPACING.y)
			plot.plot_size = PLOT_SIZE
			plot.harvested.connect(_on_harvested)
			world.add_child(plot)
			plots.append(plot)


func _spawn_decor() -> void:
	_add_sprite(PLANTS_TEX, TREE_BIG, Vector2(-178, -72), 2.0)
	_add_sprite(PLANTS_TEX, TREE_BIG, Vector2(182, -86), 2.0)
	_add_sprite(PLANTS_TEX, TREE_MEDIUM, Vector2(-188, 76), 2.0)
	_add_sprite(PLANTS_TEX, TREE_MEDIUM, Vector2(190, 68), 2.0)
	_add_sprite(PLANTS_TEX, TREE_SMALL, Vector2(-120, -128), 2.0)
	_add_sprite(PLANTS_TEX, TREE_SMALL, Vector2(128, -132), 2.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261121

	for i in 80:
		var pos := Vector2(rng.randf_range(-230.0, 230.0), rng.randf_range(-150.0, 180.0))
		if absf(pos.x) < 120.0 and pos.y > -100.0 and pos.y < 60.0:
			continue
		var tuft := _add_sprite(PLANTS_TEX, TUFT, pos, rng.randf_range(1.2, 2.0))
		tuft.modulate = Color(1, 1, 1, rng.randf_range(0.5, 0.9))
		tuft.flip_h = rng.randf() > 0.5

	for i in 24:
		var pos := Vector2(rng.randf_range(-225.0, 225.0), rng.randf_range(-145.0, 175.0))
		if absf(pos.x) < 118.0 and pos.y > -100.0 and pos.y < 60.0:
			continue
		var flower := _add_sprite(TILES_TEX, FLOWER, pos, 2.0)
		flower.modulate = Color(1, 1, 1, 0.9)


func _spawn_chickens() -> void:
	var spots: Array[Vector2] = [Vector2(-120, 55), Vector2(135, -10), Vector2(60, 120)]
	for spot in spots:
		var chicken := _add_sprite(CHICKEN_TEX, Rect2(0, 0, 8, 8), spot, 3.0)
		var base_y: float = chicken.position.y
		var tw := create_tween().set_loops()
		tw.tween_property(chicken, "position:y", base_y - 3.0, 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(chicken, "position:y", base_y, 0.45).set_trans(Tween.TRANS_SINE)


func _add_sprite(tex: Texture2D, rect: Rect2, pos: Vector2, scl: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = rect
	sprite.texture = at
	sprite.scale = Vector2(scl, scl)
	sprite.position = pos + Vector2(0, -rect.size.y * scl * 0.5)
	world.add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	if not running:
		return
	time_left = maxf(0.0, time_left - delta)
	timer_label.text = "%02d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	if time_left <= 0.0:
		_end_game(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			_try_interact()
		elif event.keycode == KEY_R:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_W:
			get_tree().change_scene_to_file("res://scenes/world.tscn")


func _try_interact() -> void:
	if not running:
		return

	var nearest = null
	var nearest_dist := 72.0
	for plot in plots:
		var d: float = player.global_position.distance_to(plot.global_position + Vector2(0, -24))
		if d < nearest_dist:
			nearest_dist = d
			nearest = plot

	if nearest == null:
		_show_toast("Dekati petak tanah dulu", 1.0)
		return
	if nearest.can_interact():
		nearest.interact()
	else:
		_show_toast("Masih tumbuh...", 1.0)


func _on_harvested(amount: int) -> void:
	coins += amount
	_update_hud()
	_show_toast("+%d koin" % amount, 0.7)
	coins_label.modulate = Color("ffe36e")
	var tw := create_tween()
	tw.tween_property(coins_label, "modulate", Color.WHITE, 0.45)
	if coins >= WIN_COINS:
		_end_game(true)


func _update_hud() -> void:
	coins_label.text = "Koin: %d / %d" % [coins, WIN_COINS]


func _show_toast(text: String, duration: float) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)


func _end_game(win: bool) -> void:
	if not running:
		return
	running = false
	overlay.visible = true
	if win:
		result_label.text = "PANEN SUKSES!\n\nKoin: %d\n\nTekan R untuk main lagi" % coins
	else:
		result_label.text = "Waktu habis!\n\nKoin: %d\n\nTekan R untuk main lagi" % coins
