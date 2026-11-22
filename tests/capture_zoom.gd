extends SceneTree
## Capture a zoomed in-engine view of a region of world.tscn.
## Usage: --script res://tests/capture_zoom.gd -- <x> <y> <zoom> <outfile> [player_x player_y]

var _frames := 0
var _args := {}
var _view: Camera2D
var _world: Node


func _initialize() -> void:
	var raw := OS.get_cmdline_user_args()
	var cx := float(raw[0]) if raw.size() > 0 else 288.0
	var cy := float(raw[1]) if raw.size() > 1 else 160.0
	var zm := float(raw[2]) if raw.size() > 2 else 2.0
	_args = {"cx": cx, "cy": cy, "zoom": zm,
		"out": raw[3] if raw.size() > 3 else "res://zoom_shot.png",
		"px": float(raw[4]) if raw.size() > 4 else NAN,
		"py": float(raw[5]) if raw.size() > 5 else NAN}


func _process(_delta: float) -> bool:
	_frames += 1

	if _frames == 1:
		_view = Camera2D.new()
		_view.position = Vector2(_args["cx"], _args["cy"])
		_view.zoom = Vector2(_args["zoom"], _args["zoom"])
		root.add_child(_view)

		_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
		var cam := _world.get_node_or_null("Player/Camera") as Camera2D
		if cam:
			cam.get_parent().remove_child(cam)
			cam.free()
		root.add_child(_world)

		if not is_nan(_args["px"]):
			var p := _world.get_node_or_null("Player") as Node2D
			if p:
				p.position = Vector2(_args["px"], _args["py"])
		return false

	if _frames == 2:
		_view.make_current()
		return false

	if _frames < 7:
		return false

	var img := root.get_texture().get_image()
	img.save_png(_args["out"])
	print("saved %s %s" % [_args["out"], img.get_size()])
	return true
