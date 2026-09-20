extends Node

signal state_changed
signal round_prepared
signal snapshot_received(state: Dictionary)
signal game_event(event: Dictionary)
signal connection_message(message: String)

enum Phase { LOBBY, INSTRUCTIONS, COUNTDOWN, PLAYING, ROUND_RESULTS, MATCH_RESULTS }

const PROTOCOL: int = 3
const RULES: Array[GameRules] = [preload("res://resources/ballista.tres"), preload("res://resources/lance.tres"), preload("res://resources/coins.tres")]

var server_mode: bool = false
var connected: bool = false
var roster: Dictionary = {}
var leader: int = -1
var phase: Phase = Phase.LOBBY
var game_index: int = 0
var selected_games: Array[String] = ["ballista", "lance", "coins"]
var random_order: bool = false
var game_order: Array[String] = ["ballista", "lance", "coins"]
var game_slot: int = 0
var round_index: int = 0
var round_id: int = 0
var heat_id: int = 0
var active_round_count: int = 3
var practice: bool = false
var game_complete: bool = false
var game_totals: Dictionary = {}
var round_performance: Dictionary = {}
var _action_sequence: int = 0
var _action_acks: Dictionary = {}
var remaining: float = 0.0
var loading: bool = false
var game_state: Dictionary = {}
var secret: Dictionary = {}
var round_points: Dictionary = {}
var game: PartyGame
var test_fast: bool = false
var _peer: ENetMultiplayerPeer
var _pending_connections: Dictionary = {}
var _loaded: Dictionary = {}
var _load_elapsed: float = 0.0
var _snapshot_elapsed: float = 0.0
var _revision: int = 0
var _snapshot_number: int = 0
var _last_snapshot: int = -1
var _rates: Dictionary = {}
var _display_name: String = "Peasant"
var _character: int = 0
var _connection_elapsed: float = 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(func() -> void: disconnect_client("Could not reach the server. Check its address and UDP port."))
	multiplayer.server_disconnected.connect(func() -> void: disconnect_client("The server disconnected. Your session has ended."))


func _physics_process(delta: float) -> void:
	if not server_mode:
		if _peer != null and not connected:
			_connection_elapsed += delta
			if _connection_elapsed > 10.0:
				disconnect_client("Connection timed out. The server may be offline or full.")
		return
	for id: int in _pending_connections.keys():
		if Time.get_ticks_msec() - int(_pending_connections[id]) > 5000:
			_peer.disconnect_peer(id)
			_pending_connections.erase(id)
	if loading:
		_load_elapsed += delta
		if _loaded.size() == roster.size():
			loading = false
			_broadcast()
		elif _load_elapsed > 20.0:
			var timed_out: Array[int] = []
			for id: int in roster.keys():
				if not _loaded.has(id):
					timed_out.append(id)
			# Disconnecting a shooter restarts loading; retain the original timeout set.
			for id: int in timed_out:
				_reject(id, "Scene loading timed out.")
				_peer_disconnected(id)
	elif phase == Phase.PLAYING and is_instance_valid(game):
		game.tick(delta)
	elif phase in [Phase.INSTRUCTIONS, Phase.COUNTDOWN, Phase.ROUND_RESULTS]:
		remaining -= delta
		if remaining <= 0.0:
			_advance_phase()
	_snapshot_elapsed += delta
	if _snapshot_elapsed >= 0.05:
		_snapshot_elapsed = 0.0
		_snapshot_number += 1
		var state: Dictionary = game.public_state() if is_instance_valid(game) else {}
		for id: int in roster:
			if _can_send(id):
				_receive_snapshot.rpc_id(id, round_id, _revision, _snapshot_number, remaining, state)


func start_server(port: int) -> Error:
	server_mode = true
	# Clients communicate only with the authority; peer relay also races mass disconnects.
	(multiplayer as SceneMultiplayer).server_relay = false
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_server(port, 8)
	if error != OK:
		push_error("Cannot bind game server port %d: %s" % [port, error_string(error)])
		return error
	multiplayer.multiplayer_peer = _peer
	print("SERVER_READY port=%d protocol=%d" % [port, PROTOCOL])
	return OK


