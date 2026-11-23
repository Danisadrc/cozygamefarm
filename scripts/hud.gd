class_name FarmHUD
extends CanvasLayer
## HUD for the farm loop. Built entirely from the Sunnyside UI pack.
##
## Layers: top bar (day / clock+phase / gold), a five-slot hotbar using the
## 9-slice box art, the backpack panel ([I]/[Tab]) with its 5x3 grid, the
## floating [E] prompt, toasts + floating gold popups, the sleep confirmation
## dialog, the seed-shop panel and the sleep fade.

const BOX_DIR := "res://assets/ui/9slice_box_white/"
const ICON_HOE: Texture2D = preload("res://assets/ui/shovel.png")
const ICON_WATER: Texture2D = preload("res://assets/ui/water.png")
const ICON_AXE: Texture2D = preload("res://assets/ui/axe.png")
const ICON_PICKAXE: Texture2D = preload("res://assets/ui/pickaxe.png")
const ICON_ROD: Texture2D = preload("res://assets/ui/rod.png")
const TOOL_ICONS := {
	"hoe": ICON_HOE,
	"water": ICON_WATER,
	"axe": ICON_AXE,
	"pickaxe": ICON_PICKAXE,
}
const ICON_BAG: Texture2D = preload("res://assets/ui/basket.png")
const ICON_SEEDS: Texture2D = preload("res://assets/crops/seeds_generic.png")
const ICON_CLOCK: Texture2D = preload("res://assets/ui/sandtimer.png")
const ICON_STOPWATCH: Texture2D = preload("res://assets/ui/stopwatch.png")
const ICON_ENERGY: Texture2D = preload("res://assets/ui/plant.png")
const ICON_WOOD: Texture2D = preload("res://assets/crops/wood.png")
const ICON_ROCK: Texture2D = preload("res://assets/crops/rock.png")
const ICON_FISH: Texture2D = preload("res://assets/crops/fish.png")
const ICON_EGG: Texture2D = preload("res://assets/crops/egg.png")
const ICON_MILK: Texture2D = preload("res://assets/crops/milk.png")
const BAR_EMPTY: Texture2D = preload("res://assets/ui/greenbar_00.png")
const BAR_FULL: Texture2D = preload("res://assets/ui/greenbar_06.png")
const BAR_RED: Texture2D = preload("res://assets/ui/redbar_06.png")
const FISH_TRACK: Texture2D = preload("res://assets/ui/bluebar_03.png")
const CROP_DIR := "res://assets/crops/"

# Bars are assembled from the real 15x7 Sunnyside pieces: a 2px left cap, a
# 2px right cap and a tiled 11px middle, so they are never stretched/blurred.
const BAR_W := 72
const BAR_H := 7
const BAR_CAP := 2
const BAR_MID := 11

const CREAM := Color(0.97, 0.92, 0.8)
const MUTED := Color(0.72, 0.66, 0.55)
const GOLD := Color(0.98, 0.82, 0.35)
const OUTLINE := Color(0.05, 0.04, 0.03, 0.95)
const PANEL_BG := Color(0.09, 0.07, 0.05, 0.9)
const PANEL_BORDER := Color(0.52, 0.41, 0.27, 1.0)

const STAM_GREEN := Color8(99, 199, 77)
const STAM_YELLOW := Color8(244, 202, 74)
const STAM_RED := Color8(228, 59, 68)

const PHASE_COLORS := {
	"Pagi": Color8(140, 208, 110),
	"Siang": Color8(248, 205, 86),
	"Sore": Color8(238, 150, 96),
	"Malam": Color8(148, 168, 232),
}

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
var _phase_label: Label
var _gold_label: Label
var _stamina_bar: TextureProgressBar
var _stamina_text: Label
var _stamina_hint: Label
var _bar_green: Texture2D
var _bar_yellow: Texture2D
var _bar_red: Texture2D
var _item_name: Label
var _slot_bgs: Array[NinePatchRect] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _prompt: PanelContainer
var _prompt_label: Label
var _prompt_anchor := Vector2.ZERO
var _prompt_has_anchor := false
var _toast: Label
var _toast_tween: Tween
var _shop_root: Control
var _shop_gold: Label
var _shop_rows: VBoxContainer
var _shop_hint: Label
var _shop_tab := "seeds"
var _shop_seed_btn: Button
var _shop_tool_btn: Button
var _buy_buttons: Array[Dictionary] = []
var _upgrade_buttons: Array[Dictionary] = []
var _confirm_root: Control
var _confirm_label: Label
var _confirm_cb: Callable
var _confirm_cancel_cb: Callable
var _fade: ColorRect
var _textures: Dictionary = {}
var _box_cache: Dictionary = {}

# Village quest tracker (top-right, under the gold panel)
var _quest_panel: PanelContainer
var _quest_head: Label
var _quest_title: Label
var _quest_goals: VBoxContainer

# Villager / quest-board dialogue (bottom 9-slice box)
var _dialog_root: Control
var _dialog_speaker: Label
var _dialog_hearts: Label
var _dialog_text: Label
var _dialog_gift_btn: Button
var _dialog_order_btn: Button
var _dialog_gift_name := ""
var _dialog_order_label := ""
var _dialog_open := false

# "Dapur Api Unggun" campfire cooking panel
var _cook_root: Control
var _cook_rows: VBoxContainer
var _cook_body: Label

# "Desa Berhasil Renovasi!" demo-complete screen
var _complete_root: Control
var _complete_summary: Label
var _complete_cb: Callable

# Fishing mini-game
var _fish_root: Control
var _fish_zone: ColorRect
var _fish_marker: ColorRect
var _fishing := false
var _fish_pos := 0.0
var _fish_dir := 1.0
var _fish_zone_c := 0.5
var _fish_zone_h := 0.11
var _fish_time := 7.0
var _fish_cb: Callable
const FISH_TRACK_W := 68.0
const FISH_SPEED := 1.15

# Pause menu (Esc)
var _pause_root: Control
var _pause_clock: Label

# Backpack panel ([I] / [Tab]) — 15 backpack slots above 5 active hotbar slots.
var _bag_root: Control
var _bag_toggle: Button
var _bag_slot_bgs: Array[NinePatchRect] = []
var _bag_slot_icons: Array[TextureRect] = []
var _bag_slot_counts: Array[Label] = []
var _bag_hot_bgs: Array[NinePatchRect] = []
var _bag_hot_icons: Array[TextureRect] = []
var _bag_hot_counts: Array[Label] = []
var _bag_sel_zone := ""
var _bag_sel_index := -1
var _bag_info_icon: TextureRect
var _bag_info_name: Label
var _bag_info_sell: Label
var _bag_info_stam: Label
var _bag_eat_btn: Button
var _bag_drop_btn: Button


