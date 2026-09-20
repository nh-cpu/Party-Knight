class_name BallistaGame
extends MovingGame

var shooter: int = -1
var ammunition: int = 4
var reload_until: float = 0.0
var shot_until: float = 0.0
var escaped: Dictionary = {}
var history: Array[Dictionary] = []
var aim: Vector3 = Vector3.BACK
var _shots: Array[Dictionary] = []


func configure(heat_number: int) -> void:
	var arena: BallistaArena = BallistaArena.new()
	add_child(arena)
	arena.build(false)
	shooter = -1 if practice else players[heat_number % players.size()]
	var runners: Array[int] = players.duplicate()
	runners.erase(shooter)
	var positions: Dictionary = {}
	for index: int in runners.size():
		positions[runners[index]] = Vector3((index - (runners.size() - 1) * 0.5) * 2.5, 0.05, 16)
	spawn_pawns(positions)
	_record_history()


func can_act(id: int) -> bool:
	return super.can_act(id) and not escaped.has(id)


func action(sender: int, kind: String, payload: Dictionary) -> void:
	if sender != shooter:
		super.action(sender, kind, payload)
		return
	if kind != "shoot" or not can_act(sender) or not payload.get("direction") is Vector3:
		return
	var direction: Vector3 = payload["direction"]
	if not direction.is_finite() or direction.length() < 0.9 or direction.length() > 1.1:
		return
	direction = direction.normalized()
	if direction.z < 0.1 or absf(direction.y) > 0.75:
		return
	if ammunition <= 0 or elapsed < reload_until or elapsed < shot_until:
		return
	shot_until = elapsed + 0.5
	ammunition -= 1
	if ammunition == 0:
		reload_until = elapsed + 3.0
	aim = direction
	# The authority chooses the rewind window from ENet RTT, never a client timestamp.
	var rewind: float = clampf(float(latency.get(sender, 0.0)) * 0.5 + 0.05, 0, 0.2)
	_shots.append({"direction": direction, "time": maxf(0, elapsed - rewind)})


func tick(delta: float) -> void:
	super.tick(delta)
	if ammunition == 0 and elapsed >= reload_until:
		ammunition = 4
	_record_history()
	for shot: Dictionary in _shots:
		_resolve_shot(shot)
	_shots.clear()
	for id: int in pawns:
		if can_act(id) and (pawns[id] as PartyPawn).position.z <= BallistaArena.FINISH_Z:
			escaped[id] = elapsed
			event_occurred.emit({"type": "finish", "id": id})
	var unresolved: bool = false
	for id: int in pawns:
		if can_act(id):
			if elapsed >= rules.duration:
				kill(id, "timeout")
			else:
				unresolved = true
	if not unresolved:
		var performance: Dictionary = {}
		var denominator: float = maxf(1, players.size() - 1)
		for id: int in players:
			performance[id] = (1.0 - float(escaped.size()) / denominator) * 0.5 if id == shooter else (0.5 / denominator if escaped.has(id) else 0.0)
		complete(performance)


func _record_history() -> void:
	var positions: Dictionary = {}
	for id: int in pawns:
		positions[id] = (pawns[id] as PartyPawn).position
	history.append({"time": elapsed, "positions": positions})
	while history.size() > 2 and float(history[1]["time"]) < elapsed - 0.25:
		history.pop_front()


func historical_position(id: int, when: float) -> Vector3:
	var previous: Dictionary = history[0]
	for sample: Dictionary in history:
		if float(sample["time"]) >= when:
			var fraction: float = inverse_lerp(float(previous["time"]), float(sample["time"]), when) if float(sample["time"]) > float(previous["time"]) else 0.0
			return (previous["positions"][id] as Vector3).lerp(sample["positions"][id], clampf(fraction, 0, 1))
		previous = sample
	return previous["positions"][id]


func _resolve_shot(shot: Dictionary) -> void:
	var origin: Vector3 = BallistaArena.MOUNT
	var direction: Vector3 = shot["direction"]
	var distance: float = 60.0
	var wall: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 1))
	if not wall.is_empty():
		distance = origin.distance_to(wall["position"])
	var victim: int = -1
	for id: int in pawns:
		if not can_act(id):
			continue
		var hit: float = capsule_hit(origin, direction, historical_position(id, float(shot["time"])))
		if hit >= 0 and hit < distance:
			distance = hit
			victim = id
	if victim >= 0:
		kill(victim, "bolt")
	event_occurred.emit({"type": "shot", "from": origin, "to": origin + direction * distance, "victim": victim})


static func capsule_hit(origin: Vector3, direction: Vector3, feet: Vector3) -> float:
	var low: Vector3 = feet + Vector3.UP * PartyPawn.RADIUS
	var high: Vector3 = feet + Vector3.UP * (PartyPawn.HEIGHT - PartyPawn.RADIUS)
	var nearest: float = INF
	for centre: Vector3 in [low, high]:
		var offset: Vector3 = origin - centre
		var b: float = offset.dot(direction)
		var discriminant: float = b * b - (offset.length_squared() - PartyPawn.RADIUS * PartyPawn.RADIUS)
		if discriminant >= 0:
			var hit: float = -b - sqrt(discriminant)
			if hit >= 0:
				nearest = minf(nearest, hit)
	var horizontal: Vector2 = Vector2(direction.x, direction.z)
	var offset_xz: Vector2 = Vector2(origin.x - feet.x, origin.z - feet.z)
	var a: float = horizontal.length_squared()
	var b: float = offset_xz.dot(horizontal)
	var discriminant: float = b * b - a * (offset_xz.length_squared() - PartyPawn.RADIUS * PartyPawn.RADIUS)
	if a > 0.000001 and discriminant >= 0:
		var hit: float = (-b - sqrt(discriminant)) / a
		var height: float = origin.y + direction.y * hit
		if hit >= 0 and height >= low.y and height <= high.y:
			nearest = minf(nearest, hit)
	return nearest if is_finite(nearest) else -1.0


func public_state() -> Dictionary:
	var state: Dictionary = super.public_state()
	state.merge({"shooter": shooter, "ammunition": ammunition, "reload_until": reload_until, "shot_until": shot_until, "escaped": escaped.duplicate(), "aim": aim})
	return state
