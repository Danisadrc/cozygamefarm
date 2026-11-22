extends Node2D
## Villager — a Sunnyside human walking the village.
##
## Built from exactly the same 96x64 human sheets the player uses (body layer +
## hair layer, both offset by -6 so the feet sit on the node origin), which is
## what keeps the villagers the same size and proportions as the farmer instead
## of the stretched 48x48 woman sheet.
##
## Bu Sari stands by the pond and the other three stroll a short stretch of road.
## Every villager owns its own `[E]` interaction zone, so a wandering villager
## carries its prompt along with it. A small chat bubble bobs overhead.

const SHEET_DIR := "res://assets/characters/human/"
const CELL := Vector2i(96, 64)
# Same convention as world_player.gd: the cell is drawn centred, so -6 puts the
# art's feet (cell y 39) on the node origin.
const SPRITE_OFFSET := Vector2(0, -6)

const CHAT_TEX := "res://assets/ui/expression_chat.png"
const BUBBLE_Y := -30.0

var speaker_name := "Bu Sari"
var hair := "longhair"
var lines: Array = []

## Interaction id this villager's own zone reports (world_game maps it to the
## prompt text). Bu Sari is the one exception: her zone is baked into
## $Zones/VillagerZone, so she is created with build_zone = false.
var zone_id := "npc"
var build_zone := true

## Wandering villagers stroll within `radius` px of `home`; static ones stay put.
var wander := false
var home := Vector2.ZERO
var radius := 0.0
var speed := 18.0

var sprite: AnimatedSprite2D
var hair_sprite: AnimatedSprite2D
var zone: Area2D

var _marker: Sprite2D
var _target := Vector2.ZERO
var _pause := 1.0
var _line_i := -1


func _ready() -> void:
	z_index = 10
	if home == Vector2.ZERO:
		home = position

	sprite = AnimatedSprite2D.new()
	sprite.name = "Body"
	sprite.sprite_frames = _build_frames("base")
	sprite.offset = SPRITE_OFFSET
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play("idle")
	add_child(sprite)

	hair_sprite = AnimatedSprite2D.new()
	hair_sprite.name = "Hair"
	hair_sprite.sprite_frames = _build_frames(hair)
	hair_sprite.offset = SPRITE_OFFSET
	hair_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hair_sprite.play("idle")
	add_child(hair_sprite)

	_marker = Sprite2D.new()
	_marker.name = "Chat"
	_marker.texture = load(CHAT_TEX)
	_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_marker.position = Vector2(0, BUBBLE_Y)
	_marker.z_index = 11
	add_child(_marker)

	var tw := create_tween().set_loops()
	tw.tween_property(_marker, "position:y", BUBBLE_Y - 3.0, 0.9) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_marker, "position:y", BUBBLE_Y, 0.9) \
		.set_trans(Tween.TRANS_SINE)

	_build_zone()


## The interaction zone rides along with the villager: world_player scans the
## whole tree for Area2D nodes carrying the `interaction` meta.
func _build_zone() -> void:
	if not build_zone:
		return
	zone = Area2D.new()
	zone.name = "Zone"
	zone.position = Vector2(0, -6)
	zone.set_meta("interaction", zone_id)
	var col := CollisionShape2D.new()
	col.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(42, 30)
	col.shape = rect
	zone.add_child(col)
	add_child(zone)


## Where the floating prompt should sit: just above the chat bubble.
func prompt_anchor() -> Vector2:
	return global_position + Vector2(0, BUBBLE_Y - 4.0)


## Next flavour line, cycling so repeated chats are not identical.
func next_line() -> String:
	if lines.is_empty():
		return "..."
	_line_i = (_line_i + 1) % lines.size()
	return String(lines[_line_i])


func _build_frames(prefix: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_anim(frames, prefix, "idle", "idle/%s_idle_strip9.png", 9, 6.0)
	_add_anim(frames, prefix, "walk", "walking/%s_walk_strip8.png", 8, 9.0)
	return frames


func _add_anim(frames: SpriteFrames, prefix: String, anim: String,
		pattern: String, count: int, fps: float) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	var path := SHEET_DIR + (pattern % prefix)
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("villager sheet hilang: %s" % path)
		return
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * CELL.x, 0, CELL.x, CELL.y)
		frames.add_frame(anim, at)


# ================================================================ wandering

func _process(delta: float) -> void:
	if not wander:
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_pick_target()
		return

	var to := _target - position
	if to.length() < 1.5:
		_pause = randf_range(1.4, 3.8)
		_play("idle")
		return

	position += to.normalized() * speed * delta
	if absf(to.x) > 0.5:
		sprite.flip_h = to.x < 0.0
	_play("walk")
	# Keep the hair glued to the body frame, exactly like the player does.
	hair_sprite.flip_h = sprite.flip_h
	hair_sprite.frame = sprite.frame


func _pick_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(10.0, maxf(12.0, radius))
	_target = home + Vector2(cos(angle), sin(angle) * 0.6) * dist


func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
		hair_sprite.play(anim)
	hair_sprite.flip_h = sprite.flip_h
	hair_sprite.frame = sprite.frame
