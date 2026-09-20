class_name BallistaView
extends GameView

var yaw: float = 0.0
var pitch: float = -0.05
var _faded: Array[MeshInstance3D] = []


func build() -> void:
	var arena: BallistaArena = BallistaArena.new()
	add_child(arena)
	arena.build(true)
	var bodies: Dictionary = Session.game_state.get("bodies", {})
	for id: int in Session.roster:
		if bodies.has(id):
			spawn_person(id, bodies[id]["position"], true)
		elif id != multiplayer.get_unique_id():
			spawn_person(id, Vector3(0, 0, -19.5))
	state = Session.game_state
	update_visuals(0.0)


func is_shooter() -> bool:
	return int(state.get("shooter", -1)) == multiplayer.get_unique_id()


func input_tick(blocked: bool) -> void:
	super.input_tick(blocked)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_shooter() and controls_enabled else Input.MOUSE_MODE_VISIBLE


func handle_input(event: InputEvent) -> void:
	if not is_shooter():
		super.handle_input(event)
		return
	if not controls_enabled:
		return
	if event is InputEventMouseMotion:
		yaw = clampf(yaw - event.relative.x * 0.0025, -1.2, 1.2)
		pitch = clampf(pitch - event.relative.y * 0.0025, -0.65, 0.65)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Session.send_action("shoot", {"direction": aim_direction()})


func aim_direction() -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()


func update_visuals(delta: float) -> void:
	if is_shooter():
		camera.fov = 60
		camera.position = BallistaArena.MOUNT
		camera.look_at(camera.position + aim_direction())
		return
	var target_id: int = multiplayer.get_unique_id()
	if not active(target_id):
		if not active(spectated) or not peasants.has(spectated):
			cycle_spectator()
		target_id = spectated
	if peasants.has(target_id):
		var target: Vector3 = (peasants[target_id] as PeasantView).position
		target.x = clampf(target.x, -2, 2)
		target.z = clampf(target.z, -16, 16)
		var destination: Vector3 = target + Vector3(0, 8, 11)
		camera.position = destination if delta == 0 else camera.position.lerp(destination, minf(1, delta * 7))
		camera.look_at(target + Vector3(0, 0.6, -2))
		_fade_occluders((peasants[target_id] as PeasantView).position + Vector3.UP * 0.3)


func _fade_occluders(target: Vector3) -> void:
	for mesh: MeshInstance3D in _faded:
		var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a = 1.0
	_faded.clear()
	var excluded: Array[RID] = []
	for index: int in 5:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position, target, 1, excluded)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		excluded.append(hit["rid"])
		var body: Node = hit["collider"] as Node
		for child: Node in body.get_children():
			if child is MeshInstance3D:
				var mesh: MeshInstance3D = child as MeshInstance3D
				var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
				if material != null:
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					material.albedo_color.a = 0.2
					_faded.append(mesh)


func on_event(event: Dictionary) -> void:
	super.on_event(event)
	if str(event.get("type", "")) == "shot":
		var from: Vector3 = event["from"]
		var to: Vector3 = event["to"]
		var trail: Node3D = Blockout.box(effects, (from + to) * 0.5, Vector3(0.035, 0.035, maxf(0.01, from.distance_to(to))), Blockout.GOLD)
		trail.look_at(to)
		var tween: Tween = create_tween()
		tween.tween_interval(0.12)
		tween.tween_callback(trail.queue_free)


func hud_lines() -> PackedStringArray:
	var reload: float = maxf(0, float(state.get("reload_until", 0)) - float(state.get("elapsed", 0)))
	if is_shooter():
		return PackedStringArray(["Mouse aim · Left click fire · ESC opens settings", "Bolts: %d / 4 · %s" % [int(state.get("ammunition", 4)), "Reloading %.1f s" % reload if reload > 0 else "Stop the runners before they reach the gold line"]])
	return PackedStringArray(["WASD move · Left click shove · Reach the gold finish line", "Unopposed course practice" if bool(state.get("practice", false)) else "Ballista: %d bolts · %s · No jumping" % [int(state.get("ammunition", 4)), "RELOADING" if reload > 0 else "READY"]])
