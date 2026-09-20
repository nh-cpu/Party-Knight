class_name GameView
extends Node3D

var camera: Camera3D
var peasants: Dictionary = {}
var proxies: Dictionary = {}
var local_pawn: PartyPawn
var state: Dictionary = {}
var history: Array[Dictionary] = []
var sequence: int = 0
var spectated: int = -1
var blood_enabled: bool = true
var controls_enabled: bool = false
var effects: Node3D
var _seen_deaths: Dictionary = {}
var _audio: AudioStreamPlayer


func _ready() -> void:
	effects = Node3D.new()
	add_child(effects)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)


func setup(view_camera: Camera3D) -> void:
	camera = view_camera
	camera.fov = 55
	build()
	apply_snapshot(Session.game_state)


func build() -> void:
	pass


func spawn_person(id: int, at: Vector3, moving: bool = false) -> PeasantView:
	var person: PeasantView = PeasantView.new()
	add_child(person)
	var player: Dictionary = Session.roster[id]
	person.build(int(player["character"]), str(player["name"]), Session.player_number(id) - 1, Session.player_number(id))
	person.position = at
	peasants[id] = person
	if moving:
		var pawn: PartyPawn = PartyPawn.new()
		add_child(pawn)
		pawn.position = at
		if id == multiplayer.get_unique_id():
			local_pawn = pawn
		else:
			pawn.collision_mask = 0
			proxies[id] = pawn
	return person


func apply_snapshot(data: Dictionary) -> void:
	state = data
	var bodies: Dictionary = state.get("bodies", {})
	for id: int in proxies:
		if bodies.has(id):
			(proxies[id] as PartyPawn).restore(bodies[id])
		(proxies[id] as PartyPawn).collision_layer = 2 if active(id) else 0
	var me: int = multiplayer.get_unique_id()
	if local_pawn != null and bodies.has(me):
		local_pawn.restore(bodies[me])
		local_pawn.collision_layer = 2 if active(me) else 0
		while not history.is_empty() and int(history[0]["seq"]) <= int(bodies[me]["ack"]):
			history.pop_front()
		if active(me):
			for frame: Dictionary in history:
				local_pawn.simulate(frame, 1.0 / 60.0)
		else:
			history.clear()


func active(id: int) -> bool:
	return bool((state.get("alive", {}) as Dictionary).get(id, false)) and not (state.get("escaped", {}) as Dictionary).has(id)


func input_tick(blocked: bool) -> void:
	controls_enabled = not blocked and Session.phase == Session.Phase.PLAYING and active(multiplayer.get_unique_id())
	if local_pawn == null or Session.phase != Session.Phase.PLAYING or not active(multiplayer.get_unique_id()):
		return
	var x: float = 0.0 if blocked else float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var z: float = 0.0 if blocked else float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right: Vector3 = camera.global_basis.x
	right.y = 0
	var direction: Vector3 = (right.normalized() * x - forward * z).limit_length(1.0)
	var frame: Dictionary = {"seq": sequence, "x": direction.x, "z": direction.z, "jump": false}
	sequence += 1
	history.append(frame)
	if history.size() > 120:
		history.pop_front()
	local_pawn.simulate(frame, 1.0 / 60.0)
	Session.send_input(history.slice(maxi(0, history.size() - 3)))


func handle_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and local_pawn != null:
		Session.send_action("shove")
		if peasants.has(multiplayer.get_unique_id()):
			(peasants[multiplayer.get_unique_id()] as PeasantView).shove_amount = 1.0


func hud_lines() -> PackedStringArray:
	return PackedStringArray(["WASD move · Left click shove", "No jumping · Shove in the direction you face"])


func _process(delta: float) -> void:
	var bodies: Dictionary = state.get("bodies", {})
	var deaths: Dictionary = state.get("eliminations", {})
	for id: int in peasants:
		var person: PeasantView = peasants[id]
		var eliminated: bool = not bool((state.get("alive", {}) as Dictionary).get(id, true))
		person.hand_lost = bool((deaths.get(id, {}) as Dictionary).get("hand_lost", false))
		person.dead = eliminated and not person.hand_lost
		if eliminated and not _seen_deaths.has(id):
			_seen_deaths[id] = true
			if person.hand_lost:
				person.detach_hand(effects)
			if blood_enabled:
				blood(person.position)
		if bodies.has(id):
			var target: Vector3 = bodies[id]["position"]
			if id == multiplayer.get_unique_id() and local_pawn != null and active(id):
				target = local_pawn.position
			person.position = person.position.lerp(target, minf(1, delta * 18))
			var velocity: Vector3 = bodies[id]["velocity"]
			person.walking = minf(1, Vector2(velocity.x, velocity.z).length() / PartyPawn.SPEED) if active(id) else 0.0
			var facing: Vector3 = bodies[id].get("facing", Vector3.FORWARD)
			person.rotation.y = lerp_angle(person.rotation.y, atan2(facing.x, facing.z), minf(1, delta * 12))
	update_visuals(delta)


func update_visuals(_delta: float) -> void:
	pass


func cycle_spectator() -> void:
	var living: Array[int] = []
	for id: int in peasants:
		if active(id):
			living.append(id)
	if not living.is_empty():
		spectated = living[(living.find(spectated) + 1) % living.size()]


func on_event(event: Dictionary) -> void:
	var kind: String = str(event.get("type", ""))
	if kind == "shove" and peasants.has(int(event["id"])):
		(peasants[int(event["id"])] as PeasantView).shove_amount = 1.0
	tone(130.0 if kind in ["death", "blade", "charge", "shot"] else 520.0)


func blood(at: Vector3) -> void:
	for index: int in 10:
		var drop: Node3D = Blockout.box(effects, at + Vector3.UP, Vector3.ONE * 0.08, Color("941d34"))
		var tween: Tween = create_tween()
		tween.tween_property(drop, "position", at + Vector3(randf_range(-0.8, 0.8), 0.04, randf_range(-0.8, 0.8)), 0.4)
		tween.tween_property(drop, "scale", Vector3(2, 0.15, 2), 0.1)


func tone(frequency: float) -> void:
	var sound: AudioStreamWAV = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples: int = 2646
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples * 2)
	for index: int in samples:
		bytes.encode_s16(index * 2, int(sin(TAU * frequency * index / 22050.0) * (1.0 - float(index) / samples) * 7000))
	sound.data = bytes
	_audio.stream = sound
	_audio.play()
