extends Node2D
## World — Main game scene controller.
##
## Wires FarmManager into the scene tree, owns the HUD reference, drives the
## day/night CanvasModulate and exposes the interaction / tool / zone entry
## points that world_player.gd calls via get_parent().

const HUD_SCRIPT := preload("res://scripts/hud.gd")
const FARM_MANAGER_SCRIPT := preload("res://scripts/farming/farm_manager.gd")
const LIVESTOCK_SCRIPT := preload("res://scripts/livestock_manager.gd")
const VILLAGER_SCRIPT := preload("res://scripts/villager_npc.gd")
const QUEST_BOARD_SCRIPT := preload("res://scripts/quest_board.gd")
const VILLAGE_DECOR_SCRIPT := preload("res://scripts/village_decor.gd")

## Villagers that stroll the road. Bu Sari (the quest-hint giver) is created
## separately because her zone is baked into $Zones/VillagerZone.
const NPC_ROSTER := [
	{
		"name": "Bejo",
		"hair": "curlyhair",
		"pos": Vector2(520, 378),
		"radius": 46.0,
		"speed": 16.0,
		"lines": [
			"Ladangmu makin rapi, Nak. Pagar tua itu dulu dibangun ayahku.",
			"Kalau sore begini, aku suka duduk di bangku dekat kolam.",
			"Air kolam itu jernih, tapi jangan terlalu dekat ke tepinya.",
		],
	},
	{
		"name": "Qumaini Aceh",
		"hair": "spikeyhair",
		"pos": Vector2(300, 376),
		"radius": 40.0,
		"speed": 20.0,
		"lines": [
			"Bu Sari bilang hasil panenmu laris di pasar. Hebat!",
			"Aku sedang menanam bunga di pinggir jalan. Jangan diinjak, ya.",
			"Papan misi di dekat pasar itu selalu punya kabar baru.",
		],
	},
	{
		"name": "Pasha",
		"hair": "longhair",
		"pos": Vector2(792, 380),
		"radius": 38.0,
		"speed": 18.0,
		"lines": [
			"Pasar buka tiap hari, tapi pagi paling ramai.",
			"Kalau kamu butuh bibit, mampir ke lapak sebelah papan misi.",
			"Sapi di padang timur itu jinak. Coba rawat dengan E.",
		],
	},
]

# Interaction reach. All three are measured from the player's feet, never from
# the mouse cursor, so nothing can be farmed from the far side of the screen.
const TARGET_RANGE := 26.0    # target_pos() must stay this close to the feet
const CLICK_RANGE := 28.0     # mouse clicks further away are ignored
const RESOURCE_REACH := 18.0  # target_pos() -> trunk base / boulder centre

# Smooth sky colours keyed by hour [0..24]. Linear-interpolated per frame.
const SKY_KEYS := [
	[0.0, Color(0.55, 0.52, 0.72)],   # deep night (violet)
	[5.0, Color(0.55, 0.52, 0.72)],
	[6.5, Color(1.0, 0.84, 0.70)],    # dawn (warm)
	[8.0, Color(1.0, 1.0, 1.0)],      # full day
	[16.0, Color(1.0, 1.0, 1.0)],
	[18.0, Color(1.0, 0.78, 0.60)],   # dusk (warm)
	[20.0, Color(0.55, 0.52, 0.72)],  # night
	[24.0, Color(0.55, 0.52, 0.72)],
]

var player: CharacterBody2D
var soil: TileMapLayer
var farm: Node2D
var hud
var overlay: Node2D
var canvas_mod: CanvasModulate
var livestock: Node2D
var villager: Node2D
var quest_board: Node2D
var village_decor: Node2D
var npcs: Array = []

var busy := false
var shop_open := false
var fishing_active := false
var _last_grown := 0
var _last_products := 0
var _last_prompt := ""
## Villager currently being talked to, so a gift can reach the right emote.
var _dialogue_npc: Node2D = null

var _resources: Array = []   # Tree_* and Boulder_* nodes
var _pond_center := Vector2.ZERO
var _pond_radii := Vector2.ZERO
var _shake_tweens: Dictionary = {}


func _ready() -> void:
	player = get_node_or_null("Player") as CharacterBody2D
	soil = get_node_or_null("FarmSoilLayer") as TileMapLayer
	canvas_mod = get_node_or_null("CanvasModulate") as CanvasModulate

	_create_farm_manager()
	_create_hud()
	_create_npc_world()
	farm.remove_placeholder_crops()
	_setup_resources()

	GameState.day_changed.connect(_on_day_changed)
	GameState.quests_done.connect(_on_quests_done)
	farm.crop_harvested.connect(_on_crop_harvested)

	hud.toast("Selamat datang! Cangkul lahan, rawat ternak [E], dan cek Papan Misi di dekat pasar.", 5.0)


func _process(_delta: float) -> void:
	if canvas_mod != null:
		canvas_mod.color = _sky_color(GameState.hour_float())
	_refresh_prompt()


# ================================================================ construction

func _create_farm_manager() -> void:
	farm = FARM_MANAGER_SCRIPT.new()
	farm.name = "FarmManager"
	add_child(farm)
	farm.setup(self, soil, player)
	overlay = farm.overlay


func _create_hud() -> void:
	hud = HUD_SCRIPT.new()
	add_child(hud)
	hud.setup(self)
	farm.set_hud(hud)


