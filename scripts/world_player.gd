extends CharacterBody2D
## Player controller for scenes/world.tscn.
##
## Two stacked AnimatedSprite2D nodes make up the character: $Sprite is the body
## and $Hair is a pure overlay drawn from the matching hair sheet. Both are
## built from the Sunnyside human sheets (96x64 cells with the 16x16 art
## centred), and the hair is kept in lockstep with the body - same animation
## name, same frame index, same flip - so the two can never drift apart.
##
## The controller also owns facing, the 16x16 farm highlight, the dig / water
## action animations, and forwards E / Space / clicks to the world game script.

const SHEET_DIR := "res://assets/characters/human/"
const CELL := Vector2i(96, 64)
const SPEED := 70.0
const TILE := 16

# In a 96x64 cell the art sits at x 43..53 (centre 48) and y 23..38.
# A centred Sprite2D draws the cell centred on its origin, so shifting by
# -6 on Y puts the art's feet exactly on the node origin.
const SPRITE_OFFSET := Vector2(0, -6)

const HAIR := "shorthair"

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hair: AnimatedSprite2D = $Hair
@onready var _soil: TileMapLayer = get_parent().get_node_or_null("FarmSoilLayer") as TileMapLayer
@onready var _game: Node = get_parent()

var current_zone: String = ""
var facing := Vector2i.DOWN
var input_locked := false

var _zones: Array[Area2D] = []
var _action_timer := 0.0
var _tool: AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = _build_frames("base")
	sprite.offset = SPRITE_OFFSET
	sprite.play("idle_down")

	hair.sprite_frames = _build_frames(HAIR)
	hair.offset = SPRITE_OFFSET
	hair.play("idle_down")

	_tool = AnimatedSprite2D.new()
	_tool.name = "Tool"
	_tool.sprite_frames = _build_tool_frames()
	_tool.offset = SPRITE_OFFSET
	_tool.visible = false
	add_child(_tool)

	_collect_zones()


func _collect_zones() -> void:
	var zones := get_parent().get_node_or_null("Zones")
	if zones == null:
		return
	for z in zones.get_children():
		if z is Area2D:
			_zones.append(z)


func _build_frames(prefix: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_anim(frames, prefix, "idle_down", "idle/%s_idle_strip9.png", 9, 6.0)
	_add_anim(frames, prefix, "walk_down", "walking/%s_walk_strip8.png", 8, 9.0)
	_add_anim(frames, prefix, "idle_up", "idle/%s_idle_strip9.png", 9, 6.0)
	_add_anim(frames, prefix, "walk_up", "walking/%s_walk_strip8.png", 8, 9.0)
	_add_anim(frames, prefix, "idle_side", "idle/%s_idle_strip9.png", 9, 6.0)
	_add_anim(frames, prefix, "walk_side", "walking/%s_walk_strip8.png", 8, 9.0)
	_add_anim(frames, prefix, "dig", "dig/%s_dig_strip13.png", 13, 18.0, false)
	_add_anim(frames, prefix, "water", "watering/%s_watering_strip5.png", 5, 12.0, false)
	return frames


func _build_tool_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_anim(frames, "tools", "dig", "dig/%s_dig_strip13.png", 13, 18.0, false)
	_add_anim(frames, "tools", "water", "watering/%s_watering_strip5.png", 5, 12.0, false)
	return frames


func _add_anim(frames: SpriteFrames, prefix: String, anim: String,
		pattern: String, count: int, fps: float, loop := true) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var tex: Texture2D = load(SHEET_DIR + (pattern % prefix))
	if tex == null:
		push_warning("sheet hilang: %s" % (pattern % prefix))
		return
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * CELL.x, 0, CELL.x, CELL.y)
		frames.add_frame(anim, at)


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not input_locked and _action_timer <= 0.0:
		dir = _read_direction()
		if dir != Vector2.ZERO:
			_update_facing(dir)

	velocity = dir * SPEED
	move_and_slide()

	if _action_timer > 0.0:
		_action_timer -= delta
		if _action_timer <= 0.0:
			_finish_action()
	else:
		_animate(dir)

	_sync_hair()
	_update_zone()
	queue_redraw()


