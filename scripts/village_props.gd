extends Node2D
## One hand-drawn village prop: street lamp, barrel, chest, park bench, well,
## campfire stones, or a flower bed.
##
## Everything is drawn from plain rects and circles, the same trick quest_board.gd
## uses, so the village can be dressed without new art. None of these props own a
## collider - they are decoration only, and the walkable paths must stay clear.

const IRON := Color8(58, 54, 66)
const IRON_LIGHT := Color8(96, 90, 106)
const WOOD := Color8(128, 90, 52)
const WOOD_DARK := Color8(86, 58, 32)
const WOOD_LIGHT := Color8(162, 120, 74)
const METAL := Color8(122, 128, 142)
const STONE := Color8(154, 160, 172)
const STONE_DARK := Color8(104, 110, 124)
const WATER := Color8(58, 86, 116)
const BRASS := Color8(232, 196, 96)
const SOIL := Color8(84, 58, 38)
const STEM := Color8(74, 126, 60)

const FLOWER_COLORS := [
	Color8(232, 96, 112), Color8(246, 208, 92),
	Color8(212, 132, 226), Color8(242, 242, 236),
]

## Sampled from the baked-in road tiles, so a cottage path reads as the same
## sandy track as the main street.
const ROAD := Color8(228, 166, 114)
const ROAD_DARK := Color8(208, 146, 100)
const ROAD_LIGHT := Color8(234, 176, 126)
const ROAD_EDGE := Color8(196, 136, 92)

var kind := "lamp"
var variant := 0
## Length of a "path" strip, drawn downwards from this node's origin.
var length := 48.0

## 0..1 dusk factor: lamps glow and campfires burn brighter after sunset.
##
## The glow itself is a separate additive child node: the world darkens with a
## CanvasModulate at night, so a normally-blended warm colour would just turn
## muddy grey. Additive blending adds light back on top of the darkened scene,
## which is what makes the lamps read as switched on.
var lit := 0.0:
	set(value):
		lit = value
		if _glow != null:
			_glow.strength = _glow_alpha()
			_glow.queue_redraw()

var _glow: Glow = null


## Additive light blob. Kept as an inner class so it can be built without a
## second script file, and so the draw call is fully local to this prop.
## A glow can have several blobs (a lamp has its halo plus a pool on the grass).
class Glow extends Node2D:
	## Each entry is [offset: Vector2, radius: float, squash: Vector2, weight: float].
	var blobs: Array = []
	var tint := Color(1.0, 0.86, 0.5)
	var strength := 0.0

	func _draw() -> void:
		if strength <= 0.01:
			return
		for b in blobs:
			draw_set_transform(Vector2(b[0]), 0.0, Vector2(b[2]))
			draw_circle(Vector2.ZERO, float(b[1]),
				Color(tint.r, tint.g, tint.b, strength * float(b[3])))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ready() -> void:
	if kind != "lamp" and kind != "fire":
		return
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = Glow.new()
	_glow.name = "Glow"
	_glow.material = mat
	_glow.z_index = 1
	if kind == "lamp":
		# Bright core on the glass pane, a warm halo around it, and a soft pool
		# of light on the ground below. The core is what sells "switched on":
		# the pane itself is multiplied by the night CanvasModulate, so only an
		# additive highlight can push it back towards white.
		_glow.blobs = [
			[Vector2(8.5, -43.5), 5.0, Vector2.ONE, 1.0],
			[Vector2(8.5, -43.5), 15.0, Vector2.ONE, 0.30],
			[Vector2(0, -1), 14.0, Vector2(1.8, 0.5), 0.16],
		]
	else:
		_glow.tint = Color(1.0, 0.62, 0.24)
		# No bright core: the animated flame sprite already provides it, and a
		# second additive highlight on top just washes the flame out to white.
		_glow.blobs = [
			[Vector2(0, -6), 15.0, Vector2(1.05, 0.9), 0.30],
			[Vector2(0, 0), 19.0, Vector2(1.6, 0.55), 0.20],
		]
	add_child(_glow)


func _glow_alpha() -> float:
	if kind == "fire":
		return 0.7 * lit
	return 0.55 * lit


func _draw() -> void:
	match kind:
		"lamp":
			_draw_lamp()
		"barrel":
			_draw_barrel()
		"chest":
			_draw_chest()
		"bench":
			_draw_bench()
		"well":
			_draw_well()
		"fire":
			_draw_fire()
		"flowers":
			_draw_flowers()
		"path":
			_draw_path()


func _draw_lamp() -> void:
	draw_rect(Rect2(-4, -4, 8, 4), IRON)          # base
	draw_rect(Rect2(-1, -36, 3, 33), IRON)        # pole
	draw_rect(Rect2(-1, -36, 1, 33), IRON_LIGHT)  # pole highlight
	draw_rect(Rect2(0, -38, 8, 2), IRON)          # arm

	draw_rect(Rect2(4, -49, 9, 11), IRON)                                  # housing
	draw_rect(Rect2(5, -48, 7, 9), Color(1.0, 0.9, 0.62, 0.3 + 0.7 * lit))  # pane
	draw_rect(Rect2(3, -51, 11, 2), IRON_LIGHT)                            # cap
	draw_rect(Rect2(5, -50, 7, 1), IRON)


