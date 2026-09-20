extends Node

var arena: ArenaView
var ui: PartyUI



func _ready() -> void:
	Engine.physics_ticks_per_second = 60
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--server" in args or OS.has_feature("dedicated_server"):
		Session.test_fast = "--test-fast" in args
		var port: int = int(_argument(args, "--port", "7000"))
		if port < 1 or port > 65535 or Session.start_server(port) != OK:
			get_tree().quit(1)
		return
	if "--test-client" in args:
		var driver: Node = load("res://tests/network_client.gd").new() as Node
		add_child(driver)
		return
	arena = ArenaView.new()
	add_child(arena)
	ui = PartyUI.new()
	ui.arena = arena
	add_child(ui)
	arena.blood_enabled = ui.blood
	arena.show_preview(ui.character)
	ui.character_selected.connect(arena.show_preview)
	ui.blood_changed.connect(func(value: bool) -> void: arena.blood_enabled = value)
	if "--capture" in args:
		var capture: Node = load("res://tests/capture_view.gd").new() as Node
		capture.set("target", self)
		add_child(capture)
	Session.state_changed.connect(func() -> void:
		if Session.phase == Session.Phase.LOBBY:
			arena.show_preview(ui.character)
	)
	if "--presentation-client" in args:
		var driver: Node = load("res://tests/presentation_client.gd").new() as Node
		driver.set("target", self)
		add_child(driver)
	if "--connect" in args:
		Session.connect_to_server(_argument(args, "--connect", "127.0.0.1"), int(_argument(args, "--port", "7000")), _argument(args, "--name", "Peasant"), int(_argument(args, "--character", "0")))


func _physics_process(_delta: float) -> void:
	if arena != null and arena.view != null:
		arena.view.input_tick(ui.input_blocked())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and ui != null:
		ui.toggle_settings()
		get_viewport().set_input_as_handled()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouse and arena != null and arena.view != null:
		arena.view.handle_input(event)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if arena == null or arena.view == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		arena.view.cycle_spectator()
	elif not ui.input_blocked():
		arena.view.handle_input(event)


func _argument(args: PackedStringArray, key: String, fallback: String) -> String:
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