func _ready() -> void:
	# The HUD keeps running while the tree is paused: it owns the pause menu,
	# so it has to be able to un-pause itself.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_prepare_bar_textures()
	_build_top_bar()
	_build_hotbar()
	_build_backpack()
	_build_prompt()
	_build_confirm()
	_build_shop()
	_build_dialogue()
	_build_cooking()
	_build_quest_complete()
	_build_toast()
	_build_fade()
	_build_fishing()
	_build_pause()
	GameState.gold_changed.connect(_on_gold_signal)
	GameState.inventory_changed.connect(_on_inventory_signal)
	GameState.day_changed.connect(_on_day_signal)
	GameState.stamina_changed.connect(_on_stamina_signal)
	GameState.quest_changed.connect(_on_quest_signal)


func setup(owner_game: Node) -> void:
	game = owner_game
	_build_shop_rows()
	_on_day_signal(GameState.day)
	_on_gold_signal(GameState.gold)
	refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	refresh_backpack()
	refresh_quest()


# ------------------------------------------------------------------ build UI

func _build_top_bar() -> void:
	var row := HBoxContainer.new()
	row.name = "TopBar"
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = 6
	row.offset_top = 4
	row.offset_right = -6
	row.offset_bottom = 84
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	# Left column: clock/day panel with the stamina bar right underneath.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	left.add_child(_build_clock_panel())
	left.add_child(_build_stamina_panel())

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# Right column: gold panel with the active-quest tracker underneath.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)

	# Gold + the small bag icon share the top-right row, so the quest tracker
	# underneath keeps its original height.
	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_END
	gold_row.add_theme_constant_override("separation", 4)
	gold_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(gold_row)

	var gold_panel := _status_panel("dt_")
	gold_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gold_row.add_child(gold_panel)
	_gold_label = _label("100 G", 11, GOLD)
	_gold_label.add_theme_color_override("font_outline_color", OUTLINE)
	_gold_label.add_theme_constant_override("outline_size", 3)
	gold_panel.add_child(_gold_label)

	_bag_toggle = Button.new()
	_bag_toggle.name = "BagButton"
	_bag_toggle.icon = ICON_BAG
	_bag_toggle.tooltip_text = "Tas Ransel [I]"
	_bag_toggle.custom_minimum_size = Vector2(26, 20)
	_bag_toggle.focus_mode = Control.FOCUS_NONE
	_bag_toggle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bag_toggle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bag_toggle.add_theme_stylebox_override("normal", _button_box("lt_"))
	_bag_toggle.add_theme_stylebox_override("hover", _button_box("w_"))
	_bag_toggle.add_theme_stylebox_override("pressed", _button_box("dt_"))
	_bag_toggle.pressed.connect(toggle_backpack)
	gold_row.add_child(_bag_toggle)

	right.add_child(_build_quest_tracker())


## Compact "MISI 1/3 — title / goal progress" card.
func _build_quest_tracker() -> PanelContainer:
	_quest_panel = _status_panel("lt_")
	_quest_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_panel.add_child(col)

	_quest_head = _label("MISI 1/3", 8, MUTED)
	_outline(_quest_head, 3)
	col.add_child(_quest_head)

	_quest_title = _label("Petani Pemula", 10, GOLD)
	_outline(_quest_title, 3)
	col.add_child(_quest_title)

	_quest_goals = VBoxContainer.new()
	_quest_goals.add_theme_constant_override("separation", 0)
	_quest_goals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_quest_goals)
	return _quest_panel


## Rebuilds the tracker card from GameState (called on every quest signal).
func refresh_quest() -> void:
	if _quest_goals == null:
		return
	for child in _quest_goals.get_children():
		_quest_goals.remove_child(child)
		child.queue_free()
	if GameState.quest_done:
		_quest_head.text = "MISI SELESAI"
		_quest_title.text = "Cozy Valley Makmur!"
		var done := _label("Terima kasih, petani.", 8, STAM_GREEN)
		_outline(done, 3)
		_quest_goals.add_child(done)
		return
	var quest: Dictionary = GameState.current_quest()
	if quest.is_empty():
		return
	_quest_head.text = "MISI %d/%d" % [GameState.quest_index + 1, GameState.QUESTS.size()]
	_quest_title.text = String(quest.get("title", ""))
	for p in GameState.quest_progress():
		var is_done := bool(p["done"])
		var line := _label("%s %d/%d" % [String(p["label"]), int(p["have"]), int(p["need"])],
			8, STAM_GREEN if is_done else CREAM)
		_outline(line, 3)
		_quest_goals.add_child(line)


## "Hari 1 • 06:00" on the first row, phase badge on the second.
func _build_clock_panel() -> PanelContainer:
	var panel := _status_panel("dt_")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	row.add_child(_icon(ICON_STOPWATCH, 12, true))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)

	_day_label = _label("Hari 1", 10, CREAM)
	_outline(_day_label, 3)
	line.add_child(_day_label)

	line.add_child(_label("•", 9, MUTED))

	_clock_label = _label("06:00", 10, CREAM)
	_outline(_clock_label, 3)
	line.add_child(_clock_label)

	_phase_label = _label("Pagi", 8, PHASE_COLORS["Pagi"])
	_outline(_phase_label, 3)
	_phase_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_stylebox_override("normal",
		_badge_style(PHASE_COLORS["Pagi"]))
	col.add_child(_phase_label)
	return panel


## Sprout icon + greenbar + "100/100", with the "[F] Makan" hint under 50%.
func _build_stamina_panel() -> PanelContainer:
	var panel := _status_panel("dt_")

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)

	line.add_child(_icon(ICON_ENERGY, 10, true))

	_stamina_bar = TextureProgressBar.new()
	_stamina_bar.texture_under = _bar_texture(BAR_EMPTY, BAR_W, Color.WHITE)
	_stamina_bar.texture_progress = _bar_green
	_stamina_bar.nine_patch_stretch = true
	_stamina_bar.stretch_margin_left = BAR_CAP
	_stamina_bar.stretch_margin_right = BAR_CAP
	_stamina_bar.max_value = GameState.MAX_STAMINA
	_stamina_bar.value = GameState.stamina
	_stamina_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_stamina_bar.custom_minimum_size = Vector2(BAR_W, BAR_H)
	_stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stamina_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_stamina_bar)

	_stamina_text = _label("%d/%d" % [GameState.stamina, GameState.MAX_STAMINA], 8, CREAM)
	_outline(_stamina_text, 3)
	_stamina_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_stamina_text)

	# Hint row, indented so it starts under the bar, not under the icon.
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 0)
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint_row)

	var indent := Control.new()
	indent.custom_minimum_size = Vector2(15, 0)
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(indent)

	_stamina_hint = _label("[F] Makan", 8, Color8(255, 226, 148))
	_outline(_stamina_hint, 3)
	_stamina_hint.visible = false
	hint_row.add_child(_stamina_hint)
	return panel


