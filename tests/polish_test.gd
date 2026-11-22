extends SceneTree
## Acceptance probe for the playtest polish pass. Checks the camera zoom, the
## collider sizes, the village dressing, the wandering villagers and the
## afternoon / night atmosphere. Prints OK / FAIL per check.

var _ok := 0
var _fail := 0


func _process(_delta: float) -> bool:
	if Engine.get_process_frames() < 3:
		return false
	var w: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(w)
	_check_camera(w)
	_check_player_box(w)
	_check_decor(w)
	_check_npcs(w)
	_check_particles(w)
	print("HASIL: %s (%d ok, %d fail)" % [
		"LULUS" if _fail == 0 else "GAGAL", _ok, _fail])
	return true


func _ok_if(cond: bool, label: String, detail := "") -> void:
	if cond:
		_ok += 1
		print("OK   %s %s" % [label, detail])
	else:
		_fail += 1
		print("FAIL %s %s" % [label, detail])


func _check_camera(w: Node) -> void:
	var cam := w.get_node("Player/Camera") as Camera2D
	_ok_if(is_equal_approx(cam.zoom.x, 1.65) and is_equal_approx(cam.zoom.y, 1.65),
		"camera zoom is 1.65x", str(cam.zoom))
	_ok_if(cam.position_smoothing_enabled, "camera smoothing enabled")
	_ok_if(cam.limit_right == 960 and cam.limit_bottom == 640,
		"camera limits match the 960x640 map")


func _check_player_box(w: Node) -> void:
	var player := w.get_node("Player") as CharacterBody2D
	var shape: RectangleShape2D = null
	for c in player.get_children():
		if c is CollisionShape2D:
			shape = (c as CollisionShape2D).shape as RectangleShape2D
	_ok_if(shape != null and shape.size == Vector2(8, 5),
		"player collider is a slim 8x5 feet box",
		str(shape.size) if shape != null else "none")


func _check_decor(w: Node) -> void:
	var decor: Node = w.village_decor
	_ok_if(decor != null, "village decor node exists")
	var ne := w.get_node_or_null("Cottage_NE") as StaticBody2D
	var se := w.get_node_or_null("Cottage_SE") as StaticBody2D
	_ok_if(ne != null, "Cottage_NE built")
	_ok_if(se != null, "Cottage_SE built")
	for body in [ne, se]:
		if body == null:
			continue
		var col := body.get_node_or_null("Base") as CollisionShape2D
		var rect: RectangleShape2D = col.shape as RectangleShape2D
		_ok_if(rect.size == Vector2(112, 26),
			"%s collider is a 112x26 facade base" % body.name, str(rect.size))

	# Every prop must be decoration only.
	var props := 0
	for c in w.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("village_props.gd"):
			props += 1
			_ok_if(not (c is CollisionObject2D),
				"prop %s has no collider" % c.name)
	_ok_if(props >= 17, "village has at least 17 props", "got %d" % props)

	var plaza := w.get_node_or_null("MarketPlaza")
	_ok_if(plaza != null, "stone plaza built")
	if plaza != null:
		_ok_if(not (plaza is CollisionObject2D), "plaza has no collider")
		var r: Rect2 = plaza.plaza
		# The board draws x -16..16, y -32..0 around its origin (664, 332).
		_ok_if(r.encloses(Rect2(648, 300, 32, 32)), "plaza covers the quest board")
		_ok_if(r.has_point(Vector2(748, 336)), "plaza covers the market stall")

	var lamps := 0
	var fires := 0
	for c in w.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("village_props.gd"):
			if c.kind == "lamp":
				lamps += 1
			elif c.kind == "fire":
				fires += 1
	_ok_if(lamps >= 11, "street lamps line the road", "got %d" % lamps)
	_ok_if(fires >= 1, "campfire by the pond", "got %d" % fires)


func _check_npcs(w: Node) -> void:
	_ok_if(w.npcs.size() == 3, "three wandering villagers", "got %d" % w.npcs.size())
	var hairs := {}
	for npc in w.npcs:
		hairs[String(npc.hair)] = true
		_ok_if(npc.wander, "%s wanders" % npc.name)
		_ok_if(npc.zone_id == "npc", "%s owns an [E] Sapa zone" % npc.name)
		var body := npc.get_node("Body") as AnimatedSprite2D
		var tex: Texture2D = body.sprite_frames.get_frame_texture("idle", 0)
		_ok_if(tex.get_size() == Vector2(96, 64),
			"%s uses the 96x64 player frame" % npc.name, str(tex.get_size()))
	_ok_if(hairs.size() == 3, "three distinct hair styles", str(hairs.keys()))
	var sari := w.get_node_or_null("Villager") as Node2D
	_ok_if(sari != null, "Bu Sari exists")
	if sari != null:
		var tex2: Texture2D = (sari.get_node("Body") as AnimatedSprite2D) \
			.sprite_frames.get_frame_texture("idle", 0)
		_ok_if(tex2.get_size() == Vector2(96, 64),
			"Bu Sari uses the 96x64 player frame", str(tex2.get_size()))


func _check_particles(w: Node) -> void:
	var leaves := w.village_decor.get_node_or_null("FallingLeaves") as CPUParticles2D
	var ff := w.village_decor.get_node_or_null("Fireflies") as CPUParticles2D
	_ok_if(leaves != null, "falling leaves system exists")
	_ok_if(ff != null, "fireflies system exists")
	if leaves != null:
		_ok_if(not leaves.local_coords, "leaves use world coordinates")
		_ok_if(leaves.emitting, "leaves always emitting")
		_ok_if(leaves.color_ramp != null, "leaves fade in and out")
	if ff != null:
		var mat := ff.material as CanvasItemMaterial
		_ok_if(mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"fireflies are additive so they glow at night")
