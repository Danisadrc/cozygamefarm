extends Node2D
## Villager — a Sunnyside human sprite standing on the path near the pond.
##
## Purely decorative plus the `[E] Bicara` zone handled by world_game. The
## sprite is built at runtime from the 4-frame idle strip and scaled down so it
## matches the 16px player. A small chat bubble bobs overhead to advertise that
## the villager can be talked to.

const SHEET_DIR := "res://assets/villagers/4 Woman/"
const CELL := 48
const SCALE := 0.55
# In a 48x48 cell the art's feet touch y=47, so -23 puts them on the node origin.
const SPRITE_OFFSET := Vector2(0, -23)

const CHAT_TEX := "res://assets/ui/expression_chat.png"

var speaker_name := "Bu Sari"

var sprite: AnimatedSprite2D
var _marker: Sprite2D


func _ready() -> void:
	z_index = 10

	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = _build_frames()
	sprite.offset = SPRITE_OFFSET
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play("idle")
	add_child(sprite)

	_marker = Sprite2D.new()
	_marker.name = "Chat"
	_marker.texture = load(CHAT_TEX)
	_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_marker.position = Vector2(0, -30)
	_marker.z_index = 11
	add_child(_marker)

	var tw := create_tween().set_loops()
	tw.tween_property(_marker, "position:y", -33.0, 0.9) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_marker, "position:y", -30.0, 0.9) \
		.set_trans(Tween.TRANS_SINE)


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_strip(frames, "idle", "Woman_idle.png", 4, 5.0)
	return frames


func _add_strip(frames: SpriteFrames, anim: String, file: String,
		count: int, fps: float) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	var tex: Texture2D = load(SHEET_DIR + file)
	if tex == null:
		push_warning("villager sheet hilang: %s" % file)
		return
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * CELL, 0, CELL, CELL)
		frames.add_frame(anim, at)