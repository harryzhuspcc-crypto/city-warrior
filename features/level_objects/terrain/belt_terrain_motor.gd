class_name BeltTerrainMotor
extends Node
## Optional actor-local terrain adapter. Stage 1 never gets one. Movement,
## jump input and combat stay in their existing workers; this owns support,
## step clearance, environmental velocity and pit recovery only.

signal fell_into_pit

const STEP_HEIGHT := 18.0
const GRAVITY := 600.0
const PIT_BOTTOM := -112.0
const PIT_DAMAGE := 20
# A jump pressed just as Billy walks off an edge (including the input chord
# delay) still leaves from that edge instead of being dropped mid-fall.
const LEDGE_GRACE_FRAMES := 8

var body: CharacterBody2D
var terrain: BeltTerrainMap
var jump: JumpComponent
var _enemy_height: float = 0.0
var _enemy_velocity: float = 0.0
var _enemy_falling: bool = false
var _visual_baseline: Vector2
var checkpoint := Vector2.ZERO
var checkpoint_elevation: float = 0.0
var invulnerability_frames: int = 0
var _initialized: bool = false
var _footprint := Rect2()
var _ledge_grace_frames: int = 0


func initialize() -> void:
	var collision := body.get_node("BodyCollision") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D
	assert(rectangle != null, "Terrain support requires the fighter's rectangular foot shape")
	_footprint = Rect2(collision.position - rectangle.size * 0.5, rectangle.size)
	_visual_baseline = body.get(&"visuals").position
	checkpoint = body.global_position
	var initial_height := float(body.get_meta(&"terrain_height", 0.0))
	var floor: Variant = _floor_at(body.global_position, initial_height)
	_enemy_height = initial_height if floor == null else float(floor)
	checkpoint_elevation = _enemy_height
	if jump != null:
		jump.ground_elevation = _enemy_height
	_initialized = true
	process_physics_priority = -10
	_apply_visual_height()


func elevation() -> float:
	return jump.ground_elevation + jump.jump_height + body.climb_component.elevation() if jump != null else _enemy_height


func camera_elevation() -> float:
	return jump.ground_elevation if jump != null else _enemy_height


func is_falling() -> bool:
	return (jump.is_airborne if jump != null else _enemy_falling)


func _floor_at(position: Vector2, ceiling: float = INF) -> Variant:
	return terrain.floor_at(position.x, position.y, ceiling, _footprint)


func _paired() -> bool:
	if body is Player:
		return is_instance_valid(body.throw_owner) or body.hair_grab_component.is_active() or body.climb_component.is_elevated()
	var enemy := body as EnemyFighter
	return enemy != null and (is_instance_valid(enemy.grab_owner) or (enemy.throw_component != null and enemy.throw_component.is_active()))


func resolve_velocity(velocity: Vector2) -> Vector2:
	if not _initialized or _paired() or not body.is_physics_processing():
		return velocity
	var result := velocity
	if not is_falling() and not body.get(&"health_component").is_dead():
		result.x += terrain.belt_at(body.global_position.x, body.global_position.y, elevation() + 0.5, _footprint)
	# Sweep the desired depth/x interval so special moves cannot tunnel up a
	# platform face. Gaps in configured fall zones don't block motion there:
	# unsupported actors really fall. Everywhere else edges hold actors in.
	var delta := body.get_physics_process_delta_time()
	if delta <= 0.0:
		return Vector2.ZERO
	var distance := result * delta
	var steps := maxi(1, int(ceilf(distance.length() / 2.0)))
	var allowed := Vector2.ZERO
	var origin := body.global_position
	for index: int in range(1, steps + 1):
		var step := distance * float(index) / float(steps)
		var next := origin + step
		var clearance := 0.5 if is_falling() else STEP_HEIGHT
		var floor: Variant = _floor_at(next, elevation() + clearance)
		var higher: Variant = _floor_at(next)
		if floor == null and higher != null and float(higher) > elevation() + clearance:
			break
		# Back edges meet the pictured wall, not an invisible fall behind it.
		# Outside fall zones every other edge does too. Preserve sideways or
		# depth movement along such an edge: clipping both axes makes
		# diagonal movement stick to the scenery.
		if _edge_blocks(next, step.y < 0.0):
			if not _edge_blocks(Vector2(next.x, origin.y + allowed.y), false):
				allowed.x = step.x
				continue
			if not _edge_blocks(Vector2(origin.x + allowed.x, next.y), step.y < 0.0):
				allowed.y = step.y
				continue
			break
		allowed = step
	return allowed / delta


