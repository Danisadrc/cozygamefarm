extends SceneTree
## Play-test: drive the player with simulated key presses and confirm it can
## reach the bed (and that the interaction zone fires).

var _world: Node
var _player: CharacterBody2D
var _frame := 0
var _phase := 0
var _log: Array[String] = []
var _keys := {}


func _initialize() -> void:
	_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(_world)
	_player = _world.get_node("Player") as CharacterBody2D


func _press(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _hold(code: Key) -> void:
	if not _keys.get(code, false):
		_keys[code] = true
		_press(code, true)


func _release(code: Key) -> void:
	if _keys.get(code, false):
		_keys[code] = false
		_press(code, false)


func _release_all() -> void:
	for k in _keys.keys():
		_release(k)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame < 5:
		return false

	var pos := _player.global_position
	match _phase:
		0:
			_log.append("spawn %s" % pos)
			_phase = 1
		1:  # walk right until under the bedroom doorway
			_hold(KEY_D)
			if pos.x >= 328.0:
				_release(KEY_D)
				_log.append("tiba di bawah pintu kamar %s" % pos)
				_phase = 2
		2:  # walk up through the doorway
			_hold(KEY_W)
			if pos.y <= 132.0:
				_release(KEY_W)
				_log.append("masuk kamar %s" % pos)
				_phase = 3
		3:  # keep walking up until the bed blocks us
			_hold(KEY_W)
			if pos.y <= 118.0 or _frame > 900:
				_release_all()
				_log.append("berhenti di depan kasur %s" % pos)
				_phase = 4
		4:
			_log.append("zona sekarang: %s" % str(_player.get("current_zone")))
			_log.append("player sprite anim: %s" % str((_player.get_node("Sprite") as AnimatedSprite2D).animation))
			for line in _log:
				print(line)
			return true

	if _frame > 1200:
		_release_all()
		_log.append("TIMEOUT di %s fase %d" % [pos, _phase])
		for line in _log:
			print(line)
		return true
	return false
