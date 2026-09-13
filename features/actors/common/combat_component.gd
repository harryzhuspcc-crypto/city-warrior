class_name CombatComponent
extends Node

signal attack_started
signal attack_phase_changed(previous_phase: StringName, current_phase: StringName)
signal hit_landed(target: HurtboxComponent, attack_data: AttackData, knockback: Vector2)
signal facing_changed(facing: float)
signal attack_finished(completed_attack: AttackData, completed_naturally: bool)

const INACTIVE: StringName = &"inactive"
const STARTUP: StringName = &"startup"
const ACTIVE: StringName = &"active"
const RECOVERY: StringName = &"recovery"

@export var attack_data: AttackData
@export var hitbox: Area2D
@export var hitbox_shape: CollisionShape2D
@export var source_actor: Node2D

var attack_frame: int = 0
var attack_facing: float = 1.0
var attack_hit_direction: float = 1.0
var current_attack_data: AttackData
var current_phase: StringName = INACTIVE
var is_attacking: bool = false
var is_hitbox_active: bool = false

var _desired_facing: float = 1.0
var _already_hit_targets: Dictionary[int, bool] = {}
var _is_finishing: bool = false
var _attack_generation: int = 0


func _ready() -> void:
	assert(attack_data != null, "CombatComponent requires AttackData")
	assert(hitbox != null, "CombatComponent requires a hitbox Area2D")
	assert(hitbox_shape != null, "CombatComponent requires a CollisionShape2D")
	assert(source_actor != null, "CombatComponent requires a source actor")
	assert(hitbox_shape.shape is RectangleShape2D, "Combat hitbox must use RectangleShape2D")

	hitbox_shape.shape = hitbox_shape.shape.duplicate()
	if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	_configure_hitbox_geometry()
	_set_hitbox_active(false)


func set_facing(horizontal_direction: float) -> void:
	if is_attacking or is_zero_approx(horizontal_direction):
		return
	_desired_facing = signf(horizontal_direction)
	attack_facing = _desired_facing
	_configure_hitbox_geometry()


func try_start_attack(requested_attack_data: AttackData = null) -> bool:
	var selected_attack := requested_attack_data if requested_attack_data != null else attack_data
	if is_attacking or _is_finishing or selected_attack == null:
		return false

	_attack_generation += 1
	var starting_generation := _attack_generation
	is_attacking = true
	current_attack_data = selected_attack
	attack_frame = 0
	attack_facing = _desired_facing
	attack_hit_direction = attack_facing * float(selected_attack.hit_direction_multiplier)
	_already_hit_targets.clear()
	_configure_hitbox_geometry()
	_set_phase(_phase_for_frame(attack_frame))
	if (
		not is_attacking
		or current_attack_data != selected_attack
		or _attack_generation != starting_generation
	):
		return false
	attack_started.emit()
	return (
		is_attacking
		and current_attack_data == selected_attack
		and _attack_generation == starting_generation
	)


func physics_tick(is_airborne: bool = false) -> void:
	if not is_attacking:
		return
	var ticking_attack := current_attack_data
	var ticking_generation := _attack_generation
	if ticking_attack.finishes_on_landing and not is_airborne:
		_finish_attack(true)
		return

	if current_phase == ACTIVE:
		_resolve_current_overlaps()
		if (
			not is_attacking
			or current_attack_data != ticking_attack
			or _attack_generation != ticking_generation
		):
			return

	if current_attack_data.finishes_on_landing:
		if attack_frame >= current_attack_data.landing_hold_frame:
			attack_frame = current_attack_data.landing_hold_frame
			_set_phase(ACTIVE)
			return
		attack_frame += 1
		if attack_frame >= current_attack_data.landing_hold_frame:
			attack_frame = current_attack_data.landing_hold_frame
			_set_phase(ACTIVE)
		else:
			_set_phase(_phase_for_frame(attack_frame))
		return

	attack_frame += 1
	if attack_frame >= current_attack_data.total_frames():
		_finish_attack(true)
		return

	_set_phase(_phase_for_frame(attack_frame))


func cancel_attack() -> void:
	if not is_attacking:
		return
	_finish_attack(false, Engine.is_in_physics_frame())


