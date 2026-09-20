class_name ArenaView
extends Node3D

var blood_enabled: bool = true
var preview: PeasantView
var camera: Camera3D
var view: GameView
var _preview_root: Node3D


func _ready() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111b25")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a6b7c7")
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	Session.round_prepared.connect(prepare_round)
	Session.snapshot_received.connect(apply_snapshot)
	Session.game_event.connect(on_event)
	show_preview(0)


func clear_arena() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(view):
		remove_child(view)
		view.queue_free()
	view = null
	if is_instance_valid(_preview_root):
		remove_child(_preview_root)
		_preview_root.queue_free()
	_preview_root = null
	preview = null


func show_preview(character: int) -> void:
	clear_arena()
	_preview_root = Node3D.new()
	add_child(_preview_root)
	Blockout.room(_preview_root)
	preview = PeasantView.new()
	_preview_root.add_child(preview)
	var me: int = multiplayer.get_unique_id()
	var number: int = Session.player_number(me) if Session.connected else 0
	preview.build(character, str(Session.roster.get(me, {}).get("name", "")), maxi(0, number - 1), number)
	preview.position = Vector3(2.8, 0, 0)
	preview.scale = Vector3.ONE * (1.4 if Session.connected else 1.6)
	camera.fov = 55
	camera.position = Vector3(0.3, 4.5, 8) if Session.connected else Vector3(0.3, 3.2, 7)
	camera.look_at(Vector3(0.3, 3.4 if Session.connected else 1.7, 0))


func prepare_round() -> void:
	clear_arena()
	view = Session.current_rules().view_scene.instantiate() as GameView
	add_child(view)
	view.blood_enabled = blood_enabled
	view.setup(camera)
	Session.scene_loaded()


func apply_snapshot(state: Dictionary) -> void:
	if view != null:
		view.apply_snapshot(state)


func on_event(event: Dictionary) -> void:
	if view != null:
		view.on_event(event)


func _process(delta: float) -> void:
	if preview != null:
		preview.rotation.y += delta * 0.12
	if view != null:
		view.blood_enabled = blood_enabled
