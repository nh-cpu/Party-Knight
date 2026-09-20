extends SceneTree

var failures: int = 0
var session: Node


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, description: String) -> void:
	if value:
		print("PASS " + description)
	else:
		failures += 1
		push_error("FAIL " + description)


func player(number: int) -> Dictionary:
	return {"name": "Peasant%d" % number, "number": number, "character": number - 1, "ready": true, "score": 0}


func run() -> void:
	session = root.get_node("Session")
	check(session.start_server(7199) == OK, "Dedicated server starts")
	session.set_physics_process(false)
	session.roster = {11: player(1), 22: player(2), 33: player(3)}
	session.leader = 11
	check(session._available_number() == 4, "Joining players receive the next free number")
	check(session._rename_player(22, "  My\nPeasant  ") and session.roster[22]["name"] == "My Peasant", "Lobby names editable and sanitized")
	check(session.player_number(22) == 2, "Renaming retains number")
	check(not session._update_match_options(22, ["coins"], true), "Only host chooses games")
	check(not session._update_match_options(11, ["coins", "coins"], false), "Duplicate games rejected")
	check(not session._update_match_options(11, ["unknown"], false), "Unknown stable game IDs rejected")
	check(session._update_match_options(11, [], false) and not session._begin_match(11), "Empty selection cannot start")
	check(session._update_match_options(11, ["coins", "lance"], true), "Host can select and shuffle games")
	check(session._begin_match(11), "Selected match starts")
	var order: Array = session.game_order.duplicate()
	order.sort()
	check(order == ["coins", "lance"], "Shuffle contains only selected games")
	check(not session._update_match_options(11, ["ballista"], false), "Selection locked during match")
	check(session.loading and not session._valid_input(11, session.round_id), "Loading/instructions reject gameplay")
	session._return_to_lobby()
	session._update_match_options(11, ["coins"], false)
	for id: int in session.roster:
		session.roster[id]["ready"] = true
	session._begin_match(11)
	session.loading = false
	session._advance_phase()
	session._advance_phase()
	check(session.route_action(11, session.round_id, session.heat_id, 1, "collect", {}), "Current action accepted")
	check(not session.route_action(11, session.round_id, session.heat_id, 1, "collect", {}), "Duplicate reliable action rejected")
	check(not session.route_action(11, session.round_id - 1, session.heat_id, 2, "collect", {}), "Stale round action rejected")
	check(not session.route_action(11, session.round_id, session.heat_id + 1, 2, "collect", {}), "Stale heat action rejected")
	check(not session.route_action(999, session.round_id, session.heat_id, 1, "collect", {}), "Unknown sender rejected")
	session.game.kill(22, "hand")
	check(not session._valid_input(22, session.round_id), "Eliminated players cannot act")
	for round_number: int in 3:
		session._round_finished({11: 10, 22: 10, 33: 5})
		if round_number < 2:
			check(session.roster[11]["score"] == 0, "Intermediate round awards no match points")
		session._advance_phase()
	check(session.phase == session.Phase.MATCH_RESULTS, "Three rounds complete one game")
	check(session.roster[11]["score"] == 3 and session.roster[22]["score"] == 3 and session.roster[33]["score"] == 1, "Equal game weight and tied totals skip ranks")
	session._return_to_lobby()
	check(session.selected_games == ["coins"] and session.game == null, "Rematch preserves selection and clears game")
	session._update_match_options(11, ["ballista"], false)
	for id: int in session.roster:
		session.roster[id]["ready"] = true
	session._begin_match(11)
	check(session.active_round_count == 3 and session.game.shooter == 11, "Ballista starts a full shooter rotation")
	session._peer_disconnected(11)
	check(session.leader == 22 and session.player_number(22) == 2, "Leadership transfers without renumbering")
	check(session.round_index == 0 and session.active_round_count == 2 and session.game.shooter == 22, "Disconnect restarts incomplete rotation fairly")
	session._peer_disconnected(22)
	check(session.phase == session.Phase.LOBBY and session.game == null, "One competitive survivor returns to lobby")
	session.roster[33]["ready"] = true
	session._update_match_options(33, ["ballista"], false)
	check(session._begin_match(33) and session.practice, "Solo lobby starts unscored practice")
	check(session.game.shooter == -1 and session.active_round_count == 1, "Solo Ballista is one unopposed heat")
	session._round_finished({33: 99})
	session._advance_phase()
	check(session.phase == session.Phase.MATCH_RESULTS and session.roster[33]["score"] == 0, "Practice never awards competitive points")
	session._peer_disconnected(33)
	check(session.phase == session.Phase.LOBBY and session.selected_games == ["ballista", "lance", "coins"], "Empty server resets lobby")
	print("SESSION_TESTS_COMPLETE failures=%d" % failures)
	quit(0 if failures == 0 else 1)