## Spawns the 4B cast: livestock right of the farm, the villager by the pond,
## the quest board outside the market, plus their interaction zones. The
## playtest polish adds the strolling villagers and the village dressing.
func _create_npc_world() -> void:
	livestock = LIVESTOCK_SCRIPT.new()
	livestock.name = "Livestock"
	add_child(livestock)
	livestock.setup(self, player)

	villager = VILLAGER_SCRIPT.new()
	villager.name = "Villager"
	villager.position = Vector2(702, 374)
	# Her zone lives in $Zones so the 4B acceptance test keeps finding it.
	villager.build_zone = false
	add_child(villager)

	quest_board = QUEST_BOARD_SCRIPT.new()
	quest_board.name = "QuestBoard"
	quest_board.position = Vector2(664, 332)
	add_child(quest_board)

	village_decor = VILLAGE_DECOR_SCRIPT.new()
	village_decor.name = "VillageDecor"
	add_child(village_decor)
	village_decor.setup(self)

	_spawn_wanderers()

	_add_zone("VillagerZone", "villager", Vector2(702, 386), Vector2(46, 32))
	_add_zone("QuestBoardZone", "quest", Vector2(664, 346), Vector2(46, 30))
	if player != null and player.has_method("refresh_zones"):
		player.refresh_zones()


## The strolling villagers. Each one builds its own interaction zone as a child
## node, so the prompt travels with them along the road.
func _spawn_wanderers() -> void:
	for cfg in NPC_ROSTER:
		var npc := VILLAGER_SCRIPT.new()
		npc.name = "Villager_" + String(cfg["name"]).replace(" ", "")
		npc.speaker_name = String(cfg["name"])
		npc.hair = String(cfg["hair"])
		npc.lines = cfg["lines"]
		npc.position = Vector2(cfg["pos"])
		npc.wander = true
		npc.radius = float(cfg["radius"])
		npc.speed = float(cfg["speed"])
		npc.zone_id = "npc"
		add_child(npc)
		npcs.append(npc)


func _add_zone(node_name: String, interaction: String, pos: Vector2, size: Vector2) -> void:
	var zones := get_node_or_null("Zones")
	if zones == null:
		return
	var area := Area2D.new()
	area.name = node_name
	area.position = pos
	area.set_meta("interaction", interaction)
	var col := CollisionShape2D.new()
	col.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	area.add_child(col)
	zones.add_child(area)


# ================================================================ input

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			_toggle_cheats()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if hud != null and hud.is_cheat_open():
				_close_cheats()
				get_viewport().set_input_as_handled()
			elif hud != null and hud.is_cooking_open():
				_close_cooking()
				get_viewport().set_input_as_handled()
			elif hud != null and hud.is_dialogue_open():
				_close_dialogue()
				get_viewport().set_input_as_handled()
			elif hud != null and hud.is_confirm_open():
				hud.close_confirm()
				get_viewport().set_input_as_handled()
			elif shop_open:
				close_shop()
				get_viewport().set_input_as_handled()
		KEY_E:
			# While a dialogue is open the player is input-locked, so the E
			# that closes it has to be caught here instead of in world_player.
			if hud != null and hud.is_dialogue_open():
				_close_dialogue()
				get_viewport().set_input_as_handled()
			elif hud != null and hud.is_cooking_open():
				_close_cooking()
				get_viewport().set_input_as_handled()


# ================================================================ player callbacks

func on_zone_changed(_zone: String) -> void:
	_refresh_prompt()


## Single source of truth for the floating [E] prompt: area zones first, then
## the nearest animal when standing on plain grass. Only touches the HUD when
## the text actually changes, so the prompt never flickers.
func _refresh_prompt() -> void:
	if hud == null or player == null:
		return
	var want := ""
	var anchor := Vector2.INF
	var blocked: bool = busy or shop_open or fishing_active or player.is_busy() \
		or hud.is_confirm_open() or hud.is_dialogue_open() or hud.is_quest_complete_open() \
		or hud.is_backpack_open() or hud.is_cooking_open() or hud.is_cheat_open()
	if not blocked:
		want = _prompt_for(player.current_zone)
		if want != "":
			anchor = _zone_anchor(player.current_zone)
		elif player.current_zone == "" and livestock != null:
			want = livestock.prompt_for_player()
			if want != "":
				anchor = livestock.prompt_anchor()
	if want == _last_prompt:
		# Same text: just keep an anchored prompt glued to its NPC / animal.
		if want != "" and anchor != Vector2.INF:
			hud.set_prompt_anchor(anchor)
		return
	_last_prompt = want
	if want == "":
		hud.hide_prompt()
	else:
		hud.show_prompt(want, anchor)


## Where the prompt box should float for each area zone: above the NPC or prop
## rather than above the player, so it never covers their face.
func _zone_anchor(zone: String) -> Vector2:
	match zone:
		"villager":
			if villager != null:
				return villager.global_position + Vector2(0, -34)
		"npc":
			var npc := _current_npc()
			if npc != null:
				return npc.prompt_anchor()
		"quest":
			if quest_board != null:
				return quest_board.global_position + Vector2(0, -50)
		"cook":
			if player != null and player.current_zone_area != null:
				return player.current_zone_area.get_parent().global_position + Vector2(0, -26)
	return Vector2.INF


## The villager whose zone the player is standing in (wandering villagers carry
## their own zone, so the zone's parent is the NPC).
func _current_npc() -> Node2D:
	if player == null or player.current_zone_area == null:
		return null
	var owner_node = player.current_zone_area.get_parent()
	if owner_node is Node2D and owner_node.has_method("next_line"):
		return owner_node
	return null


