extends Node

var _sequence: int = 0
var _frames: Array[Dictionary] = []
var _elapsed: float = 0.0
var _action_elapsed: float = 0.0
var _seen_rounds: Dictionary = {}
var _started: bool = false
var _expected_players: int = 2
var _name: String = "Test"
var _last_turn: int = -99
var _expected_reject: bool = false
var _hold_lobby: bool = false
var _probe_version: bool = false
var _withhold_load: bool = false
var _reject_text: String = ""
var _requested_games: Array[String] = ["ballista", "lance", "coins"]
var _random_order: bool = false
var _options_sent: bool = false
var _rename_sent: bool = false
var _expected_rounds: int = 9
var _player_numbers: Dictionary = {}
var _expected_matches: int = 1
var _completed_matches: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_name = _argument(args, "--name", "Test")
	_expected_players = int(_argument(args, "--players", "2"))
	_expected_matches = maxi(1, int(_argument(args, "--matches", "1")))
	_expected_reject = "--expect-reject" in args
	_hold_lobby = "--hold-lobby" in args
	_probe_version = "--wrong-version" in args
	_withhold_load = "--withhold-load" in args
	_reject_text = _argument(args, "--reject-text", "")
	_requested_games.clear()
	for value: String in _argument(args, "--games", "ballista,lance,coins").split(","):
		_requested_games.append(value)
	_random_order = "--random-order" in args
	_expected_rounds = 0
	for definition: GameRules in Session.RULES:
		if _requested_games.has(str(definition.game_id)):
			_expected_rounds += Session.rounds_for(str(definition.game_id), _expected_players)
	var canonical: Array[String] = []
	for definition: GameRules in Session.RULES:
		if _requested_games.has(str(definition.game_id)):
			canonical.append(str(definition.game_id))
	_requested_games = canonical
	if _probe_version:
		multiplayer.connected_to_server.disconnect(Session._connected_to_server)
		multiplayer.connected_to_server.connect(func() -> void: Session.rpc_id(1, "_hello", -1, "OldClient", 0))
	Session.round_prepared.connect(func() -> void:
		_sequence = 0
		_frames.clear()
		_last_turn = -99
		if not _withhold_load:
			Session.scene_loaded()
	)
	Session.state_changed.connect(_state_changed)
	Session.connection_message.connect(func(message: String) -> void:
		if message.begins_with("Connecting"):
			return
		if _expected_reject and not message.is_empty() and (_reject_text.is_empty() or _reject_text in message):
			print("EXPECTED_REJECTION %s" % message)
			get_tree().quit(0)
		elif not message.is_empty():
			push_error("Unexpected disconnect: " + message)
			get_tree().quit(1)
	)
	Session.connect_to_server(_argument(args, "--connect", "127.0.0.1"), int(_argument(args, "--port", "7000")), _name, int(_argument(args, "--character", "0")))


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 700 * _expected_matches:
		push_error("Network test timed out")
		get_tree().quit(1)
	if not Session.connected or Session.phase != Session.Phase.PLAYING:
		return
	var me: int = multiplayer.get_unique_id()
	if not bool((Session.game_state.get("alive", {}) as Dictionary).get(me, false)):
		return
	_action_elapsed += delta
	match Session.current_rules().game_id:
		&"coins":
			if _action_elapsed >= 0.12:
				_action_elapsed = 0.0
				var warning: bool = int((Session.game_state.get("hazard", {}) as Dictionary).get("phase", 0)) == HazardClock.Phase.WARNING
				if not warning or Session.player_number(me) % 2 == 0:
					Session.send_action("collect")
		&"ballista":
			var bodies: Dictionary = Session.game_state.get("bodies", {})
			if int(Session.game_state.get("shooter", -1)) == me:
				if _action_elapsed >= 0.55:
					_action_elapsed = 0.0
					for id: int in bodies:
						if bool(Session.game_state["alive"][id]) and not (Session.game_state.get("escaped", {}) as Dictionary).has(id):
							var direction: Vector3 = ((bodies[id]["position"] as Vector3) + Vector3.UP * 0.8 - BallistaArena.MOUNT).normalized()
							Session.send_action("shoot", {"direction": direction})
							break
			elif bodies.has(me) and not (Session.game_state.get("escaped", {}) as Dictionary).has(me):
				var at: Vector3 = bodies[me]["position"]
				var lane: float = 5.1 if Session.player_number(me) % 2 == 0 else -5.1
				send_movement(Vector2(clampf((lane - at.x) * 2.0, -1, 1), -1.0 if absf(lane - at.x) < 0.5 else 0.0))
		&"lance":
			var available: Array = Session.game_state.get("refuges", [])
			var bodies: Dictionary = Session.game_state.get("bodies", {})
			if not available.is_empty() and bodies.has(me):
				var refuge: int = int(available[(Session.player_number(me) - 1) % available.size()])
				var target: Vector3 = Vector3(-6 + (refuge % 4) * 4, 0, -3.6 if refuge < 4 else 3.6)
				var at: Vector3 = bodies[me]["position"]
				var aim: Vector3 = target
				if absf(target.x - at.x) > 0.1:
					aim.z = -2.2 if target.z < 0 else 2.2
				send_movement(Vector2((aim.x - at.x) * 2, (aim.z - at.z) * 2).limit_length(1))
				if _action_elapsed > 1.2:
					_action_elapsed = 0.0
					Session.send_action("shove")


