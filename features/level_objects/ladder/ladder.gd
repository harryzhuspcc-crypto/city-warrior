class_name Ladder
extends Area2D
## A climbable ladder. The node's origin is the base where feet stand and the
## child shape is the grab zone (16 px wide, from 8 px above the base to
## 12 px below it). Ladders are passive areas on collision layer 9 that the
## player's ClimbComponent queries; enemies ignore them.

## Distance from the base to the top rung, in pixels. A ladder that leads to a
## ledge ignores this and climbs to the ledge's own height instead, so the two
## can never disagree about where the top is; read the top through top_height().
@export_range(1.0, 400.0, 1.0) var climb_height: float = 96.0
## Optional. The ledge this ladder reaches: the top step leaves the rungs for
## its surface. Without one the ladder is a climb-only spot that clamps at
## climb_height.
@export var platform: ClimbPlatform
## Levels close their ladders during an encounter so the fight cannot be
## sat out on an invulnerable rung.
@export var is_climbable: bool = true


func _ready() -> void:
	add_to_group(&"ladders")


func set_climbable(climbable: bool) -> void:
	is_climbable = climbable


## How far this ladder climbs: the ledge's height when it leads to one.
func top_height() -> float:
	if platform != null:
		return platform.height
	return climb_height
