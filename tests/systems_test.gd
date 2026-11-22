extends SceneTree
## Functional checks for stamina, gathering, fishing, and eating.

var _fail := 0


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


func _wait_player_idle(player: CharacterBody2D) -> void:
	for i in 900:
		if not player.is_busy():
			return
		await process_frame


func _settle(n := 4) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var world: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for i in 4:
		await process_frame
	var GS = root.get_node("GameState")
	var hud = world.get("hud")
	var player: CharacterBody2D = world.get_node("Player")

	# --- stamina init + bar
	_check(GS.MAX_STAMINA == 100, "MAX_STAMINA = 100")
	_check(GS.stamina == 100, "stamina starts at 100")
	_check(hud._stamina_bar != null, "top-bar stamina bar exists")

	# --- 10 slots + new tool icons
	_check(hud._slot_bgs.size() == 10, "hotbar has 10 slots")
	_check(String(GS.hotbar[2]["tool"]) == "axe", "slot 3 is axe")
	_check(String(GS.hotbar[3]["tool"]) == "pickaxe", "slot 4 is pickaxe")
	_check(String(GS.hotbar[4]["tool"]) == "rod", "slot 5 is rod")
	_check(hud._slot_icons[2].texture != null, "axe icon rendered")
	_check(hud._slot_icons[3].texture != null, "pickaxe icon rendered")
	_check(hud._slot_icons[4].texture != null, "rod icon rendered")

	# --- tool stamina cost (hoe)
	var cell := Vector2i(12, 26)
	var s0: int = GS.stamina
	world.select_slot(0)
	world.use_tool(cell)
	await _wait_player_idle(player)
	_check(GS.stamina == s0 - 5, "tilling costs 5 stamina")

	# --- gathering wood (axe) on nearest tree
	var tree: Node = null
	for r in world._resources:
		if String(r.get_meta("kind", "")) == "tree":
			tree = r
			break
	_check(tree != null, "a tree resource exists")
	var center: Vector2 = world._resource_center(tree)
	player.global_position = center + Vector2(0, 18)
	player.facing = Vector2i.UP
	await _settle(2)
	world.select_slot(2)  # axe
	var wood_before: int = _count_item(GS, "wood")
	for i in 3:
		world.use_tool(Vector2i.ZERO)
		await _wait_player_idle(player)
	_check(not (tree as CanvasItem).visible, "tree hidden after 3 axe hits")
	_check(_count_item(GS, "wood") == wood_before + 1, "chopping a tree yields 1 wood")
	_check(tree.has_meta("respawn"), "felled tree scheduled to respawn")

	# --- gathering rock (pickaxe) on nearest boulder
	var boulder: Node = null
	for r in world._resources:
		if String(r.get_meta("kind", "")) == "boulder":
			boulder = r
			break
	center = world._resource_center(boulder)
	player.global_position = center + Vector2(0, 18)
	player.facing = Vector2i.UP
	await _settle(2)
	world.select_slot(3)  # pickaxe
	var rock_before: int = _count_item(GS, "rock")
	for i in 3:
		world.use_tool(Vector2i.ZERO)
		await _wait_player_idle(player)
	_check(not (boulder as CanvasItem).visible, "boulder hidden after 3 pickaxe hits")
	_check(_count_item(GS, "rock") == rock_before + 1, "mining a boulder yields 1 rock")

	# --- respawn after 3 day changes
	for d in 3:
		GS.day += 1
		GS.day_changed.emit(GS.day)
		await process_frame
	_check((tree as CanvasItem).visible, "tree respawns after 3 days")
	_check((boulder as CanvasItem).visible, "boulder respawns after 3 days")

	# --- fishing mini-game
	player.global_position = Vector2(744, 545)
	player.facing = Vector2i.UP
	await _settle(2)
	world.select_slot(4)  # rod
	var fish_before: int = _count_item(GS, "fish")
	world.use_tool(Vector2i.ZERO)
	await process_frame
	_check(world.is_fishing() and hud.is_fishing(), "fishing mini-game starts facing pond")
	hud._fish_pos = hud._fish_zone_c  # land in the green zone
	hud.fishing_press()
	await process_frame
	_check(not world.is_fishing(), "fishing ends after press")
	_check(_count_item(GS, "fish") == fish_before + 1, "successful fishing yields 1 fish")

	# --- eat for stamina
	GS.sell_all_produce()  # free up item slots filled by wood/rock/fish
	GS.stamina = 50
	GS.add_item("carrot", "Wortel", 2)
	# find the produce slot and select it
	var prod_slot := -1
	for i in range(GS.ITEM_START, GS.MAX_SLOTS):
		if String(GS.hotbar[i]["crop"]) == "carrot" and String(GS.hotbar[i]["type"]) == "produce":
			prod_slot = i
			break
	_check(prod_slot != -1, "carrot produce present for eating")
	world.select_slot(prod_slot)
	var cnt_before: int = int(GS.hotbar[prod_slot]["count"])
	# The fishing catch plays the reeling animation, which locks actions.
	await _wait_player_idle(player)
	world.eat_selected()
	await process_frame
	_check(GS.stamina == 70, "eating restores +20 stamina")
	_check(int(GS.hotbar[prod_slot]["count"]) == cnt_before - 1, "eating consumes one item")

	# --- sleep refills stamina
	GS.stamina = 30
	GS.sleep_until_morning()
	_check(GS.stamina == 100, "sleep refills stamina to full")

	print("")
	if _fail == 0:
		print("HASIL: LULUS")
		quit(0)
	else:
		print("HASIL: GAGAL (%d)" % _fail)
		quit(1)


func _count_item(GS, id: String) -> int:
	var total := 0
	for i in range(GS.ITEM_START, GS.MAX_SLOTS):
		if String(GS.hotbar[i]["crop"]) == id:
			total += int(GS.hotbar[i]["count"])
	return total