func connect_to_server(address: String, port: int, player_name: String, character: int) -> void:
	if _peer != null:
		disconnect_client("")
	_display_name = player_name.strip_edges().left(20)
	_character = clampi(character, 0, 5)
	_connection_elapsed = 0.0
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_client(address.strip_edges(), port)
	if error != OK:
		disconnect_client("Connection could not start: " + error_string(error))
		return
	multiplayer.multiplayer_peer = _peer
	connection_message.emit("Connecting to the royal court…")


func disconnect_client(message: String) -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected = false
	roster.clear()
	game_state.clear()
	secret.clear()
	phase = Phase.LOBBY
	round_id = 0
	_revision = 0
	_last_snapshot = -1
	state_changed.emit()
	connection_message.emit(message)


func set_ready(value: bool, character: int) -> void:
	_lobby_ready.rpc_id(1, value, character)


func set_player_name(value: String) -> void:
	_lobby_name.rpc_id(1, value)


func set_match_options(games: Array[String], shuffled: bool) -> void:
	_lobby_options.rpc_id(1, games, shuffled)


func player_number(id: int) -> int:
	return int(roster.get(id, {}).get("number", player_ids().find(id) + 1))


func player_caption(id: int) -> String:
	return "P%d · %s" % [player_number(id), roster.get(id, {}).get("name", "Peasant")]


func _available_number() -> int:
	for number: int in range(1, 5):
		var taken: bool = false
		for id: int in roster:
			taken = taken or player_number(id) == number
		if not taken:
			return number
	return 0


func request_start() -> void:
	_start_match.rpc_id(1)


func request_rematch() -> void:
	_rematch.rpc_id(1)


func scene_loaded() -> void:
	if _peer != null and connected:
		_scene_loaded.rpc_id(1, round_id, heat_id)


func send_action(kind: String, payload: Dictionary = {}) -> void:
	if _peer != null and connected and phase == Phase.PLAYING:
		_action_sequence += 1
		_action.rpc_id(1, round_id, heat_id, _action_sequence, kind, payload)


func send_input(frames: Array) -> void:
	if _peer != null and connected and phase == Phase.PLAYING:
		_input_frames.rpc_id(1, round_id, heat_id, frames)


func current_rules() -> GameRules:
	return RULES[game_index]


func rule_index(id: String) -> int:
	for index: int in RULES.size():
		if str(RULES[index].game_id) == id:
			return index
	return -1


func rounds_for(id: String, count: int) -> int:
	var definition: GameRules = RULES[rule_index(id)]
	return maxi(1, count) if definition.rotating_roles else definition.round_count


func _begin_game() -> void:
	game_index = rule_index(game_order[game_slot])
	active_round_count = rounds_for(game_order[game_slot], roster.size())
	round_index = 0
	game_totals.clear()
	for id: int in roster:
		game_totals[id] = 0.0
	_prepare_round()


func player_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in roster:
		ids.append(id)
	return ids


func _peer_connected(id: int) -> void:
	if server_mode:
		_pending_connections[id] = Time.get_ticks_msec()


func _peer_disconnected(id: int) -> void:
	if not server_mode:
		return
	_pending_connections.erase(id)
	_loaded.erase(id)
	_rates.erase(id)
	_action_acks.erase(id)
	if not roster.has(id):
		return
	print("PLAYER_LEFT id=%d" % id)
	roster.erase(id)
	game_totals.erase(id)
	if is_instance_valid(game):
		game.forfeit(id)
	leader = int(roster.keys()[0]) if not roster.is_empty() else -1
	if roster.is_empty():
		selected_games = ["ballista", "lance", "coins"]
		random_order = false
	if phase != Phase.LOBBY and (roster.is_empty() or (not practice and roster.size() < 2)):
		_return_to_lobby()
	elif phase not in [Phase.LOBBY, Phase.MATCH_RESULTS] and current_rules().rotating_roles and not game_complete:
		print("ROTATION_RESTART players=%d" % roster.size())
		_begin_game()
	else:
		_broadcast()

