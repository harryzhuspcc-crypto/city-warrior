extends SceneTree
## The arcade soundtrack and the prototype alley's stage track.
##
## Headless Godot runs the Dummy audio driver, so nothing here can hear the
## music. What it can check is everything that decides whether music will be
## heard: that the tracks import, that the ones playing under gameplay repeat,
## and that the stage asks for its own theme.

const PROTOTYPE_ALLEY_SCENE: PackedScene = preload(
	"res://levels/prototype_alley/prototype_alley.tscn"
)
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
## How close to the end of the track the loop check starts. Far enough back
## that the position is unmistakably near the end rather than near the start.
const SECONDS_BEFORE_THE_END: float = 0.5
## A ceiling on the wait for the track to come round, not an expected cost:
## the seek is half a second from the end.
const WRAP_FRAME_BUDGET: int = 600
const BGM_DIRECTORY: String = "res://assets/audio/bgm"
const STAGE_ONE_TRACK: String = "res://assets/audio/bgm/02_slums.mp3"
const BOSS_TRACK: String = "res://assets/audio/bgm/03_abobo_entrance.mp3"
const STAGE_CLEAR_TRACK: String = "res://assets/audio/bgm/04_mission_complete.mp3"
## The album, and which tracks play for an open-ended stretch. A track that
## underscores gameplay has to repeat; a cue of fixed length must not, or it
## restarts over whatever follows it.
const SOUNDTRACK: Array = [
	["01_opening_theme.mp3", true],
	["02_slums.mp3", true],
	["03_abobo_entrance.mp3", true],
	["04_mission_complete.mp3", false],
	["05_departure.mp3", false],
	["06_industrial_area.mp3", true],
	["07_woods.mp3", true],
	["08_enemy_headquarters.mp3", true],
	["09_ending_theme.mp3", false],
	["10_after_the_battle.mp3", false],
	["11_unused_1.mp3", false],
	["12_unused_2.mp3", false],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for slice: Callable in [
		_test_the_soundtrack_is_installed,
		_test_gameplay_tracks_repeat_and_cues_do_not,
		_test_loops_tells_a_loop_from_a_cue,
		_test_the_stage_plays_its_own_theme,
		_test_stage_clear_replaces_the_theme,
		_test_the_stage_track_comes_back_round,
		_test_the_boss_track_comes_back_round,
	]:
		var error: String = await slice.call()
		if not error.is_empty():
			_fail(error)
			return
	# A level carries music, and the audio server needs a moment with it.
	await AudioSettle.settle(self)
	print("PASS")
	quit()


## The asset half: every track of the album is in the tree and imports as
## audio Godot can play.
func _test_the_soundtrack_is_installed() -> String:
	for entry: Array in SOUNDTRACK:
		var path: String = "%s/%s" % [BGM_DIRECTORY, entry[0]]
		if not ResourceLoader.exists(path):
			return "The soundtrack is missing %s" % path
		var stream := load(path) as AudioStream
		if stream == null:
			return "%s did not import as an AudioStream" % path
		if stream.get_length() <= 0.0:
			return "%s imported with no audio in it" % path
	return ""


func _test_gameplay_tracks_repeat_and_cues_do_not() -> String:
	for entry: Array in SOUNDTRACK:
		var path: String = "%s/%s" % [BGM_DIRECTORY, entry[0]]
		var stream := load(path) as AudioStream
		var expected: bool = entry[1]
		var actual: bool = bool(stream.get(&"loop"))
		if actual != expected:
			return "%s must%s loop, and does%s" % [
				entry[0],
				"" if expected else " not",
				"" if actual else " not",
			]
	return ""


## The one question the player cannot answer by looking: a music node that has
## been handed a track that stops.
func _test_loops_tells_a_loop_from_a_cue() -> String:
	var player := MusicPlayer.new()
	if player.loops():
		return "A music player with no track cannot claim to loop"
	player.stream = load(STAGE_ONE_TRACK) as AudioStream
	if not player.loops():
		return "The stage track loops, and the music player must say so"
	player.stream = load("%s/04_mission_complete.mp3" % BGM_DIRECTORY) as AudioStream
	if player.loops():
		return "A cue does not loop, and the music player must say so"
	player.free()
	return ""


func _test_the_stage_plays_its_own_theme() -> String:
	var alley := PROTOTYPE_ALLEY_SCENE.instantiate() as PrototypeAlley
	root.add_child(alley)
	await physics_frame
	# Let the track get properly under way before asking anything of it, so
	# the check is honest: still playing a moment later, not merely playing on
	# the frame it was told to.
	await AudioSettle.settle(self)
	var error := _check_stage_music(alley)
	await AudioSettle.free_level(self, alley)
	return error


## The fixed-length mission-complete cue replaces, rather than overlaps, the
## looping street theme when the level reports its clear.
func _test_stage_clear_replaces_the_theme() -> String:
	var alley := PROTOTYPE_ALLEY_SCENE.instantiate() as PrototypeAlley
	root.add_child(alley)
	await physics_frame
	await AudioSettle.settle(self)
	if not alley.music.playing:
		await AudioSettle.free_level(self, alley)
		return "Stage-clear setup requires the street theme to be playing"
	alley._finish_stage()
	await process_frame
	var error := ""
	if alley.music.playing:
		error = "The street theme must stop when the stage clears"
	elif not alley.stage_clear_music.playing:
		error = "Stage clear did not start the mission-complete cue"
	elif alley.stage_clear_music.stream.resource_path != STAGE_CLEAR_TRACK:
		error = "Stage clear plays %s, expected %s" % [
			alley.stage_clear_music.stream.resource_path,
			STAGE_CLEAR_TRACK,
		]
	elif bool(alley.stage_clear_music.stream.get(&"loop")):
		error = "The mission-complete cue must play once, not loop"
	elif alley.stage_clear_music.bus != &"Music":
		error = "The mission-complete cue must route through the Music bus"
	await AudioSettle.free_level(self, alley)
	return error


## The loop flag read back as behaviour: a track played to its end either
## starts again or stops, and only one of those is a stage track.
func _test_the_stage_track_comes_back_round() -> String:
	return await _test_track_comes_back_round(false)


func _test_the_boss_track_comes_back_round() -> String:
	return await _test_track_comes_back_round(true)


func _test_track_comes_back_round(activate_boss: bool) -> String:
	var alley := PROTOTYPE_ALLEY_SCENE.instantiate() as PrototypeAlley
	root.add_child(alley)
	await physics_frame
	await AudioSettle.settle(self)
	if activate_boss:
		for encounter: EncounterController in alley.encounter_controllers():
			encounter.enabled = encounter == alley.boss_encounter
		alley.player.set_physics_process(false)
		alley.player.global_position.x = alley.boss_encounter.lock_x
		await physics_frame
		await AudioSettle.settle(self)
		if alley.music.stream.resource_path != BOSS_TRACK:
			await AudioSettle.free_level(self, alley)
			return "Boss activation must replace the stage track before the loop check"
		for actor: Node in alley.actors.get_children():
			if actor is EnemyFighter:
				actor.set_physics_process(false)
	var music := alley.music
	var length: float = music.stream.get_length()
	music.seek(length - SECONDS_BEFORE_THE_END)
	var error := ""
	var wrapped := false
	for _frame: int in range(WRAP_FRAME_BUDGET):
		await process_frame
		if not music.playing:
			error = "The stage track stopped at its end instead of starting again"
			break
		if music.get_playback_position() < SECONDS_BEFORE_THE_END:
			wrapped = true
			break
	if error.is_empty() and not wrapped:
		error = "The stage track never came back round from %.1fs" % length
	await AudioSettle.free_level(self, alley)
	return error


func _check_stage_music(alley: PrototypeAlley) -> String:
	var music := alley.music
	if music == null:
		return "The prototype alley must own a MusicPlayer"
	if music.stream == null:
		return "The prototype alley's music player has no track"
	if music.stream.resource_path != STAGE_ONE_TRACK:
		return "Stage 1 plays %s, expected %s" % [music.stream.resource_path, STAGE_ONE_TRACK]
	if not music.loops():
		return "Stage 1's track must loop for as long as the stage runs"
	if not music.playing:
		return "Stage 1 must start its track with the level"
	if alley.boss_music == null or alley.boss_music.resource_path != BOSS_TRACK:
		return "The prototype alley must configure Abobo entrance as boss BGM"
	if alley.boss_encounter == null or alley.boss_encounter.state != EncounterController.IDLE:
		return "Boss must start idle while the stage theme plays"
	if alley.stage_clear_music == null or alley.stage_clear_music.stream == null:
		return "The prototype alley must own a stage-clear music player"
	if alley.stage_clear_music.playing:
		return "Stage clear music must not autoplay"
	if alley.stage_clear_music.stream.resource_path != STAGE_CLEAR_TRACK:
		return "The stage-clear player must use the mission-complete cue"
	if alley.music.bus != &"Music" or alley.stage_clear_music.bus != &"Music":
		return "Stage music and clear music must route through the Music bus"
	return ""


func _fail(message: String) -> void:
	push_error("MUSIC_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
