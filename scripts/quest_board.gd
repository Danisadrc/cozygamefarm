extends Node2D
## Quest board — a small wooden notice board outside the market stall.
##
## Drawn from plain rects so it needs no extra art, with a bobbing "!" emote
## above it. The `[E] Papan Misi` zone lives in world_game.

const ALERT_TEX := "res://assets/ui/expression_alerted.png"

const POST := Color8(92, 62, 36)
const POST_DARK := Color8(64, 42, 24)
const PLANK := Color8(126, 88, 50)
const PLANK_EDGE := Color8(76, 50, 29)
const PAPER := Color8(236, 221, 182)
const INK := Color8(118, 92, 64)


func _ready() -> void:
	z_index = 9

	var marker := Sprite2D.new()
	marker.name = "Alert"
	marker.texture = load(ALERT_TEX)
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.position = Vector2(0, -42)
	marker.z_index = 11
	add_child(marker)

	var tw := create_tween().set_loops()
	tw.tween_property(marker, "position:y", -46.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(marker, "position:y", -42.0, 0.8).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	# Legs, sunk into the grass.
	draw_rect(Rect2(-9, -14, 4, 16), POST)
	draw_rect(Rect2(5, -14, 4, 16), POST)
	draw_rect(Rect2(-9, 0, 4, 2), POST_DARK)
	draw_rect(Rect2(5, 0, 4, 2), POST_DARK)
	# Board face with a darker frame.
	draw_rect(Rect2(-16, -32, 32, 19), PLANK_EDGE)
	draw_rect(Rect2(-15, -31, 30, 17), PLANK)
	draw_rect(Rect2(-13, -29, 4, 12), Color(0.72, 0.55, 0.34, 0.28))
	# Pinned parchment with three lines of writing.
	draw_rect(Rect2(-11, -28, 22, 11), PAPER)
	draw_rect(Rect2(-11, -28, 22, 11), Color(0.55, 0.44, 0.3, 0.8), false, 1.0)
	draw_rect(Rect2(-9, -26, 18, 1), INK)
	draw_rect(Rect2(-9, -23, 14, 1), INK)
	draw_rect(Rect2(-9, -20, 16, 1), INK)