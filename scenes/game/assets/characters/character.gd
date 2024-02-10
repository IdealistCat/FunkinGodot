class_name Character extends Node2D


@export var icon: Icon = Icon.new()
@export var starts_as_player: bool = false

@export var dance_steps: Array[StringName] = [&'idle']
@export_range(0.0, 1024.0, 0.01) var sing_steps: float = 4.0
var _dance_step: int = 0

@onready var _camera_offset: Node2D = $camera_offset
@onready var _animation_player: AnimationPlayer = $animation_player

var _is_player: bool = false
var _animation: StringName = &''
var _singing: bool = false
var _sing_timer: float = 0.0


func _ready() -> void:
	dance(true)


func play_anim(anim: StringName, force: bool = false) -> void:
	if not _animation_player.has_animation(anim):
		return
	
	_animation = anim
	_singing = _animation.begins_with('sing_')
	
	if _animation_player.current_animation == anim and force:
		_animation_player.seek(0.0, true)
		return
	
	_animation_player.play(anim)


func sing(note: Note, force: bool = false) -> void:
	_sing_timer = 0.0
	
	const swapped: PackedStringArray = [&'left', &'right']
	var direction: StringName = Note.directions[absi(note.data.direction) % 
			Note.directions.size()]
	
	if _is_player != starts_as_player and swapped.has(direction):
		direction = swapped[wrapi(swapped.find(direction) + 1, 0, swapped.size())]
	
	play_anim('sing_%s' % direction.to_lower(), force)


func sing_miss(note: Note, force: bool = false) -> void:
	_sing_timer = 0.0
	
	const swapped: PackedStringArray = [&'left', &'right']
	var direction: StringName = Note.directions[absi(note.data.direction) % 
			Note.directions.size()]
	
	if _is_player != starts_as_player and swapped.has(direction):
		direction = swapped[wrapi(swapped.find(direction) + 1, 0, swapped.size())]
	
	play_anim('sing_%s_miss' % direction.to_lower(), force)


func dance(force: bool = false) -> void:
	if _singing and not force:
		return
	if dance_steps.is_empty():
		return
	if dance_steps.size() > 1:
		_dance_step = wrapi(_dance_step + 1, 0, dance_steps.size())
		play_anim(dance_steps[_dance_step], force)
		return
	
	play_anim(dance_steps[0], force)


func _process(delta: float) -> void:
	if _singing:
		_sing_timer += delta * Conductor.beat_delta
		
		if _sing_timer * 4.0 >= sing_steps or sing_steps <= 0.0:
			dance(true)