func _connected_to_server() -> void:
	_hello.rpc_id(1, PROTOCOL, _display_name, _character)


func _reject(id: int, reason: String) -> void:
	if _can_send(id):
		_rejected.rpc_id(id, reason)
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if _peer != null and multiplayer.get_peers().has(id):
			_peer.disconnect_peer(id)
		_peer_disconnected(id)
	)


func _can_send(id: int) -> bool:
	if _peer == null or not multiplayer.get_peers().has(id):
		return false
	return _peer.get_peer(id).get_state() == ENetPacketPeer.STATE_CONNECTED


func _allow(id: int, bucket: String, maximum: int) -> bool:
	if not roster.has(id):
		return false
	var windows: Dictionary = _rates.get(id, {})
	var entry: Dictionary = windows.get(bucket, {"time": Time.get_ticks_msec(), "count": 0})
	if Time.get_ticks_msec() - int(entry["time"]) >= 1000:
		entry = {"time": Time.get_ticks_msec(), "count": 0}
	entry["count"] = int(entry["count"]) + 1
	windows[bucket] = entry
	_rates[id] = windows
	return int(entry["count"]) <= maximum


@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(version: int, player_name: String, character: int) -> void:
	if not server_mode:
		return
	var id: int = multiplayer.get_remote_sender_id()
	if not _pending_connections.has(id) or roster.has(id):
		return
	_pending_connections.erase(id)
	if version != PROTOCOL:
		_reject(id, "Version mismatch. Install the same Party Knight build as the server.")
		return
	if phase != Phase.LOBBY or roster.size() >= 4:
		_reject(id, "A match is in progress." if phase != Phase.LOBBY else "The lobby is full (4 players).")
		return
	roster[id] = {"name": _clean_name(player_name), "number": _available_number(), "character": clampi(character, 0, 5), "ready": false, "score": 0}
	if leader < 0:
		leader = id
	print("PLAYER_JOINED id=%d" % id)
	_broadcast()


@rpc("any_peer", "call_remote", "reliable", 0)
func _lobby_ready(value: bool, character: int) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	if not server_mode or phase != Phase.LOBBY or not _allow(id, "lobby", 8):
		return
	roster[id]["ready"] = value
	roster[id]["character"] = clampi(character, 0, 5)
	_broadcast()


@rpc("any_peer", "call_remote", "reliable", 0)
func _start_match() -> void:
	_begin_match(multiplayer.get_remote_sender_id())


func _begin_match(sender: int) -> bool:
	if not server_mode or sender != leader or phase != Phase.LOBBY or roster.is_empty() or selected_games.is_empty():
		return false
	for id: int in roster:
		if not bool(roster[id]["ready"]):
			return false
	game_order = selected_games.duplicate()
	if random_order:
		game_order.shuffle()
	practice = roster.size() == 1
	game_slot = 0
	for id: int in roster:
		roster[id]["score"] = 0
	_begin_game()
	return true

@rpc("any_peer", "call_remote", "reliable", 0)
func _lobby_name(value: String) -> void:
	_rename_player(multiplayer.get_remote_sender_id(), value)


func _rename_player(sender: int, value: String) -> bool:
	if not server_mode or phase != Phase.LOBBY or not _allow(sender, "name", 8):
		return false
	roster[sender]["name"] = _clean_name(value)
	_broadcast()
	return true


func _clean_name(value: String) -> String:
	var cleaned: String = value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(20)
	return cleaned if not cleaned.is_empty() else "Peasant"


@rpc("any_peer", "call_remote", "reliable", 0)
func _lobby_options(games: Array, shuffled: bool) -> void:
	_update_match_options(multiplayer.get_remote_sender_id(), games, shuffled)


