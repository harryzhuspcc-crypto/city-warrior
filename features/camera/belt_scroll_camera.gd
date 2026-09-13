class_name BeltScrollCamera
extends Camera2D
## Horizontal belt-scroller camera: follows the target along x inside the
## camera limits, never scrolls back toward the stage start, and can be locked
## in place for an encounter. Every move is capped at catch_up_speed, so an
## unlock re-centers with a pan rather than a snap, and the target is always
## kept inside the view so the screen-edge walls can never trap it off screen.
##
## The band is horizontal but not fixed: it rises with a target that reports
## how far it stands above the ground plane, so a climb onto a ledge keeps the
## whole sprite on screen. limit_top stops the rise at the top of the stage
## art; a target that never leaves the ground plane never moves the band.
##
## The band's size comes from the project's design viewport rather than from
## get_viewport_rect(): the game always renders that band, while a headless
## run reports a square dummy viewport, which would leave every framing rule
## here — and every test of one — measuring a screen that does not exist.
##
## The position is set in _physics_process. With position smoothing and
## physics interpolation off, Camera2D refreshes the viewport on every
## transform change, so either process callback frames the same x; switch to
## the physics callback if physics interpolation is ever enabled.

signal lock_changed(is_locked: bool)

@export var target: Node2D
## Belt scrollers do not let the player backtrack; the view only advances.
@export var scroll_forward_only: bool = true
## World y of the band this camera frames while its target stands on the
## ground plane.
@export var band_center_y: float = 108.0
## Fastest the view may travel, in pixels per second. Zero removes the cap.
@export_range(0.0, 2000.0, 1.0, "or_greater") var catch_up_speed: float = 180.0
## Smallest distance kept between the target and either view edge when a
## lock or a clamp would otherwise push it off screen.
@export_range(0.0, 192.0, 1.0) var target_margin: float = 16.0

var is_locked: bool = false
var _view_size: Vector2 = Vector2(384.0, 216.0)
var _lock_x: float = 0.0
var _scroll_x: float = 0.0
var _scroll_y: float = 0.0


func _ready() -> void:
	_view_size = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 384)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 216))
	)
	var start_x := global_position.x
	if target != null:
		start_x = target.global_position.x
	_scroll_x = _clamp_center_x(start_x)
	_scroll_y = _desired_center_y()
	_apply()


func _physics_process(delta: float) -> void:
	var step := INF
	# The cap only paces a target that is already on screen. A target outside
	# the view (a scripted teleport) is cut to at once: panning toward it
	# would sweep a screen-edge wall through it and bulldoze it along.
	if catch_up_speed > 0.0 and _is_target_in_view():
		step = catch_up_speed * delta
	_scroll_x = move_toward(_scroll_x, _desired_center_x(), step)
	_scroll_y = move_toward(_scroll_y, _desired_center_y(), step)
	_apply()


## Holds the view on center_x until unlock(): clamped to the limits, never
## behind the current scroll while scroll_forward_only, and never so far
## ahead that the target leaves the view. The view pans there at
## catch_up_speed.
func lock_at(center_x: float) -> void:
	_lock_x = center_x
	if is_locked:
		return
	is_locked = true
	lock_changed.emit(true)


func unlock() -> void:
	if not is_locked:
		return
	is_locked = false
	lock_changed.emit(false)


func center_x() -> float:
	return _scroll_x


func center_y() -> float:
	return _scroll_y


func view_left() -> float:
	return _scroll_x - half_view_width()


func view_right() -> float:
	return _scroll_x + half_view_width()


func half_view_width() -> float:
	return _view_size.x * 0.5 / zoom.x


func view_top() -> float:
	return _scroll_y - half_view_height()


func view_bottom() -> float:
	return _scroll_y + half_view_height()


func half_view_height() -> float:
	return _view_size.y * 0.5 / zoom.y


## Highest the band may ever reach: the view top resting on limit_top.
func highest_center_y() -> float:
	return _clamp_center_y(-INF)


func _desired_center_x() -> float:
	var desired := _scroll_x
	if is_locked:
		desired = _lock_x
	elif target != null:
		desired = target.global_position.x
	desired = _clamp_center_x(desired)
	if scroll_forward_only:
		desired = maxf(desired, _scroll_x)
	if target != null:
		desired = _keep_target_visible(desired)
	return _clamp_center_x(desired)


func _desired_center_y() -> float:
	return _clamp_center_y(band_center_y - _target_elevation())


## Optional on the target: an actor that can leave the ground plane reports
## how far above it stands. A target without it holds the band still.
func _target_elevation() -> float:
	if target == null or not target.has_method(&"visual_elevation"):
		return 0.0
	return float(target.call(&"visual_elevation"))


func _is_target_in_view() -> bool:
	if target == null:
		return true
	var target_x := target.global_position.x
	return target_x >= view_left() and target_x <= view_right()


func _keep_target_visible(center: float) -> float:
	var reach := maxf(half_view_width() - target_margin, 0.0)
	var target_x := target.global_position.x
	return clampf(center, target_x - reach, target_x + reach)


func _clamp_center_x(x: float) -> float:
	var half_width := half_view_width()
	var minimum := float(limit_left) + half_width
	var maximum := maxf(float(limit_right) - half_width, minimum)
	return clampf(x, minimum, maximum)


func _clamp_center_y(y: float) -> float:
	var half_height := half_view_height()
	var minimum := float(limit_top) + half_height
	var maximum := maxf(float(limit_bottom) - half_height, minimum)
	return clampf(y, minimum, maximum)


func _apply() -> void:
	global_position = Vector2(_scroll_x, _scroll_y)
