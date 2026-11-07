extends Control
## City Warrior's own entry scene. No website/global game-center state.

signal stage_requested(path: String)

const STAGES: PackedStringArray = [
	"res://levels/prototype_alley/prototype_alley.tscn",
	"res://levels/industrial_yard/industrial_yard.tscn",
	"res://levels/woods/woods.tscn",
	"res://levels/headquarters/headquarters.tscn",
]
var pending_path: String = ""
@onready var buttons: VBoxContainer = $Center/Panel/Margin/Column/Stages
@onready var status: Label = $Center/Panel/Margin/Column/Status


func _ready() -> void:
	for index: int in range(buttons.get_child_count()):
		(buttons.get_child(index) as Button).pressed.connect(start_stage.bind(index))
	(buttons.get_child(0) as Button).grab_focus()
	set_process(false)


func start_stage(index: int) -> bool:
	if not pending_path.is_empty() or index < 0 or index >= STAGES.size():
		return false
	pending_path = STAGES[index]
	for button: Button in buttons.get_children():
		button.disabled = true
	status.text = "LOADING STAGE %d..." % (index + 1)
	# The released Web template is deliberately single-threaded. Show the
	# loading UI first, then load from its local PCK without worker threads.
	if OS.has_feature("web"):
		_load_on_main_thread.call_deferred()
		return true
	var error := ResourceLoader.load_threaded_request(pending_path, "PackedScene")
	if error != OK:
		_load_failed()
		return false
	set_process(true)
	return true


func _load_on_main_thread() -> void:
	await get_tree().process_frame
	var scene := ResourceLoader.load(pending_path, "PackedScene") as PackedScene
	if scene == null:
		_load_failed()
	else:
		_open_stage.call_deferred(scene)


func _process(_delta: float) -> void:
	match ResourceLoader.load_threaded_get_status(pending_path):
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			var scene := ResourceLoader.load_threaded_get(pending_path) as PackedScene
			if scene == null:
				_load_failed()
			else:
				_open_stage.call_deferred(scene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_load_failed()


func _open_stage(scene: PackedScene) -> void:
	stage_requested.emit(pending_path)
	if get_tree().current_scene != self:
		pending_path = ""
		return
	if get_tree().change_scene_to_packed(scene) != OK:
		_load_failed()


func _load_failed() -> void:
	set_process(false)
	pending_path = ""
	status.text = "COULD NOT LOAD. PLEASE TRY AGAIN."
	for button: Button in buttons.get_children():
		button.disabled = false
	(buttons.get_child(0) as Button).grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_4:
		get_viewport().set_input_as_handled()
		start_stage(key.keycode - KEY_1)