func _draw_barrel() -> void:
	draw_rect(Rect2(-6, -15, 12, 15), WOOD)
	draw_rect(Rect2(-6, -15, 3, 15), WOOD_LIGHT)
	draw_rect(Rect2(-6, -15, 12, 2), WOOD_DARK)
	draw_rect(Rect2(-6, -10, 12, 1), METAL)
	draw_rect(Rect2(-6, -5, 12, 1), METAL)
	draw_rect(Rect2(-6, -1, 12, 1), WOOD_DARK)
	if variant == 1:
		draw_rect(Rect2(-2, -12, 4, 4), BRASS)


func _draw_chest() -> void:
	draw_rect(Rect2(-8, -10, 16, 10), WOOD)         # body
	draw_rect(Rect2(-8, -15, 16, 5), WOOD_LIGHT)    # lid
	draw_rect(Rect2(-8, -10, 16, 1), WOOD_DARK)
	draw_rect(Rect2(-8, -15, 16, 1), WOOD_DARK)
	draw_rect(Rect2(-6, -15, 2, 15), METAL)         # bands
	draw_rect(Rect2(4, -15, 2, 15), METAL)
	draw_rect(Rect2(-1, -8, 3, 4), BRASS)           # lock


func _draw_bench() -> void:
	draw_rect(Rect2(-13, -5, 3, 5), WOOD_DARK)      # legs
	draw_rect(Rect2(10, -5, 3, 5), WOOD_DARK)
	draw_rect(Rect2(-13, -12, 2, 4), WOOD_DARK)     # back posts
	draw_rect(Rect2(11, -12, 2, 4), WOOD_DARK)
	draw_rect(Rect2(-15, -8, 30, 3), WOOD)          # seat
	draw_rect(Rect2(-15, -8, 30, 1), WOOD_LIGHT)
	draw_rect(Rect2(-15, -15, 30, 3), WOOD)         # back rest
	draw_rect(Rect2(-15, -15, 30, 1), WOOD_LIGHT)


func _draw_well() -> void:
	draw_rect(Rect2(-11, -34, 2, 20), WOOD_DARK)    # posts
	draw_rect(Rect2(9, -34, 2, 20), WOOD_DARK)
	draw_circle(Vector2(0, -8), 13.0, STONE_DARK)   # stone ring
	draw_circle(Vector2(0, -9), 11.0, STONE)
	draw_circle(Vector2(0, -9), 8.0, WATER)
	draw_rect(Rect2(-14, -37, 28, 3), WOOD)         # roof beam
	draw_rect(Rect2(-14, -37, 28, 1), WOOD_LIGHT)
	draw_rect(Rect2(-1, -34, 1, 13), Color8(198, 188, 162))  # rope
	draw_rect(Rect2(-3, -22, 6, 5), WOOD)           # bucket
	draw_rect(Rect2(-3, -22, 6, 1), WOOD_LIGHT)


func _draw_fire() -> void:
	# Ash pit.
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.5, 0.55))
	draw_circle(Vector2.ZERO, 9.0, Color8(52, 44, 40))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Ring of stones: two rows so it reads as a ring from this top-down angle.
	var ring := [
		Vector2(-13, -5), Vector2(-5, -6), Vector2(4, -6), Vector2(11, -5),
	]
	for p in ring:
		draw_rect(Rect2(p.x, p.y, 5, 3), STONE)
	for p in [Vector2(-11, -2), Vector2(-2, -3), Vector2(7, -2)]:
		draw_rect(Rect2(p.x, p.y, 5, 3), STONE_DARK)

	# Two crossed logs, drawn as boxes so the pixel edges stay crisp.
	draw_rect(Rect2(-9, -4, 18, 3), WOOD_DARK)
	draw_rect(Rect2(-9, -4, 18, 1), Color8(112, 78, 44))
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.6))
	draw_rect(Rect2(-8, -3, 16, 3), WOOD)
	draw_rect(Rect2(-8, -3, 16, 1), WOOD_LIGHT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Glowing embers between the logs.
	if lit > 0.02:
		draw_rect(Rect2(-5, -2, 10, 2), Color(1.0, 0.55, 0.2, 0.35 + 0.6 * lit))


func _draw_flowers() -> void:
	draw_rect(Rect2(-15, -3, 30, 4), SOIL)
	draw_rect(Rect2(-15, -3, 30, 1), Color8(104, 74, 48))
	var count := 5 + variant % 3
	for i in count:
		var x := -12 + i * 5
		draw_rect(Rect2(x, -8, 1, 6), STEM)
		var c: Color = FLOWER_COLORS[(i + variant) % FLOWER_COLORS.size()]
		draw_rect(Rect2(x - 1, -10, 3, 2), c)
		draw_rect(Rect2(x, -11, 1, 1), c)


## A short sandy track from a cottage door down to the street or the front
## garden. Decoration only: no collider, so it can never block a walkable tile.
func _draw_path() -> void:
	var w := 20.0
	draw_rect(Rect2(-w * 0.5, 0, w, length), ROAD_EDGE)
	draw_rect(Rect2(-w * 0.5 + 1.0, 0, w - 2.0, length), ROAD)
	# Lighter wheel-worn centre and a scattering of darker grit.
	draw_rect(Rect2(-5.0, 0, 10.0, length), ROAD_LIGHT)
	var rows := int(length / 8.0)
	for i in rows:
		var n := (i * 37 + variant * 11) % 6
		var px := -7.0 + float(n % 5) * 3.0
		var py := float(i) * 8.0 + float(n)
		if py < length - 3.0:
			draw_rect(Rect2(px, py, 2, 2), ROAD_DARK)