func _build_hotbar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "Hotbar"
	bar.add_theme_constant_override("separation", 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -93
	bar.offset_right = 93
	bar.offset_top = -50
	bar.offset_bottom = -14
	add_child(bar)

	for i in GameState.MAX_SLOTS:
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


## The backpack overlay: 15 slots (5x3) on the left, the 5 active hotbar slots
## underneath, and a compact item-info column with Makan / Buang 1 on the right.
func _build_backpack() -> void:
	_bag_root = Control.new()
	_bag_root.name = "Backpack"
	_bag_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bag_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag_root.visible = false
	add_child(_bag_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag_root.add_child(dim)

	var panel := _make_box("dt_", Vector2(420, 250))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -125
	panel.offset_bottom = 125
	_bag_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	# ---- left: backpack grid + active hotbar row
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 3)
	box.add_child(left)

	var title := _label("TAS RANSEL  15 SLOT", 11, GOLD)
	_outline(title, 3)
	left.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	left.add_child(grid)
	for i in GameState.BACKPACK_SLOTS:
		_make_bag_slot(grid, "backpack", i, "")

	left.add_child(HSeparator.new())

	var hot_title := _label("HOTBAR AKTIF", 9, MUTED)
	_outline(hot_title, 3)
	left.add_child(hot_title)

	var hot_row := HBoxContainer.new()
	hot_row.add_theme_constant_override("separation", 3)
	left.add_child(hot_row)
	for i in GameState.MAX_SLOTS:
		_make_bag_slot(hot_row, "hotbar", i, str(i + 1))

	var hint := _label(
		"Klik slot untuk memilih, lalu klik slot lain untuk tukar/mindah. [I]/[Tab]/[Esc] tutup.",
		8, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(170, 0)
	left.add_child(hint)

	# ---- right: selected-item info + quick actions
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(112, 0)
	right.add_theme_constant_override("separation", 3)
	box.add_child(right)

	var info_title := _label("INFO ITEM", 9, MUTED)
	_outline(info_title, 3)
	right.add_child(info_title)

	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(icon_row)

	_bag_info_icon = TextureRect.new()
	_bag_info_icon.custom_minimum_size = Vector2(30, 30)
	_bag_info_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bag_info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bag_info_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bag_info_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(_bag_info_icon)

	_bag_info_name = _label("Pilih item", 11, CREAM)
	_bag_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bag_info_name.custom_minimum_size = Vector2(112, 0)
	_outline(_bag_info_name, 3)
	right.add_child(_bag_info_name)

	_bag_info_sell = _label("Jual: -", 9, GOLD)
	_outline(_bag_info_sell, 3)
	right.add_child(_bag_info_sell)

	_bag_info_stam = _label("Stamina: -", 9, STAM_GREEN)
	_outline(_bag_info_stam, 3)
	right.add_child(_bag_info_stam)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(spacer)

	_bag_eat_btn = _pause_button("Makan", _on_bag_eat)
	_bag_eat_btn.tooltip_text = "Makan 1 item terpilih"
	right.add_child(_bag_eat_btn)

	_bag_drop_btn = _pause_button("Buang 1", _on_bag_drop)
	_bag_drop_btn.tooltip_text = "Buang 1 item terpilih"
	right.add_child(_bag_drop_btn)

	right.add_child(_pause_button("Tutup", close_backpack))


func _make_bag_slot(parent: Control, zone: String, index: int, key_text: String) -> void:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(30, 30)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(slot)

	var bg := _make_box("lt_", Vector2(30, 30))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)

	var icon := TextureRect.new()
	icon.position = Vector2(6, 6)
	icon.size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var count := _label("", 9, CREAM)
	count.position = Vector2(0, 17)
	count.size = Vector2(27, 12)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	count.add_theme_constant_override("outline_size", 3)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count)

	if key_text != "":
		var key := _label(key_text, 8, Color(0.95, 0.9, 0.74, 0.95))
		key.position = Vector2(2, 0)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(key)

	slot.gui_input.connect(_on_bag_slot_input.bind(zone, index))
	if zone == "backpack":
		_bag_slot_bgs.append(bg)
		_bag_slot_icons.append(icon)
		_bag_slot_counts.append(count)
	else:
		_bag_hot_bgs.append(bg)
		_bag_hot_icons.append(icon)
		_bag_hot_counts.append(count)


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

	# Two tabs: seedlings and tool upgrades.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	box.add_child(tabs)
	_shop_seed_btn = _pause_button("Beli Bibit", _set_shop_tab.bind("seeds"))
	_shop_seed_btn.custom_minimum_size = Vector2(104, 24)
	tabs.add_child(_shop_seed_btn)
	_shop_tool_btn = _pause_button("Upgrade Alat", _set_shop_tab.bind("tools"))
	_shop_tool_btn.custom_minimum_size = Vector2(104, 24)
	tabs.add_child(_shop_tool_btn)

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

	_shop_hint = _label("Klik Beli untuk membeli bibit. Esc / Tutup untuk keluar.", 9, MUTED)
	box.add_child(_shop_hint)