func _update_match_options(sender: int, games: Array, shuffled: bool) -> bool:
	if not server_mode or phase != Phase.LOBBY or sender != leader or not _allow(sender, "options", 12) or games.size() > RULES.size():
		return false
	var validated: Array[String] = []
	for value: Variant in games:
		if not value is String or rule_index(value) < 0 or validated.has(value):
			return false
		validated.append(value)
	selected_games.clear()
	for definition: GameRules in RULES:
		if validated.has(str(definition.game_id)):
			selected_games.append(str(definition.game_id))
	random_order = shuffled
	_broadcast()
	return true

@rpc("any_peer", "call_remote", "reliable", 0)
func _rematch() -> void:
	if server_mode and phase == Phase.MATCH_RESULTS and multiplayer.get_remote_sender_id() == leader:
		_return_to_lobby()


@rpc("any_peer", "call_remote", "reliable", 0)
func _scene_loaded(token: int, heat: int) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	if server_mode and roster.has(id) and token == round_id and heat == heat_id and loading:
		_loaded[id] = true

@rpc("any_peer", "call_remote", "reliable", 1)
func _action(token: int, heat: int, sequence: int, kind: String, payload: Dictionary) -> void:
	route_action(multiplayer.get_remote_sender_id(), token, heat, sequence, kind, payload)


func route_action(id: int, token: int, heat: int, sequence: int, kind: String, payload: Dictionary) -> bool:
	if not _valid_input(id, token) or heat != heat_id or not _allow(id, "action", 20) or payload.size() > 4:
		return false
	var previous: int = int(_action_acks.get(id, 0))
	if sequence <= previous or sequence > previous + 180:
		return false
	_action_acks[id] = sequence
	if _can_send(id):
		game.latency[id] = float(_peer.get_peer(id).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) / 1000.0
	game.action(id, kind, payload)
	return true

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _input_frames(token: int, heat: int, frames: Array) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	if _valid_input(id, token) and heat == heat_id and frames.size() <= 3 and _allow(id, "movement", 90):
		game.input_frame(id, frames)

func _valid_input(id: int, token: int) -> bool:
	return server_mode and phase == Phase.PLAYING and token == round_id and roster.has(id) and is_instance_valid(game) and bool(game.alive.get(id, false))


func _prepare_round() -> void:
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
	round_id += 1
	heat_id = round_index if current_rules().rotating_roles else 0
	game_complete = false
	round_performance.clear()
	_action_acks.clear()
	round_points.clear()
	_loaded.clear()
	_load_elapsed = 0.0
	loading = true
	game = RULES[game_index].scene.instantiate() as PartyGame
	add_child(game)
	game.setup(player_ids(), round_index, current_rules(), practice)
	game.round_finished.connect(_round_finished)
	game.event_occurred.connect(_on_game_event)
	phase = Phase.INSTRUCTIONS if round_index == 0 else Phase.COUNTDOWN
	remaining = RULES[game_index].instruction_seconds if round_index == 0 else RULES[game_index].countdown_seconds
	if test_fast:
		remaining = 0.3
	_broadcast()
	for id: int in roster:
		if _can_send(id):
			_receive_secret.rpc_id(id, round_id, game.private_state(id))


func _advance_phase() -> void:
	match phase:
		Phase.INSTRUCTIONS:
			phase = Phase.COUNTDOWN
			remaining = 0.3 if test_fast else current_rules().countdown_seconds
		Phase.COUNTDOWN:
			phase = Phase.PLAYING
			remaining = 0.0
		Phase.ROUND_RESULTS:
			round_index += 1
			if round_index >= active_round_count:
				game_slot += 1
				if game_slot >= game_order.size():
					game_slot = game_order.size() - 1
					round_index = active_round_count - 1
					phase = Phase.MATCH_RESULTS
					print("MATCH_COMPLETE scores=%s" % JSON.stringify(roster))
				else:
					_begin_game()
					return
			else:
				_prepare_round()
				return
	_broadcast()