func resolve_hurtbox(target: HurtboxComponent) -> bool:
	if current_phase != ACTIVE or current_attack_data == null or target == null:
		return false

	var receiver_id := target.damage_receiver_id()
	if _already_hit_targets.has(receiver_id):
		return false
	_already_hit_targets[receiver_id] = true

	var resolved_attack := current_attack_data
	var knockback := Vector2(
		absf(resolved_attack.knockback.x) * attack_hit_direction
			* float(resolved_attack.knockback_direction_multiplier),
		resolved_attack.knockback.y
	)
	if not target.receive_attack(resolved_attack, knockback, source_actor):
		_already_hit_targets.erase(receiver_id)
		return false

	hit_landed.emit(target, resolved_attack, knockback)
	return true


func _phase_for_frame(frame: int) -> StringName:
	if frame < current_attack_data.startup_frames:
		return STARTUP
	if frame < current_attack_data.startup_frames + current_attack_data.active_frames:
		return ACTIVE
	return RECOVERY


func _set_phase(next_phase: StringName, defer_collision_update: bool = false) -> void:
	if next_phase == current_phase:
		return
	var previous_phase := current_phase
	current_phase = next_phase
	_set_hitbox_active(current_phase == ACTIVE, defer_collision_update)
	attack_phase_changed.emit(previous_phase, current_phase)


func _set_hitbox_active(active: bool, deferred: bool = false) -> void:
	is_hitbox_active = active
	if deferred:
		hitbox.set_deferred(&"monitoring", active)
		hitbox_shape.set_deferred(&"disabled", not active)
		return
	hitbox.monitoring = active
	hitbox_shape.disabled = not active


func _configure_hitbox_geometry() -> void:
	var geometry_data := current_attack_data if current_attack_data != null else attack_data
	if geometry_data == null or hitbox_shape == null:
		return
	var rectangle := hitbox_shape.shape as RectangleShape2D
	if rectangle == null:
		return

	rectangle.size = geometry_data.hitbox_rect.size
	var center := geometry_data.hitbox_rect.position + geometry_data.hitbox_rect.size * 0.5
	var hit_direction := attack_hit_direction if current_attack_data != null else attack_facing
	center.x = absf(center.x) * hit_direction
	hitbox_shape.position = center


func _resolve_current_overlaps() -> void:
	var world := hitbox.get_world_2d()
	if world == null:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hitbox_shape.shape
	query.transform = hitbox_shape.global_transform
	query.collision_mask = hitbox.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [hitbox.get_rid()]
	var resolving_generation := _attack_generation
	for result: Dictionary in world.direct_space_state.intersect_shape(query, 32):
		var hurtbox := result.get(&"collider") as HurtboxComponent
		if hurtbox != null:
			resolve_hurtbox(hurtbox)
			if _attack_generation != resolving_generation:
				return


func _on_hitbox_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox != null:
		resolve_hurtbox(hurtbox)


func _finish_attack(
	completed_naturally: bool,
	defer_collision_update: bool = false
) -> void:
	if _is_finishing:
		return
	_is_finishing = true
	_attack_generation += 1
	var completed_attack := current_attack_data
	var completed_facing := attack_facing
	var completed_phase := current_phase
	var should_reverse := (
		completed_naturally
		and completed_attack != null
		and completed_attack.reverse_facing_on_finish
	)

	# Finalize all logical state before lifecycle signals. Their listeners may
	# call cancel_attack(), but cannot observe or finish the old attack twice.
	is_attacking = false
	attack_frame = 0
	_already_hit_targets.clear()
	current_attack_data = null
	current_phase = INACTIVE
	_set_hitbox_active(false, defer_collision_update)
	if should_reverse:
		_desired_facing = -completed_facing
		attack_facing = _desired_facing
		attack_hit_direction = attack_facing
		_configure_hitbox_geometry()

	if completed_phase != INACTIVE:
		attack_phase_changed.emit(completed_phase, INACTIVE)
	if should_reverse:
		facing_changed.emit(attack_facing)
	attack_finished.emit(completed_attack, completed_naturally)
	_is_finishing = false