func _build_dialogue() -> void:
	_dialog_root = Control.new()
	_dialog_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_root.visible = false
	add_child(_dialog_root)

	# Sunnyside 9-slice box pinned above the hotbar so it never covers the
	# inventory slots or the held-item name.
	var panel := _make_box("dt_", Vector2(528, 96))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 56
	panel.offset_right = -56
	panel.offset_top = -196
	panel.offset_bottom = -76
	_dialog_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)

	_dialog_speaker = _label("Warga", 11, GOLD)
	_dialog_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outline(_dialog_speaker, 3)
	head.add_child(_dialog_speaker)

	_dialog_hearts = _label("", 11, Color8(255, 128, 154))
	_dialog_hearts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline(_dialog_hearts, 3)
	head.add_child(_dialog_hearts)

	_dialog_text = _label("", 10, CREAM)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog_text.custom_minimum_size = Vector2(0, 38)
	box.add_child(_dialog_text)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	box.add_child(foot)

	_dialog_gift_btn = _pause_button("Beri Hadiah", _on_dialog_gift)
	_dialog_gift_btn.tooltip_text = "Hadiahkan item yang sedang dipegang"
	_dialog_gift_btn.custom_minimum_size = Vector2(104, 22)
	_dialog_gift_btn.visible = false
	foot.add_child(_dialog_gift_btn)

	_dialog_order_btn = _pause_button("Serahkan Pesanan", _on_dialog_order)
	_dialog_order_btn.tooltip_text = "Tukar item pesanan harian dengan gold"
	_dialog_order_btn.custom_minimum_size = Vector2(132, 22)
	_dialog_order_btn.visible = false
	foot.add_child(_dialog_order_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(spacer)

	var hint := _label("[E] / [Esc] Tutup", 8, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(hint)


## Heart string for the dialogue header: "♥♥♡♡♡".
func hearts_text(hearts: int) -> String:
	var filled := clampi(hearts, 0, 5)
	return "♥".repeat(filled) + "♡".repeat(5 - filled)


func open_dialogue(speaker: String, text: String, hearts := -1,
		gift_name := "", order_label := "") -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_dialog_speaker.text = speaker
	_dialog_text.text = text
	_dialog_hearts.text = hearts_text(hearts) if hearts >= 0 else ""
	_dialog_hearts.visible = hearts >= 0
	_dialog_gift_name = gift_name
	_dialog_gift_btn.visible = gift_name != ""
	_dialog_order_label = order_label
	_dialog_order_btn.visible = order_label != ""
	_dialog_root.visible = true
	_dialog_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_dialog_root, "modulate:a", 1.0, 0.12)
	_dialog_open = true


## Rewrite the open dialogue in place (used by the quest board after delivery).
func update_dialogue(text: String, order_label := "") -> void:
	_dialog_text.text = text
	_dialog_order_label = order_label
	_dialog_order_btn.visible = order_label != ""


func _on_dialog_order() -> void:
	if game != null:
		game.submit_daily_order()


## Repaint the header hearts / gift button after a gift was accepted.
func set_dialogue_gift(hearts: int, gift_name := "") -> void:
	if _dialog_hearts != null:
		_dialog_hearts.text = hearts_text(hearts)
		_dialog_hearts.visible = true
	_dialog_gift_name = gift_name
	if _dialog_gift_btn != null:
		_dialog_gift_btn.visible = gift_name != ""


func _on_dialog_gift() -> void:
	if game != null and _dialog_gift_name != "":
		game.give_gift(_dialog_gift_name)


func close_dialogue() -> void:
	_dialog_open = false
	if _dialog_root != null:
		_dialog_root.visible = false


func is_dialogue_open() -> bool:
	return _dialog_open


# ------------------------------------------------------------------ cooking

## "Dapur Api Unggun": four recipes, live ingredient stock, one Masak button each.
func _build_cooking() -> void:
	_cook_root = Control.new()
	_cook_root.name = "Cooking"
	_cook_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cook_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_cook_root.visible = false
	add_child(_cook_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.66)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_cook_root.add_child(dim)

	var panel := _make_box("dt_", Vector2(456, 300))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -228
	panel.offset_right = 228
	panel.offset_top = -150
	panel.offset_bottom = 150
	_cook_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	var title := _label("Dapur Api Unggun", 17, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outline(title, 4)
	title_row.add_child(title)
	var close := _pause_button("Tutup", close_cooking)
	close.custom_minimum_size = Vector2(54, 22)
	title_row.add_child(close)

	_cook_body = _label(
		"Masak hasil ladang dan ternak. Bahan diambil dari tas; masakan bisa dimakan [F] atau dijual.",
		9, MUTED)
	_cook_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cook_body)

	box.add_child(HSeparator.new())

	_cook_rows = VBoxContainer.new()
	_cook_rows.add_theme_constant_override("separation", 4)
	box.add_child(_cook_rows)

	var hint := _label("[E] / [Esc] Tutup", 8, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)


func refresh_cooking() -> void:
	if _cook_rows == null:
		return
	for child in _cook_rows.get_children():
		_cook_rows.remove_child(child)
		child.queue_free()

	for recipe in DataRegistry.get_food_recipes():
		var id := String(recipe["id"])
		var ingredients: Dictionary = recipe.get("ingredients", {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		_cook_rows.add_child(row)

		var icon := _icon(_produce_icon(id), 22)
		icon.modulate = DataRegistry.item_tint(id)
		row.add_child(icon)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)

		var name := _label("%s  +%d stamina" % [String(recipe["name"]),
			int(recipe["stamina"])], 11, CREAM)
		_outline(name, 3)
		col.add_child(name)

		var parts: Array[String] = []
		var enough := true
		for ing in ingredients.keys():
			var have := GameState.count_item(String(ing))
			var need := int(ingredients[ing])
			if have < need:
				enough = false
			parts.append("%s %d/%d" % [DataRegistry.ingredient_name(String(ing)),
				have, need])
		var req := _label("Bahan: " + " • ".join(parts), 8,
			STAM_GREEN if enough else Color8(236, 118, 118))
		_outline(req, 3)
		col.add_child(req)

		var sell := _label("Jual %d G" % int(recipe["sell"]), 9, GOLD)
		sell.custom_minimum_size = Vector2(58, 0)
		sell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sell)

		var btn := _pause_button("Masak", _on_cook_pressed.bind(id))
		btn.custom_minimum_size = Vector2(58, 22)
		btn.disabled = not GameState.can_cook(id)
		row.add_child(btn)


func _on_cook_pressed(id: String) -> void:
	if game != null and game.cook_recipe(id):
		refresh_cooking()


func open_cooking() -> void:
	if _cook_root == null or _cook_root.visible:
		return
	if is_any_overlay_open():
		return
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	refresh_cooking()
	_cook_root.visible = true
	_cook_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_cook_root, "modulate:a", 1.0, 0.12)
	SfxPlayer.play("pet")
	if game != null and game.has_method("on_cooking_toggled"):
		game.on_cooking_toggled(true)


func close_cooking() -> void:
	if _cook_root == null or not _cook_root.visible:
		return
	_cook_root.visible = false
	if game != null and game.has_method("on_cooking_toggled"):
		game.on_cooking_toggled(false)


func is_cooking_open() -> bool:
	return _cook_root != null and _cook_root.visible


func _build_quest_complete() -> void:
	_complete_root = Control.new()
	_complete_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_complete_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_complete_root.visible = false
	add_child(_complete_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_complete_root.add_child(dim)

	var panel := _make_box("dt_", Vector2(420, 220))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -118
	panel.offset_bottom = 118
	_complete_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := _label("Cozy Valley Makmur!", 18, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(title, 4)
	box.add_child(title)

	var sub := _label("Desa Agung • Demo Selesai", 12, CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(sub, 3)
	box.add_child(sub)

	var sep := HSeparator.new()
	box.add_child(sep)

	_complete_summary = _label("", 10, CREAM)
	_complete_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_complete_summary.custom_minimum_size = Vector2(360, 0)
	box.add_child(_complete_summary)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	box.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	var again := Button.new()
	again.text = "Lanjut Bermain Bebas"
	again.custom_minimum_size = Vector2(190, 28)
	again.add_theme_font_size_override("font_size", 11)
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(_on_complete_pressed)
	row.add_child(again)


func show_quest_complete(days: int, gold: int, on_continue: Callable,
		stats := {}) -> void:
	_complete_cb = on_continue
	_complete_summary.text = "Total hari: %d   •   Total gold: %d G\nHidangan dimasak: %d   •   Hadiah diberikan: %d\nUpgrade alat: %d   •   Hati warga: %d\n\nTerima kasih sudah membangun Cozy Valley!" \
		% [days, gold, int(stats.get("cooked", 0)), int(stats.get("gifts", 0)),
			int(stats.get("upgrades", 0)), int(stats.get("hearts", 0))]
	_complete_root.visible = true
	_complete_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_complete_root, "modulate:a", 1.0, 0.25)


func hide_quest_complete() -> void:
	_complete_root.visible = false


func is_quest_complete_open() -> bool:
	return _complete_root != null and _complete_root.visible


func _on_complete_pressed() -> void:
	var cb := _complete_cb
	_complete_cb = Callable()
	_complete_root.visible = false
	if cb.is_valid():
		cb.call()


func _build_toast() -> void:
	_toast = _label("", 10, CREAM)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -220
	_toast.offset_right = 220
	_toast.offset_top = 74
	_toast.offset_bottom = 96
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


func _build_fishing() -> void:
	_fish_root = Control.new()
	_fish_root.size = Vector2(FISH_TRACK_W + 8.0, 22)
	_fish_root.visible = false
	_fish_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fish_root)

	var track := TextureRect.new()
	track.texture = FISH_TRACK
	track.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	track.stretch_mode = TextureRect.STRETCH_SCALE
	track.position = Vector2(4, 11)
	track.size = Vector2(FISH_TRACK_W, 7)
	track.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fish_root.add_child(track)

	_fish_zone = ColorRect.new()
	_fish_zone.color = Color(0.32, 0.95, 0.42, 0.85)
	_fish_zone.position = Vector2(4, 11)
	_fish_zone.size = Vector2(15, 7)
	_fish_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fish_root.add_child(_fish_zone)

	_fish_marker = ColorRect.new()
	_fish_marker.color = Color(1, 1, 1, 1)
	_fish_marker.size = Vector2(2, 9)
	_fish_marker.position = Vector2(4, 10)
	_fish_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fish_root.add_child(_fish_marker)

	var hint := _label("[Space]!", 9, CREAM)
	hint.position = Vector2(4, -5)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 3)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fish_root.add_child(hint)


