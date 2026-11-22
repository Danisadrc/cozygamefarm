extends Node2D
## FarmManager — Farming system for FarmSoilLayer.
##
## Attached as a child of World (or as autoload). Manages per-tile crop state,
## tool actions (till/plant/water/harvest), growth on day change, and the
## visual CropSprite nodes that track each planted cell.
##
## All crop textures come from DataRegistry (assets/crops/).
## All gold / day / inventory state goes through GameState (autoload).

const TILE := 16
const MAX_STAGE := 5   # stages _00.._05  →  5 growth steps to mature

# ---------------------------------------------------------------- signals

signal farm_changed          # emitted whenever any tile state mutates
signal crop_planted(cell: Vector2i, crop_id: String)
signal crop_harvested(cell: Vector2i, crop_id: String, qty: int)
signal crop_grown(cell: Vector2i, crop_id: String, new_stage: int)

# ---------------------------------------------------------------- node refs

var world: Node2D
var soil: TileMapLayer
var player: CharacterBody2D
var overlay: Node2D
var hud                     # untyped; calls optional methods guarded by has_method

# ---------------------------------------------------------------- tile state
# Dictionary<Vector2i, Dictionary>:
#   {"tilled": bool, "watered": bool, "crop": String, "stage": int}
var _farm: Dictionary = {}

# ---------------------------------------------------------------- visual nodes
var _crop_nodes: Dictionary = {}     # Vector2i -> Sprite2D
var _texture_cache: Dictionary = {}  # String (path) -> Texture2D


# ================================================================ setup

func setup(world_node: Node2D, soil_layer: TileMapLayer, player_node: CharacterBody2D) -> void:
	world = world_node
	soil = soil_layer
	player = player_node
	_create_overlay()


func set_hud(hud_ref) -> void:
	hud = hud_ref


func _create_overlay() -> void:
	if overlay != null:
		return
	overlay = Node2D.new()
	overlay.name = "FarmOverlay"
	overlay.z_index = 1
	world.add_child(overlay)
	overlay.draw.connect(_draw_overlay)


# ================================================================ helpers

func _tile(cell: Vector2i) -> Dictionary:
	return _farm.get(cell, {})


func _is_tilled(cell: Vector2i) -> bool:
	return _farm.has(cell) and bool(_farm[cell].get("tilled", false))


func _is_watered(cell: Vector2i) -> bool:
	return _farm.has(cell) and bool(_farm[cell].get("watered", false))


func _crop_id(cell: Vector2i) -> String:
	if not _farm.has(cell):
		return ""
	return String(_farm[cell].get("crop", ""))


func _stage(cell: Vector2i) -> int:
	if not _farm.has(cell):
		return 0
	return int(_farm[cell].get("stage", 0))


func _is_mature(cell: Vector2i) -> bool:
	return _crop_id(cell) != "" and _stage(cell) >= MAX_STAGE


# ================================================================ tool API
# Called by world_game.gd on Space / click.

## Dispatch a tool action on `cell`. `item` is the currently selected hotbar slot.
func use_tool(cell: Vector2i, item: Dictionary) -> void:
	if soil == null:
		return
	if soil.get_cell_source_id(cell) == -1:
		return   # cell is not part of the farm soil layer
	if _is_mature(cell) and String(item.get("type", "")) != "seed":
		harvest(cell)
		return
	match String(item.get("type", "")):
		"tool":
			if String(item.get("tool", "")) == "hoe":
				till(cell)
			else:
				water(cell)
		"seed":
			plant(cell, item)
		"produce":
			harvest(cell)


# ================================================================ actions

func till(cell: Vector2i) -> void:
	if _is_tilled(cell):
		_notify("Tanah ini sudah dicangkul.")
		return
	_farm[cell] = {"tilled": true, "watered": false, "crop": "", "stage": 0}
	if player and player.has_method("play_action"):
		player.play_action("dig")
	overlay.queue_redraw()
	farm_changed.emit()


func water(cell: Vector2i) -> void:
	if not _is_tilled(cell):
		_notify("Cangkul tanahnya dulu.")
		return
	if _is_watered(cell):
		_notify("Tanah ini sudah disiram hari ini.")
		return
	_farm[cell]["watered"] = true
	if player and player.has_method("play_action"):
		player.play_action("water")
	overlay.queue_redraw()
	farm_changed.emit()
	if _crop_id(cell) == "":
		_notify("Tanah disiram. Siap ditanami.")


func plant(cell: Vector2i, item: Dictionary) -> void:
	if not _is_tilled(cell):
		_notify("Cangkul tanahnya dulu.")
		return
	if _crop_id(cell) != "":
		_notify("Sudah ada tanaman di sini.")
		return
	var crop := String(item.get("crop", ""))
	if crop == "" or int(item.get("count", 0)) <= 0:
		_notify("Bibit habis. Beli lagi di pedagang.")
		return
	# consume one seed from the hotbar slot
	item["count"] = int(item["count"]) - 1
	_farm[cell]["crop"] = crop
	_farm[cell]["stage"] = 0
	_spawn_crop(cell)
	overlay.queue_redraw()
	_notify("%s ditanam." % DataRegistry.crop_name(crop))
	if hud and hud.has_method("refresh_hotbar"):
		hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	crop_planted.emit(cell, crop)
	farm_changed.emit()


