extends SceneTree
## Visual QA for Tahap 4B: villager prompt + dialogue, quest board dialogue,
## the Renovasi Desa completion screen, and free play afterwards.

var _frames := 0
var _world: Node
var _player: Node2D
var _gs: Node


func _process(_delta: float) -> bool:
	_frames += 1

	if _frames == 1:
		var view := Camera2D.new()
		view.position = Vector2(690, 360)
		view.zoom = Vector2(1, 1)
		root.add_child(view)
		view.make_current()

		_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
		var cam := _world.get_node_or_null("Player/Camera") as Camera2D
		if cam:
			cam.get_parent().remove_child(cam)
			cam.free()
		root.add_child(_world)
		_player = _world.get_node("Player")
		_gs = root.get_node("GameState")
		_player.position = Vector2(702, 392)
		_player.facing = Vector2i.UP
		return false

	if _frames == 4:
		_shot("res://tests/shot_4b_talk_prompt.png")
	if _frames == 6:
		_world._talk_villager()
	if _frames == 22:
		_shot("res://tests/shot_4b_talk_dialog.png")
	if _frames == 24:
		_world._close_dialogue()
		_player.position = Vector2(664, 352)
		_player.facing = Vector2i.UP
	if _frames == 27:
		_world._open_quest_board()
	if _frames == 44:
		_shot("res://tests/shot_4b_board_dialog.png")
	if _frames == 46:
		_world._close_dialogue()
		_gs.quest_event("harvest", 3)
		_gs.quest_event("wood", 5)
		_gs.quest_event("fish", 2)
		_gs.quest_event("egg", 2)
		_gs.add_gold(200)
		_gs.quest_event("wood", 10)
		_gs.quest_event("rock", 8)
	if _frames == 66:
		_shot("res://tests/shot_4b_complete.png")
	if _frames == 68:
		_world.hud._on_complete_pressed()
	if _frames == 86:
		_shot("res://tests/shot_4b_free.png")
		print("done")
		return true
	return false


func _shot(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path, " ", img.get_size())