extends Node2D
## Livestock — chickens and a cow grazing on the grass east of the farm.
##
## Animals are pure visuals (no colliders) so they can never block the BFS
## paths or the player. Each one wanders gently around a small home patch.
## `[E] Rawat Ternak` tends it (happiness emote); on the next sleep a tended
## animal leaves one product (egg / milk) that `[E] Ambil ...` collects.

const CHICK_SHEET := "res://assets/decor/animals/spr_deco_chicken_01_strip4.png"
const COW_SHEET := "res://assets/decor/animals/spr_deco_cow_strip4.png"
const ALERT_TEX := "res://assets/ui/expression_alerted.png"
const HAPPY_DIR := "res://assets/ui/happiness_%02d.png"

const CELL := 32
const CELL_COLS := 4
const TEND_RADIUS := 26.0

var game: Node
var player: CharacterBody2D

## Each entry: kind, id, name, product_name, sprite, indicator, home, target,
## pause, tended, product, radius, speed.
var animals: Array = []

var _time := 0.0
var _emote_seq := 0


func setup(owner_game: Node, player_node: CharacterBody2D) -> void:
	game = owner_game
	player = player_node
	_spawn()


func _spawn() -> void:
	# Open grass between the farm fence (x≈400) and the pond (x≈644).
	_add_animal("chicken", "egg", "Ayam", "Telur",
		Vector2(536, 468), CHICK_SHEET, 1.0, -11.0, 20.0, 9.0)
	_add_animal("chicken", "egg", "Ayam", "Telur",
		Vector2(574, 486), CHICK_SHEET, 1.0, -11.0, 20.0, 9.0)
	_add_animal("cow", "milk", "Sapi", "Susu",
		Vector2(600, 452), COW_SHEET, 0.75, -16.0, 15.0, 6.0)


func _add_animal(kind: String, id: String, display: String, product: String,
		pos: Vector2, sheet: String, scale: float, offset_y: float,
		radius: float, speed: float) -> void:
	var spr := AnimatedSprite2D.new()
	spr.name = "%s_%d" % [display, animals.size()]
	spr.sprite_frames = _build_frames(sheet)
	spr.offset = Vector2(0, offset_y)
	spr.scale = Vector2(scale, scale)
	spr.position = pos
	spr.z_index = 9
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.play("idle")
	add_child(spr)

	var ind := Sprite2D.new()
	ind.name = "Alert"
	ind.texture = load(ALERT_TEX)
	ind.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ind.z_index = 11
	ind.visible = false
	add_child(ind)

	animals.append({
		"kind": kind,
		"id": id,
		"name": display,
		"product_name": product,
		"sprite": spr,
		"indicator": ind,
		"home": pos,
		"target": pos,
		"pause": randf_range(0.2, 1.6),
		"tended": false,
		"product": 0,
		"radius": radius,
		"speed": speed,
		"scale": scale,
		"offset_y": offset_y,
	})


## The decor strips are a single row of 4 frames (32×32 each) with the animal
## standing on its own little shadow. The same 4 frames serve as the walk cycle;
## a grazing animal barely moves, so one gentle bob is all it needs.
func _build_frames(sheet: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var tex: Texture2D = load(sheet)
	if tex == null:
		push_warning("livestock sheet hilang: %s" % sheet)
		return frames
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 3.0)
	frames.set_animation_loop("idle", true)
	for col in CELL_COLS:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(col * CELL, 0, CELL, CELL)
		frames.add_frame("idle", at)
	return frames


# ================================================================ wandering

func _process(delta: float) -> void:
	_time += delta
	for a in animals:
		var spr: AnimatedSprite2D = a["sprite"]
		if int(a["product"]) == 0:
			a["pause"] = float(a["pause"]) - delta
			if float(a["pause"]) <= 0.0:
				var to: Vector2 = Vector2(a["target"]) - spr.position
				if to.length() < 1.0:
					_pick_target(a)
					a["pause"] = randf_range(1.2, 3.4)
				else:
					spr.position += to.normalized() * float(a["speed"]) * delta
					spr.flip_h = to.x < 0.0
		var ind: Sprite2D = a["indicator"]
		ind.visible = int(a["product"]) > 0
		ind.position = spr.position + Vector2(0, -_head_lift(a) + sin(_time * 3.0))


