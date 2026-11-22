extends SceneTree
## Regression checks for reach, hitbox facing, stamina charging, pond shape,
## fishing animations, and the 23:59 clock clamp.

var _fail := 0


func _initialize() -> void:
	_run()
	# Watchdog: a script error inside an await chain leaves the tree alive
	# forever, which would hang the shell instead of failing fast.
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("FAIL watchdog timeout")
		quit(1))


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		_fail += 1
		printerr("FAIL ", msg)


func _wait_idle(player: CharacterBody2D) -> void:
	for i in 900:
		if not player.is_busy():
			return
		await process_frame


func _settle(n := 4) -> void:
	for i in n:
		await physics_frame


## Records hits + visibility of every gatherable so a rejected swing can be
## proven to have changed nothing at all.
func _snapshot(world: Node) -> Array:
	var out := []
	for r in world._resources:
		out.append([r, int(r.get_meta("hits", 0)), (r as CanvasItem).visible])
	return out


func _unchanged(snap: Array) -> bool:
	for e in snap:
		var r: Node = e[0]
		if int(r.get_meta("hits", 0)) != int(e[1]) or (r as CanvasItem).visible != bool(e[2]):
			return false
	return true


func _run() -> void:
	var world: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for i in 4:
		await process_frame
	var GS = root.get_node("GameState")
	var hud = world.get("hud")
	var player: CharacterBody2D = world.get_node("Player")

	# ---------------------------------------------------------------- A: shake drift
	var tree: Node = null
	for r in world._resources:
		if String(r.get_meta("kind", "")) == "tree":
			tree = r
			break
	var spr: Node2D = tree.get_node("Sprite")
	var base: Vector2 = spr.position
	player.global_position = world._resource_center(tree) + Vector2(0, 16)
	player.facing = Vector2i.UP
	await _settle(2)
	world.select_slot(2)
	world.use_tool(Vector2i.ZERO)
	await _wait_idle(player)
	world.use_tool(Vector2i.ZERO)
	await _wait_idle(player)
	await create_timer(0.6).timeout
	_check(spr.position.is_equal_approx(base),
		"tree sprite returns to its base position after repeated hits (%s vs %s)" % [spr.position, base])

	# ---------------------------------------------------------------- B: reach limit
	var far: Node = null
	for r in world._resources:
		if String(r.get_meta("kind", "")) == "tree" and (r as CanvasItem).visible and r != tree:
			far = r
			break
	var far_base: Vector2 = world._resource_center(far)
	player.global_position = far_base + Vector2(0, 64)
	player.facing = Vector2i.UP
	await _settle(2)
	GS.stamina = 100
	world.use_tool(Vector2i.ZERO)
	await _wait_idle(player)
	_check(not far.has_meta("hits"), "a tree 4 tiles away cannot be chopped")
	_check(GS.stamina == 100, "no stamina spent when nothing is in reach")

	# ---------------------------------------------------------------- C: behind the back
	var near: Node = null
	for r in world._resources:
		if String(r.get_meta("kind", "")) == "tree" and (r as CanvasItem).visible:
			near = r
			break
	var snap := _snapshot(world)
	player.global_position = world._resource_center(near) + Vector2(0, 14)
	player.facing = Vector2i.DOWN  # tree is behind the player
	await _settle(2)
	world.use_tool(Vector2i.ZERO)
	await _wait_idle(player)
	_check(_unchanged(snap), "a tree behind the player cannot be chopped")

	# ---------------------------------------------------------------- D: mouse range
	GS.stamina = 100
	world.select_slot(2)
	player.global_position = Vector2(424, 270)
	await _settle(2)
	world.mouse_action(player.global_position + Vector2(180, 0))
	_check(GS.stamina == 100, "a far mouse click spends no stamina")

	# ---------------------------------------------------------------- E: single stamina charge
	GS.stamina = 100
	world.select_slot(0)
	player.global_position = Vector2(200, 424)
	player.facing = Vector2i.RIGHT
	await _settle(2)
	world.mouse_action(player.global_position + Vector2(16, 0))
	await _wait_idle(player)
	_check(GS.stamina == 95, "a mouse click charges stamina once (got %d)" % GS.stamina)
	_check(world.farm._is_tilled(Vector2i(13, 26)), "the click tilled the tile in front")

	# ---------------------------------------------------------------- F: no charge on empty soil
	GS.stamina = 100
	player.global_position = Vector2(424, 300)  # grass, not farm soil
	player.facing = Vector2i.DOWN
	await _settle(2)
	world.use_tool(player.front_cell())
	await _wait_idle(player)
	_check(GS.stamina == 100, "hoeing grass outside the farm spends nothing")

	# ---------------------------------------------------------------- G: pond is an ellipse
	# (840,552) is a cell centre inside the old AABB but outside the pond ellipse.
	player.global_position = Vector2(824, 552)
	player.facing = Vector2i.RIGHT
	await _settle(2)
	_check(player.target_pos().is_equal_approx(Vector2(840, 552)), "probe sits on the pond AABB corner")
	world.select_slot(4)
	GS.stamina = 100
	world.use_tool(Vector2i.ZERO)
	await process_frame
	_check(not world.is_fishing(), "fishing is refused on the grassy AABB corner")
	_check(GS.stamina == 100, "refused fishing spends no stamina")

	# valid water, one tile north of the pond centre column
	player.global_position = Vector2(744, 545)
	player.facing = Vector2i.UP
	await _settle(2)
	world.use_tool(Vector2i.ZERO)
	await process_frame
	_check(world.is_fishing(), "fishing starts on real water")
	_check(player.sprite.animation == "casting", "cast animation plays (got %s)" % player.sprite.animation)
	hud._fish_pos = hud._fish_zone_c
	hud.fishing_press()
	await process_frame
	_check(not world.is_fishing(), "mini-game resolves")
	_check(player.sprite.animation == "reeling", "reel animation plays (got %s)" % player.sprite.animation)

	# ---------------------------------------------------------------- H: clock stops at 23:59
	GS.hour = 23
	GS.minute = 58
	GS.time_scale = 120.0
	var day_before: int = GS.day
	await create_timer(1.5).timeout
	_check(GS.hour == 23 and GS.minute == 59, "clock stops at 23:59 (got %s)" % GS.time_string())
	_check(GS.day == day_before, "no day_changed in the middle of the night")
	GS.time_scale = 1.0

	# ---------------------------------------------------------------- I: HUD text
	_check(hud._day_label.text == "Hari 1", "day label reads 'Hari 1' (got '%s')" % hud._day_label.text)
	_check(hud._phase_label.text == "Malam", "phase badge follows the clock (got '%s')" % hud._phase_label.text)
	_check(hud._stamina_text.text == "%d/100" % GS.stamina, "stamina readout updates")

	print("")
	if _fail == 0:
		print("HASIL: LULUS")
		quit(0)
	else:
		print("HASIL: GAGAL (%d)" % _fail)
		quit(1)
