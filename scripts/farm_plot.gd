extends Node2D

signal harvested(amount: int)

const PLANTS_TEX := preload("res://assets/plants/PNG/Plants.png")
const TILES_TEX := preload("res://assets/farm_kit/2 Standart/5 Tiles/TileSet.png")

const STAGE_RECTS := [
	Rect2(12, 416, 11, 14),
	Rect2(37, 410, 21, 20),
	Rect2(67, 396, 25, 34),
]
const STAGE_TIMES := [3.5, 8.0]
const REWARD := 12

enum State { EMPTY, GROWING, READY }

var plot_size := 56.0
var state: State = State.EMPTY
var stage := 0
var grow_time := 0.0

var _crop: Sprite2D
var _arrow: Label
var _pulse: Tween


func _ready() -> void:
	_build_visuals()
	_refresh()


func _build_visuals() -> void:
	var soil := Panel.new()
	soil.size = Vector2(plot_size, plot_size)
	soil.position = Vector2(-plot_size * 0.5, -plot_size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("4a2f1b")
	sb.border_color = Color("8a5a34")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	soil.add_theme_stylebox_override("panel", sb)
	add_child(soil)

	var tex_rect := TextureRect.new()
	tex_rect.texture = _atlas(TILES_TEX, Rect2(8, 0, 8, 8))
	tex_rect.stretch_mode = TextureRect.STRETCH_TILE
	tex_rect.position = Vector2(3, 3)
	tex_rect.size = Vector2(plot_size - 6.0, plot_size - 6.0)
	tex_rect.modulate = Color(1, 1, 1, 0.85)
	soil.add_child(tex_rect)

	_crop = Sprite2D.new()
	_crop.position = Vector2(0, -plot_size * 0.5)
	_crop.scale = Vector2(1.35, 1.35)
	add_child(_crop)

	_arrow = Label.new()
	_arrow.text = "E"
	_arrow.add_theme_font_size_override("font_size", 12)
	_arrow.add_theme_color_override("font_color", Color("ffe36e"))
	_arrow.add_theme_color_override("font_outline_color", Color("3a2410"))
	_arrow.add_theme_constant_override("outline_size", 4)
	_arrow.position = Vector2(-6, -plot_size - 22.0)
	_arrow.visible = false
	add_child(_arrow)


func _process(delta: float) -> void:
	if state != State.GROWING:
		return
	grow_time += delta
	if stage == 0 and grow_time >= STAGE_TIMES[0]:
		stage = 1
		_refresh()
	if stage == 1 and grow_time >= STAGE_TIMES[1]:
		stage = 2
		state = State.READY
		_refresh()


func can_interact() -> bool:
	return state != State.GROWING


func is_ready() -> bool:
	return state == State.READY


func interact() -> void:
	match state:
		State.EMPTY:
			state = State.GROWING
			stage = 0
			grow_time = 0.0
			_refresh()
		State.READY:
			state = State.EMPTY
			stage = 0
			_refresh()
			harvested.emit(REWARD)


func _refresh() -> void:
	if _pulse and _pulse.is_valid():
		_pulse.kill()

	if state == State.EMPTY:
		_crop.visible = false
		_arrow.visible = false
		return

	_crop.visible = true
	_crop.texture = _atlas(PLANTS_TEX, STAGE_RECTS[stage])
	_crop.scale = Vector2(1.35, 1.35)
	_arrow.visible = state == State.READY

	if state == State.READY:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_crop, "scale", Vector2(1.5, 1.5), 0.6)
		_pulse.tween_property(_crop, "scale", Vector2(1.35, 1.35), 0.6)


func _atlas(tex: Texture2D, rect: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = rect
	return at
