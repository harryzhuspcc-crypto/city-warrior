class_name CombatComponent
extends Node

signal attack_started
signal attack_phase_changed(previous_phase: StringName, current_phase: StringName)
signal hit_landed(target: HurtboxComponent, attack_data: AttackData, knockback: Vector2)
signal attack_finished

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
var current_attack_data: AttackData
var current_phase: StringName = INACTIVE
var is_attacking: bool = false
var is_hitbox_active: bool = false

var _desired_facing: float = 1.0
var _already_hit_targets: Dictionary[int, bool] = {}


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
	if is_zero_approx(horizontal_direction):
		return
	_desired_facing = signf(horizontal_direction)
	if not is_attacking:
		attack_facing = _desired_facing
		_configure_hitbox_geometry()


func try_start_attack(requested_attack_data: AttackData = null) -> bool:
	var selected_attack := requested_attack_data if requested_attack_data != null else attack_data
	if is_attacking or selected_attack == null:
		return false

	is_attacking = true
	current_attack_data = selected_attack
	attack_frame = 0
	attack_facing = _desired_facing
	_already_hit_targets.clear()
	_configure_hitbox_geometry()
	_set_phase(_phase_for_frame(attack_frame))
	attack_started.emit()
	return true


func physics_tick() -> void:
	if not is_attacking:
		return

	if current_phase == ACTIVE:
		_resolve_current_overlaps()

	attack_frame += 1
	if attack_frame >= current_attack_data.total_frames():
		_finish_attack()
		return

	_set_phase(_phase_for_frame(attack_frame))


func cancel_attack() -> void:
	if not is_attacking:
		return
	_finish_attack(Engine.is_in_physics_frame())


func resolve_hurtbox(target: HurtboxComponent) -> bool:
	if current_phase != ACTIVE or target == null:
		return false

	var receiver_id := target.damage_receiver_id()
	if _already_hit_targets.has(receiver_id):
		return false
	_already_hit_targets[receiver_id] = true

	var knockback := Vector2(
		absf(current_attack_data.knockback.x) * attack_facing,
		current_attack_data.knockback.y
	)
	if not target.receive_attack(current_attack_data, knockback, source_actor):
		_already_hit_targets.erase(receiver_id)
		return false

	hit_landed.emit(target, current_attack_data, knockback)
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
	center.x = absf(center.x) * attack_facing
	hitbox_shape.position = center


func _resolve_current_overlaps() -> void:
	for area: Area2D in hitbox.get_overlapping_areas():
		var hurtbox := area as HurtboxComponent
		if hurtbox != null:
			resolve_hurtbox(hurtbox)


func _on_hitbox_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox != null:
		resolve_hurtbox(hurtbox)


func _finish_attack(defer_collision_update: bool = false) -> void:
	_set_phase(INACTIVE, defer_collision_update)
	is_attacking = false
	attack_frame = 0
	_already_hit_targets.clear()
	current_attack_data = null
	attack_finished.emit()
