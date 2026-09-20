class_name PartyGame
extends Node3D

signal round_finished(points: Dictionary)
signal event_occurred(event: Dictionary)

var players: Array[int] = []
var alive: Dictionary = {}
var elapsed: float = 0.0
var finished: bool = false
var rules: GameRules
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var practice: bool = false
var simulation_tick: int = 0
var eliminations: Dictionary = {}
var forfeited: Dictionary = {}
var latency: Dictionary = {}


func setup(ids: Array[int], round_number: int, game_rules: GameRules, solo: bool = false) -> void:
	players = ids.duplicate()
	practice = solo
	rules = game_rules
	rng.randomize()
	for id: int in players:
		alive[id] = true
	configure(round_number)


func configure(_round_number: int) -> void:
	pass


func tick(delta: float) -> void:
	elapsed += delta
	simulation_tick += 1


func action(_sender: int, _kind: String, _payload: Dictionary) -> void:
	pass


func input_frame(_sender: int, _frames: Array) -> void:
	pass


func public_state() -> Dictionary:
	return {"alive": alive.duplicate(), "elapsed": elapsed, "tick": simulation_tick, "eliminations": eliminations.duplicate(true), "practice": practice, "remaining": maxf(0.0, rules.duration - elapsed)}


func private_state(_id: int) -> Dictionary:
	return {}


func forfeit(id: int) -> void:
	forfeited[id] = true
	kill(id, "disconnect")


func kill(id: int, cause: String = "death") -> void:
	if not bool(alive.get(id, false)):
		return
	alive[id] = false
	eliminations[id] = {"cause": cause, "tick": simulation_tick, "hand_lost": cause == "hand"}
	event_occurred.emit({"type": "death", "id": id, "cause": cause, "tick": simulation_tick})


func can_act(id: int) -> bool:
	return not finished and bool(alive.get(id, false))


func survival_points() -> Dictionary:
	var values: Dictionary = {}
	for id: int in players:
		if not forfeited.has(id):
			values[id] = simulation_tick + 1 if bool(alive[id]) else int(eliminations[id]["tick"])
	return placement_points(values, rules.points)


static func placement_points(values: Dictionary, points: PackedInt32Array = PackedInt32Array([3, 2, 1, 0])) -> Dictionary:
	var result: Dictionary = {}
	for id: int in values:
		var rank: int = 0
		for other: int in values:
			if float(values[other]) > float(values[id]) + 0.000001:
				rank += 1
		result[id] = points[mini(rank, points.size() - 1)]
	return result


func complete(points: Dictionary) -> void:
	if finished:
		return
	finished = true
	round_finished.emit(points)


func ranked_points(values: Dictionary, lower_wins: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for id: int in players:
		result[id] = 0
		if not bool(alive.get(id, false)) or not values.has(id):
			continue
		var rank: int = 0
		for other: int in players:
			if other == id or not bool(alive.get(other, false)) or not values.has(other):
				continue
			if (float(values[other]) < float(values[id])) if lower_wins else (float(values[other]) > float(values[id])):
				rank += 1
		result[id] = rules.points[mini(rank, rules.points.size() - 1)]
	return result
