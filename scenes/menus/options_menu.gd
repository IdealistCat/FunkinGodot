class_name OptionsMenu extends Node


static var from_pause: bool = false

@onready var options_label: AnimatedSprite2D = $top/options_label
var active: bool = true


func _ready() -> void:
	var music_player := GlobalAudio.get_player('MUSIC')
	
	Conductor.bpm = 125.0
	music_player.stream = load('res://resources/music/menus/options_theme.ogg')
	music_player.play()
	Conductor.reset()
	Conductor.target_audio = music_player
	
	Conductor.beat_hit.connect(_on_beat_hit)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if not event.is_pressed():
		return
	if event.is_action('ui_cancel'):
		GlobalAudio.get_player('MENU/CANCEL').play()
		if from_pause:
			from_pause = false
			SceneManager.switch_to('scenes/game/game.tscn')
		else:
			SceneManager.switch_to('scenes/menus/main_menu.tscn')


func _process(delta: float) -> void:
	options_label.scale = options_label.scale.lerp(Vector2(0.6, 0.6), delta * 4.5)


func _on_beat_hit(beat: int) -> void:
	options_label.scale += Vector2(0.03, 0.03)


func _exit_tree() -> void:
	var music_player := GlobalAudio.get_player('MUSIC')
	music_player.stream = load('res://resources/music/menus/main_theme.ogg')