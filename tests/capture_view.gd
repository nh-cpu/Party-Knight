extends Node

var _main: Node
var session: Node
var target: Node


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	session = get_tree().root.get_node("Session")
	_main = target
	_main.set_physics_process(false)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("res://.godot/menu-preview.png")
	var arena: ArenaView = _main.get("arena") as ArenaView
	for index: int in 6:
		arena.show_preview(index)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://.godot/peasant-%d.png" % index)
	session.connected = true
	session.roster = {1: {"name": "Turnip", "character": 0, "score": 3, "ready": true}, 2: {"name": "Cabbage", "character": 1, "score": 2, "ready": true}, 3: {"name": "Mud", "character": 4, "score": 1, "ready": true}, 4: {"name": "Bread", "character": 5, "score": 0, "ready": true}}
	for id: int in session.roster:
		session.roster[id]["number"] = id
	session.leader = 1
	session.phase = session.Phase.LOBBY
	var ui: PartyUI = _main.get("ui") as PartyUI
	ui.display_name = "Turnip"
	ui.character = 0
	session.state_changed.emit()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("res://.godot/lobby-preview.png")
	session.phase = session.Phase.PLAYING
	for index: int in 3:
		session.game_index = index
		session.game_slot = index
		session.active_round_count = session.rounds_for(str(session.RULES[index].game_id), 4)
		session.round_id += 1
		var game: PartyGame = session.RULES[index].scene.instantiate() as PartyGame
		get_tree().root.add_child(game)
		game.setup([1, 2, 3, 4], 0, session.RULES[index])
		session.game_state = game.public_state()
		session.secret = game.private_state(1)
		arena.prepare_round()
		session.state_changed.emit()
		session.snapshot_received.emit(session.game_state)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://.godot/arena-%d.png" % index)
		if game is BallistaGame:
			game.free()
			game = session.RULES[index].scene.instantiate() as PartyGame
			get_tree().root.add_child(game)
			game.setup([1, 2, 3, 4], 1, session.RULES[index])
			session.game_state = game.public_state()
			arena.prepare_round()
			session.state_changed.emit()
			await get_tree().create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			get_tree().root.get_texture().get_image().save_png("res://.godot/ballista-runner.png")
		elif game is LanceGame:
			var lance: LanceGame = game as LanceGame
			lance.hazard.enter(HazardClock.Phase.ACTIVE, 0, 1.5)
			lance.elapsed = 0.8
			session.game_state = lance.public_state()
			arena.apply_snapshot(session.game_state)
			await get_tree().create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			get_tree().root.get_texture().get_image().save_png("res://.godot/lance-charge.png")
		elif game is CoinsGame:
			game.kill(1, "hand")
			for character: int in 6:
				session.roster[1]["character"] = character
				session.game_state = game.public_state()
				arena.prepare_round()
				arena.camera.position = Vector3(-4.5, 2.4, 4.6)
				arena.camera.look_at(Vector3(-4.5, 1.2, 1.2))
				await get_tree().create_timer(0.7).timeout
				await RenderingServer.frame_post_draw
				get_tree().root.get_texture().get_image().save_png("res://.godot/hand-loss-%d.png" % character)
		game.free()
	print("CAPTURES_COMPLETE")
	get_tree().quit()
