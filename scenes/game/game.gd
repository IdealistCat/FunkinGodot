class_name Game extends Node2D


static var song: StringName = &'philly_nice'
static var chart: Chart = null
static var scroll_speed: float = 3.3

## Each note type is stored here for use in any note field.
static var note_types: Dictionary = {}
static var instance: Game = null

@onready var accuracy_calculator: AccuracyCalculator = %accuracy_calculator
@onready var ratings_calculator: RatingsCalculator = %ratings_calculator
@onready var tracks: Tracks = $tracks
@onready var camera: Camera2D = $camera
@onready var hud: Node2D = $hud_layer/hud
@onready var health_bar: HealthBar = %health_bar
@onready var rating_container: Node2D = %rating_container
@onready var rating_sprite: Sprite2D = rating_container.get_node('rating')
var rating_tween: Tween
@onready var combo_node: Node2D = rating_container.get_node('combo')
@onready var song_label: Label = hud.get_node('song_label')

var target_camera_position: Vector2 = Vector2.ZERO
var target_camera_zoom: Vector2 = Vector2(1.05, 1.05)

@onready var _stage: Node2D = $stage
@onready var _characters: Node2D = $characters

@onready var _player_field: NoteField = $hud_layer/hud/note_fields/player
@onready var _opponent_field: NoteField = $hud_layer/hud/note_fields/opponent

var assets: SongAssets
var metadata: SongMetadata

var player: Character
var opponent: Character
var spectator: Character
var stage: Stage

var health: float = 50.0
var score: int = 0
var misses: int = 0
var combo: int = 0
var accuracy: float = 0.0:
	get:
		if is_instance_valid(accuracy_calculator):
			return accuracy_calculator.get_accuracy()
		
		return 0.0

@onready var skin: HUDSkin = load('res://resources/hud_skins/default.tres')

@onready var _default_note := load('res://scenes/game/notes/note.tscn')
var _event: int = 0

signal event_hit(event: EventData)


func _ready() -> void:
	instance = self
	GlobalAudio.get_player('MUSIC').stop()
	
	tracks.load_tracks(song)
	
	if not chart:
		var funkin_chart := FunkinChart.new()
		funkin_chart.json = JSON.parse_string(\
				FileAccess.get_file_as_string('res://songs/%s/charts/hard.json' % song))
		chart = funkin_chart.parse()
	
	chart.notes.sort_custom(func(a, b):
		return a.time < b.time)
	chart.events.sort_custom(func(a, b):
		return a.time < b.time)
	
	note_types.clear()
	note_types['default'] = _default_note.instantiate()
	
	if ResourceLoader.exists('res://songs/%s/meta.tres' % song):
		metadata = load('res://songs/%s/meta.tres' % song)
	
	if ResourceLoader.exists('res://songs/%s/assets.tres' % song):
		# Load SongAssets tres.
		assets = load('res://songs/%s/assets.tres' % song)
		
		# Instantiate the PackedScene(s) and add them to the scene.
		player = assets.player.instantiate()
		opponent = assets.opponent.instantiate()
		spectator = assets.spectator.instantiate()
		_characters.add_child(spectator)
		_characters.add_child(player)
		_characters.add_child(opponent)
		
		stage = assets.stage.instantiate()
		_stage.add_child(stage)
		target_camera_zoom = Vector2(stage.default_zoom, stage.default_zoom)
		camera.zoom = target_camera_zoom
		
		# Position and scale the characters.
		var player_point: Node2D = stage.get_node('player')
		var opponent_point: Node2D = stage.get_node('opponent')
		var spectator_point: Node2D = stage.get_node('spectator')
		player.global_position = player_point.global_position
		player.scale *= Vector2(-1.0, 1.0) * player_point.scale
		player._is_player = true
		opponent.global_position = opponent_point.global_position
		opponent.scale *= opponent_point.scale
		spectator.global_position = spectator_point.global_position
		spectator.scale *= spectator_point.scale
		
		# Set the NoteField characters.
		_player_field._default_character = player
		_opponent_field._default_character = opponent
	
	health_bar._ready()
	
	_player_field.note_miss.connect(_on_note_miss)
	_player_field.note_hit.connect(_on_note_hit)
	
	song_label.text = '%s • [%s]' % [metadata.display_name, 'HARD'.to_upper()]
	
	tracks.play()
	Conductor.reset()
	Conductor.on_beat_hit.connect(_on_beat_hit)
	Conductor.on_measure_hit.connect(_on_measure_hit)
	
	if chart.events.is_empty():
		return
	
	while (not chart.events.is_empty()) and _event < chart.events.size() \
			and chart.events[_event].time <= 0.0:
		_on_event_hit(chart.events[_event])
		_event += 1


func _process(delta: float) -> void:
	camera.position = lerp(camera.position, target_camera_position, delta * 3.0)
	camera.zoom = lerp(camera.zoom, target_camera_zoom, delta * 3.0)
	hud.scale = lerp(hud.scale, Vector2.ONE, delta * 3.0)
	
	if not is_instance_valid(chart):
		return
	
	while _event < chart.events.size() and \
			Conductor.time >= chart.events[_event].time:
		var event := chart.events[_event]
		
		_on_event_hit(event)
		event_hit.emit(event)
		_event += 1


func _on_beat_hit(beat: int) -> void:
	player.dance()
	opponent.dance()
	spectator.dance()


func _on_measure_hit(measure: int) -> void:
	camera.zoom += Vector2(0.015, 0.015)
	hud.scale += Vector2(0.03, 0.03)


func _on_event_hit(event: EventData) -> void:
	match event.name.to_lower():
		&'bpm change':
			Conductor.bpm = event.data[0]
		&'camera pan':
			var character: Character = player if event.data[0] == 1 else opponent
			target_camera_position = character._camera_offset.global_position
			
			if event.time <= 0.0:
				camera.position = target_camera_position
		_:
			pass


func _on_note_miss(note: Note) -> void:
	rating_container.visible = false
	
	accuracy_calculator.record_hit(Conductor.default_input_zone)
	health = clampf(health - 2.0, 0.0, 100.0)
	misses += 1
	score -= 10
	combo = 0
	health_bar.update_score_label()


func _on_note_hit(note: Note) -> void:
	var difference: float = Conductor.time - note.data.time
	accuracy_calculator.record_hit(absf(difference))
	
	if is_instance_valid(rating_tween) and rating_tween.is_running():
		rating_tween.kill()
	
	var rating := ratings_calculator.get_rating(absf(difference * 1000.0))
	match rating.name:
		&'marvelous':
			rating_sprite.texture = skin.marvelous
		&'sick':
			rating_sprite.texture = skin.sick
		&'good':
			rating_sprite.texture = skin.good
		&'bad':
			rating_sprite.texture = skin.bad
		&'shit':
			rating_sprite.texture = skin.shit
	
	rating_container.visible = true
	rating_container.modulate.a = 1.0
	rating_container.scale = Vector2(1.1, 1.1)
	rating_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rating_tween.tween_property(rating_container, 'scale', Vector2.ONE, 0.15)
	rating_tween.tween_property(rating_container, 'modulate:a', 0.0, 0.15).set_delay(0.2)
	
	health = clampf(health + rating.health, 0.0, 100.0)
	score += rating.score
	combo += 1
	
	var combo_str := str(combo).pad_zeros(4)
	
	for i in combo_node.get_child_count():
		var number: Sprite2D = combo_node.get_child(i)
		
		if i <= combo_str.length() - 1:
			number.frame = int(combo_str[i])
			number.visible = true
		else:
			number.frame = 0
			number.visible = false
	
	health_bar.update_score_label()