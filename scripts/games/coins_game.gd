class_name CoinsGame
extends PartyGame

var coins: Dictionary = {}
var exposed_until: Dictionary = {}
var last_tap: Dictionary = {}
var cycle: int = 0
var hazard: HazardClock = HazardClock.new()


func configure(_round_number: int) -> void:
	for id: int in players:
		coins[id] = 0
		exposed_until[id] = 0.0
		last_tap[id] = -1.0
	hazard.enter(HazardClock.Phase.RESET, elapsed, 2.5)


func action(sender: int, kind: String, _payload: Dictionary) -> void:
	if kind != "collect" or not can_act(sender) or elapsed - float(last_tap[sender]) < 0.1 - 0.000001:
		return
	last_tap[sender] = elapsed
	exposed_until[sender] = elapsed + 0.25
	coins[sender] = int(coins[sender]) + 1


func tick(delta: float) -> void:
	super.tick(delta)
	if hazard.expired(elapsed):
		match hazard.phase:
			HazardClock.Phase.RESET:
				hazard.enter(HazardClock.Phase.WARNING, elapsed, rng.randf_range(1.0, 4.0))
				event_occurred.emit({"type": "warning"})
			HazardClock.Phase.WARNING:
				for id: int in players:
					if float(exposed_until[id]) > elapsed + 0.000001:
						kill(id, "hand")
				hazard.enter(HazardClock.Phase.ACTIVE, elapsed, 0.25)
				event_occurred.emit({"type": "blade"})
			HazardClock.Phase.ACTIVE:
				hazard.enter(HazardClock.Phase.RECOVERY, elapsed, 0.5)
			HazardClock.Phase.RECOVERY:
				cycle += 1
				hazard.enter(HazardClock.Phase.RESET, elapsed, maxf(1.25, 2.5 - cycle * 0.25))
	if cycle >= 6 or elapsed >= rules.duration or not alive.values().has(true):
		complete(coins.duplicate())


func public_state() -> Dictionary:
	var state: Dictionary = super.public_state()
	var extensions: Dictionary = {}
	for id: int in players:
		extensions[id] = clampf((float(exposed_until[id]) - elapsed) / 0.25, 0, 1)
	state.merge({"coins": coins.duplicate(), "extensions": extensions, "cycle": cycle, "hazard": hazard.state(true)})
	return state
