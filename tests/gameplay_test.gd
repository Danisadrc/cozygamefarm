extends SceneTree
## Headless gameplay smoke test for the farm loop.

var _fail := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		_fail += 1
		printerr("FAIL ", msg)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _wait_idle(game: Node) -> void:
	for i in 600:
		if not game.busy:
			return
		await process_frame
	_fail += 1
	printerr("FAIL sleep sequence never finished")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/world.tscn")
	var world := packed.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var game := world
	var player: CharacterBody2D = world.get_node("Player")
	var hud = game.hud
	var cell := Vector2i(12, 26)

	_check(game.day == 1, "day starts at 1")
	_check(game.gold == 100, "gold starts at 100")
	_check(int(game.hotbar[2]["count"]) == 5, "carrot seeds start at 5")
	_check(hud != null, "HUD exists")
	_check(hud._day_label.text == "Hari ke-1", "day label rendered")
	_check(hud._gold_label.text == "100 G", "gold label rendered")

	# --- till
	game.select_slot(0)
	game.use_tool(cell)
	_check(game._farm.has(cell), "hoe tills a farm cell")
	_check(bool(game._farm[cell]["tilled"]), "cell is tilled")
	await _wait(0.9)

	# --- plant
	game.select_slot(2)
	game.use_tool(cell)
	_check(int(game.hotbar[2]["count"]) == 4, "planting consumes one seed")
	_check(String(game._farm[cell]["crop"]) == "carrot", "carrot planted")
	_check(game._crop_nodes.has(cell), "crop sprite spawned")

	# --- water
	game.select_slot(1)
	game.use_tool(cell)
	_check(bool(game._farm[cell]["watered"]), "cell is watered")
	await _wait(0.7)

	# --- sleep -> growth
	player.global_position = Vector2(424, 250)
	await process_frame
	game.interact("sleep")
	await _wait_idle(game)
	_check(game.day == 2, "sleep advances the day")
	_check(int(game._farm[cell]["stage"]) == 1, "watered crop grows one stage")
	_check(not bool(game._farm[cell]["watered"]), "soil dries after sleep")
	_check(hud._day_label.text == "Hari ke-2", "day label updates")

	# --- force mature and harvest
	game._farm[cell]["stage"] = 5
	game._update_crop_visual(cell)
	player.global_position = Vector2(200, 416)
	await process_frame
	game.select_slot(6)
	game.use_tool(cell)
	_check(int(game.hotbar[6]["count"]) == 1, "harvest fills produce slot 7")
	_check(String(game.hotbar[6]["crop"]) == "carrot", "produce slot holds carrot")
	_check(not game._crop_nodes.has(cell), "crop sprite removed after harvest")

	# --- sell
	var before := int(game.gold)
	game.interact("ship")
	_check(int(game.gold) == before + 20, "shipping bin sells carrot for 20 G")
	_check(int(game.hotbar[6]["count"]) == 0, "produce slot emptied after sale")

	# --- shop
	var seeds_before := int(game.hotbar[2]["count"])
	game.interact("shop")
	_check(game.shop_open, "shop opens at merchant zone")
	game.buy_seed("carrot")
	_check(int(game.gold) == before + 20 - 10, "buying a carrot seed costs 10 G")
	_check(int(game.hotbar[2]["count"]) == seeds_before + 1, "bought seed added to slot 3")
	game.close_shop()
	_check(not game.shop_open, "shop closes")

	# --- prompt in zones
	player.global_position = Vector2(424, 234)
	await process_frame
	await process_frame
	_check(hud._prompt.visible, "interaction prompt visible in door zone")
	_check(hud._prompt_label.text == "[E] Tidur", "prompt text for bed")
	player.global_position = Vector2(472, 422)
	await process_frame
	await process_frame
	_check(hud._prompt_label.text == "[E] Jual hasil panen", "prompt text for shipping bin")
	player.global_position = Vector2(748, 350)
	await process_frame
	await process_frame
	_check(hud._prompt_label.text == "[E] Beli bibit", "prompt text for merchant")
	player.global_position = Vector2(424, 270)
	await process_frame
	await process_frame
	_check(not hud._prompt.visible, "prompt hidden outside zones")

	# --- hotbar selection via keys / wheel
	game.select_slot(0)
	game.cycle_slot(-1)
	_check(game.selected == 7, "mouse wheel wraps hotbar selection")
	game.select_slot(4)
	_check(game.selected == 4, "number key selection works")

	print("")
	if _fail == 0:
		print("HASIL: LULUS")
		quit(0)
	else:
		print("HASIL: GAGAL (%d)" % _fail)
		quit(1)