func _round_finished(performance: Dictionary) -> void:
	round_performance = performance.duplicate()
	for id: int in roster:
		game_totals[id] = float(game_totals.get(id, 0.0)) + float(performance.get(id, 0.0))
	game_complete = round_index + 1 >= active_round_count
	round_points.clear()
	if game_complete and not practice:
		round_points = PartyGame.placement_points(game_totals)
		for id: int in roster:
			roster[id]["score"] = int(roster[id]["score"]) + int(round_points.get(id, 0))
	phase = Phase.ROUND_RESULTS
	remaining = 0.3 if test_fast else current_rules().results_seconds
	print("ROUND_COMPLETE game=%s round=%d heat=%d performance=%s points=%s" % [current_rules().game_id, round_index, heat_id, JSON.stringify(performance), JSON.stringify(round_points)])
	_broadcast()

func _on_game_event(event: Dictionary) -> void:
	for id: int in roster:
		if _can_send(id):
			_receive_event.rpc_id(id, round_id, event)


func _return_to_lobby() -> void:
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
	game = null
	phase = Phase.LOBBY
	practice = false
	game_complete = false
	game_totals.clear()
	round_performance.clear()
	_loaded.clear()
	_action_acks.clear()
	loading = false
	remaining = 0.0
	round_points.clear()
	for id: int in roster:
		roster[id]["ready"] = false
		roster[id]["score"] = 0
	_broadcast()


func _broadcast() -> void:
	_revision += 1
	var data: Dictionary = {"roster": roster, "leader": leader, "phase": phase, "game": str(current_rules().game_id), "round": round_index, "token": round_id, "remaining": remaining, "loading": loading, "points": round_points, "revision": _revision, "state": game.public_state() if is_instance_valid(game) else {}}
	data.merge({"selected_games": selected_games, "random_order": random_order, "game_order": game_order, "game_slot": game_slot, "heat": heat_id, "round_count": active_round_count, "practice": practice, "game_complete": game_complete, "totals": game_totals, "performance": round_performance})
	for id: int in roster:
		if _can_send(id):
			_receive_state.rpc_id(id, data)
	print("STATE phase=%s token=%d players=%d" % [Phase.keys()[phase], round_id, roster.size()])


@rpc("authority", "call_remote", "reliable", 0)
func _receive_state(data: Dictionary) -> void:
	var new_round: bool = round_id != int(data["token"])
	connected = true
	roster = data["roster"]
	leader = int(data["leader"])
	phase = int(data["phase"]) as Phase
	game_index = rule_index(str(data["game"]))
	heat_id = int(data["heat"])
	active_round_count = int(data["round_count"])
	practice = bool(data["practice"])
	game_complete = bool(data["game_complete"])
	game_totals = data["totals"]
	round_performance = data["performance"]
	selected_games.assign(data["selected_games"])
	random_order = bool(data["random_order"])
	game_order.assign(data["game_order"])
	game_slot = int(data["game_slot"])
	round_index = int(data["round"])
	round_id = int(data["token"])
	remaining = float(data["remaining"])
	loading = bool(data["loading"])
	round_points = data["points"]
	_revision = int(data["revision"])
	game_state = data["state"]
	if new_round:
		_action_sequence = 0
		secret.clear()
		_last_snapshot = -1
		round_prepared.emit()
	state_changed.emit()
	snapshot_received.emit(game_state)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_secret(token: int, data: Dictionary) -> void:
	if token == round_id:
		secret = data
		state_changed.emit()


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _receive_snapshot(token: int, revision: int, number: int, seconds: float, state: Dictionary) -> void:
	if token != round_id or revision != _revision or number <= _last_snapshot:
		return
	_last_snapshot = number
	remaining = seconds
	game_state = state
	snapshot_received.emit(state)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_event(token: int, event: Dictionary) -> void:
	if token == round_id:
		game_event.emit(event)


@rpc("authority", "call_remote", "reliable", 0)
func _rejected(reason: String) -> void:
	disconnect_client(reason)