# ------------------------------------------------------------------ pause menu

func _build_pause() -> void:
	_pause_root = Control.new()
	_pause_root.name = "PauseMenu"
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_root.visible = false
	add_child(_pause_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.66)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_root.add_child(dim)

	# Sunnyside dark-wood 9-slice panel, same art as the shop and dialogue.
	var panel := _make_box("dt_", Vector2(300, 208))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -104
	panel.offset_bottom = 104
	_pause_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := _label("Jeda", 20, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(title, 4)
	box.add_child(title)

	_pause_clock = _label("Hari 1 • 06:00", 10, MUTED)
	_pause_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(_pause_clock, 3)
	box.add_child(_pause_clock)

	var sep := HSeparator.new()
	box.add_child(sep)

	box.add_child(_pause_button("Lanjutkan", _on_pause_resume))
	box.add_child(_pause_button("Menu Utama", _on_pause_menu))
	box.add_child(_pause_button("Keluar", _on_pause_quit))


func _pause_button(text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 26)
	btn.focus_mode = Control.FOCUS_NONE
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", CREAM)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.2, 0.14, 0.08))
	btn.add_theme_color_override("font_outline_color", OUTLINE)
	btn.add_theme_constant_override("outline_size", 3)
	btn.add_theme_stylebox_override("normal", _button_box("lt_"))
	btn.add_theme_stylebox_override("hover", _button_box("w_"))
	btn.add_theme_stylebox_override("pressed", _button_box("dt_"))
	btn.pressed.connect(on_press)
	return btn


## Esc: close the pause menu, or open it when nothing else is on screen.
## Other overlays (dialogue, shop, confirm, fishing, backpack) handle Esc
## themselves, so this returns without consuming the key for them.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	if is_pause_open():
		resume_game()
		get_viewport().set_input_as_handled()
		return
	if is_any_overlay_open():
		return
	pause_game()
	get_viewport().set_input_as_handled()


## [I] / [Tab] toggle the backpack; Esc closes it before it can reach the pause
## menu. Handled in _input so the shortcut also works while the player is
## input-locked and before Godot's focus navigation can eat Tab.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		if is_cooking_open():
			close_cooking()
			get_viewport().set_input_as_handled()
			return
		if is_backpack_open():
			close_backpack()
			get_viewport().set_input_as_handled()
		return
	if key.keycode != KEY_I and key.keycode != KEY_TAB:
		return
	if is_pause_open():
		return
	if is_backpack_open():
		close_backpack()
	elif not is_any_overlay_open():
		open_backpack()
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ backpack

func open_backpack() -> void:
	if _bag_root == null or _bag_root.visible:
		return
	# Never stack the bag on top of the shop / dialogue / confirm / pause.
	if is_any_overlay_open():
		return
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_bag_sel_zone = ""
	_bag_sel_index = -1
	refresh_backpack()
	_bag_root.visible = true
	_bag_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_bag_root, "modulate:a", 1.0, 0.12)
	SfxPlayer.play("pet")
	if game != null and game.has_method("on_backpack_toggled"):
		game.on_backpack_toggled(true)


func close_backpack() -> void:
	if _bag_root == null or not _bag_root.visible:
		return
	_bag_root.visible = false
	_bag_sel_zone = ""
	_bag_sel_index = -1
	if game != null and game.has_method("on_backpack_toggled"):
		game.on_backpack_toggled(false)


func toggle_backpack() -> void:
	if is_backpack_open():
		close_backpack()
	else:
		open_backpack()


func is_backpack_open() -> bool:
	return _bag_root != null and _bag_root.visible


