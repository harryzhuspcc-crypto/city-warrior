class_name MusicPlayer
extends AudioStreamPlayer
## A stage's background music: one looping track at a time, started with the
## level and optionally replaced on encounter activation.
##
## Godot imports audio with looping switched off, and a stage track that does
## not loop fails quietly - the level is silent from the moment the song runs
## out rather than broken at startup. So the loop flag is checked here instead
## of trusted, each time a track is assigned for playback.


func _ready() -> void:
	play_track(stream)


## Replace rather than layer gameplay themes; stage clear can stop this same
## player regardless of which encounter supplied the current track.
func play_track(track: AudioStream) -> void:
	assert(track != null, "MusicPlayer requires a track")
	stop()
	stream = track
	assert(loops(), "MusicPlayer needs a looping track, got %s" % stream.resource_path)
	play()


## Whether the current track repeats. Each imported stream type carries its own
## loop flag rather than a shared one, so the question goes to the resource by
## property name; a stream that has no such flag cannot loop.
func loops() -> bool:
	return stream != null and bool(stream.get(&"loop"))
