extends Node2D
## Stone-tiled plaza under the market stall and the quest board.
##
## Pure floor: no colliders, so it can never change the BFS paths. Drawn as a
## grid of 16px slabs in the same blue-grey palette as the Sunnyside tileset's
## own stone platform, with a darker border and a few scattered pebbles, so it
## reads as part of the map art rather than a pasted rectangle.

var plaza := Rect2(636, 288, 196, 64)

## Sampled from the tileset stone block (atlas rows 14-15): light slab top,
## mid slab body, dark grout.
const SLAB_TOP := Color8(192, 203, 220)
const SLAB_A := Color8(160, 172, 194)
const SLAB_B := Color8(148, 161, 186)
const SLAB_C := Color8(136, 149, 176)
const GROUT := Color8(97, 111, 141)
const EDGE := Color8(70, 82, 110)
const PEBBLE := Color8(186, 197, 214)

const TILE := 16


func _draw() -> void:
	draw_rect(plaza, GROUT)

	var cols := int(ceil(plaza.size.x / TILE))
	var rows := int(ceil(plaza.size.y / TILE))
	for row in rows:
		for col in cols:
			var p := plaza.position + Vector2(col * TILE, row * TILE)
			var cell := Rect2(p + Vector2(1, 1), Vector2(TILE - 2, TILE - 2))
			# Keep the slabs inside the plaza rect even if it is not a multiple
			# of 16 (the right/bottom cells get clipped).
			cell = cell.intersection(plaza)
			if cell.size.x <= 0.0 or cell.size.y <= 0.0:
				continue
			# Deterministic pseudo-random shade so the floor looks worn rather
			# than tiled, but is identical every run.
			var n := (row * 31 + col * 17 + row * col * 7) % 7
			var shade := SLAB_A
			if n == 0 or n == 3:
				shade = SLAB_B
			elif n == 5:
				shade = SLAB_C
			draw_rect(cell, shade)
			# Lit top edge of each slab.
			if cell.size.y >= 3.0:
				draw_rect(Rect2(cell.position, Vector2(cell.size.x, 1)), SLAB_TOP)
			# Occasional pebble.
			if n == 2 and cell.size.x >= 12.0 and cell.size.y >= 12.0:
				draw_rect(Rect2(cell.position + Vector2(5, 7), Vector2(3, 2)), PEBBLE)
			elif n == 4 and cell.size.x >= 12.0 and cell.size.y >= 12.0:
				draw_rect(Rect2(cell.position + Vector2(9, 5), Vector2(2, 2)), PEBBLE)

	# A one-pixel darker frame around the whole plaza.
	draw_rect(Rect2(plaza.position, Vector2(plaza.size.x, 1)), EDGE)
	draw_rect(Rect2(plaza.position + Vector2(0, plaza.size.y - 1),
		Vector2(plaza.size.x, 1)), EDGE)
	draw_rect(Rect2(plaza.position, Vector2(1, plaza.size.y)), EDGE)
	draw_rect(Rect2(plaza.position + Vector2(plaza.size.x - 1, 0),
		Vector2(1, plaza.size.y)), EDGE)
