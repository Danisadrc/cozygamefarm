extends Node2D
## Village dressing: two extra cottages, a stone plaza under the market, street
## lamps, barrels, chests, a bench and campfire by the pond, flower beds along
## the road, and the falling leaves / fireflies that come out in the afternoon.
##
## The cottages are built here instead of being baked into world.tscn so their
## colliders stay small and deliberate: each one is a single 112x26 shape at the
## base of the walls, which keeps every road tile in validate_world.gd walkable.
## Every other prop is decoration with no collider at all.
##
## Cottages and props are added as children of the World node (not of this node)
## so they y-sort against the player and the trees exactly like the baked-in
## scenery does.

const PROPS_SCRIPT := preload("res://scripts/village_props.gd")
const PLAZA_SCRIPT := preload("res://scripts/plaza_floor.gd")
const PROP_ANIM := preload("res://scripts/prop_anim.gd")

## Cottage art: recolours of the farmhouse, so the village houses share its
## proportions and palette instead of using the tileset atlas fragments.
const COTTAGE_DIR := "res://assets/generated/cottage_%s.png"
const HOUSE_SIZE := Vector2(112, 112)
## Collider: 112 wide, 26 tall, sitting on the bottom of the facade.
const HOUSE_BASE := Vector2(112, 26)

const FIRE_SHEET := "res://assets/decor/vfx/fire/spr_deco_fire_02_strip4.png"

## Positions are node origins (bottom-centre of the 112x112 facade). Both spots
## were checked against the baked-in road tiles and colliders: the whole 7x7
## tile footprint is free grass and the row in front of each door is walkable.
## The fourth value is the length of the sandy track that runs from the door
## down towards the street (or the front garden).
const COTTAGES := [
	["Cottage_NE", Vector2(776, 240), "green", 46.0],
	["Cottage_SE", Vector2(464, 544), "orange", 26.0],
]

## Street lamps line both sides of the road; the two cottages get their own
## lamp by the door. Nothing here has a collider.
const LAMPS := [
	# north verge of the main road
	Vector2(200, 346), Vector2(392, 346), Vector2(612, 346),
	# market plaza corners
	Vector2(646, 292), Vector2(822, 292),
	# south verge
	Vector2(96, 408), Vector2(312, 408), Vector2(470, 408),
	Vector2(862, 408), Vector2(930, 408),
	# cottage door lamps
	Vector2(712, 242), Vector2(408, 546),
]

const BARRELS := [
	Vector2(858, 302), Vector2(872, 318), Vector2(700, 344), Vector2(714, 344),
	Vector2(540, 566), Vector2(554, 566),
]

const CHESTS := [
	Vector2(866, 648), Vector2(628, 302), Vector2(536, 560),
]

const FLOWER_BEDS := [
	Vector2(240, 344), Vector2(330, 344), Vector2(430, 344), Vector2(500, 344),
	Vector2(58, 410), Vector2(112, 410), Vector2(152, 410),
	Vector2(862, 412), Vector2(920, 412),
	Vector2(742, 246), Vector2(444, 556),
]

var game: Node

var _lamps: Array = []
var _fires: Array = []
var _leaves: CPUParticles2D
var _fireflies: CPUParticles2D
var _leaf_alpha := 0.0
var _fire_alpha := 0.0
var _lamp_lit := 0.0


func setup(owner_game: Node) -> void:
	game = owner_game
	_build()


func _build() -> void:
	_add_plaza()
	for c in COTTAGES:
		_add_cottage(String(c[0]), Vector2(c[1]), String(c[2]), float(c[3]))
	for p in LAMPS:
		_add_lamp(p)
	for p in BARRELS:
		_add_prop("barrel", p, "Barrel")
	for p in CHESTS:
		_add_prop("chest", p, "Chest")
	for p in FLOWER_BEDS:
		_add_prop("flowers", p, "FlowerBed")
	# Pond south bank: the bench and the campfire sit in the gaps between the
	# baked-in tree canopies (Tree_29 at x=544, Tree_30/31 at x=624/640,
	# Tree_32 at x=752), so neither of them is hidden behind a trunk.
	_add_prop("bench", Vector2(584, 594), "ParkBench")
	_add_fire(Vector2(700, 594), "Campfire")
	_add_particles()


