@tool
class_name Alphabet extends Node2D


@export var no_casing: bool = true
@export var frames: SpriteFrames = preload('res://resources/fonts/alphabet/alphabet.res')
@export var suffix: String = ' bold'

@export_multiline var text: String = '':
	set(value):
		text = value
		_create_characters()

@export var centered: bool = false:
	set(value):
		centered = value
		_create_characters()

@export_enum('Left', 'Center', 'Right') var horizontal_alignment: String = 'Left':
	set(value):
		horizontal_alignment = value
		_create_characters()

const UNCHANGED_CHARACTERS: StringName = &'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
const MAGIC_OFFSET: float = 20.0

var bounding_box: Vector2i = Vector2i.ZERO

signal updated


func _ready() -> void:
	_create_characters()


func _create_characters() -> void:
	for child in get_children():
		child.queue_free()
	
	bounding_box = Vector2i.ZERO
	
	var x_position: float = 0.0
	var y_position: float = 0.0
	var lines: Array[Dictionary] = []
	var line_index: int = 0
	
	for character in text:
		if lines.size() - 1 < line_index:
			lines.push_back({
				'size': Vector2i.ZERO,
				'characters': [],
			})
		
		if character == ' ':
			x_position += 50.0
			continue
		if character == '\n':
			x_position = 0.0
			y_position += 70.0
			line_index += 1
			continue
		
		var character_data := _create_character(x_position, y_position, character)
		add_child(character_data[0])
		
		x_position += character_data[1].x
		
		if x_position > bounding_box.x:
			bounding_box.x = x_position
		if y_position + character_data[1].y > bounding_box.y:
			bounding_box.y = y_position + character_data[1].y
		
		var line_dict := lines[line_index]
		line_dict.get('characters', []).push_back(character_data[0])
		
		var size: Vector2i = line_dict.get('size', Vector2i.ZERO)
		
		# x should basically be always true lol
		if x_position > size.x:
			size.x = x_position
		if y_position + character_data[1].y > size.y:
			size.y = y_position + character_data[1].y
		
		line_dict['size'] = size
	
	if centered:
		for child in get_children():
			child.position -= bounding_box * 0.5
	
	match horizontal_alignment:
		'Left':
			pass
		'Center':
			for line in lines:
				var characters: Array = line.get('characters', [])
				var size: Vector2i = line.get('size', Vector2i.ZERO)
				
				if characters.is_empty() or size <= Vector2i.ZERO:
					continue
				
				for character in characters:
					character.position.x += (bounding_box.x - size.x) / 2.0
		'Right':
			for line in lines:
				var characters: Array = line.get('characters', [])
				var size: Vector2i = line.get('size', Vector2i.ZERO)
				
				if characters.is_empty() or size <= Vector2i.ZERO:
					continue
				
				for character in characters:
					character.position.x -= size.x - bounding_box.x
	
	updated.emit()


func _create_character(x: float, y: float, character: String) -> Array:
	var animation_data := _character_to_animation(character)
	
	var node: AnimatedSprite2D = AnimatedSprite2D.new()
	node.centered = false
	node.sprite_frames = frames
	node.position = Vector2(x, y)
	node.animation = animation_data.name + suffix
	node.offset = animation_data.offset
	node.play()
	
	var size: Vector2 = Vector2.ZERO
	
	if node.sprite_frames.has_animation(node.animation):
		var frame_texture := node.sprite_frames.get_frame_texture(node.animation, 0)
		size = frame_texture.get_size()
	
	node.offset.y -= (size.y - 65.0) / 2.0
	return [node, size]


func _character_to_animation(character: String) -> AlphabetAnimationData:
	var data := AlphabetAnimationData.new()
	
	if UNCHANGED_CHARACTERS.contains(character.to_upper()):
		data.name = character.to_lower() if no_casing else character
		data.offset = Vector2.ZERO
		return data
	
	# all used by bold.xml, not sure about default.xml support rn :3
	match character:
		'\'', '‘', '’':
			data.name = 'apostrophe'
			data.offset.y = -MAGIC_OFFSET
		'\\':
			data.name = 'back slash'
		',':
			data.name = 'comma'
			data.offset.y = MAGIC_OFFSET
		'“', '"':
			data.name = 'start quote'
			data.offset.y = -MAGIC_OFFSET
		'”':
			data.name = 'end quote'
			data.offset.y = -MAGIC_OFFSET
		'!':
			data.name = 'exclamation'
		'/':
			data.name = 'forward slash'
		'♥', '❤️':
			data.name = 'heart'
		'×':
			data.name = 'multiply x'
		'.':
			data.name = 'period'
			data.offset.y = MAGIC_OFFSET
		'?':
			data.name = 'question mark'
		'←':
			data.name = 'left arrow'
		'↓':
			data.name = 'down arrow'
		'↑':
			data.name = 'up arrow'
		'→':
			data.name = 'right arrow'
		':':
			data.name = character
		'_':
			data.name = '-'
			data.offset.y = MAGIC_OFFSET * 1.5
		'ñ':
			data.name = character
			data.offset.y = -MAGIC_OFFSET * 0.6
		_:
			data.name = character
	
	return data


class AlphabetAnimationData extends Object:
	var name: StringName
	var offset: Vector2