func _prompt_for(zone: String) -> String:
	match zone:
		"sleep":
			return "[E] Tidur"
		"ship":
			return "[E] Jual Hasil Panen"
		"shop":
			return "[E] Beli Bibit"
		"villager":
			return "[E] Bicara"
		"npc":
			return "[E] Sapa"
		"quest":
			return "[E] Papan Misi"
		"cook":
			return "[E] Masak"
	return ""


func select_slot(index: int) -> void:
	GameState.select_slot(index)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)


func cycle_slot(step: int) -> void:
	GameState.cycle_slot(step)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)


## Called by the HUD when the backpack panel opens or closes: movement and
## world clicks are locked while the bag is in front of the player.
func on_backpack_toggled(open: bool) -> void:
	if player != null:
		player.input_locked = open
	_last_prompt = ""
	_refresh_prompt()


# ================================================================ interaction

func interact(zone: String) -> void:
	if busy or shop_open or (player != null and player.is_busy()):
		return
	if hud != null and hud.is_backpack_open():
		return
	if hud != null and (hud.is_cooking_open() or hud.is_cheat_open()):
		return
	if zone == "":
		# Plain grass: [E] tends / harvests the closest animal.
		if livestock != null:
			livestock.try_interact()
		return
	match zone:
		"sleep":
			_ask_sleep()
		"ship":
			_sell_all()
		"shop":
			_open_shop()
		"villager":
			_talk_villager()
		"npc":
			_talk_npc()
		"quest":
			_open_quest_board()
		"cook":
			_open_cooking()


# ================================================================ villagers / quest board

func _talk_villager() -> void:
	if player != null:
		player.input_locked = true
	hud.hide_prompt()
	var who := "Warga"
	_dialogue_npc = villager
	if villager != null:
		who = String(villager.speaker_name)
	hud.open_dialogue(who, _villager_text(), GameState.hearts_for(who),
		_gift_option(who))


func _talk_npc() -> void:
	var npc := _current_npc()
	if npc == null:
		return
	if player != null:
		player.input_locked = true
	hud.hide_prompt()
	_dialogue_npc = npc
	var who := String(npc.speaker_name)
	hud.open_dialogue(who, String(npc.next_line()), GameState.hearts_for(who),
		_gift_option(who))


## Name of the held gift when this NPC still accepts one today, else "".
func _gift_option(who: String) -> String:
	if GameState.gifted_today(who):
		return ""
	var gift := GameState.selected_gift()
	return String(gift.get("name", ""))


func _villager_text() -> String:
	var greet := ""
	match GameState.phase_name():
		"Pagi":
			greet = "Pagi yang cerah! Embun masih menempel di daun-daun ladangmu."
		"Siang":
			greet = "Matahari makin terik. Kalau lelah, makan hasil panen dengan F, ya."
		"Sore":
			greet = "Langit sore ini cantik sekali, seperti lukisan cat air."
		"Malam":
			greet = "Sudah malam... desa jadi sunyi. Jangan lupa tidur di rumah."
	return greet + "\n\n" + GameState.quest_hint()


func _open_quest_board() -> void:
	if player != null:
		player.input_locked = true
	hud.hide_prompt()
	_dialogue_npc = null
	var speaker := "Papan Misi"
	if not GameState.quest_done:
		speaker = "Papan Misi • Misi %d/%d" % [GameState.quest_index + 1,
			GameState.QUESTS.size()]
	hud.open_dialogue(speaker, _quest_board_text(), -1, "", _quest_board_order_label())


## The board's full body: active main quest, then today's side order. Kept to
## four short lines so it always fits the bottom dialogue panel.
func _quest_board_text() -> String:
	var lines: Array[String] = []
	if GameState.quest_done:
		lines.append("Semua misi desa selesai. Cozy Valley Makmur!")
	else:
		var quest := GameState.current_quest()
		var reward := GameState.quest_reward()
		var reward_text := "Renovasi Agung" if reward <= 0 else "%d G" % reward
		lines.append(String(quest.get("title", "")))
		lines.append("%s  •  Hadiah: %s"
			% [GameState.quest_progress_text(), reward_text])

	lines.append("")
	var order := GameState.daily_order_progress()
	if order.is_empty():
		lines.append("Pesanan Harian: belum ada pesanan.")
	elif bool(order["done"]):
		lines.append("Pesanan Harian: sudah dikirim. Tidur untuk pesanan baru.")
	else:
		lines.append("Pesanan Harian: antar %d %s (%d/%d) → +%d G"
			% [int(order["qty"]), String(order["label"]), int(order["have"]),
				int(order["qty"]), int(order["reward"])])
	return "\n".join(lines)


## "Serahkan Pesanan" is offered until today's order has been delivered.
func _quest_board_order_label() -> String:
	var order := GameState.daily_order_progress()
	if order.is_empty() or bool(order["done"]):
		return ""
	return "Serahkan Pesanan"


## HUD button on the quest board: trade the requested items for gold.
func submit_daily_order() -> void:
	var result := GameState.submit_daily_order()
	if result.is_empty():
		hud.toast("Bahan pesanan belum cukup. Cek stok di tas.", 1.8)
		return
	SfxPlayer.play("coin")
	hud.set_gold(GameState.gold)
	hud.pop_gold(int(result["reward"]))
	hud.toast("Pesanan %d %s dikirim: +%d G"
		% [int(result["qty"]), String(result["label"]), int(result["reward"])], 2.2)
	hud.update_dialogue(_quest_board_text(), _quest_board_order_label())


