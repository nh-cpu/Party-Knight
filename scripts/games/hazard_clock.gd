class_name HazardClock
extends RefCounted

enum Phase { RESET, WARNING, ACTIVE, RECOVERY }

var phase: Phase = Phase.RESET
var started: float = 0.0
var deadline: float = 0.0


func enter(next: Phase, now: float, duration: float) -> void:
	phase = next
	started = now
	deadline = now + duration


func expired(now: float) -> bool:
	return now + 0.000001 >= deadline


func state(hidden_deadline: bool = false) -> Dictionary:
	var result: Dictionary = {"phase": phase, "started": started}
	if not hidden_deadline:
		result["deadline"] = deadline
	return result
