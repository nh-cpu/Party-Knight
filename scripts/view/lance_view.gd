class_name LanceView
extends GameView

var arena: LanceArena
var sharks: Node3D


func build() -> void:
	arena = LanceArena.new()
	add_child(arena)
	arena.build(true)
	var bodies: Dictionary = Session.game_state.get("bodies", {})
	for id: int in Session.roster:
		spawn_person(id, (bodies.get(id, {}) as Dictionary).get("position", Vector3.ZERO), true)
	sharks = Node3D.new()
	add_child(sharks)
	for lane: int in 5:
		var shark: Node3D = Node3D.new()
		sharks.add_child(shark)
		shark.position.z = (lane - 2) * 1.15
		var body: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		body.mesh = sphere
		body.material_override = Blockout.material(Color("779dab"))
		shark.add_child(body)
		body.position.y = 0.75
		body.scale = Vector3(2.2, 0.75, 0.7)
		for side: float in [-1.0, 1.0]:
			Blockout.box(shark, Vector3(0.65, 0.92, side * 0.29), Vector3(0.12, 0.12, 0.06), Color("10141a"))
		var fin: MeshInstance3D = Blockout.cylinder(shark, Vector3(-0.2, 1.3, 0), 0.3, 0.65, Color("526e80"))
		var cone: CylinderMesh = fin.mesh as CylinderMesh
		cone.top_radius = 0
		Blockout.box(shark, Vector3(1.05, 0.65, 0), Vector3(0.2, 0.25, 0.5), Color("eeeece"))
		Blockout.box(shark, Vector3(-1.15, 0.8, 0), Vector3(0.25, 0.85, 0.8), Color("526e80"))
	camera.position = Vector3(0, 13, 13)
	camera.look_at(Vector3.ZERO)


func update_visuals(_delta: float) -> void:
	var hazard: Dictionary = state.get("hazard", {})
	var active_wave: bool = int(hazard.get("phase", 0)) == HazardClock.Phase.ACTIVE
	var locked: bool = int(hazard.get("phase", 0)) in [HazardClock.Phase.ACTIVE, HazardClock.Phase.RECOVERY]
	arena.apply_state(state.get("refuges", []), locked)
	sharks.visible = active_wave
	sharks.position.x = lerpf(-10, 10, clampf((float(state.get("elapsed", 0)) - float(hazard.get("started", 0))) / 1.5, 0, 1))


func hud_lines() -> PackedStringArray:
	var warning: bool = int((state.get("hazard", {}) as Dictionary).get("phase", 0)) == HazardClock.Phase.WARNING
	var seconds: int = ceili(maxf(0, float((state.get("hazard", {}) as Dictionary).get("deadline", 0)) - float(state.get("elapsed", 0))))
	return PackedStringArray(["SHARKS IN %d — claim an OPEN stall!" % seconds if warning else "WASD move · Left click shove · Find an OPEN stall", "Wave %d · %d safe stalls · Face a rival to shove · No jumping" % [int(state.get("wave", 0)) + 1, (state.get("refuges", []) as Array).size()]])
