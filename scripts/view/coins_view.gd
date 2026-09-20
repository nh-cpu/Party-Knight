class_name CoinsView
extends GameView

var blades: Array[Node3D] = []


func build() -> void:
	Blockout.room(self)
	var ids: Array[int] = Session.player_ids()
	for index: int in ids.size():
		var x: float = (index - (ids.size() - 1) * 0.5) * 3.0
		var person: PeasantView = spawn_person(ids[index], Vector3(x, 0, 1.6))
		person.rotation.y = PI
		Blockout.box(self, Vector3(x, 0.6, 0), Vector3(2.4, 1.2, 1.2), Blockout.WOOD)
		for side: float in [-1.1, 1.1]:
			Blockout.box(self, Vector3(x + side, 1.8, 0), Vector3(0.18, 3.6, 0.18), Blockout.STONE)
		blades.append(Blockout.box(self, Vector3(x, 3.2, 0), Vector3(2, 0.5, 0.14), Color("bdc6cc")))
		for coin: int in 7:
			Blockout.cylinder(self, Vector3(x + (coin % 3 - 1) * 0.3, 1.25, (coin / 3) * 0.2), 0.13, 0.05, Blockout.GOLD)
	camera.position = Vector3(0, 6.2, 10.5)
	camera.look_at(Vector3(0, 1.1, 0))


func handle_input(event: InputEvent) -> void:
	if controls_enabled and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		Session.send_action("collect")


func update_visuals(delta: float) -> void:
	var hazard: Dictionary = state.get("hazard", {})
	var phase: int = int(hazard.get("phase", 0))
	for id: int in peasants:
		(peasants[id] as PeasantView).reaching = float((state.get("extensions", {}) as Dictionary).get(id, 0))
	for blade: Node3D in blades:
		blade.position.y = lerpf(blade.position.y, 1.1 if phase == HazardClock.Phase.ACTIVE else 3.2, minf(delta * 30, 1))
		blade.rotation.z = sin(Time.get_ticks_msec() * 0.06) * 0.035 if phase == HazardClock.Phase.WARNING else 0.0


func hud_lines() -> PackedStringArray:
	var warning: bool = int((state.get("hazard", {}) as Dictionary).get("phase", 0)) == HazardClock.Phase.WARNING
	return PackedStringArray(["THE BLADE IS SHAKING — stop tapping to retract!" if warning else "Tap E for coins · Stop to protect your hand", "Coins: %d · Cycle %d / 6 · Retraction: 0.25 s · Coins remain after hand loss" % [(state.get("coins", {}) as Dictionary).get(multiplayer.get_unique_id(), 0), mini(6, int(state.get("cycle", 0)) + 1)]])
