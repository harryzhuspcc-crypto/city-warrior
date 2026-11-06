extends SceneTree

const FINAL := preload("res://levels/headquarters/headquarters.tscn")
const WOODS := preload("res://levels/woods/woods.tscn")
const FINAL_PATH := "res://levels/headquarters/headquarters.tscn"
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _wait_until(condition: Callable, budget: int = 150) -> bool:
	for tick: int in range(budget):
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _run() -> void:
	await _test_single_block_projection()
	await _test_route_and_ending()
	await _test_lethal_walls()
	await _test_willy()
	await _test_transition_and_restart()
	await AudioSettle.settle(self)
	if failures.is_empty():
		print("STAGE_FOUR_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("STAGE_FOUR_SMOKE_TEST_FAIL: " + message)
		quit(1)


func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func _walk(stage: PrototypeAlley, destination: Vector2, budget: int = 900) -> void:
	for tick: int in range(budget):
		if stage.state == PrototypeAlley.CLEARED:
			_release_inputs()
			return
		var difference := destination - stage.player.position
		if absf(difference.x) < 1.6 and absf(difference.y) < 1.1:
			_release_inputs()
			return
		_release_inputs()
		if absf(difference.x) >= 1.6:
			Input.action_press(&"move_right" if difference.x > 0 else &"move_left")
		if absf(difference.y) >= 1.1:
			Input.action_press(&"move_down" if difference.y > 0 else &"move_up")
		await physics_frame
		if stage.player.is_dead():
			break
	_release_inputs()
	_check(false, "Route reaches %s (got %s, health %s)" % [destination, stage.player.position, stage.player.health_component.current_health])


func _test_single_block_projection() -> void:
	var stage := FINAL.instantiate() as PrototypeAlley
	root.add_child(stage)
	await physics_frame
	_check(await _wait_until(func() -> bool: return not stage.stage_transition.is_busy()), "Single-block fixture intro")
	stage.set_encounters_enabled(false)
	var traps: Array = stage.get("wall_traps")
	var picture := Image.new()
	picture.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/stages/headquarters.png"))
	picture.convert(Image.FORMAT_RGBA8)
	for index: int in range(traps.size()):
		var trap := traps[index] as TimedWallTrap
		trap.enabled = false
		var stone := Image.new()
		stone.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/stages/headquarters_wall_block_%d.png" % (index + 1)))
		stone.convert(Image.FORMAT_RGBA8)
		_check(stone.get_size() == Vector2i(24, 24), "Each piston uses only one square stone, not an 80x88 panel")
		_check(stone.get_data() == picture.get_region(Rect2i(272 + 112 * index, 256, 24, 24)).get_data(), "Stone texture is the exact selected original masonry cell")
		var socket := trap.socket_rect()
		trap.apply_clock(posmod(174 - trap.phase_offset_frames, TimedWallTrap.PERIOD_FRAMES))
		_check(trap.extension > TimedWallTrap.REACH * 0.5, "Thrust uses an eased punch rather than linear downward sliding")
		trap.apply_clock(posmod(180 - trap.phase_offset_frames, TimedWallTrap.PERIOD_FRAMES))
		_check(trap.socket_rect() == socket, "Stone socket and neighbouring wall stay fixed while the block extends")
		var front := trap.projected_front()
		_check(front.size.x > 24.0 and front.size.x == front.size.y, "Approaching face grows in perspective but remains one square")
		_check(front.position.x < trap.block_offset.x, "Depth projection has a sideways vanishing direction, not just a Y translation")
		_check(is_equal_approx(front.end.y, TimedWallTrap.REACH), "Full-extension front meets its lethal floor projection")
		_check(trap.danger_rect().size.x <= 40.0 and trap.danger_polygon().size() == 4, "Lethal footprint is the narrow projected block, not the entire panel")
	var first := traps[0] as TimedWallTrap
	stage.player.position = Vector2(320, 320)
	await physics_frame # Reset the sweep history while the fixture is disarmed.
	first.elapsed_frames = 178
	first.enabled = true
	for tick: int in range(3):
		await physics_frame
	_check(stage.player.health_component.current_health == 100, "Standing alongside stationary masonry is safe while its single block is extended")
	stage.player.position = Vector2(280, 320)
	_check(await _wait_until(func() -> bool: return stage.player.is_dead(), 5), "Moving into the extended single block is still instantly lethal")
	await AudioSettle.free_level(self, stage)


func _test_route_and_ending() -> void:
	var stage := FINAL.instantiate() as PrototypeAlley
	root.add_child(stage)
	await physics_frame
	var traps: Array = stage.get("wall_traps")
	_check(traps.size() == 3 and not traps[0].enabled, "Three entrance walls wait for the intro")
	_check(await _wait_until(func() -> bool: return not stage.stage_transition.is_busy()), "Final-stage intro restores controls")
	_check(traps[0].enabled and traps[0].elapsed_frames < 3, "Trap clock starts with player control, not scene loading")
	_check(stage.music.loops() and stage.music.stream.resource_path.ends_with("08_enemy_headquarters.mp3"), "Headquarters music loops")
	_check(not stage.stage_transition.has_next_stage(), "Stage 4 really is the last stage")
	_check(stage.camera.limit_bottom == 352 and stage.camera.limit_right == 1712, "Camera never exposes beyond the original picture")
	var terrain := stage.get_node("Terrain") as BeltTerrainMap
	_check(terrain.surfaces.size() == 5 and terrain.get_child_count() == 7, "Five native-art floor traces and two map boundaries")
	_check(terrain.floor_at(750, 296) == 0.0 and terrain.floor_at(750, 330) == null, "Statue walkway has no invisible floor over the spikes")
	var source := Image.new()
	source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/source_sheets/final-mission.png"))
	source.convert(Image.FORMAT_RGBA8)
	var picture := Image.new()
	picture.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/stages/headquarters.png"))
	picture.convert(Image.FORMAT_RGBA8)
	_check(source.get_data() == picture.get_data(), "Every final-stage background pixel matches the original picture")
	var spawned: Array[StringName] = []
	for encounter: EncounterController in stage.encounter_controllers():
		encounter.enemy_spawned.connect(func(enemy: Node2D) -> void:
			spawned.append(encounter.name)
			_check(terrain.floor_at(enemy.position.x, enemy.position.y) == 0.0, "Every final-stage enemy spawns on drawn floor")
			_check((enemy as EnemyFighter).terrain_motor != null, "Every final-stage enemy gets terrain collision")
			enemy.set_physics_process(false)
			enemy.queue_free()
		)
	# Real input/movement crosses each piston while fully retracted. Waiting
	# bays are outside the moving footprint; no hazard or encounter is disabled.
	await _walk(stage, Vector2(224, 320))
	for index: int in range(traps.size()):
		var trap := traps[index] as TimedWallTrap
		if index == 2:
			await _walk(stage, Vector2(448, 296))
		_check(await _wait_until(func() -> bool:
			return posmod(trap.elapsed_frames + trap.phase_offset_frames, TimedWallTrap.PERIOD_FRAMES) < 8, 250), "A repeatable retracted crossing window exists")
		await _walk(stage, Vector2(336 + index * 112, 296 if index == 2 else 320))
	_check(stage.player.health_component.current_health == 100, "All three wall traps are traversable without damage")
	await _walk(stage, Vector2(560, 296))
	await _walk(stage, Vector2(980, 296))
	await _walk(stage, Vector2(1040, 272))
	await _walk(stage, Vector2(1296, 272))
	await _walk(stage, Vector2(1536, 240))
	_check(await _wait_until(func() -> bool: return stage._all_encounters_cleared(), 120), "All three final-stage arenas clear in order")
	_check(spawned.size() == 7, "All seven enemies including Willy actually spawn")
	_check(stage.state == PrototypeAlley.PLAYING, "Defeating the boss alone does not skip the rescue")
	await _walk(stage, stage.exit.position)
	_check(await _wait_until(func() -> bool: return stage.state == PrototypeAlley.CLEARED, 15), "Reaching the dragon door completes the campaign")
	_check(not stage.player.is_physics_processing() and stage.player.hurtbox.is_invulnerable, "Ending freezes and protects Billy from lingering gunfire")
	_check(stage.stage_clear_music.playing and stage.stage_clear_music.stream.resource_path.ends_with("09_ending_theme.mp3"), "Campaign completion plays the ending theme")
	_check(await _wait_until(func() -> bool: return stage._restart_armed), "Finale offers replay")
	_check(stage.hud.message_label.text.contains("MARIAN RESCUED") and stage.hud.message_label.text.contains("REPLAY THE FINAL STAGE"), "Final rescue and replay banner")
	_check(stage.player.health_component.current_health == 100, "Full final-stage traversal takes no environmental damage")
	await AudioSettle.free_level(self, stage)


func _test_lethal_walls() -> void:
	for scenario: int in range(4):
		var stage := FINAL.instantiate() as PrototypeAlley
		root.add_child(stage)
		await physics_frame
		_check(await _wait_until(func() -> bool: return not stage.stage_transition.is_busy()), "Crush fixture intro")
		stage.set_encounters_enabled(false)
		var traps: Array = stage.get("wall_traps")
		for other: TimedWallTrap in traps:
			other.enabled = false
		var trap := traps[0] as TimedWallTrap
		trap.apply_clock(122)
		_check(trap.phase == TimedWallTrap.SAFE and is_zero_approx(trap.extension), "Safe interval has no invisible wall")
		trap.apply_clock(123)
		_check(trap.phase == TimedWallTrap.WARNING and is_zero_approx(trap.extension), "Amber warning precedes movement by 45 frames")
		trap.apply_clock(168)
		_check(trap.phase == TimedWallTrap.EXTENDING and trap.extension > 0.0, "Thrust begins on its fixed frame")
		trap.apply_clock(180)
		_check(trap.extension == 64.0, "Single block reaches the front of the entrance lane")
		trap.apply_clock(240)
		_check(trap.phase == TimedWallTrap.SAFE and is_zero_approx(trap.extension), "Wall retracts completely every 240 frames")
		trap.apply_clock(180 + TimedWallTrap.PERIOD_FRAMES * 12)
		_check(trap.phase == TimedWallTrap.HOLDING and trap.extension == 64.0, "No rhythm drift after repeated cycles")
		stage.player.position = Vector2(280, 320)
		stage.player.hurtbox.is_invulnerable = true
		if scenario == 1:
			stage.player.health_component.take_damage(93)
		elif scenario == 2:
			stage.player.jump_component.try_jump()
		elif scenario == 3:
			# A deep lane is initially beyond the advancing face, then struck.
			stage.player.position.y = 350
		trap.elapsed_frames = 123 if scenario == 0 else 178
		trap.enabled = true
		if scenario == 0:
			await physics_frame
			_check(not stage.player.is_dead(), "Warning alone never damages Billy")
			trap.elapsed_frames = 178
		_check(await _wait_until(func() -> bool: return stage.player.is_dead(), 15), "Wall contact instantly kills at any HP, lane, or jump state")
		_check(stage.player.health_component.current_health == 0 and stage.state == PrototypeAlley.DEFEATED, "Crushing uses normal death and game-over flow, bypassing combat invulnerability")
		_check(not trap.enabled, "Trap clock stops on defeat")
		_check(await _wait_until(func() -> bool: return stage._restart_armed), "Crushing still offers restart")
		await AudioSettle.free_level(self, stage)


func _test_willy() -> void:
	var stage := FINAL.instantiate() as PrototypeAlley
	root.add_child(stage)
	await physics_frame
	_check(await _wait_until(func() -> bool: return not stage.stage_transition.is_busy()), "Willy fixture intro")
	stage.encounter_controller.enabled = false
	stage.get_node("Encounters/HallEncounter").enabled = false
	stage.player.position = Vector2(stage.boss_encounter.lock_x, 240)
	_check(await _wait_until(func() -> bool: return stage.boss_encounter.spawned_count == 1, 15), "Final boss spawns through encounter controller")
	var boss: Willy
	for actor: Node in stage.actors.get_children():
		if actor is Willy:
			boss = actor as Willy
	_check(boss != null and boss.health_component.current_health == 240, "Willy has original art and separate boss stats")
	_check(await _wait_until(func() -> bool: return stage.player.health_component.current_health < 100, 180), "Telegraphed gun fires a visible damaging projectile")
	_check(stage.player.health_component.current_health == 82, "Gunshot deals 18 HP, not wall-style instant death")
	boss.combat_component.cancel_attack()
	boss.set_physics_process(false)
	# A fired round is still safe to tick if its firing actor is removed.
	var bullet_script := preload("res://features/actors/enemies/willy/willy_bullet.gd")
	var bullet := bullet_script.new()
	bullet.target = stage.player
	bullet.attack = boss.bullet_attack
	bullet.position = stage.player.position + Vector2(40, 0)
	bullet.direction = -1
	stage.actors.add_child(bullet)
	stage.player.jump_component.try_jump()
	for tick: int in range(18):
		await physics_frame
	_check(stage.player.health_component.current_health == 82, "A well-timed jump dodges Willy's round")
	bullet.queue_free()
	boss.health_component.take_damage(999)
	boss.set_physics_process(true)
	_check(await _wait_until(func() -> bool: return stage.boss_encounter.is_cleared(), 120), "Willy's normal death releases the arena")
	await AudioSettle.free_level(self, stage)


func _test_transition_and_restart() -> void:
	var woods := WOODS.instantiate() as PrototypeAlley
	root.add_child(woods)
	current_scene = woods
	await physics_frame
	_check(await _wait_until(func() -> bool: return not woods.stage_transition.is_busy()), "Woods transition fixture intro")
	woods.set_encounters_enabled(false)
	woods.stage_transition.clear_hold_frames = 2
	woods.stage_transition.walk_frames = 2
	woods.stage_transition.fade_frames = 2
	woods.player.position = woods.exit.position
	woods.player.jump_component.ground_elevation = 224.0
	woods.player.jump_component.land_immediately()
	var woods_id := woods.get_instance_id()
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == FINAL_PATH, 30), "Real Stage 3 to Stage 4 scene replacement")
	_check(instance_from_id(woods_id) == null, "Woods actors are freed on transition")
	var stage := current_scene as PrototypeAlley
	_check(await _wait_until(func() -> bool: return not stage.stage_transition.is_busy()), "Real final-stage intro finishes")
	_check(stage.player.health_component.current_health == 100 and stage.player.position == Vector2(56, 312), "Final-stage entry has fresh health and a safe spawn")
	stage.player.position = stage.exit.position
	await physics_frame
	_check(stage.state == PrototypeAlley.PLAYING, "Uncleared encounters prevent early campaign completion")
	stage.player.health_component.take_damage(999)
	_check(await _wait_until(func() -> bool: return stage._restart_armed), "Final-stage defeat offers retry")
	var previous_id := stage.get_instance_id()
	stage.request_restart()
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != previous_id, 20), "Final stage actually reloads")
	var fresh := current_scene as PrototypeAlley
	_check(fresh.scene_file_path == FINAL_PATH and fresh.player.health_component.current_health == 100, "Retry stays in Stage 4")
	var traps: Array = fresh.get("wall_traps")
	_check(traps[0].elapsed_frames == 0 and not traps[0].enabled, "Retry resets the deterministic trap clock")
	current_scene = null
	await AudioSettle.free_level(self, fresh)