func _close_dialogue() -> void:
	if hud == null:
		return
	hud.close_dialogue()
	_dialogue_npc = null
	if player != null and not busy:
		player.input_locked = false
	_last_prompt = ""
	_refresh_prompt()


# ================================================================ campfire cooking

func _open_cooking() -> void:
	if hud == null:
		return
	hud.hide_prompt()
	hud.open_cooking()


func _close_cooking() -> void:
	if hud == null:
		return
	hud.close_cooking()


## Called by the HUD when the cooking panel opens or closes so movement and
## world clicks stay locked behind the 9-slice panel.
func on_cooking_toggled(open: bool) -> void:
	if player != null:
		player.input_locked = open
	_last_prompt = ""
	_refresh_prompt()


## HUD "Masak" button -> consume ingredients, add the dish, play the fire SFX.
func cook_recipe(id: String) -> bool:
	if not GameState.can_cook(id):
		hud.toast("Bahan belum cukup untuk resep ini.", 1.6)
		return false
	if not GameState.cook(id):
		hud.toast("Tas penuh! Jual dulu hasil panen di Shipping Bin.", 1.8)
		return false
	SfxPlayer.play("water")
	GameState.quest_event("cook", 1)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	hud.toast("%s siap disantap! (total masak: %d)"
		% [DataRegistry.item_name(id), GameState.cooked_count], 1.8)
	return true


# ================================================================ gifts

## HUD "Beri Hadiah" button. Consumes the held harvest / product / dish, gives
## one heart, shows the love emote, and pays the first-time 3-heart bonus.
func give_gift(who: String) -> void:
	if not GameState.can_gift_today(who):
		hud.toast("%s sudah menerima hadiah hari ini." % who, 1.6)
		return
	var gift := GameState.consume_selected_gift()
	if gift.is_empty():
		hud.toast("Pegang hasil panen, ikan, telur, susu, atau masakan dulu.", 1.8)
		return
	GameState.record_gift(who)
	var hearts := GameState.add_heart(who)
	GameState.quest_event("gift", 1)
	SfxPlayer.play("coin")
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)

	var npc := _npc_by_name(who)
	if npc != null and npc.has_method("show_emote"):
		npc.show_emote()

	var bonus := false
	if hearts >= 3 and GameState.claim_three_heart_reward(who):
		GameState.add_gold(75)
		bonus = true
		hud.pop_gold(75)

	var msg := "%s menyukai %s!  ♥ %d/5" % [who, String(gift["name"]), hearts]
	if bonus:
		msg += "  Hadiah balik +75 G!"
	hud.toast(msg, 2.4)
	hud.set_dialogue_gift(hearts, _gift_option(who))


func _npc_by_name(who: String) -> Node2D:
	if villager != null and String(villager.speaker_name) == who:
		return villager
	for npc in npcs:
		if is_instance_valid(npc) and String(npc.speaker_name) == who:
			return npc
	if _dialogue_npc != null and is_instance_valid(_dialogue_npc):
		return _dialogue_npc
	return null


# ================================================================ quests

func _on_crop_harvested(_cell: Vector2i, _crop: String, qty: int) -> void:
	GameState.quest_event("harvest", qty)


func _on_quests_done() -> void:
	busy = true
	if player != null:
		player.input_locked = true
	SfxPlayer.play("catch")
	hud.hide_prompt()
	var hearts := 0
	for value in GameState.friendship_hearts.values():
		hearts += int(value)
	hud.show_quest_complete(GameState.day, GameState.gold, _resume_free_play, {
		"cooked": GameState.cooked_count,
		"gifts": GameState.gifts_given,
		"hearts": hearts,
		"upgrades": (GameState.hoe_level - 1) + (GameState.water_level - 1) \
			+ (GameState.axe_level - 1) + (GameState.pickaxe_level - 1),
	})


func _resume_free_play() -> void:
	hud.hide_quest_complete()
	busy = false
	if player != null:
		player.input_locked = false
	_last_prompt = ""
	_refresh_prompt()


func use_tool(cell: Vector2i) -> void:
	if busy or shop_open or player == null or player.is_busy():
		return
	if hud != null and hud.is_backpack_open():
		return
	var item: Dictionary = GameState.get_selected()
	var tool := String(item.get("tool", ""))
	if tool == "axe" or tool == "pickaxe":
		_hit_resource_near(tool)
		return
	if tool == "rod":
		_try_fish()
		return
	# Soil work: pay stamina only when the action really changes a tile.
	var is_soil_tool := tool == "hoe" or tool == "water"
	var acted: bool = farm.can_use(cell, item)
	if is_soil_tool and not farm._is_mature(cell) and acted:
		if not _spend_stamina(GameState.tool_stamina_cost(tool, 5)):
			return
	farm.use_tool(cell, item)
	if acted:
		_play_soil_sfx(item, tool)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)


## Cangkul -> hit, siram -> water, tanam -> water.
func _play_soil_sfx(item: Dictionary, tool: String) -> void:
	match String(item.get("type", "")):
		"seed":
			SfxPlayer.play("water")
		"tool":
			SfxPlayer.play("water" if tool == "water" else "hit")


