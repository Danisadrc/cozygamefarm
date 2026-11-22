extends Control
## Title screen — a painted Sunnyside village with the game's name and the two
## ways in: start a fresh save, or quit.
##
## The backdrop is drawn procedurally (sky gradient, sun, clouds, hills, grass
## and the road) and dressed with the same house / cottage / pond / fence / tree
## art the world scene uses, so the menu and the game look like one place.
## Everything is built in code: the .tscn only holds this full-rect Control.

const VIEW := Vector2(640, 360)
const WORLD_SCENE := "res://scenes/world.tscn"
const BOX_DIR := "res://assets/ui/9slice_box_white/"

const HOUSE_TEX := "res://assets/generated/house.png"
const COTTAGE_TEX := "res://assets/generated/cottage_green.png"
const POND_TEX := "res://assets/generated/pond.png"
const TREE_TEX := "res://assets/decor/plants/spr_deco_tree_01_strip4.png"
const PINE_TEX := "res://assets/decor/plants/spr_deco_tree_02_strip4.png"
const CHICK_TEX := "res://assets/decor/animals/spr_deco_chicken_01_strip4.png"

const CREAM := Color(0.98, 0.94, 0.83)
const GOLD := Color(0.99, 0.84, 0.42)
const MUTED := Color(0.86, 0.80, 0.68)
const OUTLINE := Color(0.11, 0.07, 0.04, 0.95)

## Horizon: everything above is sky, everything below is grass.
const HORIZON := 246.0
const ROAD_TOP := 300.0
const ROAD_H := 38.0

var _start_button: Button
var _quit_button: Button
var _box_cache: Dictionary = {}
var _seed := 1
var _starting := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Freeze the world clock while the menu is up; "Mulai Bermain" calls
	# GameState.reset() which sets time_scale back to 1.0.
	GameState.time_scale = 0.0
	get_tree().paused = false
	_build_village()
	_build_text()
	_build_buttons()
	_start_button.grab_focus()


# ================================================================ backdrop

## Static props, placed so they read as the village from the world scene: the
## farmhouse on the left, a cottage and a fenced garden in the middle, trees at
## the edges and the pond in the bottom-right corner.
func _build_village() -> void:
	_add_sprite(HOUSE_TEX, Vector2(58, 146))
	_add_sprite(COTTAGE_TEX, Vector2(390, 142))
	_add_sprite(POND_TEX, Vector2(470, 264))

	# First frame of each 4-frame decor strip, kept clear of the menu buttons.
	_add_sprite(TREE_TEX, Vector2(2, 198), 2.0, Rect2(0, 0, 32, 34))
	_add_sprite(TREE_TEX, Vector2(586, 184), 2.0, Rect2(0, 0, 32, 34))
	_add_sprite(PINE_TEX, Vector2(520, 150), 2.0, Rect2(0, 0, 28, 43))
	_add_sprite(CHICK_TEX, Vector2(140, 264), 1.0, Rect2(0, 0, 32, 32))
	_add_sprite(CHICK_TEX, Vector2(172, 276), 1.0, Rect2(0, 0, 32, 32))

	_add_leaves()


func _add_sprite(path: String, pos: Vector2, scale: float = 1.0,
		region: Rect2 = Rect2()) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		return
	if region.size != Vector2.ZERO:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = region
		tex = at
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.position = pos
	spr.scale = Vector2(scale, scale)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)


## A handful of leaves drifting down over the menu, so the screen is never
## completely still.
func _add_leaves() -> void:
	var p := CPUParticles2D.new()
	p.name = "Leaves"
	p.texture = _leaf_texture()
	p.position = Vector2(VIEW.x * 0.5, 20)
	p.z_index = 3
	p.amount = 30
	p.lifetime = 10.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(VIEW.x * 0.5, 10)
	p.direction = Vector2(0, 1)
	p.spread = 22.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector2(7, 13)
	p.angular_velocity_min = -80.0
	p.angular_velocity_max = 80.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.86, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.95),
		Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.0),
	])
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)


func _leaf_texture() -> ImageTexture:
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color8(226, 132, 62)
	for p in [Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
			Vector2i(2, 2), Vector2i(2, 3)]:
		img.set_pixelv(p, body)
	img.set_pixelv(Vector2i(3, 2), Color8(170, 84, 40))
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	_seed = 20240517
	_draw_sky()
	_draw_sun()
	_draw_clouds()
	_draw_hills()
	_draw_ground()
	_draw_road()
	_draw_title_rule()


