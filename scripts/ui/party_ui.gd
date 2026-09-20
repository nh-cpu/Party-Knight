class_name PartyUI
extends CanvasLayer

signal character_selected(index: int)
signal blood_changed(enabled: bool)

var arena: ArenaView
var character: int = 0
var display_name: String = "Peasant"
var address: String = "127.0.0.1"
var port: int = 7000
var blood: bool = true
var volume: float = 0.7
var _root: Control
var _content: Control
var _notice: Label
var _timer: Label
var _detail: Label
var _secret_label: Label
var _actions: Array[Button] = []
var _settings_open: bool = false
var _message: String = ""


func _ready() -> void:
	_load_settings()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.theme = _theme()
	Session.state_changed.connect(rebuild)
	Session.snapshot_received.connect(func(_state: Dictionary) -> void: _update_hud())
	Session.connection_message.connect(func(message: String) -> void:
		_message = message
		rebuild()
	)
	rebuild()


func rebuild() -> void:
	if is_instance_valid(_content):
		_root.remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)
	_actions.clear()
	_timer = null
	_detail = null
	_secret_label = null
	if not Session.connected or Session.phase == Session.Phase.LOBBY:
		_build_menu()
	else:
		_build_game()
	if _settings_open:
		_build_settings()


func _build_menu() -> void:
	var panel: VBoxContainer = _panel(Vector2(44, 36), Vector2(470, 638))
	if Session.connected:
		panel.add_theme_constant_override("separation", 6)
	_label(panel, "THE KING REQUESTS YOUR PRESENCE", 14, Color("bfa984"))
	_label(panel, "PARTY KNIGHT" if Session.connected else "PARTY\nKNIGHT", 32 if Session.connected else 60, Color("efcf90"))
	_label(panel, "Your trials. Your peasants. One crown.", 19)
	_separator(panel)
	if not Session.connected:
		_label(panel, "YOUR NAME", 13, Color("bfa984"))
		var name_input: LineEdit = LineEdit.new()
		name_input.text = display_name
		name_input.max_length = 20
		panel.add_child(name_input)
		name_input.text_changed.connect(func(value: String) -> void: display_name = value)
		var row: HBoxContainer = HBoxContainer.new()
		panel.add_child(row)
		var server_input: LineEdit = LineEdit.new()
		server_input.text = address
		server_input.placeholder_text = "Server address"
		server_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(server_input)
		server_input.text_changed.connect(func(value: String) -> void: address = value)
		var port_input: SpinBox = SpinBox.new()
		port_input.min_value = 1
		port_input.max_value = 65535
		port_input.value = port
		row.add_child(port_input)
		port_input.value_changed.connect(func(value: float) -> void: port = int(value))
		_character_picker(panel)
		_button(panel, "ENTER THE COURT  →", func() -> void:
			_save_settings()
			Session.connect_to_server(address, port, display_name, character)
		)
		_label(panel, "1–4 players • Connect to your dedicated server", 13, Color("99a9b7"))
	else:
		_label(panel, "THE WAITING PEASANTS   %d / 4" % Session.roster.size(), 18, Color("efcf90"))
		for id: int in Session.roster:
			var player: Dictionary = Session.roster[id]
			_label(panel, "%s  %s%s" % ["●" if bool(player["ready"]) else "○", Session.player_caption(id), "  · Host" if id == Session.leader else ""], 19, _player_color(id))
		_label(panel, "YOUR NAME", 13, Color("bfa984"))
		var name_row: HBoxContainer = HBoxContainer.new()
		panel.add_child(name_row)
		var name_input: LineEdit = LineEdit.new()
		name_input.text = display_name
		name_input.max_length = 20
		name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_input)
		name_input.text_changed.connect(func(value: String) -> void: display_name = value)
		name_input.text_submitted.connect(func(_value: String) -> void: _apply_name())
		_button(name_row, "Apply", _apply_name)
		_character_picker(panel)
		var my_id: int = multiplayer.get_unique_id()
		var ready: bool = bool(Session.roster.get(my_id, {}).get("ready", false))
		_button(panel, "NOT READY" if ready else "I AM READY", func() -> void: Session.set_ready(not ready, character))
		if my_id == Session.leader:
			var start: Button = _button(panel, "BEGIN THE TRIALS", Session.request_start)
			start.disabled = Session.selected_games.is_empty()
			for id: int in Session.roster:
				if not bool(Session.roster[id]["ready"]):
					start.disabled = true
		else:
			_label(panel, "The lobby leader begins when everyone is ready.", 14)
		_button(panel, "Leave court", func() -> void: Session.disconnect_client(""))
		_build_match_options()
	if not Session.connected:
		_notice = _label(panel, _message, 15, Color("e3a17f"))
	_button(panel, "Settings", func() -> void:
		_settings_open = true
		rebuild()
	)


