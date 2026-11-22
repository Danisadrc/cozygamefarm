class_name FarmHUD
extends CanvasLayer
## HUD for the farm loop. Built entirely from the Sunnyside UI pack.
##
## Layers: top bar (day / clock+phase / gold), an eight-slot hotbar using the
## 9-slice box art, the floating [E] prompt, toasts + floating gold popups, the
## sleep confirmation dialog, the seed-shop panel and the sleep fade.

const BOX_DIR := "res://assets/ui/9slice_box_white/"
const ICON_HOE: Texture2D = preload("res://assets/ui/shovel.png")
const ICON_WATER: Texture2D = preload("res://assets/ui/water.png")
const ICON_SEEDS: Texture2D = preload("res://assets/crops/seeds_generic.png")
const ICON_CLOCK: Texture2D = preload("res://assets/ui/sandtimer.png")
const CROP_DIR := "res://assets/crops/"

const CREAM := Color(0.97, 0.92, 0.8)
const MUTED := Color(0.72, 0.66, 0.55)
const GOLD := Color(0.98, 0.82, 0.35)
const PANEL_BG := Color(0.09, 0.07, 0.05, 0.9)
const PANEL_BORDER := Color(0.52, 0.41, 0.27, 1.0)

const SEED_TINTS := {
	"carrot": Color(1.0, 0.66, 0.32),
	"potato": Color(0.93, 0.83, 0.58),
	"beetroot": Color(0.88, 0.46, 0.62),
	"cabbage": Color(0.62, 0.96, 0.56),
	"cauliflower": Color(0.95, 0.93, 0.78),
	"kale": Color(0.45, 0.78, 0.5),
	"parsnip": Color(0.95, 0.9, 0.7),
	"pumpkin": Color(0.98, 0.6, 0.25),
	"radish": Color(0.96, 0.55, 0.6),
	"sunflower": Color(1.0, 0.86, 0.35),
	"wheat": Color(0.92, 0.82, 0.5),
}

var game: Node

var _day_label: Label
var _clock_label: Label
var _gold_label: Label
var _item_name: Label
var _slot_bgs: Array[NinePatchRect] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _prompt: PanelContainer
var _prompt_label: Label
var _toast: Label
var _toast_tween: Tween
var _shop_root: Control
var _shop_gold: Label
var _shop_rows: VBoxContainer
var _buy_buttons: Array[Dictionary] = []
var _confirm_root: Control
var _confirm_label: Label
var _confirm_cb: Callable
var _fade: ColorRect
var _textures: Dictionary = {}
var _box_cache: Dictionary = {}


func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_hotbar()
	_build_prompt()
	_build_confirm()
	_build_shop()
	_build_toast()
	_build_fade()
	GameState.gold_changed.connect(_on_gold_signal)
	GameState.inventory_changed.connect(_on_inventory_signal)
	GameState.day_changed.connect(_on_day_signal)


func setup(owner_game: Node) -> void:
	game = owner_game
	_build_shop_rows()
	_on_day_signal(GameState.day)
	_on_gold_signal(GameState.gold)
	refresh_hotbar(GameState.hotbar, GameState.selected_slot)


# ------------------------------------------------------------------ build UI

