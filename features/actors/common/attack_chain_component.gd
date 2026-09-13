class_name AttackChainComponent
extends Node
## One actor's combo chains. A chain is an ordered list of attacks whose steps
## are earned rather than counted: only an attack that actually connects moves
## the chain on, so a whiffed punch puts the next press back on the first step.
##
## The component owns the step and the window that keeps it open, and nothing
## else. Combat still owns the attack itself and reports its hits and its
## finishes here, so an actor without a chain is unaffected by any of this.

## How long the chain stays open after a connected hit, in physics frames. A
## press later than this starts over.
@export_range(0, 120, 1) var open_frames: int = 24

## The step the next press will use. Zero is the opener.
var index: int = 0

var _chain: Array[AttackData] = []
var _pending_attack: AttackData
var _hit_confirmed: bool = false
var _open_frames_remaining: int = 0


func configure(stats: FighterStats) -> void:
	open_frames = stats.chain_window_frames


## The attack the given chain should start now. Asking for a chain other than
## the open one starts over, which is what breaks a combo when punches and
## kicks are mixed.
func next_attack(chain: Array[AttackData]) -> AttackData:
	if chain.is_empty():
		return null
	if chain != _chain:
		reset()
		_chain = chain
	if index >= chain.size():
		index = 0
	_hit_confirmed = false
	_pending_attack = chain[index]
	return _pending_attack


## A hit landed. Only the chain's own step counts, so an elbow or a head
## attack landed mid-combo cannot earn the next punch.
func confirm_hit(attack: AttackData) -> void:
	if attack != null and attack == _pending_attack:
		_hit_confirmed = true


## An attack ended. The chain advances only when its own step ran to the end
## and connected; a whiff, an interruption, or any other move sends the next
## press back to the opener.
func finish_attack(attack: AttackData, completed_naturally: bool) -> void:
	var advances := (
		attack != null
		and attack == _pending_attack
		and completed_naturally
		and _hit_confirmed
	)
	_pending_attack = null
	_hit_confirmed = false
	if not advances:
		reset()
		return
	index += 1
	if index >= _chain.size():
		# The finisher connected: the chain is spent and starts over.
		reset()
		return
	_open_frames_remaining = open_frames


## Counts the open window down. An attack in progress holds it: the window is
## the pause between the steps, not the time the steps take.
func physics_tick() -> void:
	if _pending_attack != null or _open_frames_remaining <= 0:
		return
	_open_frames_remaining -= 1
	if _open_frames_remaining <= 0:
		reset()


## True while a started chain can still be continued.
func is_open() -> bool:
	return index > 0 and (_pending_attack != null or _open_frames_remaining > 0)


func reset() -> void:
	index = 0
	_chain = []
	_pending_attack = null
	_hit_confirmed = false
	_open_frames_remaining = 0
