class_name ClimbPlatform
extends Node2D
## A ledge that ladders lead to. The belt keeps one ground plane, so a ledge is
## not a second floor: it is a height the visuals rise by plus the span of
## stage x its surface covers. The node's origin is the ground-plane point
## under the middle of that span — the depth line an actor walks while up
## there — so a ladder's base and the ledge it reaches share one depth.

## Pixels the surface stands above the ground plane. Every ladder that leads
## here climbs exactly this far, so two ladders onto one ledge cannot disagree
## about where the top is.
@export_range(1.0, 400.0, 1.0) var height: float = 135.0
## Width of the surface an actor may walk, centred on this node: the ledge the
## art draws, inset by a body's half width so nobody stands over the corner.
@export_range(16.0, 1024.0, 1.0) var walkable_width: float = 330.0


func left_x() -> float:
	return global_position.x - walkable_width * 0.5


func right_x() -> float:
	return global_position.x + walkable_width * 0.5


func covers_x(x: float) -> bool:
	return x >= left_x() and x <= right_x()


## Clamps a stage x onto the surface. The ends stop an actor rather than drop
## one: a ledge in this prototype has no fall.
func hold_x(x: float) -> float:
	return clampf(x, left_x(), right_x())