func _build_top_bar() -> void:
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_top = 6
	top.offset_right = -8
	top.offset_bottom = 34
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)

	# Day panel
	var day_panel := _status_panel()
	row.add_child(day_panel)
	_day_label = _label("Hari ke-1", 12, CREAM)
	day_panel.add_child(_day_label)

	# Clock panel (icon + HH:MM + phase)
	var clock_panel := _status_panel()
	row.add_child(clock_panel)
	clock_panel.add_child(_icon(ICON_CLOCK, 14))
	_clock_label = _label("08:00  Pagi", 12, CREAM)
	clock_panel.add_child(_clock_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# Gold panel
	var gold_panel := _status_panel()
	row.add_child(gold_panel)
	_gold_label = _label("100 G", 12, GOLD)
	gold_panel.add_child(_gold_label)


func _build_hotbar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "Hotbar"
	bar.add_theme_constant_override("separation", 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -152
	bar.offset_right = 152
	bar.offset_top = -50
	bar.offset_bottom = -14
	add_child(bar)

	for i in 8:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(34, 34)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.add_child(slot)

		# 9-slice box background (selectbox / 9slice pack).
		var bg := _make_box("lt_", Vector2(34, 34))
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(bg)

		var icon := TextureRect.new()
		icon.position = Vector2(7, 7)
		icon.size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		var key := _label(str(i + 1), 8, Color(0.95, 0.9, 0.74, 0.95))
		key.position = Vector2(3, 0)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(key)

		var count := _label("", 9, CREAM)
		count.position = Vector2(0, 20)
		count.size = Vector2(31, 12)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		count.add_theme_constant_override("outline_size", 3)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)

		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		_slot_bgs.append(bg)
		_slot_icons.append(icon)
		_slot_counts.append(count)

	_item_name = _label("", 10, CREAM)
	_item_name.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_item_name.offset_left = -150
	_item_name.offset_right = 150
	_item_name.offset_top = -70
	_item_name.offset_bottom = -52
	_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_item_name.add_theme_constant_override("outline_size", 3)
	_item_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_item_name)


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_stylebox_override("panel",
		_style(Color(0.08, 0.07, 0.05, 0.94), GOLD, 1, 4, 8, 3))
	add_child(_prompt)

	_prompt_label = _label("[E] Tidur", 11, CREAM)
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(_prompt_label)


