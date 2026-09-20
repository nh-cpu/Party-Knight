class_name MovingGame
extends PartyGame

var pawns: Dictionary = {}
var pending: Dictionary = {}
var last_frames: Dictionary = {}
var received_at: Dictionary = {}
var acknowledgements: Dictionary = {}
var shove_until: Dictionary = {}
var _shoves: Array[int] = []


func spawn_pawns(positions: Dictionary) -> void:
	for id: int in positions:
		var pawn: PartyPawn = PartyPawn.new()
		add_child(pawn)
		pawn.position = positions[id]
		pawns[id] = pawn
		pending[id] = []
		last_frames[id] = {}
		received_at[id] = 0.0
		acknowledgements[id] = -1
		shove_until[id] = 0.0


func input_frame(sender: int, frames: Array) -> void:
	if not can_act(sender) or not pawns.has(sender):
		return
	var queue: Array = pending[sender]
	for raw: Variant in frames.slice(0, 3):
		if not raw is Dictionary:
			continue
		var frame: Dictionary = raw
		if frame.size() > 4 or not frame.get("seq") is int:
			continue
		if not (frame.get("x") is float or frame.get("x") is int) or not (frame.get("z") is float or frame.get("z") is int):
			continue
		if frame.has("jump") and (not frame["jump"] is bool or bool(frame["jump"])):
			continue
		var seq: int = int(frame["seq"])
		var previous: int = int(queue.back()["seq"]) if not queue.is_empty() else int(acknowledgements[sender])
		var direction: Vector2 = Vector2(float(frame["x"]), float(frame["z"]))
		if not direction.is_finite() or seq <= previous or seq > previous + 180 or queue.size() >= 8:
			continue
		direction = direction.limit_length(1.0)
		queue.append({"seq": seq, "x": direction.x, "z": direction.y, "jump": false})
		received_at[sender] = elapsed


func action(sender: int, kind: String, _payload: Dictionary) -> void:
	if kind == "shove" and can_act(sender) and pawns.has(sender) and elapsed >= float(shove_until[sender]):
		shove_until[sender] = elapsed + 1.0
		_shoves.append(sender)


func tick(delta: float) -> void:
	super.tick(delta)
	for id: int in pawns:
		var pawn: PartyPawn = pawns[id]
		if not can_act(id):
			pawn.collision_layer = 0
			continue
		var queue: Array = pending[id]
		if not queue.is_empty():
			var frame: Dictionary = queue.pop_front()
			last_frames[id] = frame
			acknowledgements[id] = int(frame["seq"])
		elif elapsed - float(received_at[id]) > 0.25:
			last_frames[id] = {}
		pawn.simulate(last_frames[id], delta)
	_resolve_shoves()


func _resolve_shoves() -> void:
	var impulses: Dictionary = {}
	for sender: int in _shoves:
		if not can_act(sender):
			continue
		var source: PartyPawn = pawns[sender]
		for target: int in pawns:
			if target == sender or not can_act(target):
				continue
			var victim: PartyPawn = pawns[target]
			var offset: Vector3 = victim.position - source.position
			offset.y = 0
			if offset.length() > 1.2 or offset.length() < 0.01 or source.facing.dot(offset.normalized()) < cos(deg_to_rad(35.0)):
				continue
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(source.position + Vector3.UP, victim.position + Vector3.UP, 1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				continue
			impulses[target] = (impulses.get(target, Vector3.ZERO) as Vector3) + source.facing * 6.0
		event_occurred.emit({"type": "shove", "id": sender})
	for id: int in impulses:
		(pawns[id] as PartyPawn).impulse += (impulses[id] as Vector3).limit_length(8.0)
	_shoves.clear()


func public_state() -> Dictionary:
	var state: Dictionary = super.public_state()
	var bodies: Dictionary = {}
	for id: int in pawns:
		bodies[id] = (pawns[id] as PartyPawn).state(int(acknowledgements[id]))
	state.merge({"bodies": bodies, "shove_until": shove_until.duplicate()})
	return state