func mouse_action(mouse_world: Vector2) -> void:
	if busy or shop_open or player == null or player.is_busy():
		return
	if hud != null and hud.is_backpack_open():
		return
	if mouse_world.distance_to(player.global_position) > CLICK_RANGE:
		hud.toast("Terlalu jauh - dekati dulu.")
		return
	# Turn towards the click first: the action animation and the probe tile
	# must both point at what the player aimed at.
	_face_toward(mouse_world)
	var item: Dictionary = GameState.get_selected()
	var tool := String(item.get("tool", ""))
	if tool == "axe" or tool == "pickaxe":
		_hit_resource_near(tool)
		return
	if tool == "rod":
		_try_fish()
		return
	use_tool(player.front_cell())


## Turns the player towards a world point (4-way, X-dominant like movement).
func _face_toward(pos: Vector2) -> void:
	if player == null or not player.has_method("face"):
		return
	var d := pos - player.global_position
	if d.length_squared() < 0.0001:
		return
	if absf(d.x) >= absf(d.y):
		player.face(Vector2i(int(signf(d.x)), 0))
	else:
		player.face(Vector2i(0, int(signf(d.y))))


# ================================================================ sleep

func _ask_sleep() -> void:
	if player != null:
		player.input_locked = true
	hud.hide_prompt()
	hud.open_confirm("Tidur dan lanjut ke hari berikutnya?", _do_sleep, _cancel_sleep)


## "Tidak" / Esc on the sleep prompt: release the input lock again.
func _cancel_sleep() -> void:
	if player != null and not busy:
		player.input_locked = false
	_last_prompt = ""
	_refresh_prompt()


func _do_sleep() -> void:
	if busy:
		return
	busy = true
	if player != null:
		player.input_locked = true
	hud.hide_prompt()

	var fade_in: Tween = hud.fade_to(1.0, 0.35)
	await fade_in.finished

	# Reset clock to 06:00 and advance the calendar. Emitting day_changed runs
	# _on_day_changed() which grows watered crops and resets the water flags.
	GameState.sleep_until_morning()

	if player != null:
		player.global_position = Vector2(424, 258)
		if player.has_method("face"):
			player.face(Vector2i.DOWN)
		else:
			player.facing = Vector2i.DOWN
		player.queue_redraw()

	await get_tree().create_timer(0.3).timeout

	var msg := "Hari ke-%d. " % GameState.day
	if _last_grown > 0:
		msg += "%d tanaman tumbuh." % _last_grown
	else:
		msg += "Tanaman butuh disiram sebelum tidur."
	if _last_products > 0:
		msg += " %d produk ternak siap diambil [E]." % _last_products
	var order := GameState.daily_order_progress()
	if not order.is_empty() and not bool(order["done"]):
		msg += " Pesanan harian baru: %d %s (+%d G)." % [int(order["qty"]),
			String(order["label"]), int(order["reward"])]
	hud.toast(msg, 3.4)

	var fade_out: Tween = hud.fade_to(0.0, 0.35)
	await fade_out.finished
	if player != null:
		player.input_locked = false
	busy = false


func _on_day_changed(_new_day: int) -> void:
	_last_grown = farm.on_day_changed()
	_last_products = livestock.on_day_changed() if livestock != null else 0
	_respawn_resources()
	hud.set_day(GameState.day)
	hud.set_gold(GameState.gold)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)


# ================================================================ demo cheats
# F1 menu used during presentations. Nothing here is required to finish the
# game; every helper adds only the items that the selected feature still needs.

func _toggle_cheats() -> void:
	if hud == null:
		return
	if hud.is_cheat_open():
		_close_cheats()
	else:
		_open_cheats()


func _open_cheats() -> void:
	if hud == null or busy or shop_open or fishing_active:
		return
	if player != null and player.is_busy():
		return
	if hud.is_any_overlay_open():
		return
	hud.hide_prompt()
	hud.open_cheats()
	_last_prompt = ""
	_refresh_prompt()


func _close_cheats() -> void:
	if hud == null:
		return
	hud.close_cheats()
	_last_prompt = ""
	_refresh_prompt()


## HUD tells the world when the demo panel opens / closes so movement pauses
## behind it, but the sky keeps animating so the time buttons are visible.
func on_cheat_toggled(open: bool) -> void:
	if player != null:
		player.input_locked = open or busy \
			or (hud != null and hud.is_quest_complete_open())
	_last_prompt = ""
	_refresh_prompt()


func cheat_set_time(phase: String) -> void:
	if hud == null:
		return
	var label := ""
	match phase:
		"pagi":
			GameState.set_clock(7, 0)
			label = "Pagi (07:00)"
		"siang":
			GameState.set_clock(13, 0)
			label = "Siang (13:00)"
		"sore":
			GameState.set_clock(17, 30)
			label = "Sore (17:30)"
		"malam":
			GameState.set_clock(21, 0)
			label = "Malam (21:00)"
		_:
			return
	SfxPlayer.play("pet")
	hud.toast("Waktu diubah ke %s." % label, 1.8)
	hud.set_cheat_status("Waktu sekarang: %s" % label)