func _build_confirm() -> void:
	_confirm_root = Control.new()
	_confirm_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_root.visible = false
	add_child(_confirm_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -140
	panel.offset_right = 140
	panel.offset_top = -54
	panel.offset_bottom = 54
	panel.add_theme_stylebox_override("panel",
		_style(Color(0.12, 0.09, 0.06, 0.99), Color(0.74, 0.57, 0.33, 1.0), 2, 6, 14, 12))
	_confirm_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	_confirm_label = _label("", 12, CREAM)
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.custom_minimum_size = Vector2(240, 0)
	box.add_child(_confirm_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var yes := Button.new()
	yes.text = "Ya"
	yes.custom_minimum_size = Vector2(72, 24)
	yes.add_theme_font_size_override("font_size", 11)
	yes.focus_mode = Control.FOCUS_NONE
	yes.pressed.connect(_on_confirm_yes)
	row.add_child(yes)

	var no := Button.new()
	no.text = "Tidak"
	no.custom_minimum_size = Vector2(72, 24)
	no.add_theme_font_size_override("font_size", 11)
	no.focus_mode = Control.FOCUS_NONE
	no.pressed.connect(close_confirm)
	row.add_child(no)


func _build_shop() -> void:
	_shop_root = Control.new()
	_shop_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_root.visible = false
	add_child(_shop_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_root.add_child(dim)

	# 9-slice Sunnyside panel as the shop background.
	var panel := _make_box("dt_", Vector2(400, 300))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -150
	panel.offset_bottom = 150
	_shop_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	var title := _label("Pedagang Bibit", 15, CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close := Button.new()
	close.text = "Tutup"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(52, 22)
	close.add_theme_font_size_override("font_size", 10)
	close.pressed.connect(_on_close_pressed)
	title_row.add_child(close)

	_shop_gold = _label("Gold: 100 G", 11, GOLD)
	box.add_child(_shop_gold)

	var sep := HSeparator.new()
	box.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_shop_rows = VBoxContainer.new()
	_shop_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_rows.add_theme_constant_override("separation", 3)
	scroll.add_child(_shop_rows)

	var hint := _label("Klik Beli untuk membeli bibit. Esc / Tutup untuk keluar.", 9, MUTED)
	box.add_child(hint)


func _build_toast() -> void:
	_toast = _label("", 10, CREAM)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -220
	_toast.offset_right = 220
	_toast.offset_top = 36
	_toast.offset_bottom = 58
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _build_shop_rows() -> void:
	for child in _shop_rows.get_children():
		child.queue_free()
	_buy_buttons.clear()
	if game == null:
		return
	for entry in DataRegistry.get_shop_entries():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_shop_rows.add_child(row)

		var crop := String(entry.get("crop", entry.get("id", "")))
		var seed_icon := _icon(ICON_SEEDS, 18)
		seed_icon.modulate = SEED_TINTS.get(crop, Color.WHITE)
		row.add_child(seed_icon)

		var name := _label(String(entry["name"]), 11, CREAM)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)

		var sell := _label("Jual %dG" % int(entry.get("sell", 0)), 9, MUTED)
		sell.custom_minimum_size = Vector2(62, 0)
		sell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(sell)

		var price := _label("%d G" % int(entry["price"]), 11, GOLD)
		price.custom_minimum_size = Vector2(48, 0)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(price)

		var buy := Button.new()
		buy.text = "Beli"
		buy.focus_mode = Control.FOCUS_NONE
		buy.custom_minimum_size = Vector2(52, 22)
		buy.add_theme_font_size_override("font_size", 10)
		buy.pressed.connect(_on_buy_pressed.bind(String(entry["id"])))
		row.add_child(buy)
		_buy_buttons.append({"id": entry["id"], "button": buy, "price": int(entry["price"])})


# ------------------------------------------------------------------ live data

func set_day(day: int) -> void:
	if _day_label != null:
		_day_label.text = "Hari ke-%d" % day


func set_gold(gold: int) -> void:
	if _gold_label != null:
		_gold_label.text = "%d G" % gold


func refresh_hotbar(items: Array[Dictionary], selected: int) -> void:
	for i in _slot_bgs.size():
		if i >= items.size():
			continue
		var item: Dictionary = items[i]
		var tex: Texture2D = null
		var tint := Color.WHITE
		var count_text := ""
		match String(item.get("type", "")):
			"tool":
				tex = ICON_HOE if String(item.get("tool", "")) == "hoe" else ICON_WATER
			"seed":
				tex = ICON_SEEDS
				tint = SEED_TINTS.get(String(item.get("crop", "")), Color.WHITE)
				count_text = "x%d" % int(item.get("count", 0))
			"produce":
				var crop := String(item.get("crop", ""))
				var amount := int(item.get("count", 0))
				if amount > 0:
					tex = _load_texture(CROP_DIR + crop + "_05.png")
				count_text = ("x%d" % amount) if amount > 0 else ""
		_slot_icons[i].texture = tex
		_slot_icons[i].modulate = tint
		_slot_counts[i].text = count_text
		_slot_counts[i].modulate = Color(1, 1, 1, 1) if int(item.get("count", 1)) > 0 else Color(1, 1, 1, 0.4)
		var is_sel := (i == selected)
		_slot_bgs[i].texture = _compose_box("w_" if is_sel else "lt_")
		_slot_bgs[i].modulate = GOLD if is_sel else Color.WHITE

	if selected >= 0 and selected < items.size():
		_item_name.text = _display_name(items[selected])
	else:
		_item_name.text = ""


func show_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt.visible = true
	_prompt.reset_size()


func hide_prompt() -> void:
	_prompt.visible = false


func toast(text: String, duration := 2.2) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.45)


## Floating "+XX G" popup that rises and fades in the centre of the screen.
func pop_gold(amount: int) -> void:
	var lbl := _label("+%d G" % amount, 18, GOLD)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	lbl.position = Vector2(-60, -40)
	lbl.size = Vector2(120, 30)
	var start := lbl.position
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", start + Vector2(0, -36), 1.1)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.1)
	tw.chain().tween_callback(lbl.queue_free)


# ------------------------------------------------------------------ confirm

func open_confirm(text: String, on_yes: Callable) -> void:
	_confirm_label.text = text
	_confirm_cb = on_yes
	_confirm_root.visible = true
	_confirm_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_confirm_root, "modulate:a", 1.0, 0.12)


func close_confirm() -> void:
	_confirm_root.visible = false


func is_confirm_open() -> bool:
	return _confirm_root != null and _confirm_root.visible


func _on_confirm_yes() -> void:
	var cb := _confirm_cb
	_confirm_cb = Callable()
	_confirm_root.visible = false
	if cb.is_valid():
		cb.call()


# ------------------------------------------------------------------ shop

func open_shop(gold: int) -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_item_name.visible = false
	refresh_shop(gold)
	_shop_root.visible = true
	_shop_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_shop_root, "modulate:a", 1.0, 0.14)


