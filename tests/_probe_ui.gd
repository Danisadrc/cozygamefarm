extends SceneTree

func _initialize() -> void:
	var dir := "res://assets/ui/9slice_box_white/"
	for name in ["lt_box_9slice_tl.png", "lt_box_9slice_c.png", "selectbox_tl.png"]:
		var path := dir + name if name.begins_with("lt_") else "res://assets/ui/" + name
		var tex: Texture2D = load(path)
		if tex == null:
			print("NULL: ", path)
			continue
		var img := tex.get_image()
		print("%s -> tex=%s img=%s" % [path.get_file(), tex.get_size(), (img.get_size() if img != null else "null")])
	quit(0)