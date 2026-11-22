extends SceneTree
## Capture gameplay states for visual review (windowed, not headless).

var _frames := 0
var _world: Node
var _player: CharacterBody2D
var _camera: Camera2D


func _process(_delta: float) -> bool:
	_frames += 1

	if _frames == 1:
		_setup_scene()
		return false

	if _frames == 6:
		_capture("res://tests/shot_crops.png")
	if _frames == 8:
		_world._open_shop()
	if _frames == 20:
		_capture("res://tests/shot_shop.png")
	if _frames == 22:
		_world.close_shop()
		_player.facing = Vector2i.DOWN
		_player.play_action("dig")
	if _frames == 25:
		_capture("res://tests/shot_dig.png")
	if _frames == 29:
		_capture("res://tests/shot_dig2.png")
	if _frames == 70:
		_player.play_action("water")
	if _frames == 73:
		_capture("res://tests/shot_water.png")
	if _frames == 75:
		_world._open_shop()
		_world.buy_seed("carrot")
	if _frames == 78:
		_capture("res://tests/shot_buy.png")
	if _frames > 80:
		print("done")
		return true
	return false


func _setup_scene() -> void:
	_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	var cam := _world.get_node_or_null("Player/Camera") as Camera2D
	if cam:
		cam.get_parent().remove_child(cam)
		cam.free()
	root.add_child(_world)

	_camera = Camera2D.new()
	_camera.position = Vector2(264, 460)
	_camera.zoom = Vector2(4, 4)
	root.add_child(_camera)
	_camera.make_current()

	_player = _world.get_node("Player") as CharacterBody2D
	_player.global_position = Vector2(264, 454)
	_player.facing = Vector2i.DOWN
	_player.queue_redraw()
	_setup_farm()


func _setup_farm() -> void:
	var cells := [
		[Vector2i(13, 27), "carrot", 0, true],
		[Vector2i(14, 27), "carrot", 2, false],
		[Vector2i(15, 27), "potato", 5, false],
		[Vector2i(16, 27), "beetroot", 3, true],
		[Vector2i(17, 27), "cabbage", 4, false],
		[Vector2i(13, 29), "carrot", 5, false],
		[Vector2i(14, 29), "cabbage", 1, true],
		[Vector2i(15, 29), "potato", 0, false],
		[Vector2i(16, 29), "beetroot", 5, false],
		[Vector2i(17, 29), "cabbage", 5, false],
	]
	for data in cells:
		var cell: Vector2i = data[0]
		_world._farm[cell] = {
			"tilled": true, "watered": data[3],
			"crop": data[1], "stage": data[2],
		}
		_world._spawn_crop(cell)
	for cell in [Vector2i(18, 27), Vector2i(18, 29), Vector2i(19, 27)]:
		_world._farm[cell] = {"tilled": true, "watered": false, "crop": "", "stage": 0}
	_world.overlay.queue_redraw()


func _capture(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