func close_shop() -> void:
	_shop_root.visible = false
	_item_name.visible = true


func refresh_shop(gold: int) -> void:
	if _shop_gold == null:
		return
	_shop_gold.text = "Gold: %d G" % gold
	for entry in _buy_buttons:
		entry["button"].disabled = gold < int(entry["price"])


func fade_to(alpha: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", alpha, duration)
	return tw


# ------------------------------------------------------------------ per frame

func _process(_delta: float) -> void:
	# Live clock + phase.
	if _clock_label != null:
		_clock_label.text = "%s  %s" % [GameState.time_string(), GameState.phase_name()]
	if _day_label != null:
		_day_label.text = "Hari ke-%d" % GameState.day
	if _gold_label != null:
		_gold_label.text = "%d G" % GameState.gold
	# Keep the floating prompt above the player's head.
	if not _prompt.visible or game == null or not is_instance_valid(game.player):
		return
	var player: CharacterBody2D = game.player
	var screen := get_viewport().get_canvas_transform() * (player.global_position + Vector2(0, -30))
	_prompt.reset_size()
	var vp := get_viewport().get_visible_rect().size
	screen.x = clampf(screen.x, _prompt.size.x * 0.5 + 6.0, vp.x - _prompt.size.x * 0.5 - 6.0)
	screen.y = clampf(screen.y, 28.0, vp.y - 80.0)
	_prompt.position = (screen - Vector2(_prompt.size.x * 0.5, _prompt.size.y + 4.0)).round()


# ------------------------------------------------------------------ signals

func _on_gold_signal(new_gold: int) -> void:
	set_gold(new_gold)


func _on_day_signal(new_day: int) -> void:
	set_day(new_day)


func _on_inventory_signal() -> void:
	refresh_hotbar(GameState.hotbar, GameState.selected_slot)


# ------------------------------------------------------------------ helpers

func _display_name(item: Dictionary) -> String:
	match String(item.get("type", "")):
		"tool":
			return "Cangkul" if String(item.get("tool", "")) == "hoe" else "Penyiram"
		"seed":
			return "Bibit %s" % DataRegistry.crop_name(String(item.get("crop", "")))
		"produce":
			var amount := int(item.get("count", 0))
			if amount <= 0:
				return "Tangan kosong"
			return "%s x%d" % [DataRegistry.crop_name(String(item.get("crop", ""))), amount]
	return "Tangan kosong"


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game != null:
			game.select_slot(index)


func _on_buy_pressed(id: String) -> void:
	if game != null:
		game.buy_seed(id)


func _on_close_pressed() -> void:
	if game != null:
		game.close_shop()


func _load_texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = load(path)
	_textures[path] = tex
	return tex


# ---- 9-slice composition from the individual 3x3 Sunnyside pieces ----

func _compose_box(prefix: String) -> Texture2D:
	if _box_cache.has(prefix):
		return _box_cache[prefix]
	var layout := [
		["tl", 0, 0], ["tc", 1, 0], ["tr", 2, 0],
		["lc", 0, 1], ["c", 1, 1], ["rc", 2, 1],
		["bl", 0, 2], ["bc", 1, 2], ["br", 2, 2],
	]
	var full := Image.new()
	full.create(9, 9, false, Image.FORMAT_RGBA8)
	full.fill(Color(0, 0, 0, 0))
	for e in layout:
		var path := "%s%sbox_9slice_%s.png" % [BOX_DIR, prefix, e[0]]
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		full.blit_rect(img, Rect2i(0, 0, 3, 3), Vector2i(int(e[1]) * 3, int(e[2]) * 3))
	var out := ImageTexture.create_from_image(full)
	_box_cache[prefix] = out
	return out


func _make_box(prefix: String, min_size: Vector2) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = _compose_box(prefix)
	np.patch_margin_left = 3
	np.patch_margin_top = 3
	np.patch_margin_right = 3
	np.patch_margin_bottom = 3
	np.custom_minimum_size = min_size
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return np


func _icon(tex: Texture2D, size_px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(size_px, size_px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _status_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL_BG, PANEL_BORDER, 1, 3, 8, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _style(bg: Color, border: Color, width: int, radius: int,
		pad_x: int, pad_y: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style