func _edge_blocks(point: Vector2, toward_back: bool) -> bool:
	if is_falling():
		# Airborne actors may cross gaps only where a surface lies below.
		# The rear wall is never an assisted landing corridor: allowing Up
		# behind it can strand a descending actor behind the roof's crates.
		if toward_back:
			return not terrain.allows_fall_at(point.x) and _edge_floor_at(point) == null
		return not terrain.allows_fall_at(point.x) and not _has_landing_near(point)
	var floor: Variant = _edge_floor_at(point, elevation() + STEP_HEIGHT)
	if toward_back and (floor == null or float(floor) < elevation() - STEP_HEIGHT):
		return true
	if terrain.allows_fall_at(point.x):
		return false
	return floor == null or float(floor) < elevation() - STEP_HEIGHT


# A slightly smaller foot than the support check uses, so a spot allowed by
# an edge never loses its support or landing to rounding once reached.
func _edge_floor_at(point: Vector2, ceiling: float = INF) -> Variant:
	return terrain.floor_at(point.x, point.y, ceiling, _footprint.grow(-1.0))


func _has_landing_near(point: Vector2) -> bool:
	if _edge_floor_at(point) != null:
		return true
	for distance: int in range(2, int(terrain.landing_depth_assist) + 1, 2):
		for direction: float in [-1.0, 1.0]:
			var candidate := terrain.surface_at(point.x, point.y + float(distance) * direction, INF, _footprint.grow(-1.0))
			if float(candidate.get("landing_depth_assist", 0.0)) >= float(distance):
				return true
	return false


func _assisted_landing(ceiling: float) -> void:
	# A belt-scroller's depth is hard to judge from a narrow slanted top.
	# Catch only an actual descending height crossing, at the same x, then
	# move the feet ONTO that top. Strict polygons/gaps remain unchanged.
	if not jump.is_airborne or jump.jump_velocity > 0.0:
		return
	for distance: int in range(2, int(terrain.landing_depth_assist) + 1, 2):
		for direction: float in [-1.0, 1.0]:
			var motion := Vector2(0, float(distance) * direction)
			var point := body.global_position + motion
			var surface := terrain.surface_at(point.x, point.y, ceiling, _footprint)
			if surface.is_empty() or float(surface.get("landing_depth_assist", 0.0)) < float(distance):
				continue
			var floor := float(surface["height"])
			if floor < elevation() or body.test_move(body.global_transform, motion):
				continue
			body.global_position = point
			jump.ground_elevation = float(floor)
			_ledge_grace_frames = 0
			jump.land_immediately()
			return


func after_move() -> void:
	if not _initialized or _paired():
		return
	if jump != null:
		_update_player_support()
	else:
		_update_enemy_support()
	_apply_visual_height()
	_save_checkpoint()


func has_ledge_grace() -> bool:
	return _ledge_grace_frames > 0 and jump.is_airborne and jump.jump_velocity <= 0.0


## Restores the edge Billy just walked off so the jump leaves from it.
func consume_ledge_grace() -> bool:
	if not has_ledge_grace():
		return false
	_ledge_grace_frames = 0
	jump.jump_height = 0.0
	return true


func physics_jump(delta: float) -> void:
	_ledge_grace_frames = maxi(_ledge_grace_frames - 1, 0)
	_update_player_support()
	if jump.is_airborne:
		jump.jump_velocity -= jump.gravity() * delta
		jump.jump_height += jump.jump_velocity * delta
		_update_player_support()
	_apply_visual_height()
	if elevation() < PIT_BOTTOM:
		_pit_fall()


func _update_player_support() -> void:
	var landing_sweep := maxf(0.0, -jump.jump_velocity * body.get_physics_process_delta_time())
	var floor: Variant = _floor_at(body.global_position, elevation() + (landing_sweep + 0.5 if jump.is_airborne else STEP_HEIGHT))
	if not jump.is_airborne:
		if floor == null or float(floor) < elevation() - 1.0:
			jump.is_airborne = true
			jump.jump_velocity = 0.0
			_ledge_grace_frames = LEDGE_GRACE_FRAMES
		elif float(floor) <= elevation() + STEP_HEIGHT:
			jump.ground_elevation = float(floor)
	elif floor != null and jump.jump_velocity <= 0.0 and elevation() <= float(floor):
		_ledge_grace_frames = 0
		jump.ground_elevation = float(floor)
		jump.land_immediately()
	elif jump.is_airborne:
		_assisted_landing(elevation() + landing_sweep + 0.5)