func _draw_sky() -> void:
	var top := Color8(108, 176, 226)
	var mid := Color8(163, 214, 239)
	var low := Color8(255, 233, 191)
	var y := 0
	while y < int(HORIZON):
		var t := float(y) / HORIZON
		var c: Color
		if t < 0.55:
			c = top.lerp(mid, t / 0.55)
		else:
			c = mid.lerp(low, (t - 0.55) / 0.45)
		draw_rect(Rect2(0, y, VIEW.x, 1), c)
		y += 1


func _draw_sun() -> void:
	var centre := Vector2(500, 64)
	draw_circle(centre, 34.0, Color(1.0, 0.93, 0.70, 0.16))
	draw_circle(centre, 25.0, Color(1.0, 0.95, 0.78, 0.32))
	draw_circle(centre, 18.0, Color8(255, 241, 190))


func _draw_clouds() -> void:
	_cloud(Vector2(96, 62), 1.0)
	_cloud(Vector2(330, 38), 0.8)
	_cloud(Vector2(548, 104), 0.65)


func _cloud(pos: Vector2, s: float) -> void:
	var white := Color(1, 1, 1, 0.88)
	var shade := Color(0.86, 0.92, 0.97, 0.88)
	draw_rect(Rect2(pos.x, pos.y + 4 * s, 48 * s, 9 * s), shade)
	draw_rect(Rect2(pos.x + 6 * s, pos.y, 34 * s, 10 * s), white)
	draw_rect(Rect2(pos.x + 16 * s, pos.y - 7 * s, 18 * s, 9 * s), white)
	draw_rect(Rect2(pos.x + 2 * s, pos.y + 4 * s, 42 * s, 7 * s), white)


func _draw_hills() -> void:
	var far := Color8(126, 166, 128)
	var near := Color8(104, 154, 110)
	draw_rect(Rect2(0, 210, VIEW.x, 40), far)
	for i in 9:
		draw_circle(Vector2(i * 78.0 + 20.0, 212.0), 34.0, far)
	draw_rect(Rect2(0, 226, VIEW.x, 26), near)
	for i in 8:
		draw_circle(Vector2(i * 92.0 + 54.0, 230.0), 30.0, near)


func _draw_ground() -> void:
	var grass := Color8(126, 194, 104)
	var grass_dark := Color8(112, 178, 92)
	var grass_light := Color8(146, 210, 120)
	draw_rect(Rect2(0, HORIZON, VIEW.x, VIEW.y - HORIZON), grass)
	draw_rect(Rect2(0, HORIZON, VIEW.x, 2), grass_light)

	# Deterministic speckles so the field has texture without shimmering.
	for i in 220:
		var x := floorf(_rand01() * VIEW.x)
		var y := HORIZON + 4.0 + floorf(_rand01() * (VIEW.y - HORIZON - 6.0))
		var c := grass_dark if _rand01() < 0.6 else grass_light
		draw_rect(Rect2(x, y, 2, 1), c)

	# Tiny flowers.
	for i in 14:
		var x := floorf(_rand01() * VIEW.x)
		var y := HORIZON + 8.0 + floorf(_rand01() * 44.0)
		draw_rect(Rect2(x, y, 1, 1), Color8(250, 244, 214))
		draw_rect(Rect2(x + 1, y + 1, 1, 1), Color8(236, 196, 92))


func _draw_road() -> void:
	var road := Color8(228, 176, 118)
	var edge := Color8(203, 149, 98)
	draw_rect(Rect2(0, ROAD_TOP, VIEW.x, ROAD_H), road)
	draw_rect(Rect2(0, ROAD_TOP, VIEW.x, 2), edge)
	draw_rect(Rect2(0, ROAD_TOP + ROAD_H - 2, VIEW.x, 2), edge)

	# Door path from the farmhouse down to the road.
	draw_rect(Rect2(104, 252, 18, ROAD_TOP - 252), road)

	# Pebbles.
	for i in 40:
		var x := floorf(_rand01() * VIEW.x)
		var y := ROAD_TOP + 3.0 + floorf(_rand01() * (ROAD_H - 6.0))
		draw_rect(Rect2(x, y, 2, 1), edge)


