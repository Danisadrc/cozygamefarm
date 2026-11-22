extends SceneTree
## Headless acceptance test for res://scenes/world.tscn
##
## Checks the things that are easy to break while regenerating the scene: the
## ground is covered, the cottage is solid except at its door, the farm is the
## right size and its gate is open, the pond and cliff actually block, the hair
## overlay exists, and a BFS walk from the spawn reaches every interaction zone.

const FARM_GATE := Vector2i(17, 25)
const SPAWN_TILE := Vector2i(26, 16)


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/world.tscn")
	if packed == null:
		printerr("GAGAL: world.tscn tidak bisa dimuat")
		quit(1)
		return

	var w := packed.instantiate()
	root.add_child(w)

	var ok := true
	var fail := func(msg: String) -> void:
		printerr("GAGAL: " + msg)

	# ---------------------------------------------------------------- layers
	for name in ["GroundLayer", "FarmSoilLayer", "DecorLayer"]:
		var n := w.get_node_or_null(name)
		if n == null:
			fail.call("layer %s tidak ada" % name)
			ok = false
			continue
		var count: int = (n as TileMapLayer).get_used_cells().size()
		print("layer %-14s cells=%d" % [name, count])
		if count == 0:
			fail.call("layer %s kosong" % name)
			ok = false

	# ---------------------------------------------------------------- grass
	var grass := w.get_node_or_null("Grass") as Sprite2D
	if grass == null:
		fail.call("Grass tidak ada")
		ok = false
	elif grass.texture == null:
		fail.call("Grass tanpa tekstur")
		ok = false
	else:
		print("rumput: %s repeat=%d region=%s"
			% [grass.texture.resource_path.get_file(), grass.texture_repeat, grass.region_rect.size])

	# ---------------------------------------------------------------- cottage
	var house := w.get_node_or_null("House")
	if house == null:
		fail.call("House tidak ada")
		ok = false
	else:
		var walls := 0
		for c in house.get_children():
			if c is CollisionShape2D:
				walls += 1
		print("rumah: %d collider dinding" % walls)
		if walls < 2:
			fail.call("rumah butuh 2 collider (kiri/kanan pintu)")
			ok = false

	# ---------------------------------------------------------------- zones
	for zname in ["DoorZone", "ShippingBinZone", "MerchantZone"]:
		var n := w.get_node_or_null("Zones/" + zname)
		if n == null or n.get_node_or_null("Shape") == null:
			fail.call("zona %s tidak lengkap" % zname)
			ok = false
		else:
			print("zona %-18s interaction=%s" % [zname, n.get_meta("interaction", "-")])

	# ---------------------------------------------------------------- farm
	var soil := w.get_node("FarmSoilLayer") as TileMapLayer
	var used := soil.get_used_cells()
	if used.is_empty():
		fail.call("lahan kosong")
		ok = false
	else:
		var r := soil.get_used_rect()
		print("lahan: %dx%d tile di (%d,%d)" % [r.size.x, r.size.y, r.position.x, r.position.y])
		if r.size.x < 12 or r.size.y < 8:
			fail.call("lahan kurang dari 12x8")
			ok = false

	# ---------------------------------------------------------------- fence
	var fence := w.get_node_or_null("FarmFence")
	if fence == null:
		fail.call("FarmFence tidak ada")
		ok = false
	else:
		var rails := 0
		for c in fence.get_node_or_null("Rails").get_children():
			if c is CollisionShape2D:
				rails += 1
		print("pagar: %d collider" % rails)
		if rails < 5:
			fail.call("pagar butuh 5 collider (2 utara + selatan + 2 samping)")
			ok = false
		var segs := 0
		for c in fence.get_children():
			if c is Sprite2D:
				segs += 1
		print("pagar: %d segmen sprite" % segs)
		if segs != 7:
			fail.call("pagar butuh 7 segmen, ada %d" % segs)
			ok = false

	# ---------------------------------------------------------------- blockers
	for p in ["Pond", "Cliff", "ShippingBin", "Merchant"]:
		var n := w.get_node_or_null(p)
		if n == null:
			fail.call("%s tidak ada" % p)
			ok = false
		elif not (n is StaticBody2D):
			fail.call("%s bukan StaticBody2D" % p)
			ok = false
		else:
			var shapes := 0
			for c in n.get_children():
				if c is CollisionShape2D:
					shapes += 1
			print("%-12s collider=%d" % [p, shapes])
			if shapes == 0:
				fail.call("%s tanpa collision" % p)
				ok = false

	# ---------------------------------------------------------------- player
	var player := w.get_node_or_null("Player")
	if player == null:
		fail.call("Player tidak ada")
		ok = false
	else:
		if player.get_node_or_null("Sprite") == null:
			fail.call("Player/Sprite tidak ada")
			ok = false
		if player.get_node_or_null("Hair") == null:
			fail.call("Player/Hair tidak ada")
			ok = false
		else:
			print("rambut: overlay ada")

	# ---------------------------------------------------------------- props
	var trees := 0
	for c in w.get_children():
		if c.name.begins_with("Tree_"):
			trees += 1
	print("pohon: %d" % trees)
	if trees < 10:
		fail.call("pohon kurang dari 10")
		ok = false

	# ---------------------------------------------------------------- walkable
	# BFS over the tile grid. The pond and the fence are StaticBody2D colliders
	# rather than tiles now, so they are rasterised back onto the grid from
	# their own shape sizes: that is the same information the player hits.
	var blocked := {}

	# Every StaticBody2D under World blocks: fence, pond, cliff, house, bin,
	# stall, crates, stumps, trees. Rasterising them all keeps the reachability
	# answer honest instead of testing a world that is not there.
	_rasterise_all(blocked, w)

	# the cliff band and the strip of ground under it are never walkable
	for y in range(0, 3):
		for x in range(60):
			blocked[Vector2i(x, y)] = true

	var bounds := Rect2i(0, 0, 60, 40)
	var reach := _flood(blocked, SPAWN_TILE, bounds)
	print("tile terjangkau: %d" % reach.size())

	if reach.is_empty():
		fail.call("spawn %s terhalang" % SPAWN_TILE)
		ok = false

	for zname in ["DoorZone", "ShippingBinZone", "MerchantZone"]:
		var z := w.get_node("Zones/" + zname) as Node2D
		var tile := Vector2i(floori(z.global_position.x / 16.0), floori(z.global_position.y / 16.0))
		var hit := _nearest_reachable(reach, tile)
		if hit == Vector2i(-1, -1):
			fail.call("%s tidak bisa dijangkau dari spawn" % zname)
			ok = false
		else:
			print("rute ke %-18s lewat tile %s" % [zname, hit])

	if not reach.has(FARM_GATE):
		fail.call("gerbang lahan %s tidak terjangkau" % FARM_GATE)
		ok = false
	else:
		print("gerbang lahan terjangkau di %s" % FARM_GATE)

	var inside := Vector2i(FARM_GATE.x, FARM_GATE.y + 2)
	if not reach.has(inside):
		fail.call("dalam lahan %s tidak terjangkau" % inside)
		ok = false
	else:
		print("dalam lahan terjangkau di %s" % inside)

	# the pond must be closed off, or the water is decoration only
	var pond_cell := Vector2i(46, 30)
	if reach.has(pond_cell):
		fail.call("kolam %s bisa diinjak" % pond_cell)
		ok = false
	else:
		print("kolam tertutup di %s" % pond_cell)

	print("")
	print("HASIL: %s" % ("LULUS" if ok else "GAGAL"))
	quit(0 if ok else 1)


