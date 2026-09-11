extends SceneTree

const ACTION_KEYS: Dictionary = {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"attack": [KEY_J],
	&"jump": [KEY_K],
	&"grab": [KEY_L],
	&"pause": [KEY_ESCAPE],
}


func _initialize() -> void:
	_configure_display()
	_configure_input_map()
	ProjectSettings.set_setting(
		&"application/run/main_scene",
		&"res://features/actors/player/player.tscn"
	)
	ProjectSettings.save()
	quit()


func _configure_display() -> void:
	ProjectSettings.set_setting(&"display/window/size/viewport_width", 384)
	ProjectSettings.set_setting(&"display/window/size/viewport_height", 216)
	ProjectSettings.set_setting(&"display/window/size/window_width_override", 1152)
	ProjectSettings.set_setting(&"display/window/size/window_height_override", 648)
	ProjectSettings.set_setting(&"display/window/stretch/mode", &"canvas_items")
	ProjectSettings.set_setting(&"display/window/stretch/aspect", &"expand")
	ProjectSettings.set_setting(&"display/window/stretch/scale_mode", &"integer")
	ProjectSettings.set_setting(&"physics/common/physics_ticks_per_second", 60)
	ProjectSettings.set_setting(
		&"rendering/textures/default_filters/use_nearest_mipmap_filter",
		false
	)
	ProjectSettings.set_setting(
		&"rendering/textures/canvas_textures/default_texture_filter",
		0
	)
	ProjectSettings.set_setting(&"rendering/2d/snap/snap_2d_transforms_to_pixel", true)
	ProjectSettings.set_setting(&"rendering/2d/snap/snap_2d_vertices_to_pixel", true)
	ProjectSettings.set_setting(&"rendering/environment/defaults/default_clear_color", Color("263245"))


func _configure_input_map() -> void:
	for action: StringName in ACTION_KEYS:
		var events: Array[InputEvent] = []
		var keys: Array = ACTION_KEYS[action]
		for keycode: Key in keys:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			events.append(key_event)

		ProjectSettings.set_setting(
			"input/%s" % action,
			{
				"deadzone": 0.2,
				"events": events,
			}
		)
