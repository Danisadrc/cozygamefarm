extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/world.tscn")
	if packed == null:
		print("FAILED TO LOAD WORLD")
		quit()
		return
	var world: Node = packed.instantiate()
	var soil: TileMapLayer = world.get_node("FarmSoilLayer")
	var cells := soil.get_used_cells()
	print("SOIL CELL COUNT: ", cells.size())
	print("SOIL CELLS: ", cells)
	if cells.size() > 0:
		var min_x := 9999
		var max_x := -9999
		var min_y := 9999
		var max_y := -9999
		for c in cells:
			min_x = mini(min_x, c.x)
			max_x = maxi(max_x, c.x)
			min_y = mini(min_y, c.y)
			max_y = maxi(max_y, c.y)
		print("SOIL BOUNDS: x %d..%d  y %d..%d" % [min_x, max_x, min_y, max_y])
	var player: Node2D = world.get_node("Player")
	print("PLAYER POS: ", player.position)
	for zone_name in ["DoorZone", "ShippingBinZone", "MerchantZone"]:
		var zone: Area2D = world.get_node("Zones/" + zone_name)
		var shape: CollisionShape2D = zone.get_node("Shape")
		var rect: Vector2 = (shape.shape as RectangleShape2D).size
		print("%s pos=%s rect=%s" % [zone_name, zone.position, rect])
	for crop in ["Crop_carrot_01", "Crop_cabbage_00", "Crop_beetroot_00", "Crop_radish_00"]:
		var n: Sprite2D = world.get_node(crop)
		print("%s pos=%s" % [crop, n.position])
	world.free()
	quit()