func _rasterise_all(blocked: Dictionary, node: Node) -> void:
	for c in node.get_children():
		if c is StaticBody2D:
			for s in c.get_children():
				if s is CollisionShape2D:
					_rasterise(blocked, c, s)
		else:
			_rasterise_all(blocked, c)


func _rasterise(blocked: Dictionary, body: Node2D, col: CollisionShape2D) -> void:
	var shape := col.shape as RectangleShape2D
	if shape == null:
		return
	var centre: Vector2 = body.global_position + col.position
	var half: Vector2 = shape.size * 0.5
	var x0 := floori((centre.x - half.x) / 16.0)
	var x1 := floori((centre.x + half.x - 0.01) / 16.0)
	var y0 := floori((centre.y - half.y) / 16.0)
	var y1 := floori((centre.y + half.y - 0.01) / 16.0)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			blocked[Vector2i(x, y)] = true


func _flood(blocked: Dictionary, start: Vector2i, bounds: Rect2i) -> Dictionary:
	var seen := {}
	if blocked.has(start):
		return seen
	seen[start] = true
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nxt: Vector2i = cur + d
			if not bounds.has_point(nxt):
				continue
			if seen.has(nxt) or blocked.has(nxt):
				continue
			seen[nxt] = true
			queue.push_back(nxt)
	return seen


func _nearest_reachable(reach: Dictionary, target: Vector2i) -> Vector2i:
	for r in range(0, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := target + Vector2i(dx, dy)
				if reach.has(t):
					return t
	return Vector2i(-1, -1)
