extends SceneTree
## Drive the farm loop through real key events (not direct method calls).

var _fail := 0
var _world: Node
var _player: CharacterBody2D


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		_fail += 1
		printerr("FAIL ", msg)


func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _tap(code: Key) -> void:
	_key(code, true)
	await process_frame
	_key(code, false)
	await process_frame


func _wait_idle() -> void:
	for i in 600:
		if not _player.is_busy():
			return
		await process_frame


func _run() -> void:
	_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(_world)
	await process_frame
	await process_frame

	var game := _world
	_player = _world.get_node("Player") as CharacterBody2D
	var cell := Vector2i(13, 26)

	_player.global_position = Vector2(200, 416)
	_player.facing = Vector2i.RIGHT
	await process_frame

	# 1 = hoe, Space = till the tile in front
	await _tap(KEY_1)
	await _tap(KEY_SPACE)
	_check(game.selected == 0, "key 1 selects the hoe")
	_check(game._farm.has(cell) and bool(game._farm[cell]["tilled"]), "Space tills the front tile")
	await _wait_idle()

	# 3 = carrot seeds, Space = plant
	await _tap(KEY_3)
	await _tap(KEY_SPACE)
	_check(game.selected == 2, "key 3 selects carrot seeds")
	_check(String(game._farm[cell]["crop"]) == "carrot", "Space plants carrot")
	_check(int(game.hotbar[2]["count"]) == 4, "seed count decreases")
	await _wait_idle()

	# 2 = watering can, Space = water
	await _tap(KEY_2)
	await _tap(KEY_SPACE)
	_check(bool(game._farm[cell]["watered"]), "Space waters the planted tile")
	await _wait_idle()

	# Wheel cycles the selection.
	await _tap(KEY_8)
	_check(game.selected == 7, "key 8 selects the last slot")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await process_frame
	_check(game.selected == 0, "wheel down wraps from slot 8 to slot 1")

	# E at the door sleeps and grows the watered crop.
	_player.global_position = Vector2(424, 234)
	await process_frame
	await process_frame
	_check(_world.hud._prompt.visible, "prompt appears in the door zone")
	await _tap(KEY_E)
	for i in 900:
		if not game.busy:
			break
		await process_frame
	_check(game.day == 2, "E at the door advances the day")
	_check(int(game._farm[cell]["stage"]) == 1, "watered crop grew overnight")

	# E at the merchant opens the shop; Esc closes it.
	_player.global_position = Vector2(748, 350)
	await process_frame
	await process_frame
	await _tap(KEY_E)
	_check(game.shop_open, "E at the merchant opens the shop")
	await _tap(KEY_ESCAPE)
	_check(not game.shop_open, "Esc closes the shop")

	print("")
	if _fail == 0:
		print("HASIL: LULUS")
		quit(0)
	else:
		print("HASIL: GAGAL (%d)" % _fail)
		quit(1)