# ================================================================ builders

func _add_plaza() -> void:
	var plaza = PLAZA_SCRIPT.new()
	plaza.name = "MarketPlaza"
	plaza.z_index = 2
	get_parent().add_child(plaza)


func _add_cottage(node_name: String, pos: Vector2, colour: String, path_len: float) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.z_index = 10
	body.position = pos
	get_parent().add_child(body)

	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = load(COTTAGE_DIR % colour)
	spr.centered = false
	spr.position = Vector2(-HOUSE_SIZE.x * 0.5, -HOUSE_SIZE.y)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(spr)

	var col := CollisionShape2D.new()
	col.name = "Base"
	var rect := RectangleShape2D.new()
	rect.size = HOUSE_BASE
	col.shape = rect
	col.position = Vector2(0, -HOUSE_BASE.y * 0.5)
	body.add_child(col)

	# Sandy track from the door to the street. Drawn as a sibling (not a child)
	# so it y-sorts on the ground and is never hidden by the facade.
	if path_len > 0.0:
		var path = PROPS_SCRIPT.new()
		path.name = node_name + "_Path"
		path.kind = "path"
		path.length = path_len
		path.position = pos
		path.z_index = 1
		get_parent().add_child(path)


func _add_prop(kind: String, pos: Vector2, node_name: String, variant := 0) -> Node2D:
	var prop = PROPS_SCRIPT.new()
	prop.name = "%s_%d" % [node_name, get_parent().get_child_count()]
	prop.kind = kind
	prop.variant = variant
	prop.position = pos
	prop.z_index = 10
	get_parent().add_child(prop)
	return prop


func _add_lamp(pos: Vector2) -> void:
	var lamp := _add_prop("lamp", pos, "StreetLamp")
	_lamps.append(lamp)


func _add_fire(pos: Vector2, node_name: String) -> void:
	var prop := _add_prop("fire", pos, node_name)
	var flame = AnimatedSprite2D.new()
	flame.name = "Flame"
	flame.set_script(PROP_ANIM)
	flame.sheet = load(FIRE_SHEET)
	flame.frame_count = 4
	flame.fps = 9.0
	flame.frame_size = Vector2i(8, 12)
	flame.offset = Vector2(0, -10)
	flame.z_index = 1
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prop.add_child(flame)
	_fires.append(prop)


# ================================================================ particles

## Both systems follow the camera target with world-space particles, so the
## density stays constant no matter where the player walks: a map-wide emitter
## would put only a handful of particles inside the 388x218 camera window.
## The alpha ramp makes each particle fade in and out, so they never pop.

func _add_particles() -> void:
	_leaves = CPUParticles2D.new()
	_leaves.name = "FallingLeaves"
	_leaves.texture = _leaf_texture()
	_leaves.local_coords = false
	_leaves.position = Vector2(480, 320)
	_leaves.z_index = 12
	_leaves.amount = 96
	_leaves.lifetime = 7.0
	_leaves.preprocess = 4.0
	_leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_leaves.emission_rect_extents = Vector2(200, 120)
	_leaves.direction = Vector2(0, 1)
	_leaves.spread = 30.0
	_leaves.initial_velocity_min = 4.0
	_leaves.initial_velocity_max = 12.0
	_leaves.gravity = Vector2(9, 13)
	_leaves.angular_velocity_min = -110.0
	_leaves.angular_velocity_max = 110.0
	_leaves.scale_amount_min = 1.0
	_leaves.scale_amount_max = 1.6
	_leaves.color = Color(1, 1, 1, 0.95)
	_leaves.color_ramp = _fade_ramp()
	# Always emitting, faded in/out by modulate.a: `preprocess` only runs while
	# the system is emitting, so toggling emitting on would leave the first
	# seconds empty and the leaves would trickle in one at a time.
	_leaves.emitting = true
	_leaves.modulate.a = 0.0
	add_child(_leaves)

	_fireflies = CPUParticles2D.new()
	_fireflies.name = "Fireflies"
	_fireflies.texture = _firefly_texture()
	# Additive so the dots actually glow through the night CanvasModulate.
	var ff_mat := CanvasItemMaterial.new()
	ff_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fireflies.material = ff_mat
	_fireflies.local_coords = false
	_fireflies.position = Vector2(480, 320)
	_fireflies.z_index = 12
	_fireflies.amount = 44
	_fireflies.lifetime = 6.0
	_fireflies.preprocess = 4.0
	_fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fireflies.emission_rect_extents = Vector2(190, 115)
	_fireflies.direction = Vector2(0, -1)
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 2.0
	_fireflies.initial_velocity_max = 8.0
	_fireflies.gravity = Vector2.ZERO
	_fireflies.scale_amount_min = 1.0
	_fireflies.scale_amount_max = 1.8
	_fireflies.color = Color(1.0, 0.96, 0.62, 0.95)
	_fireflies.color_ramp = _fade_ramp()
	_fireflies.emitting = true
	_fireflies.modulate.a = 0.0
	add_child(_fireflies)