func harvest(cell: Vector2i) -> void:
	var crop := _crop_id(cell)
	if crop == "":
		_notify("Tidak ada tanaman di sini.")
		return
	if _stage(cell) < MAX_STAGE:
		_notify("%s belum siap panen (%d/%d)." % [
			DataRegistry.crop_name(crop), _stage(cell), MAX_STAGE])
		return
	if not GameState.add_produce(crop, 1):
		_notify("Tas panen penuh! Jual hasilnya dulu.")
		return
	_farm[cell]["crop"] = ""
	_farm[cell]["stage"] = 0
	_farm[cell]["watered"] = false
	_remove_crop_node(cell)
	overlay.queue_redraw()
	_notify("+1 %s" % DataRegistry.crop_name(crop))
	if hud and hud.has_method("refresh_hotbar"):
		hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	crop_harvested.emit(cell, crop, 1)
	farm_changed.emit()


# ================================================================ day cycle
# Called by world_game.gd on sleep.

## Advance all watered crops by one stage, then reset watered flags.
## Returns the number of crops that grew.
func on_day_changed() -> int:
	var grown := 0
	for key in _farm.keys():
		var tile: Dictionary = _farm[key]
		if not bool(tile.get("tilled", false)):
			continue
		if String(tile.get("crop", "")) != "" and bool(tile.get("watered", false)) \
				and int(tile.get("stage", 0)) < MAX_STAGE:
			tile["stage"] = int(tile["stage"]) + 1
			grown += 1
			_update_crop_visual(key)
			crop_grown.emit(key, String(tile["crop"]), int(tile["stage"]))
		tile["watered"] = false
	overlay.queue_redraw()
	farm_changed.emit()
	return grown


# ================================================================ visuals

func _spawn_crop(cell: Vector2i) -> void:
	var node: Sprite2D = _crop_nodes.get(cell)
	if node == null:
		node = Sprite2D.new()
		node.name = "CropSprite"
		node.z_index = 2
		world.add_child(node)
		_crop_nodes[cell] = node
	_apply_crop_visual(node, cell, _crop_id(cell), _stage(cell))


func _update_crop_visual(cell: Vector2i) -> void:
	var node: Sprite2D = _crop_nodes.get(cell)
	if node == null:
		_spawn_crop(cell)
		return
	_apply_crop_visual(node, cell, _crop_id(cell), _stage(cell))


func _apply_crop_visual(node: Sprite2D, cell: Vector2i, crop: String, stage: int) -> void:
	var tex := _crop_texture(crop, stage)
	if tex == null:
		return
	node.texture = tex
	# Anchor: bottom-center of the sprite sits on the bottom-center of the tile.
	node.position = Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE)
	node.offset = Vector2(0, -tex.get_height() * 0.5 + 4)


func _remove_crop_node(cell: Vector2i) -> void:
	var node: Sprite2D = _crop_nodes.get(cell)
	if node != null:
		node.queue_free()
		_crop_nodes.erase(cell)


func _crop_texture(crop: String, stage: int) -> Texture2D:
	var tex: Texture2D = DataRegistry.crop_stage_texture(crop, stage)
	return tex


# ================================================================ overlay draw

func _draw_overlay() -> void:
	if overlay == null:
		return
	for key in _farm.keys():
		var tile: Dictionary = _farm[key]
		if not bool(tile.get("tilled", false)):
			continue
		var cell: Vector2i = key
		var origin := Vector2(cell.x * TILE, cell.y * TILE)
		# tilled soil base
		overlay.draw_rect(Rect2(origin + Vector2(1, 1), Vector2(14, 14)),
			Color(0.82, 0.55, 0.32, 0.12), true)
		overlay.draw_rect(Rect2(origin + Vector2(1, 1), Vector2(14, 14)),
			Color(0.3, 0.16, 0.07, 0.22), false, 1.0)
		# watered tint
		if bool(tile.get("watered", false)):
			overlay.draw_rect(Rect2(origin, Vector2(TILE, TILE)),
				Color(0.18, 0.22, 0.38, 0.28), true)
		# furrow marks
		for spot in [Vector2(4, 5), Vector2(9, 5), Vector2(6, 10), Vector2(11, 10)]:
			overlay.draw_rect(Rect2(origin + spot, Vector2(2, 1)),
				Color(0.32, 0.18, 0.08, 0.35), true)


# ================================================================ util

func _notify(msg: String) -> void:
	if hud and hud.has_method("toast"):
		hud.toast(msg)


# ================================================================ placeholder cleanup
# Call once on startup to hide/remove the static Crop_* Sprite2D examples
# that shipped in world.tscn, since FarmManager now owns all crop visuals.

func remove_placeholder_crops() -> void:
	if world == null:
		return
	for child in world.get_children():
		if child is Sprite2D and String(child.name).begins_with("Crop_"):
			child.visible = false
			child.queue_free()