func _on_bag_slot_input(event: InputEvent, zone: String, index: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_on_bag_slot_clicked(zone, index)


## First click selects (gold highlight); the next click swaps / merges with the
## selected slot. Clicking the same slot again clears the selection.
func _on_bag_slot_clicked(zone: String, index: int) -> void:
	if _bag_sel_index >= 0:
		if _bag_sel_zone == zone and _bag_sel_index == index:
			_bag_sel_zone = ""
			_bag_sel_index = -1
			refresh_backpack()
			return
		if GameState.swap_slots(_bag_sel_zone, _bag_sel_index, zone, index):
			SfxPlayer.play("pet")
		_bag_sel_zone = ""
		_bag_sel_index = -1
		refresh_backpack()
		return
	if GameState.is_slot_empty(GameState.get_slot(zone, index)):
		_bag_sel_zone = ""
		_bag_sel_index = -1
		refresh_backpack()
		return
	_bag_sel_zone = zone
	_bag_sel_index = index
	refresh_backpack()


func _on_bag_eat() -> void:
	var info := GameState.slot_info(_bag_sel_zone, _bag_sel_index)
	if info.is_empty():
		return
	if not bool(info["edible"]):
		toast("Item ini tidak bisa dimakan.", 1.4)
		return
	if GameState.stamina >= GameState.MAX_STAMINA:
		toast("Stamina sudah penuh.", 1.4)
		return
	var gain := GameState.eat_slot(_bag_sel_zone, _bag_sel_index)
	if gain <= 0:
		return
	toast("Makan %s  (+%d stamina)" % [String(info["name"]), gain], 1.6)
	pop_stamina(gain)
	refresh_backpack()


func _on_bag_drop() -> void:
	var info := GameState.slot_info(_bag_sel_zone, _bag_sel_index)
	if info.is_empty():
		return
	if not bool(info["discardable"]):
		toast("Alat tidak bisa dibuang.", 1.4)
		return
	if GameState.discard_one(_bag_sel_zone, _bag_sel_index):
		toast("Dibuang 1 %s" % String(info["name"]), 1.2)
		refresh_backpack()


func is_any_overlay_open() -> bool:
	return is_confirm_open() or is_dialogue_open() or is_quest_complete_open() \
		or is_shop_open() or is_fishing() or is_backpack_open() or is_cooking_open()


func is_shop_open() -> bool:
	return _shop_root != null and _shop_root.visible


func is_pause_open() -> bool:
	return _pause_root != null and _pause_root.visible


func pause_game() -> void:
	if _pause_root == null:
		return
	hide_prompt()
	if _pause_clock != null:
		_pause_clock.text = "Hari %d • %s" % [GameState.day, GameState.time_string()]
	_pause_root.visible = true
	get_tree().paused = true


func resume_game() -> void:
	if _pause_root != null:
		_pause_root.visible = false
	get_tree().paused = false


func _on_pause_resume() -> void:
	resume_game()


func _on_pause_menu() -> void:
	get_tree().paused = false
	if _pause_root != null:
		_pause_root.visible = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _on_pause_quit() -> void:
	get_tree().quit()


func _build_shop_rows() -> void:
	for child in _shop_rows.get_children():
		_shop_rows.remove_child(child)
		child.queue_free()
	_buy_buttons.clear()
	_upgrade_buttons.clear()
	if game == null:
		return
	if _shop_seed_btn != null:
		_shop_seed_btn.modulate = GOLD if _shop_tab == "seeds" else Color.WHITE
	if _shop_tool_btn != null:
		_shop_tool_btn.modulate = GOLD if _shop_tab == "tools" else Color.WHITE
	if _shop_tab == "tools":
		_build_tool_rows()
	else:
		_build_seed_rows()
	_apply_shop_affordability()


func _set_shop_tab(tab: String) -> void:
	if _shop_tab == tab:
		return
	_shop_tab = tab
	if _shop_hint != null:
		if tab == "tools":
			_shop_hint.text = "Klik Upgrade untuk alat Lv.2 (150 G + 5 Kayu + 5 Batu)."
		else:
			_shop_hint.text = "Klik Beli untuk membeli bibit. Esc / Tutup untuk keluar."
	_build_shop_rows()
	refresh_shop(GameState.gold)


func _build_seed_rows() -> void:
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


func _build_tool_rows() -> void:
	for row_data in GameState.tool_upgrade_rows():
		var tool := String(row_data["tool"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_shop_rows.add_child(row)

		row.add_child(_icon(TOOL_ICONS.get(tool, ICON_HOE), 18))

		var name := _label("%s  Lv.%d" % [String(row_data["name"]), int(row_data["level"])],
			11, CREAM)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)

		var cost := _label("MAX" if bool(row_data["maxed"])
			else "%dG + %d Kayu + %d Batu" % [GameState.TOOL_UPGRADE_GOLD,
				GameState.TOOL_UPGRADE_WOOD, GameState.TOOL_UPGRADE_ROCK],
			9, GOLD if not bool(row_data["maxed"]) else MUTED)
		cost.custom_minimum_size = Vector2(132, 0)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cost)

		var btn := Button.new()
		btn.text = "MAX" if bool(row_data["maxed"]) else "Upgrade"
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(58, 22)
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_on_upgrade_pressed.bind(tool))
		row.add_child(btn)
		_upgrade_buttons.append({"tool": tool, "button": btn})


func _on_upgrade_pressed(tool: String) -> void:
	if game == null:
		return
	if game.upgrade_tool(tool):
		_build_shop_rows()


func _apply_shop_affordability() -> void:
	for entry in _buy_buttons:
		entry["button"].disabled = GameState.gold < int(entry["price"])
	for entry in _upgrade_buttons:
		entry["button"].disabled = not GameState.can_upgrade_tool(String(entry["tool"]))


# ------------------------------------------------------------------ live data

func set_day(day: int) -> void:
	if _day_label != null:
		_day_label.text = "Hari %d" % day


func set_gold(gold: int) -> void:
	if _gold_label != null:
		_gold_label.text = "%d G" % gold


func refresh_hotbar(items: Array[Dictionary], selected: int) -> void:
	for i in _slot_bgs.size():
		if i >= items.size():
			continue
		var item: Dictionary = items[i]
		var vis := _slot_visual(item)
		_slot_icons[i].texture = vis["texture"]
		_slot_icons[i].modulate = vis["tint"]
		_slot_counts[i].text = String(vis["count"])
		_slot_counts[i].modulate = Color(1, 1, 1, 1) if int(item.get("count", 1)) > 0 \
			else Color(1, 1, 1, 0.4)
		var is_sel := (i == selected)
		_slot_bgs[i].texture = _compose_box("w_" if is_sel else "lt_")
		_slot_bgs[i].modulate = GOLD if is_sel else Color.WHITE

	if selected >= 0 and selected < items.size():
		_item_name.text = _display_name(items[selected])
	else:
		_item_name.text = ""


## Repaints the backpack panel (15 slots + the 5 hotbar slots inside it) and
## the selected-item info column. Safe to call while the panel is closed.
func refresh_backpack() -> void:
	if _bag_root == null:
		return
	# A stack that ran out (eaten / discarded / sold) drops the selection.
	if _bag_sel_index >= 0 and GameState.is_slot_empty(
			GameState.get_slot(_bag_sel_zone, _bag_sel_index)):
		_bag_sel_zone = ""
		_bag_sel_index = -1

	for i in _bag_slot_bgs.size():
		var item: Dictionary = GameState.get_slot("backpack", i)
		var is_sel := _bag_sel_zone == "backpack" and _bag_sel_index == i
		_paint_bag_slot(_bag_slot_bgs[i], _bag_slot_icons[i],
			_bag_slot_counts[i], item, is_sel)

	for i in _bag_hot_bgs.size():
		var item: Dictionary = GameState.hotbar[i]
		var is_sel := _bag_sel_zone == "hotbar" and _bag_sel_index == i
		_paint_bag_slot(_bag_hot_bgs[i], _bag_hot_icons[i],
			_bag_hot_counts[i], item, is_sel)

	_refresh_bag_info()


func _paint_bag_slot(bg: NinePatchRect, icon: TextureRect, count: Label,
		item: Dictionary, is_sel: bool) -> void:
	var vis := _slot_visual(item)
	icon.texture = vis["texture"]
	icon.modulate = vis["tint"]
	count.text = String(vis["count"])
	bg.texture = _compose_box("w_" if is_sel else "lt_")
	bg.modulate = GOLD if is_sel else Color.WHITE