func _character_picker(parent: VBoxContainer) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	_button(row, "‹", func() -> void: _select_character((character + 5) % 6))
	var label: Label = _label(row, "PEASANT %02d" % (character + 1), 18, Color("efcf90"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(row, "›", func() -> void: _select_character((character + 1) % 6))


func _apply_name() -> void:
	Session.set_player_name(display_name)
	_save_settings()


func _player_color(id: int) -> Color:
	return PeasantView.COLORS[clampi(Session.player_number(id) - 1, 0, 3)]


func _build_match_options() -> void:
	var panel: VBoxContainer = _panel(Vector2(560, 36), Vector2(676, 290))
	var is_host: bool = multiplayer.get_unique_id() == Session.leader
	_label(panel, "CHOOSE THE TRIALS" if is_host else "THE HOST'S TRIALS", 24, Color("efcf90"))
	for index: int in Session.RULES.size():
		var option: CheckBox = CheckBox.new()
		option.text = Session.RULES[index].title
		option.button_pressed = Session.selected_games.has(str(Session.RULES[index].game_id))
		option.disabled = not is_host
		panel.add_child(option)
		var game_id: String = str(Session.RULES[index].game_id)
		option.toggled.connect(func(value: bool) -> void:
			var games: Array[String] = Session.selected_games.duplicate()
			if value and not games.has(game_id):
				games.append(game_id)
			elif not value:
				games.erase(game_id)
			Session.set_match_options(games, Session.random_order)
		)
	var shuffle: CheckButton = CheckButton.new()
	shuffle.text = "Random game order"
	shuffle.button_pressed = Session.random_order
	shuffle.disabled = not is_host
	panel.add_child(shuffle)
	shuffle.toggled.connect(func(value: bool) -> void: Session.set_match_options(Session.selected_games, value))
	var attempts: int = 0
	for id: String in Session.selected_games:
		attempts += Session.rounds_for(id, Session.roster.size())
	_label(panel, "%d games · %d rounds/heats%s" % [Session.selected_games.size(), attempts, " · Select at least one game" if Session.selected_games.is_empty() else ""], 16, Color("bfa984"))
	if Session.roster.size() == 1:
		_label(panel, "SOLO PRACTICE · No match points", 15, Color("6dbdce"))


func _select_character(index: int) -> void:
	character = index
	character_selected.emit(character)
	if Session.connected:
		Session.set_ready(false, character)
	rebuild()


func _build_game() -> void:
	var rules: GameRules = Session.current_rules()
	var top: VBoxContainer = _panel(Vector2(28, 20), Vector2(1224, 110))
	var row: HBoxContainer = HBoxContainer.new()
	top.add_child(row)
	row.add_theme_constant_override("separation", 18)
	var title: Label = _label(row, ("SOLO · " if Session.practice else "") + rules.title, 27, Color("efcf90"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size.x = 360
	_label(row, "TRIAL %d / %d   %s %d / %d" % [Session.game_slot + 1, Session.game_order.size(), "HEAT" if rules.rotating_roles else "ROUND", Session.round_index + 1, Session.active_round_count], 17)
	_timer = _label(row, "", 24, Color("efcf90"))
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var scores: HBoxContainer = HBoxContainer.new()
	top.add_child(scores)
	for id: int in Session.roster:
		_label(scores, "%s  %d favour" % [Session.player_caption(id), Session.roster[id]["score"]], 16, _player_color(id))
	_button(scores, "Settings", toggle_settings)
	_button(scores, "Leave", func() -> void: Session.disconnect_client("You left the match."))
	var bottom: VBoxContainer = _panel(Vector2(28, 566), Vector2(1224, 134))
	_detail = _label(bottom, "", 21, Color("efcf90"))
	_secret_label = _label(bottom, "", 16)
	if Session.phase == Session.Phase.PLAYING and int(Session.game_state.get("shooter", -1)) == multiplayer.get_unique_id():
		var reticle: Label = _label(_content, "+", 32, Color("efcf90"))
		reticle.position = Vector2(630, 337)
		reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Session.phase in [Session.Phase.INSTRUCTIONS, Session.Phase.COUNTDOWN]:
		var center: VBoxContainer = _panel(Vector2(280, 210), Vector2(720, 280))
		_label(center, "PRACTICE" if Session.practice else "LEARN YOUR FATE", 32, Color("efcf90"))
		_label(center, rules.instructions, 22)
	elif Session.phase in [Session.Phase.ROUND_RESULTS, Session.Phase.MATCH_RESULTS]:
		var center: VBoxContainer = _panel(Vector2(310, 155), Vector2(660, 370))
		var final: bool = Session.phase == Session.Phase.MATCH_RESULTS
		_label(center, "PRACTICE COMPLETE" if Session.practice and final else ("THE CROWN IS CLAIMED" if final else ("TRIAL COMPLETE" if Session.game_complete else "ROUND RESULTS")), 28, Color("efcf90"))
		var high_score: int = -1
		for id: int in Session.roster:
			high_score = maxi(high_score, int(Session.roster[id]["score"]))
		for id: int in Session.roster:
			var crowned: bool = final and not Session.practice and int(Session.roster[id]["score"]) == high_score
			var performance: String = "%.1f %s" % [float(Session.game_totals.get(id, 0)) * rules.performance_scale, rules.performance_label]
			_label(center, "%s%s · %s · %d favour" % ["♛ " if crowned else "", Session.player_caption(id), performance, Session.roster[id]["score"]], 20, _player_color(id))
		_label(center, "Practice is unscored." if Session.practice else ("Match points awarded once per completed game." if Session.game_complete else "Performance accumulates across this game's rounds/heats."), 15)
		if final:
			if multiplayer.get_unique_id() == Session.leader:
				_button(center, "RETURN TO COURT / REMATCH", Session.request_rematch)
			else:
				_label(center, "Waiting for the host to return to court.", 16)
	_update_hud()


func _update_hud() -> void:
	if _timer == null:
		return
	var state: Dictionary = Session.game_state
	var me: int = multiplayer.get_unique_id()
	_timer.text = "%02d s" % ceili(maxf(0, float(state.get("remaining", Session.remaining)) if Session.phase == Session.Phase.PLAYING else Session.remaining))
	_secret_label.text = ""
	if Session.loading:
		_detail.text = "Waiting for every peasant to arrive…"
	elif Session.phase == Session.Phase.COUNTDOWN:
		_detail.text = "Starting in %d…" % ceili(Session.remaining)
	elif Session.phase == Session.Phase.INSTRUCTIONS:
		_detail.text = "Read the rules. Everyone starts together."
	elif Session.phase in [Session.Phase.ROUND_RESULTS, Session.Phase.MATCH_RESULTS]:
		_detail.text = "SOLO PRACTICE · No match points" if Session.practice else "Each completed trial carries equal match weight."
	elif not bool((state.get("alive", {}) as Dictionary).get(me, true)) or (state.get("escaped", {}) as Dictionary).has(me):
		_detail.text = "SPECTATING · TAB changes view · You return next round or heat"
		_secret_label.text = "Your earned performance remains recorded."
	elif arena != null and arena.view != null:
		var lines: PackedStringArray = arena.view.hud_lines()
		_detail.text = lines[0]
		_secret_label.text = lines[1]


func toggle_settings() -> void:
	_settings_open = not _settings_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _settings_open:
		_save_settings()
	rebuild()


func _build_settings() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.7)
	_content.add_child(shade)
	var panel: VBoxContainer = _panel(Vector2(420, 175), Vector2(440, 370))
	_label(panel, "SETTINGS", 32, Color("efcf90"))
	_label(panel, "Master volume", 18)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = volume
	panel.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		volume = value
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, volume)))
	)
	var blood_toggle: CheckButton = CheckButton.new()
	blood_toggle.text = "Blood splatter"
	blood_toggle.button_pressed = blood
	panel.add_child(blood_toggle)
	blood_toggle.toggled.connect(func(value: bool) -> void:
		blood = value
		blood_changed.emit(value)
	)
	var fullscreen: CheckButton = CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	panel.add_child(fullscreen)
	fullscreen.toggled.connect(func(value: bool) -> void: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED))
	_label(panel, "Online matches continue while settings are open.", 14)
	_button(panel, "Done", func() -> void:
		_settings_open = false
		_save_settings()
		rebuild()
	)