## Thin gold rule under the title, so the text has a base to sit on.
func _draw_title_rule() -> void:
	draw_rect(Rect2(236, 106, 168, 2), Color(0.99, 0.84, 0.42, 0.9))
	draw_rect(Rect2(248, 109, 144, 1), Color(0.99, 0.84, 0.42, 0.45))


# ================================================================ text + buttons

func _build_text() -> void:
	var shadow := _label("COZY VALLEY", 40, Color(0.16, 0.09, 0.05, 0.55))
	shadow.position = Vector2(3, 52)
	shadow.size = Vector2(VIEW.x, 52)
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(shadow)

	var title := _label("COZY VALLEY", 40, CREAM)
	title.position = Vector2(0, 49)
	title.size = Vector2(VIEW.x, 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", OUTLINE)
	title.add_theme_constant_override("outline_size", 10)
	add_child(title)

	var sub := _label("Desa kecil di lembah Sunnyside", 11, MUTED)
	sub.position = Vector2(0, 116)
	sub.size = Vector2(VIEW.x, 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", OUTLINE)
	sub.add_theme_constant_override("outline_size", 4)
	add_child(sub)

	# Soft scrim so the buttons stay readable over the grass and road.
	var scrim := ColorRect.new()
	scrim.position = Vector2(0, 246)
	scrim.size = Vector2(VIEW.x, VIEW.y - 246)
	scrim.color = Color(0.05, 0.04, 0.03, 0.34)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


func _build_buttons() -> void:
	_start_button = _menu_button("Mulai Bermain")
	_start_button.position = Vector2(VIEW.x * 0.5 - 90.0, 258)
	_start_button.size = Vector2(180, 34)
	_start_button.pressed.connect(_on_start_pressed)
	add_child(_start_button)

	_quit_button = _menu_button("Keluar")
	_quit_button.position = Vector2(VIEW.x * 0.5 - 90.0, 300)
	_quit_button.size = Vector2(180, 30)
	_quit_button.pressed.connect(_on_quit_pressed)
	add_child(_quit_button)

	var hint := _label("WASD / Panah: jalan   •   E: aksi   •   Esc: jeda", 9, MUTED)
	hint.position = Vector2(0, 338)
	hint.size = Vector2(VIEW.x, 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_outline_color", OUTLINE)
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)


func _menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_ALL
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", CREAM)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.2, 0.14, 0.08))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_outline_color", OUTLINE)
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_stylebox_override("normal", _button_box("dt_"))
	btn.add_theme_stylebox_override("hover", _button_box("lt_"))
	btn.add_theme_stylebox_override("pressed", _button_box("w_"))
	btn.add_theme_stylebox_override("focus", _button_box("w_"))
	return btn


func _button_box(prefix: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _compose_box(prefix)
	style.texture_margin_left = 3
	style.texture_margin_top = 3
	style.texture_margin_right = 3
	style.texture_margin_bottom = 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


## Rebuilds the 3x3 Sunnyside box art into one 9x9 texture (same technique the
## HUD uses for its panels).
func _compose_box(prefix: String) -> Texture2D:
	if _box_cache.has(prefix):
		return _box_cache[prefix]
	var layout := [
		["tl", 0, 0], ["tc", 1, 0], ["tr", 2, 0],
		["lc", 0, 1], ["c", 1, 1], ["rc", 2, 1],
		["bl", 0, 2], ["bc", 1, 2], ["br", 2, 2],
	]
	var full := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
	full.fill(Color(0, 0, 0, 0))
	for e in layout:
		var tex: Texture2D = load("%s%sbox_9slice_%s.png" % [BOX_DIR, prefix, e[0]])
		if tex == null:
			continue
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		full.blit_rect(img, Rect2i(0, 0, 3, 3), Vector2i(int(e[1]) * 3, int(e[2]) * 3))
	var out := ImageTexture.create_from_image(full)
	_box_cache[prefix] = out
	return out


func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _rand01() -> float:
	_seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF
	return float(_seed) / 2147483647.0


# ================================================================ actions

func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true
	_start_button.disabled = true
	_quit_button.disabled = true
	# Fresh save: gold, day, clock, stamina, hotbar and the three quests.
	GameState.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
