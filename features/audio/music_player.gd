class_name MusicPlayer
extends AudioStreamPlayer
## A stage's background music: one track, looping, started with the level.
##
## Godot imports audio with looping switched off, and a stage track that does
## not loop fails quietly - the level is silent from the moment the song runs
## out rather than broken at startup. So the loop flag is checked here instead
## of trusted, at the one moment a wrong track is still cheap to notice.


func _ready() -> void:
	assert(stream != null, "MusicPlayer requires a track")
	assert(loops(), "MusicPlayer needs a looping track, got %s" % stream.resource_path)
	play()


## Whether the current track repeats. Each imported stream type carries its own
## loop flag rather than a shared one, so the question goes to the resource by
## property name; a stream that has no such flag cannot loop.
func loops() -> bool:
	return stream != null and bool(stream.get(&"loop"))
