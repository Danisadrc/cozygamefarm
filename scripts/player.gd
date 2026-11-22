extends CharacterBody2D

const SHEET_DIR := "res://assets/farm_kit/2 Standart/1 Character/"
const FRAME_SIZE := Vector2i(24, 24)
const SPEED := 85.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = _build_frames()
	sprite.offset = Vector2(0, -8)
	sprite.play("idle_down")


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_anim(frames, "idle_down", "D_Idle.png", 2, 4.0)
	_add_anim(frames, "idle_up", "U_Idle.png", 2, 4.0)
	_add_anim(frames, "idle_side", "S_Idle.png", 2, 4.0)
	_add_anim(frames, "walk_down", "D_Run.png", 4, 10.0)
	_add_anim(frames, "walk_up", "U_Run.png", 4, 10.0)
	_add_anim(frames, "walk_side", "S_Run.png", 4, 10.0)
	return frames


func _add_anim(frames: SpriteFrames, anim: String, file: String, count: int, fps: float) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	var tex: Texture2D = load(SHEET_DIR + file)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(anim, at)


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		dir.y += 1.0
	dir = dir.normalized()

	velocity = dir * SPEED
	move_and_slide()

	position.x = clampf(position.x, -235.0, 235.0)
	position.y = clampf(position.y, -165.0, 190.0)

	_animate(dir)


func _animate(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		if sprite.animation.begins_with("walk"):
			sprite.play(sprite.animation.replace("walk", "idle"))
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