func _refresh_bag_info() -> void:
	if _bag_info_name == null:
		return
	var info: Dictionary = {}
	if _bag_sel_index >= 0:
		info = GameState.slot_info(_bag_sel_zone, _bag_sel_index)
	if info.is_empty():
		_bag_info_icon.texture = null
		_bag_info_icon.modulate = Color.WHITE
		_bag_info_name.text = "Pilih item"
		_bag_info_sell.text = "Jual: -"
		_bag_info_stam.text = "Stamina: -"
		_bag_eat_btn.disabled = true
		_bag_drop_btn.disabled = true
		return
	var item: Dictionary = GameState.get_slot(_bag_sel_zone, _bag_sel_index)
	var vis := _slot_visual(item)
	_bag_info_icon.texture = vis["texture"]
	_bag_info_icon.modulate = vis["tint"]
	var label := String(info["name"])
	if String(info["type"]) != "tool" and int(info["count"]) > 0:
		label += " x%d" % int(info["count"])
	_bag_info_name.text = label
	_bag_info_sell.text = "Jual: %d G" % int(info["sell"]) if int(info["sell"]) > 0 \
		else "Jual: -"
	_bag_info_stam.text = "Stamina: +%d" % int(info["stamina"]) if bool(info["edible"]) \
		else "Stamina: -"
	_bag_eat_btn.disabled = not bool(info["edible"])
	_bag_drop_btn.disabled = not bool(info["discardable"])


## Icon / tint / count text for any inventory slot. Shared by the hotbar and
## the backpack so both always render the same item the same way.
func _slot_visual(item: Dictionary) -> Dictionary:
	var tex: Texture2D = null
	var tint := Color.WHITE
	var count_text := ""
	match String(item.get("type", "")):
		"tool":
			match String(item.get("tool", "")):
				"hoe": tex = ICON_HOE
				"water": tex = ICON_WATER
				"axe": tex = ICON_AXE
				"pickaxe": tex = ICON_PICKAXE
				"rod": tex = ICON_ROD
				_: tex = ICON_HOE
		"seed":
			tex = ICON_SEEDS
			tint = SEED_TINTS.get(String(item.get("crop", "")), Color.WHITE)
			var seeds := int(item.get("count", 0))
			count_text = ("x%d" % seeds) if seeds > 0 else ""
		"produce":
			var crop := String(item.get("crop", ""))
			var amount := int(item.get("count", 0))
			if crop != "" and amount > 0:
				tex = _produce_icon(crop)
				if DataRegistry.is_food(crop):
					tint = DataRegistry.item_tint(crop)
			count_text = ("x%d" % amount) if amount > 0 else ""
	return {"texture": tex, "tint": tint, "count": count_text}


func show_prompt(text: String, anchor := Vector2.INF) -> void:
	_prompt_label.text = text
	_prompt_has_anchor = anchor != Vector2.INF
	if _prompt_has_anchor:
		_prompt_anchor = anchor
	_prompt.visible = true
	_prompt.reset_size()


func hide_prompt() -> void:
	_prompt.visible = false
	_prompt_has_anchor = false


## Move an already-visible prompt without re-showing it (animals wander).
func set_prompt_anchor(anchor: Vector2) -> void:
	_prompt_has_anchor = anchor != Vector2.INF
	if _prompt_has_anchor:
		_prompt_anchor = anchor


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

func open_confirm(text: String, on_yes: Callable, on_no := Callable()) -> void:
	_confirm_label.text = text
	_confirm_cb = on_yes
	_confirm_cancel_cb = on_no
	_confirm_root.visible = true
	_confirm_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_confirm_root, "modulate:a", 1.0, 0.12)


## Close without accepting. Fires the optional cancel callback so a prompt that
## locked player input can release it again.
func close_confirm() -> void:
	if _confirm_root == null or not _confirm_root.visible:
		return
	_confirm_root.visible = false
	_confirm_cb = Callable()
	var cb := _confirm_cancel_cb
	_confirm_cancel_cb = Callable()
	if cb.is_valid():
		cb.call()


func is_confirm_open() -> bool:
	return _confirm_root != null and _confirm_root.visible


func _on_confirm_yes() -> void:
	var cb := _confirm_cb
	_confirm_cb = Callable()
	_confirm_cancel_cb = Callable()
	_confirm_root.visible = false
	if cb.is_valid():
		cb.call()


# ------------------------------------------------------------------ shop

func open_shop(gold: int) -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_item_name.visible = false
	_build_shop_rows()
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
	_apply_shop_affordability()


