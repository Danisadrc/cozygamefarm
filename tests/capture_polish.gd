extends SceneTree
## Visual QA for the polish pass: camera zoom, villager proportions, cow size,
## the new cottages, and the village dressing (lamps, plaza, bench, campfire).
## Uses the Player's own Camera2D so the shots show the real 1.65x zoom.
##
## The camera has smoothing, so every teleport calls reset_smoothing() and then
## waits a few frames - otherwise the shot is taken mid-pan and shows the wrong
## part of the map.
##
## Each entry is [player position, facing, output path, hour]. A negative hour
## keeps the clock where it is; otherwise the clock is moved there before the
## shot so the afternoon leaves / night fireflies can be checked too.

var _frames := 0
var _world: Node
var _player: Node2D
var _camera: Camera2D
var _state: Node
## Filled in once the world exists.
var _shots: Array = []
var _next := 0


func _process(_delta: float) -> bool:
	_frames += 1

	if _frames == 1:
		_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
		root.add_child(_world)
		_player = _world.get_node("Player")
		_camera = _world.get_node("Player/Camera")
		_state = root.get_node("/root/GameState")
		return false

	if _frames < 4:
		return false

	# 10 frames per shot: teleport on the first, capture on the eighth.
	var slot := (_frames - 4) % 10
	if slot == 0:
		if _shots.is_empty():
			_build_shot_list()
		if _next >= _shots.size():
			print("done")
			return true
		var s: Array = _shots[_next]
		if float(s[3]) >= 0.0:
			_state.hour = int(s[3])
			_state.minute = 30
			# One big tick so the decor fades its lamps / particles in.
			_world.village_decor._process(3.0)
		_player.global_position = s[0]
		_player.facing = s[1]
		_camera.reset_smoothing()
	elif slot == 8 and _next < _shots.size():
		_shot(_shots[_next][2])
		_next += 1
	return false


func _build_shot_list() -> void:
	var npc = _world.npcs[0]
	var sari := _world.get_node_or_null("Villager")
	_shots = [
		[Vector2(424, 300), Vector2i.UP, "res://tests/shot_pol_farm.png", -1.0],
		[Vector2(700, 380), Vector2i.UP, "res://tests/shot_pol_market.png", -1.0],
		[Vector2(830, 300), Vector2i.UP, "res://tests/shot_pol_ne.png", -1.0],
		[Vector2(480, 500), Vector2i.UP, "res://tests/shot_pol_se.png", -1.0],
		[Vector2(600, 440), Vector2i.UP, "res://tests/shot_pol_cow.png", -1.0],
		[Vector2(660, 520), Vector2i.UP, "res://tests/shot_pol_pond.png", -1.0],
		[npc.global_position + Vector2(-28, 12), Vector2i.UP,
			"res://tests/shot_pol_npc.png", -1.0],
	]
	if sari != null:
		_shots.append([sari.global_position + Vector2(0, 26), Vector2i.UP,
			"res://tests/shot_pol_busari.png", -1.0])
	# Afternoon leaves, then night lamps + fireflies, then the campfire at night.
	_shots.append([Vector2(500, 300), Vector2i.UP, "res://tests/shot_pol_sore.png", 17.0])
	_shots.append([Vector2(700, 400), Vector2i.UP, "res://tests/shot_pol_malam.png", 21.0])
	_shots.append([Vector2(650, 545), Vector2i.UP, "res://tests/shot_pol_fire.png", -1.0])


func _shot(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
