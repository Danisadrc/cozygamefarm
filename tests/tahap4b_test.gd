extends SceneTree
## Tahap 4B checks: livestock products, villager dialogue, and the three-stage
## village quest chain (including the Renovasi Desa completion screen).

var _fail := 0


func _initialize() -> void:
	_run()
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("FAIL watchdog timeout")
		quit(1))


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		_fail += 1
		printerr("FAIL ", msg)


func _settle(n := 2) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _count_item(GS, id: String) -> int:
	var total := 0
	for i in range(GS.ITEM_START, GS.MAX_SLOTS):
		if String(GS.hotbar[i]["crop"]) == id:
			total += int(GS.hotbar[i]["count"])
	return total


func _run() -> void:
	var world: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for i in 4:
		await process_frame
	var GS = root.get_node("GameState")
	var DataReg = root.get_node("DataRegistry")
	var hud = world.hud
	var player: CharacterBody2D = world.get_node("Player")
	var live = world.livestock

	# ---------------------------------------------------------- items
	_check(DataReg.item_sell_price("egg") == 35, "egg sells for 35 G")
	_check(DataReg.item_sell_price("milk") == 50, "milk sells for 50 G")
	_check(DataReg.item_stamina("egg") == 25, "egg restores 25 stamina")
	_check(DataReg.item_stamina("milk") == 35, "milk restores 35 stamina")
	_check(DataReg.item_icon("egg") != null, "egg icon loads")
	_check(DataReg.item_icon("milk") != null, "milk icon loads")
	_check(GS.sell_price("egg") == 35, "GameState uses egg price")
	_check(GS.sell_price("milk") == 50, "GameState uses milk price")
	_check(hud._produce_icon("milk") == hud.ICON_MILK, "milk hotbar icon wired")
	_check(hud._item_label("milk") == "Susu", "milk label is Susu")

	# ---------------------------------------------------------- livestock spawn
	_check(live != null, "livestock manager exists")
	_check(live.animals.size() == 3, "3 animals spawned")
	var chickens := 0
	var cows := 0
	var placement_ok := true
	for a in live.animals:
		var kind := String(a["kind"])
		if kind == "chicken":
			chickens += 1
		elif kind == "cow":
			cows += 1
		var p: Vector2 = (a["sprite"] as Node2D).global_position
		# Open grass east of the farm fence and west of the pond.
		if p.x < 400.0 or p.x > 636.0 or p.y < 400.0 or p.y > 520.0:
			placement_ok = false
	_check(chickens == 2 and cows == 1, "2 chickens + 1 cow")
	_check(placement_ok, "animals spawn on the open grass right of the farm")
	_check(live.find_children("*", "CollisionObject2D", true, false).is_empty(),
		"animals have no colliders (BFS paths untouched)")

	# ---------------------------------------------------------- tend -> egg
	var chick: Dictionary = live.animals[0]
	var chick_spr: Node2D = chick["sprite"]
	player.global_position = chick_spr.global_position + Vector2(0, 10)
	player.facing = Vector2i.UP
	await _settle()
	_check(live.prompt_for_player() == "[E] Rawat Ternak", "proximity prompt is Rawat Ternak")
	_check(hud._prompt.visible and hud._prompt_label.text == "[E] Rawat Ternak",
		"HUD shows the livestock prompt")

	world.interact("")
	await process_frame
	_check(bool(chick["tended"]), "tending marks the chicken as cared for")

	var eggs_before := _count_item(GS, "egg")
	GS.day += 1
	GS.day_changed.emit(GS.day)
	await process_frame
	_check(int(chick["product"]) == 1, "tended chicken lays one egg on sleep")
	_check(world._last_products >= 1, "sleep summary counts the product")
	_check(live.prompt_for_player() == "[E] Ambil Telur", "product prompt offers collection")
	world.interact("")
	await process_frame
	_check(_count_item(GS, "egg") == eggs_before + 1, "collecting adds 1 egg to inventory")
	_check(int(chick["product"]) == 0, "product cleared after collection")
	_check(GS.sell_price("egg") == 35, "egg still sells for 35 G")

	# ---------------------------------------------------------- tend -> milk
	var cow: Dictionary = live.animals[2]
	var cow_spr: Node2D = cow["sprite"]
	player.global_position = cow_spr.global_position + Vector2(0, 12)
	player.facing = Vector2i.UP
	await _settle()
	_check(live.prompt_for_player() == "[E] Rawat Ternak", "cow can be tended too")
	world.interact("")
	GS.day += 1
	GS.day_changed.emit(GS.day)
	await process_frame
	_check(int(cow["product"]) == 1, "tended cow produces one milk on sleep")
	_check(live.prompt_for_player() == "[E] Ambil Susu", "cow prompt offers milk")
	var milk_before := _count_item(GS, "milk")
	world.interact("")
	await process_frame
	_check(_count_item(GS, "milk") == milk_before + 1, "collecting adds 1 milk")

	# ---------------------------------------------------------- zones + prompts
	_check(world.get_node_or_null("Zones/VillagerZone") != null, "villager zone exists")
	_check(world.get_node_or_null("Zones/QuestBoardZone") != null, "quest board zone exists")
	_check(world._prompt_for("villager") == "[E] Bicara", "villager prompt text")
	_check(world._prompt_for("quest") == "[E] Papan Misi", "quest board prompt text")

	player.global_position = Vector2(702, 386)
	player.facing = Vector2i.DOWN
	await _settle()
	_check(player.current_zone == "villager", "standing by the villager enters its zone")
	_check(hud._prompt_label.text == "[E] Bicara", "villager prompt is shown")

	player.global_position = Vector2(664, 346)
	player.facing = Vector2i.DOWN
	await _settle()
	_check(player.current_zone == "quest", "standing by the board enters its zone")
	_check(hud._prompt_label.text == "[E] Papan Misi", "quest board prompt is shown")

	# ---------------------------------------------------------- villager dialogue
	GS.hour = 9
	GS.minute = 0
	world._talk_villager()
	await process_frame
	_check(hud.is_dialogue_open(), "villager opens the dialogue box")
	_check(player.input_locked, "dialogue locks player input")
	_check(hud._dialog_speaker.text == "Bu Sari", "dialogue names the villager")
	var morning: String = hud._dialog_text.text
	_check(morning.contains("Pagi"), "morning dialogue mentions Pagi")
	_check(morning.contains("Papan Misi"), "villager hints at the quest board")
	world._close_dialogue()
	await process_frame
	_check(not hud.is_dialogue_open(), "dialogue closes")
	_check(not player.input_locked, "closing dialogue unlocks input")

	GS.hour = 21
	world._talk_villager()
	await process_frame
	var night: String = hud._dialog_text.text
	_check(night.contains("malam"), "night dialogue mentions malam")
	_check(night != morning, "dialogue text changes with the phase")
	world._close_dialogue()
	await process_frame

	# ---------------------------------------------------------- quest board text
	world._open_quest_board()
	await process_frame
	_check(hud.is_dialogue_open(), "quest board opens the dialogue box")
	_check(String(hud._dialog_speaker.text).contains("Papan Misi"), "board speaker label")
	var board_text: String = hud._dialog_text.text
	_check(board_text.contains("Petani Pemula"), "board shows the active quest title")
	_check(board_text.contains("Panen 0/3"), "board shows quest progress")
	_check(board_text.contains("Hadiah: 100 G"), "board shows the quest reward")
	world._close_dialogue()
	await process_frame

	# ---------------------------------------------------------- quest chain
	_check(GS.quest_index == 0, "quest 1 starts active")
	_check(hud._quest_title.text == "Petani Pemula", "HUD tracks quest 1")
	_check(hud._quest_goals.get_child_count() == 2, "tracker lists two goals")

	GS.quest_event("harvest", 1)
	await process_frame
	var first_goal: Label = hud._quest_goals.get_child(0)
	_check(first_goal.text == "Panen 1/3", "tracker updates harvest progress")

	GS.quest_event("harvest", 2)
	GS.quest_event("wood", 5)
	await process_frame
	_check(GS.quest_index == 1, "Q1 completes after 3 harvests + 5 wood")
	_check(GS.gold == 200, "Q1 pays +100 G (got %d)" % GS.gold)
	_check(hud._quest_title.text == "Nelayan & Peternak", "HUD advances to quest 2")

	GS.quest_event("fish", 2)
	GS.quest_event("egg", 2)
	await process_frame
	_check(GS.quest_index == 2, "Q2 completes after 2 fish + 2 eggs")
	_check(GS.gold == 350, "Q2 pays +150 G (got %d)" % GS.gold)
	_check(hud._quest_title.text == "Renovasi Desa", "HUD advances to quest 3")

	GS.add_gold(200)
	GS.quest_event("wood", 10)
	GS.quest_event("rock", 8)
	await process_frame
	_check(GS.quest_done, "Q3 completes after 400 G + 10 wood + 8 rock")
	_check(hud.is_quest_complete_open(), "Renovasi Desa screen opens")
	_check(world.busy, "completion screen pauses the world")
	_check(hud._complete_summary.text.contains("Total hari: %d" % GS.day),
		"completion screen lists total days")
	_check(hud._complete_summary.text.contains("Total gold: %d G" % GS.gold),
		"completion screen lists total gold")
	_check(hud._quest_head.text == "MISI SELESAI", "tracker switches to finished state")

	hud._on_complete_pressed()
	await process_frame
	_check(not hud.is_quest_complete_open(), "Lanjut Bermain Bebas closes the screen")
	_check(not world.busy, "free play resumes after the screen")
	_check(not player.input_locked, "player unlocked after the screen")

	world._open_quest_board()
	await process_frame
	_check(hud._dialog_text.text.contains("sudah selesai"), "board reports all quests done")
	world._close_dialogue()
	await process_frame

	# ---------------------------------------------------------- real hook wiring
	# The chain above used quest_event() directly; these checks go through the
	# actual gameplay paths so a broken signal or missing call cannot ship.
	GS.quest_done = false
	GS.quest_index = 0
	GS.quest_counts.clear()
	GS.quest_changed.emit()
	await process_frame

	var farm = world.farm
	var cell := Vector2i(17, 27)
	farm._farm[cell] = {"tilled": true, "watered": false, "crop": "carrot", "stage": 5}
	farm._update_crop_visual(cell)
	for i in range(GS.ITEM_START, GS.MAX_SLOTS):
		GS.hotbar[i]["crop"] = ""
		GS.hotbar[i]["name"] = ""
		GS.hotbar[i]["count"] = 0
	player.global_position = Vector2(200, 416)
	await _settle()
	world.select_slot(7)
	world.use_tool(cell)
	await process_frame
	_check(int(GS.quest_counts.get("harvest", 0)) == 1,
		"harvesting a crop feeds the quest tracker")
	for i in 40:
		await physics_frame

	var tree: Node = null
	for r in world._resources:
		if is_instance_valid(r) and String(r.get_meta("kind", "")) == "tree":
			tree = r
			break
	_check(tree != null, "a tree is available to chop")
	if tree != null:
		for i in 3:
			world._hit_resource(tree, "tree")
		await process_frame
		_check(int(GS.quest_counts.get("wood", 0)) == 1,
			"chopping a tree feeds the wood goal")

	# Quest 2: fishing and egg collection.
	GS.quest_index = 1
	GS.quest_counts.clear()
	GS.quest_changed.emit()
	await process_frame
	world._on_fish_result(true)
	await process_frame
	_check(int(GS.quest_counts.get("fish", 0)) == 1, "catching a fish feeds quest 2")

	chick["product"] = 1
	player.global_position = chick_spr.global_position + Vector2(0, 10)
	player.facing = Vector2i.UP
	# Headless runs physics slower than process, so wait on physics ticks.
	for i in 120:
		if not player.is_busy():
			break
		await physics_frame
	await _settle()
	world.interact("")
	await process_frame
	_check(int(GS.quest_counts.get("egg", 0)) == 1, "collecting an egg feeds quest 2")

	print("")
	if _fail == 0:
		print("HASIL: LULUS")
		quit(0)
	else:
		print("HASIL: GAGAL (%d)" % _fail)
		quit(1)