func _read_direction() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		dir.y += 1.0
	return dir.normalized()


func _update_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		facing = Vector2i(signi(int(signf(dir.x))), 0)
	elif dir.y != 0.0:
		facing = Vector2i(0, signi(int(signf(dir.y))))


func _animate(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		if sprite.animation.begins_with("walk"):
			sprite.play(_idle_anim())
		return

	if absf(dir.x) > absf(dir.y):
		sprite.flip_h = dir.x < 0.0
		sprite.play("walk_side")
	elif dir.y < 0.0:
		sprite.flip_h = false
		sprite.play("walk_up")
	else:
		sprite.flip_h = false
		sprite.play("walk_down")


func _idle_anim() -> String:
	if facing == Vector2i.UP:
		return "idle_up"
	if facing.x != 0:
		return "idle_side"
	return "idle_down"


## Plays a one-shot farm action and freezes movement for its duration.
func play_action(kind: String) -> void:
	if _action_timer > 0.0:
		return
	if not sprite.sprite_frames.has_animation(kind):
		return
	var count := sprite.sprite_frames.get_frame_count(kind)
	var fps := maxf(1.0, sprite.sprite_frames.get_animation_speed(kind))
	_action_timer = float(count) / fps
	sprite.play(kind)
	hair.play(kind)
	_tool.play(kind)
	_tool.visible = true
	sprite.flip_h = facing.x < 0
	hair.flip_h = sprite.flip_h
	_tool.flip_h = sprite.flip_h


func _finish_action() -> void:
	_action_timer = 0.0
	_tool.visible = false
	sprite.flip_h = facing.x < 0
	sprite.play(_idle_anim())
	hair.play(_idle_anim())
	hair.flip_h = sprite.flip_h


func is_busy() -> bool:
	return _action_timer > 0.0


## Keeps the hair exactly on top of the body: same animation, same frame, same
## facing. Called every physics tick so a one-frame desync is impossible.
func _sync_hair() -> void:
	hair.flip_h = sprite.flip_h
	if hair.animation != sprite.animation:
		hair.play(sprite.animation)
	hair.frame = sprite.frame
	hair.speed_scale = sprite.speed_scale
	if _tool.visible:
		_tool.flip_h = sprite.flip_h
		_tool.frame = sprite.frame


func _update_zone() -> void:
	var found := ""
	for z in _zones:
		var col := z.get_node_or_null("Shape") as CollisionShape2D
		if col == null or col.shape == null:
			continue
		var rect: Vector2 = (col.shape as RectangleShape2D).size
		var box := Rect2(z.global_position - rect * 0.5, rect)
		if box.has_point(global_position):
			found = String(z.get_meta("interaction", ""))
			break
	if found != current_zone:
		current_zone = found
		if _game != null and _game.has_method("on_zone_changed"):
			_game.on_zone_changed(current_zone)


## The farm tile directly in front of the player's feet.
func front_cell() -> Vector2i:
	if _soil == null:
		return Vector2i.ZERO
	var cell := _soil.local_to_map(_soil.to_local(global_position))
	return cell + facing


func _draw() -> void:
	if input_locked or _soil == null:
		return
	var cell := front_cell()
	if _soil.get_cell_source_id(cell) == -1:
		return
	var rect := Rect2(Vector2(cell.x * TILE, cell.y * TILE) - global_position,
		Vector2(TILE, TILE))
	rect.position = rect.position.round()
	draw_rect(rect, Color(1.0, 0.96, 0.55, 0.16), true)
	draw_rect(rect, Color(1.0, 0.9, 0.4, 0.85), false, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if input_locked:
			return
		match event.keycode:
			KEY_E:
				_game.interact(current_zone)
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				_game.use_tool(front_cell())
				get_viewport().set_input_as_handled()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				_game.select_slot(event.keycode - KEY_1)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if input_locked:
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _action_timer <= 0.0:
					_game.mouse_action(get_global_mouse_position())
			MOUSE_BUTTON_WHEEL_UP:
				_game.cycle_slot(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_game.cycle_slot(1)
