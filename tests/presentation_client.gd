extends "res://tests/network_client.gd"

var target: Node
var maximum_error: float = 0.0
var samples: int = 0
var _keys: Dictionary = {}
var _reported: bool = false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var arena: ArenaView = target.get("arena") as ArenaView
	var me: int = multiplayer.get_unique_id()
	if Session.phase != Session.Phase.PLAYING:
		send_movement(Vector2.ZERO)
	if arena.view != null and arena.view.local_pawn != null and arena.view.active(me):
		var bodies: Dictionary = Session.game_state.get("bodies", {})
		if bodies.has(me):
			var error: float = arena.view.local_pawn.position.distance_to(bodies[me]["position"])
			maximum_error = maxf(maximum_error, error)
			samples += 1
			if error > 3.0:
				push_error("Predicted pawn diverged from authority: %.3f m" % error)
				get_tree().quit(1)
	if Session.phase == Session.Phase.MATCH_RESULTS and not _reported:
		_reported = true
		if samples == 0:
			push_error("No presentation prediction samples collected")
			get_tree().quit(1)
		print("PRESENTATION_PASS samples=%d max_snapshot_distance=%.3f" % [samples, maximum_error])


func send_movement(direction: Vector2) -> void:
	var desired: Dictionary = {KEY_A: direction.x < -0.15, KEY_D: direction.x > 0.15, KEY_W: direction.y < -0.15, KEY_S: direction.y > 0.15}
	for key: int in desired:
		if bool(_keys.get(key, false)) == bool(desired[key]):
			continue
		_keys[key] = desired[key]
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key as Key
		event.pressed = desired[key]
		Input.parse_input_event(event)