func _pick_target(a: Dictionary) -> void:
	var angle := randf() * TAU
	var dist := randf() * float(a["radius"])
	a["target"] = Vector2(a["home"]) \
		+ Vector2(cos(angle), sin(angle) * 0.55) * dist


# ================================================================ interaction

func _nearest() -> Dictionary:
	if player == null:
		return {}
	var best: Dictionary = {}
	var best_d := TEND_RADIUS
	for a in animals:
		var spr: Node2D = a["sprite"]
		var d := player.global_position.distance_to(spr.global_position)
		if d <= best_d:
			best_d = d
			best = a
	return best


## World position the prompt box should float above (nearest animal's head).
func prompt_anchor() -> Vector2:
	var a := _nearest()
	if a.is_empty():
		return Vector2.INF
	var spr: Node2D = a["sprite"]
	return spr.global_position + Vector2(0, -_head_lift(a))


func _head_lift(a: Dictionary) -> float:
	# Sprite cells are 32px and centred on `offset_y`; float the prompt just
	# above the top edge of the cell, whatever the animal's scale.
	return -float(a["offset_y"]) + 16.0 * float(a["scale"]) + 4.0


## Floating prompt text for the closest animal, or "" when none is in reach.
func prompt_for_player() -> String:
	var a := _nearest()
	if a.is_empty():
		return ""
	if int(a["product"]) > 0:
		return "[E] Ambil %s" % String(a["product_name"])
	return "[E] Rawat Ternak"


## E press with no area zone underfoot. Returns true if an animal was handled.
func try_interact() -> bool:
	var a := _nearest()
	if a.is_empty():
		return false
	if int(a["product"]) > 0:
		var label := String(a["product_name"])
		if GameState.add_item(String(a["id"]), label):
			a["product"] = 0
			a["pause"] = 0.6
			_emote(a, 4)
			if game != null and game.hud != null:
				game.hud.toast("+1 %s dari %s" % [label, String(a["name"])], 1.6)
			GameState.quest_event(String(a["id"]), 1)
		else:
			if game != null and game.hud != null:
				game.hud.toast("Tas penuh! Jual hasil panen dulu.")
		return true

	if not bool(a["tended"]):
		a["tended"] = true
		_emote(a, 3)
		if game != null and game.hud != null:
			game.hud.toast("%s senang dirawat! Besok ia menghasilkan %s."
				% [String(a["name"]), String(a["product_name"])], 2.4)
	else:
		_emote(a, 1)
		if game != null and game.hud != null:
			game.hud.toast("%s sudah dirawat hari ini. Tidur untuk memanen." % String(a["name"]), 2.0)
	return true


## Sleep hook: every tended animal leaves one product for tomorrow.
func on_day_changed() -> int:
	var produced := 0
	for a in animals:
		if bool(a["tended"]):
			a["tended"] = false
			a["product"] = 1
			a["pause"] = 0.4
			produced += 1
	return produced


func _emote(a: Dictionary, big: int = 0) -> void:
	var spr: Node2D = a["sprite"]
	_emote_seq += 1
	var idx: int = big if big > 0 else _emote_seq
	var pic := Sprite2D.new()
	pic.texture = load(HAPPY_DIR % ((idx - 1) % 4 + 1))
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.z_index = 12
	pic.position = spr.position + Vector2(0, -_head_lift(a) + 2.0)
	add_child(pic)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pic, "position:y", pic.position.y - 10.0, 0.85)
	tw.tween_property(pic, "modulate:a", 0.0, 0.85)
	tw.chain().tween_callback(pic.queue_free)