## "Selesaikan Misi Ini" / "Selesaikan Semua Misi".
func cheat_finish_quest(all := false) -> void:
	if hud == null:
		return
	if GameState.quest_done:
		hud.toast("Semua misi sudah selesai. Cozy Valley Makmur!", 2.4)
		hud.set_cheat_status("Semua misi sudah selesai.")
		return
	# Completing the last quest opens the victory screen, so get the panel out
	# of the way first and let the ending play cleanly.
	if all or GameState.quest_index >= GameState.QUESTS.size() - 1:
		_close_cheats()
	var result: Dictionary = GameState.cheat_finish_all_quests() if all \
		else GameState.cheat_finish_current_quest()
	_refresh_after_cheat()
	if result.is_empty():
		hud.toast("Misi tidak bisa diselesaikan sekarang.", 1.8)
		return
	SfxPlayer.play("coin")
	var msg := ""
	if all:
		msg = "Semua misi selesai!" if bool(result.get("done", false)) \
			else "Misi diselesaikan bertahap."
	elif int(result.get("after", 0)) > int(result.get("before", 0)):
		msg = "Misi %s selesai! +%d G" % [String(result.get("title", "")),
			int(result.get("reward", 0))]
	else:
		msg = "Kebutuhan misi ditambahkan."
	var added_text := _cheat_added_text(result.get("added", {}))
	if added_text != "":
		msg += " " + added_text
	var failed: Array = result.get("failed", [])
	if not failed.is_empty():
		msg += " (tas penuh: %s)" % ", ".join(failed)
	hud.toast(msg, 3.2)
	hud.set_cheat_status(msg)


## Add only the missing units of today's side order.
func cheat_stock_daily_order() -> void:
	if hud == null:
		return
	var result := GameState.cheat_stock_daily_order()
	if result.is_empty():
		hud.toast("Belum ada pesanan harian aktif.", 1.8)
		hud.set_cheat_status("Pesanan harian belum tersedia.")
		return
	_refresh_after_cheat()
	var label := String(result.get("label", ""))
	var qty := int(result.get("qty", 0))
	var have := int(result.get("have", 0))
	var added := int(result.get("added", 0))
	var msg := ""
	if bool(result.get("done", false)):
		msg = "Pesanan hari ini sudah dikirim. Tidur untuk pesanan baru."
	elif added > 0:
		msg = "Stok pesanan: +%d %s (%d/%d)." % [added, label, have, qty]
	elif have >= qty:
		msg = "Pesanan sudah siap: %d %s (%d/%d)." % [qty, label, have, qty]
	else:
		msg = "Tas penuh! Kosongkan slot untuk %d %s." % [qty, label]
	SfxPlayer.play("coin" if added > 0 else "pet")
	hud.toast(msg, 2.6)
	hud.set_cheat_status(msg)


## Add two servings of every campfire recipe's ingredients.
func cheat_stock_cooking() -> void:
	if hud == null:
		return
	var result := GameState.cheat_stock_cooking()
	_refresh_after_cheat()
	var added: Dictionary = result.get("added", {})
	var failed: Array = result.get("failed", [])
	var msg := ""
	if added.is_empty() and failed.is_empty():
		msg = "Bahan masak sudah lengkap."
	else:
		msg = "Bahan masak: " + _cheat_added_text(added)
		if not failed.is_empty():
			msg += " (tas penuh: %s)" % ", ".join(failed)
	SfxPlayer.play("water" if not added.is_empty() else "pet")
	hud.toast(msg, 3.2)
	hud.set_cheat_status(msg)


func cheat_add_gold(amount := 300) -> void:
	if hud == null:
		return
	GameState.add_gold(amount)
	hud.pop_gold(amount)
	SfxPlayer.play("coin")
	var msg := "+%d G (demo) • total %d G" % [amount, GameState.gold]
	hud.toast(msg, 1.8)
	hud.set_cheat_status(msg)


func cheat_fill_stamina() -> void:
	if hud == null:
		return
	GameState.refill_stamina()
	SfxPlayer.play("pet")
	var msg := "Stamina penuh (%d/%d)." % [GameState.stamina, GameState.MAX_STAMINA]
	hud.toast(msg, 1.6)
	hud.set_cheat_status(msg)


func _cheat_added_text(added: Dictionary) -> String:
	var parts: Array[String] = []
	for id in added.keys():
		var key := String(id)
		if key == "gold":
			parts.append("+%d G" % int(added[id]))
		elif key == "upgrade":
			parts.append("%d alat Lv.2" % int(added[id]))
		else:
			parts.append("+%d %s" % [int(added[id]), GameState.item_display_name(key)])
	return ", ".join(parts)


func _refresh_after_cheat() -> void:
	if hud == null:
		return
	hud.set_gold(GameState.gold)
	hud.set_day(GameState.day)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	hud.refresh_backpack()
	hud.refresh_quest()
	if shop_open:
		hud.refresh_shop(GameState.gold)


# ================================================================ stamina

## Try to pay `amount` stamina. Returns false (and warns) when too low.
func _spend_stamina(amount: int) -> bool:
	if GameState.stamina < amount:
		hud.toast("Stamina habis! Tidur untuk memulihkan.")
		return false
	GameState.spend_stamina(amount)
	return true


## F key: eat the selected produce / fish / egg for stamina.
func eat_selected() -> void:
	if busy or shop_open or player == null or player.is_busy():
		return
	if hud != null and hud.is_backpack_open():
		return
	var item: Dictionary = GameState.get_selected()
	if String(item.get("type", "")) != "produce" or int(item.get("count", 0)) <= 0:
		hud.toast("Pegang hasil panen / ikan lalu tekan F untuk makan.")
		return
	var crop := String(item.get("crop", ""))
	if crop == "" or GameState.eat_gain(item) <= 0:
		hud.toast("Tidak ada yang bisa dimakan.")
		return
	if GameState.stamina >= GameState.MAX_STAMINA:
		hud.toast("Stamina sudah penuh.")
		return
	var gain := GameState.eat_slot("hotbar", GameState.selected_slot)
	if gain <= 0:
		return
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	hud.toast("Makan %s  (+%d stamina)" % [_item_label(crop), gain], 1.6)
	hud.pop_stamina(gain)


