class_name LanceGame
extends MovingGame

var arena: LanceArena
var hazard: HazardClock = HazardClock.new()
var available: Array[int] = []
var wave: int = 0


func configure(round_number: int) -> void:
	arena = LanceArena.new()
	add_child(arena)
	arena.build(false)
	var positions: Dictionary = {}
	for index: int in players.size():
		var slot: int = (index + round_number) % players.size()
		positions[players[index]] = Vector3((slot - (players.size() - 1) * 0.5) * 2.0, 0.05, 0)
	spawn_pawns(positions)
	_choose_refuges()
	hazard.enter(HazardClock.Phase.RESET, elapsed, 3.0)


func _choose_refuges() -> void:
	var options: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
	# Every pair of openings is reachable within the four-second warning at 6 m/s.
	for index: int in range(options.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var temporary: int = options[index]
		options[index] = options[other]
		options[other] = temporary
	available.assign(options.slice(0, maxi(1, players.size() - wave)))
	arena.apply_state(available, false)


func tick(delta: float) -> void:
	super.tick(delta)
	if hazard.expired(elapsed):
		match hazard.phase:
			HazardClock.Phase.RESET:
				hazard.enter(HazardClock.Phase.WARNING, elapsed, 4.0)
				event_occurred.emit({"type": "warning"})
			HazardClock.Phase.WARNING:
				hazard.enter(HazardClock.Phase.ACTIVE, elapsed, 1.5)
				arena.apply_state(available, true)
				event_occurred.emit({"type": "charge"})
			HazardClock.Phase.ACTIVE:
				hazard.enter(HazardClock.Phase.RECOVERY, elapsed, 1.0)
			HazardClock.Phase.RECOVERY:
				wave += 1
				_choose_refuges()
				hazard.enter(HazardClock.Phase.RESET, elapsed, maxf(1.0, 3.0 - wave))
	if hazard.phase == HazardClock.Phase.ACTIVE:
		var front: float = lerpf(-10.0, 10.0, clampf((elapsed - hazard.started) / 1.5, 0, 1))
		for id: int in pawns:
			var pawn: PartyPawn = pawns[id]
			if pawn.position.x <= front and arena.safe_refuge(pawn.position, available) < 0:
				kill(id, "shark")
	var survivors: int = alive.values().count(true)
	if survivors == 0 or (not practice and survivors == 1) or elapsed >= rules.duration:
		complete(survival_points())


func public_state() -> Dictionary:
	var state: Dictionary = super.public_state()
	state.merge({"hazard": hazard.state(), "refuges": available.duplicate(), "wave": wave})
	return state