func _update_enemy_support() -> void:
	var landing_sweep := maxf(0.0, -_enemy_velocity * body.get_physics_process_delta_time())
	var floor: Variant = _floor_at(body.global_position, _enemy_height + (landing_sweep + 0.5 if _enemy_falling else STEP_HEIGHT))
	if not _enemy_falling:
		if floor == null or float(floor) < _enemy_height - 1.0:
			_enemy_falling = true
			_enemy_velocity = 0.0
		elif float(floor) <= _enemy_height + STEP_HEIGHT:
			_enemy_height = float(floor)
	elif floor != null and _enemy_velocity <= 0.0 and _enemy_height <= float(floor):
		_enemy_height = float(floor)
		_enemy_falling = false
		_enemy_velocity = 0.0


func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	# Crate footprints collide only on the pictured loading deck. The upper
	# awning passes above them; Stage 1 never enables this additional layer.
	body.set_collision_mask_value(10, elevation() >= 192.0 and elevation() <= 240.0 and not _paired())
	var base_height := jump.ground_elevation if jump != null else _enemy_height
	body.set_collision_mask_value(13, base_height >= 192.0 and not _paired())
	if not body.is_physics_processing() or _paired():
		return
	if invulnerability_frames > 0:
		invulnerability_frames -= 1
		body.get(&"visuals").modulate.a = 0.4 if invulnerability_frames % 8 < 4 else 1.0
		if invulnerability_frames == 0:
			body.get(&"hurtbox").is_invulnerable = false
			body.get(&"visuals").modulate.a = 1.0
	if jump != null:
		return # Player's one existing jump clock calls physics_jump().
	_update_enemy_support()
	if _enemy_falling:
		_enemy_velocity -= GRAVITY * delta
		_enemy_height += _enemy_velocity * delta
		_update_enemy_support()
	_apply_visual_height()
	if elevation() < PIT_BOTTOM:
		_pit_fall()


func _apply_visual_height() -> void:
	if _paired():
		return
	if jump != null:
		body.get(&"climb_component").ground_elevation = jump.ground_elevation
		jump.sync_visual_height()
	else:
		body.get(&"visuals").position = _visual_baseline + Vector2.UP * _enemy_height


func _save_checkpoint() -> void:
	if jump == null or is_falling() or body.get(&"health_component").is_dead():
		return
	# A checkpoint needs room for the feet, not the last toe over an edge.
	var x := body.global_position.x
	var y := body.global_position.y
	var height := elevation()
	var forward_margin := 20.0 if terrain.belt_at(x, y, height + 0.5) > 0.0 else 8.0
	for offset: Vector2 in [Vector2(-8, 0), Vector2(0, -8), Vector2(0, 8)]:
		var floor: Variant = terrain.floor_at(x + offset.x, y + offset.y, height + 0.5)
		if floor == null or not is_equal_approx(float(floor), height):
			return
	# Check the whole margin, not just an endpoint beyond a narrow opening.
	for offset: int in range(0, int(forward_margin) + 1, 2):
		var floor: Variant = terrain.floor_at(x + float(offset), y, height + 0.5)
		if floor == null or not is_equal_approx(float(floor), height):
			return
	checkpoint = body.global_position
	checkpoint_elevation = height


func _pit_fall() -> void:
	fell_into_pit.emit()
	var fighter_health := body.get(&"health_component") as HealthComponent
	if jump == null:
		fighter_health.take_damage(1000)
		body.set_physics_process(false)
		body.emit_signal(&"defeated")
		body.queue_free()
		set_physics_process(false)
		return
	var player := body as Player
	player.combat_component.cancel_attack()
	player.hair_grab_component.release()
	player.hit_reaction_component.reset()
	player.input_component.clear_buffered_actions()
	_ledge_grace_frames = 0
	body.global_position = checkpoint
	body.velocity = Vector2.ZERO
	jump.ground_elevation = checkpoint_elevation
	jump.land_immediately()
	player.audio_component.play_ground_fall()
	fighter_health.take_damage(PIT_DAMAGE)
	if not fighter_health.is_dead():
		invulnerability_frames = 45
		player.hurtbox.is_invulnerable = true
		player.state_machine.transition_to(PlayerStateMachine.IDLE)
