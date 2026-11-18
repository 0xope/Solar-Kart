extends SceneTree

var _failures: Array[String] = []
var _passed: Array[String] = []

func _init() -> void:
	call_deferred("_run_tests")

func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_passed.append(test_name)
		print("  [PASS] %s" % test_name)
	else:
		_failures.append(test_name)
		print("  [FAIL] %s" % test_name)

func _run_tests() -> void:
	print("==================================================")
	print(" SOLAR KART - AUTOMATED COMPREHENSIVE TEST SUITE  ")
	print("==================================================")

	var packed := load("res://Game/Scenes/TestTrack.tscn") as PackedScene
	_assert(packed != null, "Load TestTrack.tscn")
	var track := packed.instantiate()
	root.add_child(track)

	await physics_frame
	await physics_frame

	var kart := track.get_node("PlayerKart") as PlayerKart
	var race_mgr := track.get_node("RaceManager") as RaceManager
	var hud := track.get_node("RaceHUD") as RaceHUD
	var nitro := kart.nitro

	_assert(kart != null, "PlayerKart found")
	_assert(race_mgr != null, "RaceManager found")
	_assert(hud != null, "RaceHUD found")
	_assert(nitro != null, "NitroController found on kart")

	# -----------------------------------------------------------------
	# Test 1: Drifting completely removed
	# -----------------------------------------------------------------
	print("\n--- Test Suite 1: Drift System Removal ---")
	_assert(not kart.has_node("DriftController"), "No DriftController child in PlayerKart")
	_assert(not kart.has_node("DriftIndicator"), "No DriftIndicator child in PlayerKart")
	_assert(not InputMap.has_action("drift"), "No drift action in InputMap")
	_assert(InputMap.has_action("nitro"), "Nitro action configured in InputMap")

	# -----------------------------------------------------------------
	# Test 2: Race Countdown prevents early movement
	# -----------------------------------------------------------------
	print("\n--- Test Suite 2: Countdown & Race Start ---")
	_assert(race_mgr.state == RaceManager.RaceState.COUNTDOWN, "Race starts in COUNTDOWN state")
	_assert(kart._controls_enabled == false, "Kart controls locked during countdown")

	var initial_pos := kart.global_position
	Input.action_press("accelerate")
	for i in range(30):
		await physics_frame
	Input.action_release("accelerate")

	_assert(kart.global_position.distance_to(initial_pos) < 0.05, "Kart cannot accelerate before race start")

	# Fast forward through countdown to GO!
	race_mgr._countdown_timer = -0.7
	for i in range(15):
		await physics_frame

	_assert(race_mgr.state == RaceManager.RaceState.RACING, "Race enters RACING state after GO")
	_assert(kart._controls_enabled == true, "Kart controls enabled after GO")
	_assert(race_mgr.race_time > 0.0, "Race timer starts incrementing")

	# -----------------------------------------------------------------
	# Test 3: Normal Driving (Acceleration, Steering, Braking, Reverse)
	# -----------------------------------------------------------------
	print("\n--- Test Suite 3: Arcade Driving Physics ---")
	Input.action_press("accelerate")
	for i in range(60):
		await physics_frame
	Input.action_release("accelerate")

	var speed_after_accel := kart.forward_speed()
	_assert(speed_after_accel > 10.0, "Kart accelerates normally (speed=%.2f m/s)" % speed_after_accel)

	# Test steering
	var rot_before := kart.rotation.y
	Input.action_press("accelerate")
	Input.action_press("steer_right")
	for i in range(30):
		await physics_frame
	Input.action_release("steer_right")
	Input.action_release("accelerate")

	_assert(absf(kart.rotation.y - rot_before) > 0.1, "Kart steering rotates vehicle")

	# Test braking and reverse
	Input.action_press("brake")
	for i in range(120):
		await physics_frame
	Input.action_release("brake")

	var speed_after_brake := kart.forward_speed()
	_assert(speed_after_brake < 0.0, "Brake transitions into reverse gear (speed=%.2f m/s)" % speed_after_brake)

	# -----------------------------------------------------------------
	# Test 4: Nitro System (Spacebar, Charge, Boost)
	# -----------------------------------------------------------------
	print("\n--- Test Suite 4: Nitro & Boost Mechanics ---")
	kart.reset_to_transform(race_mgr._start_grid_transform)
	kart.set_controls_enabled(true)
	await physics_frame

	var charge_before := nitro.current_charge
	_assert(charge_before == 100.0, "Nitro starts with 100% full charge")

	# Accelerate to min speed, then press nitro
	Input.action_press("accelerate")
	for i in range(30):
		await physics_frame

	var speed_pre_nitro := kart.forward_speed()
	Input.action_press("nitro")
	await physics_frame
	Input.action_release("nitro")

	_assert(nitro.is_active(), "Space / nitro action successfully activates Nitro")
	_assert(nitro.current_charge < charge_before, "Nitro consumes charge (remaining: %.1f)" % nitro.current_charge)

	for i in range(30):
		await physics_frame
	var speed_with_nitro := kart.forward_speed()
	_assert(speed_with_nitro > speed_pre_nitro, "Nitro gives noticeable speed boost (%.2f -> %.2f)" % [speed_pre_nitro, speed_with_nitro])

	Input.action_release("accelerate")

	# -----------------------------------------------------------------
	# Test 5: Obstacle Collision System
	# -----------------------------------------------------------------
	print("\n--- Test Suite 5: Obstacle Collision System ---")
	var cone := track.find_child("Cone_1", true, false) as Obstacle
	_assert(cone != null, "ObstacleCone found on track")

	kart.global_position = Vector3(45, 0, -8.0)
	kart.rotation = Vector3(0, -PI * 0.5, 0)
	kart._forward_speed = 20.0
	await physics_frame

	# Simulate impact
	cone._on_body_entered(kart)
	_assert(kart.forward_speed() < 20.0, "Obstacle collision reduces kart speed (now: %.2f m/s)" % kart.forward_speed())
	_assert(cone._cooldown > 0.0, "Obstacle hit cooldown active (debounce prevents multi-penalty spam)")

	# -----------------------------------------------------------------
	# Test 6: Collectibles (Solar Coins & Nitro Cells)
	# -----------------------------------------------------------------
	print("\n--- Test Suite 6: Collectibles System ---")
	var coin := track.find_child("SolarCoin_1", true, false) as Collectible
	var nitro_cell := track.find_child("NitroCell_1", true, false) as Collectible
	_assert(coin != null, "SolarCoin found on track")
	_assert(nitro_cell != null, "NitroCell found on track")

	var coins_before := race_mgr.coins
	coin._on_body_entered(kart)
	_assert(race_mgr.coins == coins_before + 1, "Solar Coin increments coin counter (now: %d)" % race_mgr.coins)
	_assert(coin._collected == true, "Solar Coin marked collected and disabled")

	# Collect again while inactive -> should not duplicate
	coin._on_body_entered(kart)
	_assert(race_mgr.coins == coins_before + 1, "Coin cannot be collected multiple times in same race")

	# Test Nitro Cell
	nitro.current_charge = 40.0
	nitro_cell._on_body_entered(kart)
	_assert(nitro.current_charge > 40.0, "Nitro Cell restores charge (now: %.1f)" % nitro.current_charge)

	# -----------------------------------------------------------------
	# Test 7: Out-of-Bounds Detection & Checkpoint Respawning
	# -----------------------------------------------------------------
	print("\n--- Test Suite 7: Out-of-Bounds & Checkpoint Respawn ---")
	var coins_at_fall := race_mgr.coins
	# Throw kart off the track
	kart.global_position = Vector3(0, -6.0, 0)
	await physics_frame
	await physics_frame

	_assert(race_mgr.state == RaceManager.RaceState.RESPAWNING, "Falling below threshold triggers RESPAWNING state")
	_assert(kart.global_position.y >= 0.0, "Kart respawned back up on track surface")
	_assert(kart.forward_speed() == 0.0, "Kart velocity reset on respawn")
	_assert(race_mgr.coins == coins_at_fall, "Respawning does NOT reset player's collected coins")

	for i in range(30):
		await physics_frame
	_assert(race_mgr.state == RaceManager.RaceState.RACING, "Controls restored after respawn delay")

	# -----------------------------------------------------------------
	# Test 8: Checkpoint Progression & Lap System
	# -----------------------------------------------------------------
	print("\n--- Test Suite 8: Checkpoints & Laps ---")
	_assert(race_mgr.current_lap == 1, "Race starts on Lap 1")

	# Pass checkpoints sequentially
	for cp_idx in range(race_mgr._total_checkpoints):
		var cp_t := Transform3D(Basis(), Vector3(cp_idx * 10, 0, 0))
		race_mgr._on_checkpoint_passed(cp_idx, cp_t)

	_assert(race_mgr.current_lap == 2, "Completing all checkpoints advances to Lap 2")

	# Try skipping checkpoints out of order -> should NOT advance
	race_mgr._on_checkpoint_passed(5, Transform3D())
	_assert(race_mgr._next_checkpoint == 1, "Skipping checkpoints out of order is rejected")

	# -----------------------------------------------------------------
	# Test 9: Race Finish and Restart
	# -----------------------------------------------------------------
	print("\n--- Test Suite 9: Race Completion & Restart ---")
	# Advance remaining laps to finish race
	race_mgr.total_laps = 2
	for cp_idx in range(race_mgr._total_checkpoints):
		race_mgr._on_checkpoint_passed(cp_idx, Transform3D())

	_assert(race_mgr.state == RaceManager.RaceState.FINISHED, "Completing all laps finishes race")
	_assert(hud.finish_panel.visible == true, "Race finish panel displayed on HUD")

	# Restart race
	race_mgr.restart_race()
	await physics_frame
	_assert(race_mgr.state == RaceManager.RaceState.COUNTDOWN, "Restarting resets state to COUNTDOWN")
	_assert(race_mgr.current_lap == 1, "Restarting resets current lap to 1")
	_assert(race_mgr.coins == 0, "Restarting resets coins to 0")
	_assert(coin._collected == false, "Restarting restores collected pickups on track")

	# -----------------------------------------------------------------
	# Summary
	# -----------------------------------------------------------------
	print("\n==================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [_passed.size(), _failures.size()])
	print("==================================================")

	track.free()
	if _failures.size() > 0:
		push_error("Test suite failed with %d errors" % _failures.size())
		quit(1)
	else:
		print("ALL SYSTEMS TESTED AND VERIFIED SUCCESSFULLY!")
		quit(0)