## Transparent -> opaque -> transparent, so a particle never pops in or out.
## The opaque span is generous so most live particles are actually visible.
func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.08, 0.88, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0),
	])
	return g


## A 7x7 autumn leaf: warm ochre body, darker vein, and a lighter highlight so
## it stays readable against the grass at 1.65x zoom.
func _leaf_texture() -> ImageTexture:
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color8(226, 132, 62)
	var dark := Color8(170, 84, 40)
	var light := Color8(244, 178, 96)
	# Leaf silhouette (rounded diamond).
	var rows := {
		1: [2, 3, 4],
		2: [1, 2, 3, 4, 5],
		3: [1, 2, 3, 4, 5],
		4: [2, 3, 4, 5],
		5: [3, 4],
	}
	for y in rows:
		for x in rows[y]:
			img.set_pixelv(Vector2i(x, y), body)
	img.set_pixelv(Vector2i(3, 1), light)
	img.set_pixelv(Vector2i(2, 2), light)
	img.set_pixelv(Vector2i(4, 3), dark)
	img.set_pixelv(Vector2i(3, 4), dark)
	# Little stem.
	img.set_pixelv(Vector2i(3, 5), dark)
	img.set_pixelv(Vector2i(3, 6), dark)
	return ImageTexture.create_from_image(img)


func _firefly_texture() -> ImageTexture:
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var core := Color(1.0, 1.0, 0.78, 1.0)
	var halo := Color(0.95, 1.0, 0.5, 0.42)
	for p in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(4, 2), Vector2i(2, 4)]:
		img.set_pixelv(p, halo)
	img.set_pixelv(Vector2i(2, 2), core)
	img.set_pixelv(Vector2i(1, 2), core)
	img.set_pixelv(Vector2i(3, 2), core)
	img.set_pixelv(Vector2i(2, 1), core)
	img.set_pixelv(Vector2i(2, 3), core)
	return ImageTexture.create_from_image(img)


# ================================================================ dusk mood

func _process(delta: float) -> void:
	var phase: String = GameState.phase_name()
	var leaf_target := 1.0 if phase == "Sore" else 0.0
	var fire_target := 1.0 if phase == "Malam" else 0.0
	var lamp_target := 1.0 if phase in ["Sore", "Malam"] else 0.0

	_leaf_alpha = move_toward(_leaf_alpha, leaf_target, delta * 0.7)
	_fire_alpha = move_toward(_fire_alpha, fire_target, delta * 0.7)
	_lamp_lit = move_toward(_lamp_lit, lamp_target, delta * 0.8)

	if _leaves != null:
		_leaves.modulate.a = _leaf_alpha
	if _fireflies != null:
		_fireflies.modulate.a = _fire_alpha

	# Keep the weather centred on the player so the particle density is the same
	# wherever the camera happens to be.
	if game != null and game.player != null:
		var focus: Vector2 = game.player.global_position
		if _leaves != null:
			_leaves.position = focus
		if _fireflies != null:
			_fireflies.position = focus

	for lamp in _lamps:
		if is_instance_valid(lamp):
			lamp.lit = _lamp_lit
			lamp.queue_redraw()
	for fire in _fires:
		if is_instance_valid(fire):
			fire.lit = maxf(_lamp_lit, _fire_alpha)
			fire.queue_redraw()
