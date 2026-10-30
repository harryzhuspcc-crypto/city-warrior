class_name Hud
extends CanvasLayer
## Stateless projection of gameplay values. The level feeds it through
## methods; it never looks up actors itself.

@export var health_bar: ProgressBar
@export var message_label: Label
@export var stage_label: Label


func _ready() -> void:
	assert(health_bar != null, "Hud requires a health bar")
	assert(message_label != null, "Hud requires a message label")
	message_label.hide()


func set_health(current_health: int, maximum_health: int) -> void:
	health_bar.max_value = maxi(maximum_health, 1)
	health_bar.value = clampi(current_health, 0, maximum_health)


func show_message(text: String) -> void:
	message_label.text = text
	message_label.show()


func hide_message() -> void:
	message_label.hide()


func set_stage_name(text: String) -> void:
	if stage_label != null:
		stage_label.text = text