func send_movement(direction: Vector2) -> void:
	_frames.append({"seq": _sequence, "x": direction.x, "z": direction.y, "jump": false})
	_sequence += 1
	if _frames.size() > 3:
		_frames.pop_front()
	Session.send_input(_frames)


func _state_changed() -> void:
	if not Session.connected:
		return
	var me: int = multiplayer.get_unique_id()
	if Session.phase == Session.Phase.LOBBY:
		if _started:
			_started = false
			_seen_rounds.clear()
			for id: int in Session.roster:
				if int(Session.roster[id]["score"]) != 0:
					push_error("Rematch did not reset scores")
					get_tree().quit(1)
					return
			print("CLIENT_REMATCH_RESET names_and_numbers_preserved=true")
		for id: int in Session.roster:
			var number: int = Session.player_number(id)
			if number < 1 or number > 4 or (_player_numbers.has(id) and int(_player_numbers[id]) != number):
				push_error("Player number changed or is invalid")
				get_tree().quit(1)
				return
			_player_numbers[id] = number
		if not _rename_sent:
			_rename_sent = true
			Session.set_player_name(_name + "Custom")
			return
		if str(Session.roster[me]["name"]) != _name + "Custom":
			return
		if not bool(Session.roster[me]["ready"]):
			Session.set_ready(true, int(Session.roster[me]["character"]))
		if Session.roster.size() == _expected_players and Session.leader == me and not _hold_lobby:
			if not _options_sent:
				_options_sent = true
				Session.set_match_options(_requested_games, _random_order)
				return
			if Session.selected_games != _requested_games or Session.random_order != _random_order:
				return
			var ready: bool = true
			for id: int in Session.roster:
				ready = ready and bool(Session.roster[id]["ready"])
			if ready:
				Session.request_start()
	elif Session.phase == Session.Phase.ROUND_RESULTS:
		_seen_rounds[Session.round_id] = true
		var scores: Array[String] = []
		for id: int in Session.roster:
			scores.append("%s:%d" % [Session.roster[id]["name"], Session.roster[id]["score"]])
		scores.sort()
		print("CLIENT_ROUND token=%d game=%s heat=%d scores=%s" % [Session.round_id, Session.current_rules().game_id, Session.heat_id, JSON.stringify(scores)])
	elif Session.phase == Session.Phase.MATCH_RESULTS and not _started:
		_started = true
		if _seen_rounds.size() != _expected_rounds:
			push_error("Expected %d rounds, got %d" % [_expected_rounds, _seen_rounds.size()])
			get_tree().quit(1)
			return
		var sorted_order: Array[String] = Session.game_order.duplicate()
		sorted_order.sort()
		var expected: Array[String] = _requested_games.duplicate()
		expected.sort()
		if sorted_order != expected:
			push_error("Played games outside the selected list")
			get_tree().quit(1)
			return
		print("CLIENT_MATCH_COMPLETE rounds=%d games=%s names_and_numbers=true" % [_expected_rounds, JSON.stringify(Session.game_order)])
		_completed_matches += 1
		if _completed_matches < _expected_matches:
			if Session.leader == me:
				get_tree().create_timer(1.0).timeout.connect(Session.request_rematch)
		else:
			get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(0))


func _argument(args: PackedStringArray, key: String, fallback: String) -> String:
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
