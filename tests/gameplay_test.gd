extends SceneTree
## Headless gameplay smoke test for the farm loop.

var _fail := 0
var _gs: Node


func _initialize() -> void:
	_run()
	# Watchdog: a script error inside an await chain would otherwise leave the
	# tree running forever and hang the shell instead of failing fast.
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("FAIL watchdog timeout")
		quit(1))


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


## Action animations lock the player; wait them out before the next input.
func _wait_player_idle(player: CharacterBody2D) -> void:
	for i in 600:
		if not player.is_busy():
			return
		await process_frame
	_fail += 1
	printerr("FAIL player animation never finished")


## Lets the zone Area2Ds report their overlaps after a teleport.
func _settle() -> void:
	for i in 4:
		await physics_frame
	await process_frame


func _run() -> void:
	var packed: PackedScene = load("res://scenes/world.tscn")
	var world := packed.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var game := world
	_gs = root.get_node("GameState")
	var player: CharacterBody2D = world.get_node("Player")
	var hud = game.hud
	var cell := Vector2i(12, 26)
	var seed_slot := 5    # carrot seeds
	var prod_slot := 7    # first produce slot

	_check(_gs.day == 1, "day starts at 1")
	_check(_gs.gold == 100, "gold starts at 100")
	_check(int(_gs.hotbar[seed_slot]["count"]) == 5, "carrot seeds start at 5")
	_check(hud != null, "HUD exists")
	_check(hud._day_label.text == "Hari 1", "day label rendered")
	_check(hud._gold_label.text == "100 G", "gold label rendered")

	# --- till
	game.select_slot(0)
	game.use_tool(cell)
	_check(game.farm._farm.has(cell), "hoe tills a farm cell")
	_check(bool(game.farm._farm[cell]["tilled"]), "cell is tilled")
	await _wait_player_idle(player)

	# --- plant
	game.select_slot(seed_slot)
	game.use_tool(cell)
	_check(int(_gs.hotbar[seed_slot]["count"]) == 4, "planting consumes one seed")
	_check(String(game.farm._farm[cell]["crop"]) == "carrot", "carrot planted")
	_check(game.farm._crop_nodes.has(cell), "crop sprite spawned")
	await _wait_player_idle(player)

	# --- water
	game.select_slot(1)
	game.use_tool(cell)
	_check(bool(game.farm._farm[cell]["watered"]), "cell is watered")
	await _wait_player_idle(player)

	# --- sleep -> growth (sleeping goes through the confirm dialog)
	player.global_position = Vector2(424, 250)
	await _settle()
	game.interact("sleep")
	_check(hud.is_confirm_open(), "sleep asks for confirmation")
	hud._on_confirm_yes()
	await _wait_idle(game)
	_check(_gs.day == 2, "sleep advances the day")
	_check(int(game.farm._farm[cell]["stage"]) == 1, "watered crop grows one stage")
	_check(not bool(game.farm._farm[cell]["watered"]), "soil dries after sleep")
	_check(hud._day_label.text == "Hari 2", "day label updates")

	# --- force mature and harvest
	game.farm._farm[cell]["stage"] = 5
	game.farm._update_crop_visual(cell)
	player.global_position = Vector2(200, 416)
	await _settle()
	game.select_slot(prod_slot)
	game.use_tool(cell)
	_check(int(_gs.hotbar[prod_slot]["count"]) == 1, "harvest fills a produce slot")
	_check(String(_gs.hotbar[prod_slot]["crop"]) == "carrot", "produce slot holds carrot")
	_check(not game.farm._crop_nodes.has(cell), "crop sprite removed after harvest")
	await _wait_player_idle(player)

	# --- sell
	var before := int(_gs.gold)
	game.interact("ship")
	_check(int(_gs.gold) == before + 20, "shipping bin sells carrot for 20 G")
	_check(int(_gs.hotbar[prod_slot]["count"]) == 0, "produce slot emptied after sale")

	# --- shop
	var seeds_before := int(_gs.hotbar[seed_slot]["count"])
	game.interact("shop")
	_check(game.shop_open, "shop opens at merchant zone")
	game.buy_seed("carrot")
	_check(int(_gs.gold) == before + 20 - 10, "buying a carrot seed costs 10 G")
	_check(int(_gs.hotbar[seed_slot]["count"]) == seeds_before + 1, "bought seed added to the seed slot")
	game.close_shop()
	_check(not game.shop_open, "shop closes")

	# --- prompt in zones
	player.global_position = Vector2(424, 234)
	await _settle()
	_check(hud._prompt.visible, "interaction prompt visible in door zone")
	_check(hud._prompt_label.text == "[E] Tidur", "prompt text for bed")
	player.global_position = Vector2(472, 422)
	await _settle()
	_check(hud._prompt_label.text == "[E] Jual Hasil Panen", "prompt text for shipping bin")
	player.global_position = Vector2(748, 350)
	await _settle()
	_check(hud._prompt_label.text == "[E] Beli Bibit", "prompt text for merchant")
	player.global_position = Vector2(424, 270)
	await _settle()
	_check(not hud._prompt.visible, "prompt hidden outside zones")

	# --- hotbar selection via keys / wheel
	game.select_slot(0)
	game.cycle_slot(-1)
	_check(_gs.selected_slot == 9, "mouse wheel wraps hotbar selection")
	game.select_slot(4)
	_check(_gs.selected_slot == 4, "number key selection works")

	print("")
	if _fail == 0:
		print("HASIL: LULUS")
		quit(0)
	else:
		print("HASIL: GAGAL (%d)" % _fail)
		quit(1)