func fade_to(alpha: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", alpha, duration)
	return tw


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	# Live clock + phase.
	if _clock_label != null:
		_clock_label.text = GameState.time_string()
	if _day_label != null:
		_day_label.text = "Hari %d" % GameState.day
	if _phase_label != null:
		_set_phase(GameState.phase_name())
	if _gold_label != null:
		_gold_label.text = "%d G" % GameState.gold
	if _stamina_bar != null:
		_stamina_bar.value = GameState.stamina
		_update_stamina_ui(delta)

	# Fishing mini-game: move the marker and pin the bar above the player.
	if _fishing:
		_update_fishing(delta)
		if game != null and is_instance_valid(game.player):
			_position_above(_fish_root, game.player.global_position, 44.0, false)
		return

	# Keep the floating prompt above the player's head — or above the NPC /
	# board being talked to, so the box never covers their face.
	if not _prompt.visible or game == null:
		return
	var anchor := _prompt_anchor
	var y_off := 0.0
	if not _prompt_has_anchor:
		if not is_instance_valid(game.player):
			return
		anchor = game.player.global_position
		y_off = 30.0
	_position_above(_prompt, anchor, y_off, true)


func _position_above(ctrl: Control, world_pos: Vector2, y_off: float, do_reset: bool) -> void:
	var screen := get_viewport().get_canvas_transform() * (world_pos + Vector2(0, -y_off))
	if do_reset:
		ctrl.reset_size()
	var vp := get_viewport().get_visible_rect().size
	screen.x = clampf(screen.x, ctrl.size.x * 0.5 + 6.0, vp.x - ctrl.size.x * 0.5 - 6.0)
	screen.y = clampf(screen.y, 28.0, vp.y - 80.0)
	ctrl.position = (screen - Vector2(ctrl.size.x * 0.5, ctrl.size.y + 4.0)).round()


# ------------------------------------------------------------------ fishing

func start_fishing(cb: Callable) -> void:
	_fish_cb = cb
	_fishing = true
	_fish_pos = 0.0
	_fish_dir = 1.0
	_fish_time = 7.0
	_fish_zone_c = randf_range(0.32, 0.68)
	_fish_zone_h = 0.10
	var zw := _fish_zone_h * 2.0 * FISH_TRACK_W
	_fish_zone.size = Vector2(zw, 7)
	_fish_zone.position = Vector2(4.0 + (_fish_zone_c - _fish_zone_h) * FISH_TRACK_W, 11.0)
	_fish_marker.position = Vector2(4.0, 10.0)
	_fish_root.visible = true


func fishing_press() -> void:
	if not _fishing:
		return
	var hit := absf(_fish_pos - _fish_zone_c) <= _fish_zone_h
	_finish_fishing(hit)


func is_fishing() -> bool:
	return _fishing


func _update_fishing(delta: float) -> void:
	_fish_pos += _fish_dir * FISH_SPEED * delta
	if _fish_pos >= 1.0:
		_fish_pos = 1.0
		_fish_dir = -1.0
	elif _fish_pos <= 0.0:
		_fish_pos = 0.0
		_fish_dir = 1.0
	_fish_marker.position.x = 4.0 + _fish_pos * FISH_TRACK_W - 1.0
	_fish_time -= delta
	if _fish_time <= 0.0:
		_finish_fishing(false)


func _finish_fishing(success: bool) -> void:
	if not _fishing:
		return
	_fishing = false
	_fish_root.visible = false
	var cb := _fish_cb
	_fish_cb = Callable()
	if cb.is_valid():
		cb.call(success)


# ------------------------------------------------------------------ signals

func _on_gold_signal(new_gold: int) -> void:
	set_gold(new_gold)


func _on_day_signal(new_day: int) -> void:
	set_day(new_day)


func _on_inventory_signal() -> void:
	refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	refresh_backpack()


func _on_quest_signal() -> void:
	refresh_quest()


func _on_stamina_signal(new_stamina: int) -> void:
	if _stamina_bar != null:
		_stamina_bar.value = new_stamina


func _set_phase(phase: String) -> void:
	if _phase_label == null or _phase_label.text == phase:
		return
	_phase_label.text = phase
	var accent: Color = PHASE_COLORS.get(phase, CREAM)
	_phase_label.add_theme_color_override("font_color", accent)
	_phase_label.add_theme_stylebox_override("normal", _badge_style(accent))


## Green > 50%, yellow 25-50%, red < 25%, plus the numeric readout.
func _update_stamina_ui(_delta: float) -> void:
	var ratio := clampf(float(GameState.stamina) / float(GameState.MAX_STAMINA), 0.0, 1.0)
	var tex := _bar_green
	if ratio < 0.25:
		tex = _bar_red
	elif ratio <= 0.5:
		tex = _bar_yellow
	if tex != null and _stamina_bar.texture_progress != tex:
		_stamina_bar.texture_progress = tex
		# Soft fade instead of a hard colour cut.
		_stamina_bar.modulate = Color(1, 1, 1, 0.55)
		var tw := create_tween()
		tw.tween_property(_stamina_bar, "modulate", Color.WHITE, 0.22)
	if _stamina_text != null:
		_stamina_text.text = "%d/%d" % [GameState.stamina, GameState.MAX_STAMINA]
	if _stamina_hint != null:
		_stamina_hint.visible = ratio < 0.5


## Floating "+XX stamina" popup (green) used when eating.
func pop_stamina(amount: int) -> void:
	var lbl := _label("+%d stamina" % amount, 12, Color(0.42, 0.95, 0.5))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	lbl.position = Vector2(-60, -24)
	lbl.size = Vector2(120, 24)
	var start := lbl.position
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", start + Vector2(0, -28), 1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.chain().tween_callback(lbl.queue_free)


# ------------------------------------------------------------------ helpers

func _produce_icon(crop: String) -> Texture2D:
	if DataRegistry.is_food(crop):
		var item := DataRegistry.get_item(crop)
		return _load_texture(CROP_DIR + String(item.get("icon", "")))
	match crop:
		"fish": return ICON_FISH
		"wood": return ICON_WOOD
		"rock": return ICON_ROCK
		"egg": return ICON_EGG
		"milk": return ICON_MILK
	return _load_texture(CROP_DIR + crop + "_05.png")


func _display_name(item: Dictionary) -> String:
	match String(item.get("type", "")):
		"tool":
			match String(item.get("tool", "")):
				"hoe": return "Cangkul"
				"water": return "Penyiram"
				"axe": return "Kapak"
				"pickaxe": return "Beliung"
				"rod": return "Pancingan"
			return "Alat"
		"seed":
			return "Bibit %s" % DataRegistry.crop_name(String(item.get("crop", "")))
		"produce":
			var amount := int(item.get("count", 0))
			if amount <= 0:
				return "Tangan kosong"
			return "%s x%d" % [_item_label(String(item.get("crop", ""))), amount]
	return "Tangan kosong"


func _item_label(id: String) -> String:
	if not DataRegistry.get_crop(id).is_empty():
		return DataRegistry.crop_name(id)
	return DataRegistry.item_name(id)


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


# ---- bars composed from the 15x7 Sunnyside pieces (caps + tiled middle) ----

func _prepare_bar_textures() -> void:
	_bar_green = _bar_texture(BAR_FULL, BAR_W, STAM_GREEN)
	_bar_yellow = _bar_texture(BAR_FULL, BAR_W, STAM_YELLOW)
	_bar_red = _bar_texture(BAR_RED, BAR_W, STAM_RED)


## Builds a `width`-wide bar from the 15x7 Sunnyside piece: the 2px caps are
## copied and the 11px middle is tiled, never stretched. `fill` recolours only
## the interior fill pixels, so the white bevel and dark border stay authored.
func _bar_texture(src: Texture2D, width: int, fill: Color) -> Texture2D:
	var key := "%s|%d|%s" % [src.resource_path, width, fill.to_html(false)]
	if _box_cache.has(key):
		return _box_cache[key]
	var img := src.get_image()
	img.convert(Image.FORMAT_RGBA8)
	if fill != Color.WHITE:
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				if p.a > 0.5 and p.g > 0.55 and p.r < 0.75 and p.b < 0.6:
					img.set_pixel(x, y, Color(fill.r, fill.g, fill.b, p.a))
	var h := img.get_height()
	var out := Image.create_empty(width, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(img, Rect2i(0, 0, BAR_CAP, h), Vector2i(0, 0))
	for x in width - BAR_CAP * 2:
		out.blit_rect(img, Rect2i(BAR_CAP + (x % BAR_MID), 0, 1, h),
			Vector2i(BAR_CAP + x, 0))
	out.blit_rect(img, Rect2i(13, 0, BAR_CAP, h), Vector2i(width - BAR_CAP, 0))
	var tex := ImageTexture.create_from_image(out)
	_box_cache[key] = tex
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
	var full := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
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


## The same 9-slice art as a StyleBoxTexture, for buttons that should match the
## panels around them.
func _button_box(prefix: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _compose_box(prefix)
	style.texture_margin_left = 3
	style.texture_margin_top = 3
	style.texture_margin_right = 3
	style.texture_margin_bottom = 3
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _icon(tex: Texture2D, size_px: int, exact := false) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	if exact:
		# Draw at the native pixel size: no fractional up-scaling, no blur.
		t.custom_minimum_size = tex.get_size()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP
	else:
		t.custom_minimum_size = Vector2(size_px, size_px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Sunnyside 9-slice frame (dt_ = dark wood) that grows with its content.
func _status_panel(prefix := "dt_") -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = _compose_box(prefix)
	style.texture_margin_left = 3
	style.texture_margin_top = 3
	style.texture_margin_right = 3
	style.texture_margin_bottom = 3
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _badge_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.88)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _outline(label: Label, size_px: int) -> void:
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", size_px)


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