func _item_label(id: String) -> String:
	if not DataRegistry.get_crop(id).is_empty():
		return DataRegistry.crop_name(id)
	return DataRegistry.item_name(id)


# ================================================================ gathering (axe / pickaxe)

func _setup_resources() -> void:
	_resources.clear()
	for child in get_children():
		var n := String(child.name)
		if n.begins_with("Tree_"):
			_resources.append(child)
			child.set_meta("kind", "tree")
		elif n.begins_with("Boulder_"):
			_resources.append(child)
			child.set_meta("kind", "boulder")
	# Cache the pond as an ellipse: the sprite is a rounded pond, so its AABB
	# corners are grass and must not count as water.
	var pond := get_node_or_null("Pond")
	if pond is Node2D:
		var spr := pond.get_node_or_null("Sprite") as Sprite2D
		if spr != null and spr.texture != null:
			var size := spr.texture.get_size()
			_pond_center = (pond as Node2D).to_global(spr.position + size * 0.5)
			_pond_radii = Vector2(maxf(1.0, size.x * 0.5 - 4.0),
				maxf(1.0, size.y * 0.5 - 4.0))


## Anchor used for distance checks and hit particles. Trees are measured at
## their trunk base (the node origin, where the trunk collider sits), boulders
## at the centre of their un-centred sprite.
func _resource_center(node: Node) -> Vector2:
	if node is Sprite2D:
		var s := node as Sprite2D
		if not s.centered and s.texture != null:
			return s.global_position + s.texture.get_size() * 0.5
	return (node as Node2D).global_position


func _hit_resource_near(tool: String) -> void:
	if player == null:
		return
	var target: Vector2 = player.target_pos()
	if target.distance_to(player.global_position) > TARGET_RANGE:
		return
	var want := "boulder" if tool == "pickaxe" else "tree"
	var fdir := Vector2(player.facing) if player.facing != Vector2i.ZERO else Vector2.DOWN
	var best: Node = null
	var best_d := RESOURCE_REACH
	for r in _resources:
		if not is_instance_valid(r) or not (r as CanvasItem).visible:
			continue
		if String(r.get_meta("kind", "")) != want:
			continue
		var anchor := _resource_center(r)
		var d := target.distance_to(anchor)
		if d > best_d:
			continue
		# The object must also be in front of the player, not behind their back.
		var to_obj := anchor - player.global_position
		if to_obj.length_squared() < 0.0001:
			continue
		if fdir.dot(to_obj.normalized()) <= 0.3:
			continue
		best_d = d
		best = r
	if best == null:
		hud.toast("Tidak ada %s di depanmu." % ("batu" if want == "boulder" else "pohon"))
		return
	var cost := GameState.tool_stamina_cost(tool,
		8 if want == "boulder" else 7)
	if not _spend_stamina(cost):
		return
	if player != null and player.has_method("play_action"):
		player.play_action("mining" if want == "boulder" else "axe")
	SfxPlayer.play("hit")
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	_hit_resource(best, want)


func _hit_resource(node: Node, kind: String) -> void:
	var hits := int(node.get_meta("hits", 0)) + 1
	node.set_meta("hits", hits)
	_shake(node)
	_burst(_resource_center(node), kind)
	if hits >= GameState.resource_hits_required(kind):
		node.set_meta("hits", 0)
		_break_resource(node, kind)


func _break_resource(node: Node, kind: String) -> void:
	var id := "wood" if kind == "tree" else "rock"
	var label := "Kayu" if kind == "tree" else "Batu"
	if GameState.add_item(id, label):
		hud.toast("+1 %s" % label, 1.2)
		GameState.quest_event(id, 1)
	else:
		hud.toast("Tas penuh! Jual dulu di Shipping Bin.")
	(node as CanvasItem).visible = false
	node.set_meta("respawn", 3)
	_set_collisions(node, false)


func _respawn_resources() -> void:
	for r in _resources:
		if not is_instance_valid(r):
			continue
		if (r as CanvasItem).visible or not r.has_meta("respawn"):
			continue
		var d := int(r.get_meta("respawn")) - 1
		if d <= 0:
			(r as CanvasItem).visible = true
			r.remove_meta("respawn")
			_set_collisions(r, true)
		else:
			r.set_meta("respawn", d)


func _set_collisions(node: Node, enabled: bool) -> void:
	# Boulders keep their StaticBody2D under the sprite so the art can be
	# un-centred, so this walks down instead of only checking the node itself.
	for c in node.get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).set_deferred("disabled", not enabled)
		else:
			_set_collisions(c, enabled)


func _shake(node: Node) -> void:
	var spr: Node2D = node as Node2D
	if node.has_node("Sprite"):
		spr = node.get_node("Sprite") as Node2D
	if spr == null:
		return
	# Remember the resting position once, so repeated hits can never walk the
	# prop away from where the scene placed it.
	if not spr.has_meta("base_pos"):
		spr.set_meta("base_pos", spr.position)
	var base: Vector2 = spr.get_meta("base_pos")
	var key := spr.get_instance_id()
	var old: Tween = _shake_tweens.get(key)
	if old != null and old.is_valid():
		old.kill()
	spr.position = base
	var tw := create_tween()
	_shake_tweens[key] = tw
	for i in 3:
		tw.tween_property(spr, "position", base + Vector2(2, 0), 0.035)
		tw.tween_property(spr, "position", base - Vector2(2, 0), 0.035)
	tw.tween_property(spr, "position", base, 0.035)
	tw.finished.connect(func() -> void: spr.position = base)


