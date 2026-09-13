extends RefCounted
## Shared teardown for suites that stand up a level, because a level has music.
##
## The audio server starts and releases playbacks on its own mixing pass rather
## than on a frame, and a suite can outrun it in both directions. Tear a level
## down in the same instant it starts playing and the stop overtakes a start
## the server has not finished; quit in the same breath as the last `free()`
## and the server is still holding the stream. Godot reports either at exit as
## a leak - a red suite that says nothing about the code under test.
##
## The waits are wall-clock rather than frame counts on purpose: the mixing
## pass is a real-time interval, so a frame count passes or fails by how fast
## the machine happens to be running.

## An order of magnitude over the mixing interval, and paid a few times a suite.
const SETTLE_SECONDS: float = 0.2


## Waits for the audio server to catch up with what it has been told.
static func settle(tree: SceneTree) -> void:
	await tree.create_timer(SETTLE_SECONDS).timeout


## Puts a level away in the order the audio server needs: let what it started
## get under way, then stop it, then let the server let go.
static func free_level(tree: SceneTree, level: Node) -> void:
	await settle(tree)
	level.get_parent().remove_child(level)
	level.free()
	await settle(tree)