func input_blocked() -> bool:
	return _settings_open


func _panel(at: Vector2, dimensions: Vector2) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = at
	panel.custom_minimum_size = dimensions
	_content.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	return column


func _label(parent: Node, text: String, size: int = 20, color: Color = Color("dce2e5")) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	parent.add_child(button)
	button.pressed.connect(pressed)
	return button


func _separator(parent: Node) -> void:
	parent.add_child(HSeparator.new())


func _theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 18
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.055, 0.075, 0.95)
	panel.border_color = Color("6d5c40")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	theme.set_stylebox("panel", "PanelContainer", panel)
	var normal: StyleBoxFlat = panel.duplicate() as StyleBoxFlat
	normal.bg_color = Color("293743")
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", normal)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("695337")
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	theme.set_stylebox("disabled", "Button", panel)
	theme.set_color("font_disabled_color", "Button", Color("6d7883"))
	return theme


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		address = str(config.get_value("connection", "address", address))
		port = int(config.get_value("connection", "port", port))
		display_name = str(config.get_value("player", "name", display_name))
		character = clampi(int(config.get_value("player", "character", character)), 0, 5)
		blood = bool(config.get_value("settings", "blood", true))
		volume = clampf(float(config.get_value("settings", "volume", 0.7)), 0, 1)
		if bool(config.get_value("settings", "fullscreen", false)):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, volume)))


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("connection", "address", address)
	config.set_value("connection", "port", port)
	config.set_value("player", "name", display_name)
	config.set_value("player", "character", character)
	config.set_value("settings", "blood", blood)
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.save("user://settings.cfg")
