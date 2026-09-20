extends SceneTree

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, description: String) -> void:
	if value:
		print("PASS " + description)
	else:
		failures += 1
		push_error("FAIL " + description)


func run() -> void:
	var ids: Array[int] = [11, 22, 33, 44]
	var coins: CoinsGame = CoinsGame.new()
	root.add_child(coins)
	coins.setup(ids, 0, load("res://resources/coins.tres") as GameRules)
	coins.action(11, "collect", {})
	coins.action(11, "collect", {})
	check(coins.coins[11] == 1, "Coin rate cap rejects rapid repeated actions")
	coins.elapsed = 0.1
	coins.action(11, "collect", {})
	check(coins.coins[11] == 2, "Ten taps per second accepted")
	coins.hazard.enter(HazardClock.Phase.WARNING, 0.1, 0.25)
	coins.tick(0.25)
	check(bool(coins.alive[11]), "Exactly 0.25 seconds retracts safely")
	coins.action(22, "collect", {})
	coins.action(33, "collect", {})
	coins.hazard.enter(HazardClock.Phase.WARNING, coins.elapsed, 0.1)
	coins.tick(0.1)
	check(not coins.alive[22] and not coins.alive[33], "Exposed hands are eliminated simultaneously")
	check(coins.eliminations[22]["tick"] == coins.eliminations[33]["tick"], "Same-tick injury metadata agrees")
	coins.action(22, "collect", {})
	check(coins.coins[22] == 1, "Eliminated collectors retain coins and cannot collect")
	check(not (coins.public_state()["hazard"] as Dictionary).has("deadline"), "Coin snapshots hide the random impact deadline")
	check(not coins.public_state().has("rng"), "Hazard random state stays private")
	coins.elapsed = 35
	coins.tick(0)
	check(coins.finished, "Coins has a 35-second upper bound")
	check(PartyGame.placement_points({11: 8, 22: 8, 33: 3, 44: 1}) == {11: 3, 22: 3, 33: 1, 44: 0}, "Equal placements skip occupied ranks")
	coins.free()

	var lance: LanceGame = LanceGame.new()
	root.add_child(lance)
	lance.setup(ids, 1, load("res://resources/lance.tres") as GameRules)
	await physics_frame
	await process_frame
	check(lance.arena.refuges.size() == 8 and lance.available.size() == 4, "Four players start with four of eight refuges")
	for index: int in 8:
		check(lance.arena.safe_refuge(lance.arena.refuges[index], [index]) == index, "Refuge %d has valid capsule clearance" % index)
	lance.wave = 2
	lance._choose_refuges()
	check(lance.available.size() == 2, "Waves progressively reduce safe spaces")
	lance.input_frame(11, [{"seq": 0, "x": 999.0, "z": -999.0, "jump": false}])
	var frame: Dictionary = (lance.pending[11] as Array)[0]
	check(Vector2(frame["x"], frame["z"]).length() <= 1.001, "Movement is normalized by the server")
	lance.input_frame(11, [{"seq": 1, "x": 0.0, "z": 0.0, "jump": true}])
	check((lance.pending[11] as Array).size() == 1, "Jumping inputs rejected")
	lance.input_frame(11, [{"seq": 0, "x": 0.0, "z": 0.0}])
	check((lance.pending[11] as Array).size() == 1, "Duplicate movement frames rejected")
	var a: PartyPawn = lance.pawns[11]
	var b: PartyPawn = lance.pawns[22]
	a.position = Vector3(-0.4, 0.05, 0)
	b.position = Vector3(0.4, 0.05, 0)
	a.facing = Vector3.RIGHT
	b.facing = Vector3.LEFT
	lance.action(11, "shove", {})
	lance.action(22, "shove", {})
	lance.action(11, "shove", {})
	check(lance._shoves.size() == 2, "Shove cooldown rejects duplicate attacks")
	lance._resolve_shoves()
	check(a.impulse.x < 0 and b.impulse.x > 0, "Simultaneous shoves resolve from the same positions")
	check(a.collision_mask == 3, "Pawns collide with players and the world")
	a.impulse = Vector3.ZERO
	b.impulse = Vector3.ZERO
	a.velocity = Vector3.ZERO
	b.velocity = Vector3.ZERO
	a.position = Vector3(-1, 0.05, 0)
	b.position = Vector3(1, 0.05, 0)
	await physics_frame
	await process_frame
	for tick: int in 60:
		await physics_frame
		a.simulate({"x": 1.0, "z": 0.0, "jump": true}, 1.0 / 60.0)
		b.simulate({"x": -1.0, "z": 0.0, "jump": true}, 1.0 / 60.0)
	print("COLLISION_POSITIONS a=%s b=%s" % [a.position, b.position])
	check(a.position.x < b.position.x and a.position.distance_to(b.position) >= 0.65, "Moving bodies cannot walk through one another")
	check(a.position.y < 0.1 and b.position.y < 0.1, "Disabled jump remains grounded during simulation")
	lance.kill(11, "shark")
	lance.kill(22, "shark")
	var ranks: Dictionary = lance.survival_points()
	check(ranks[11] == ranks[22] and ranks[33] == 3, "Survival ties retain placement points after elimination")
	lance.free()

	var ballista: BallistaGame = BallistaGame.new()
	root.add_child(ballista)
	ballista.setup([11, 22], 1, load("res://resources/ballista.tres") as GameRules)
	await physics_frame
	await process_frame
	check(ballista.shooter == 22 and ballista.rules.duration == 60, "Role rotation selects next shooter with a 60-second heat")
	ballista.action(11, "shoot", {"direction": Vector3.BACK})
	check(ballista.ammunition == 4, "Runner cannot operate the ballista")
	ballista.action(22, "shoot", {"direction": Vector3(NAN, 0, 1)})
	check(ballista.ammunition == 4, "Non-finite forged aim rejected")
	for shot: int in 4:
		ballista.elapsed = shot * 0.5
		ballista.action(22, "shoot", {"direction": Vector3(0, 0.5, 1).normalized()})
	check(ballista.ammunition == 0 and is_equal_approx(ballista.reload_until, 4.5), "Four shots trigger a three-second reload")
	ballista.action(22, "shoot", {"direction": Vector3.BACK})
	check(ballista._shots.size() == 4, "Empty magazine cannot shoot")
	ballista._shots.clear()
	ballista.elapsed = 4.5
	ballista.tick(0)
	check(ballista.ammunition == 4, "Magazine refills at reload boundary")
	ballista.elapsed = 59.9
	ballista.tick(0)
	check(not ballista.finished, "Unresolved heat remains active before 60 seconds")
	ballista.tick(0.1)
	check(ballista.finished and not ballista.alive[11], "60-second timeout eliminates unfinished runners")
	ballista.free()

	ballista = BallistaGame.new()
	root.add_child(ballista)
	ballista.setup([11, 22], 0, load("res://resources/ballista.tres") as GameRules)
	await physics_frame
	await process_frame
	var runner: PartyPawn = ballista.pawns[22]
	runner.position = Vector3(-2.5, 0.05, -4)
	ballista.history.clear()
	ballista._record_history()
	var direction: Vector3 = (runner.position + Vector3.UP * 0.8 - BallistaArena.MOUNT).normalized()
	ballista._resolve_shot({"direction": direction, "time": 0.0})
	check(ballista.alive[22], "Static cover blocks historical hitscan")
	runner.position = Vector3(4, 0.05, -12)
	ballista.history.clear()
	ballista._record_history()
	direction = (runner.position + Vector3.UP * 0.8 - BallistaArena.MOUNT).normalized()
	ballista._resolve_shot({"direction": direction, "time": 0.0})
	check(not ballista.alive[22], "Unobstructed capsule hit eliminates runner")
	ballista.tick(0)
	check(ballista.finished, "Heat ends early when all runners resolve")
	ballista.free()

	ballista = BallistaGame.new()
	root.add_child(ballista)
	ballista.setup([11, 22], 0, load("res://resources/ballista.tres") as GameRules)
	await physics_frame
	await process_frame
	runner = ballista.pawns[22]
	runner.position = Vector3(4, 0.05, -16.1)
	ballista.history.clear()
	ballista._record_history()
	direction = (runner.position + Vector3.UP * 0.8 - BallistaArena.MOUNT).normalized()
	ballista.action(11, "shoot", {"direction": direction})
	ballista.tick(1.0 / 60.0)
	check(not ballista.alive[22] and not ballista.escaped.has(22), "A shot resolves before a finish crossing on the same tick")
	ballista.free()

	ballista = BallistaGame.new()
	root.add_child(ballista)
	ballista.setup([11, 22, 33], 0, load("res://resources/ballista.tres") as GameRules)
	await physics_frame
	await process_frame
	(ballista.pawns[22] as PartyPawn).position = Vector3(4, 0.05, -16.1)
	ballista.tick(1.0 / 60.0)
	direction = ((ballista.pawns[22] as PartyPawn).position + Vector3.UP * 0.8 - BallistaArena.MOUNT).normalized()
	ballista.action(11, "shoot", {"direction": direction})
	ballista.tick(1.0 / 60.0)
	check(ballista.alive[22] and ballista.escaped.has(22), "Already-finished runners cannot be shot")
	ballista.latency[11] = 99.0
	ballista.elapsed = 1.0
	ballista.action(11, "shoot", {"direction": Vector3.BACK})
	check(is_equal_approx(float(ballista._shots.back()["time"]), 0.8), "Rewind remains capped at 200 ms")
	ballista.free()

	for count: int in [2, 3, 4]:
		var role_ids: Array[int] = ids.slice(0, count)
		var shooters: Array[int] = []
		for heat: int in count:
			ballista = BallistaGame.new()
			root.add_child(ballista)
			ballista.setup(role_ids, heat, load("res://resources/ballista.tres") as GameRules)
			shooters.append(ballista.shooter)
			check(float(ballista.public_state()["remaining"]) == 60.0, "Fresh heat timer resets to 60 seconds")
			ballista.free()
		check(shooters == role_ids, "Every player shoots exactly once in a %d-player rotation" % count)
	print("RULE_TESTS_COMPLETE failures=%d" % failures)
	quit(0 if failures == 0 else 1)