func _burst(pos: Vector2, kind: String) -> void:
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 46.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.1
	p.color = Color(0.55, 0.36, 0.2) if kind == "tree" else Color(0.62, 0.62, 0.66)
	p.texture = load("res://assets/crops/%s.png" % ("wood" if kind == "tree" else "rock"))
	p.position = pos
	p.z_index = 12
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


# ================================================================ fishing (rod)

func is_fishing() -> bool:
	return fishing_active


func fishing_press() -> void:
	if hud != null:
		hud.fishing_press()


func _is_facing_pond() -> bool:
	if player == null or _pond_radii.x <= 0.0:
		return false
	var target: Vector2 = player.target_pos()
	if target.distance_to(player.global_position) > TARGET_RANGE:
		return false
	var d := target - _pond_center
	return (d.x * d.x) / (_pond_radii.x * _pond_radii.x) \
		+ (d.y * d.y) / (_pond_radii.y * _pond_radii.y) <= 1.0


func _try_fish() -> void:
	if fishing_active:
		return
	if not _is_facing_pond():
		hud.toast("Hadapi air kolam dulu untuk memancing.")
		return
	if not _spend_stamina(5):
		return
	fishing_active = true
	if player != null:
		player.input_locked = true
		if player.has_method("play_action"):
			player.play_action("casting", true)
	hud.hide_prompt()
	hud.start_fishing(_on_fish_result)


func _on_fish_result(success: bool) -> void:
	fishing_active = false
	if player != null:
		player.input_locked = false
	if success:
		if GameState.add_item("fish", "Ikan"):
			SfxPlayer.play("catch")
			hud.toast("Dapat ikan! Jual di Shipping Bin atau makan (F).", 2.2)
			GameState.quest_event("fish", 1)
			if player != null and player.has_method("play_action"):
				player.play_action("reeling", true)
		else:
			hud.toast("Tas penuh! Jual dulu di Shipping Bin.")
	else:
		hud.toast("Ikan lepas... coba lagi.", 1.5)
	if player != null:
		on_zone_changed(player.current_zone)


# ================================================================ selling / shop

func _sell_all() -> void:
	var total := GameState.sell_all_produce()
	if total == 0:
		hud.toast("Belum ada hasil panen. Panen tanaman matang dulu.")
		return
	hud.set_gold(GameState.gold)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	hud.pop_gold(total)
	hud.toast("Menjual hasil panen: +%d G" % total, 2.6)
	SfxPlayer.play("coin")


func _open_shop() -> void:
	shop_open = true
	if player != null:
		player.input_locked = true
	hud.hide_prompt()
	hud.open_shop(GameState.gold)


func close_shop() -> void:
	if not shop_open:
		return
	shop_open = false
	if player != null:
		player.input_locked = false
	hud.close_shop()
	if player != null:
		on_zone_changed(player.current_zone)


func buy_seed(id: String) -> void:
	if not shop_open:
		return
	if not GameState.can_add_seed(id):
		hud.toast("Tas penuh! Jual hasil panen dulu.")
		return
	var price := DataRegistry.crop_seed_price(id)
	if not GameState.spend_gold(price):
		hud.toast("Gold tidak cukup untuk membeli bibit ini.")
		return
	if not GameState.add_seed(id, 1):
		GameState.add_gold(price)
		hud.toast("Tidak ada slot kosong untuk bibit!")
		return
	GameState.inventory_changed.emit()
	hud.set_gold(GameState.gold)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	hud.refresh_shop(GameState.gold)
	hud.toast("Bibit %s +1  (-%d G)" % [DataRegistry.crop_seed_name(id), price], 1.8)
	SfxPlayer.play("coin")


## HUD Upgrade tab button -> spend 150 G + 5 wood + 5 rock to reach Lv.2.
func upgrade_tool(tool: String) -> bool:
	if not shop_open:
		return false
	var display := String(GameState.TOOL_NAMES.get(tool, tool))
	if GameState.tool_upgraded(tool):
		hud.toast("%s sudah mencapai Lv.2." % display, 1.6)
		return false
	if not GameState.can_upgrade_tool(tool):
		hud.toast("Butuh %d G + %d Kayu + %d Batu untuk upgrade."
			% [GameState.TOOL_UPGRADE_GOLD, GameState.TOOL_UPGRADE_WOOD,
				GameState.TOOL_UPGRADE_ROCK], 2.0)
		return false
	if not GameState.upgrade_tool(tool):
		return false
	hud.set_gold(GameState.gold)
	hud.refresh_hotbar(GameState.hotbar, GameState.selected_slot)
	hud.refresh_shop(GameState.gold)
	hud.toast("%s naik ke Lv.2! Stamina -50%%%s" % [display,
		", hancurkan dalam 2 pukulan." if tool == "axe" or tool == "pickaxe" else "."],
		2.4)
	SfxPlayer.play("coin")
	return true


# ================================================================ lighting

func _sky_color(h: float) -> Color:
	for i in range(SKY_KEYS.size() - 1):
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var t := (h - float(a[0])) / (float(b[0]) - float(a[0]))
			return (a[1] as Color).lerp(b[1] as Color, t)
	return SKY_KEYS[0][1]