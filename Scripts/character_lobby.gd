extends Node3D

# Preload your character scenes
var character_scenes = [
	preload("res://Scenes/barbarian.tscn"),
	preload("res://Scenes/knight_animated.tscn"),
	preload("res://Scenes/mage_animated.tscn"),
	preload("res://Scenes/rogue_animated.tscn")
]

var characters: Array[Node3D] = []
var current_index = 0
var radius = 5.0  # distance from center

@onready var char_name_label: Label = $UI/CharacterName
@onready var abilities_label: RichTextLabel = $UI/Abilities

func _ready():
	var total = character_scenes.size()
	if total == 0:
		push_error("No characters found!")
		return

	for i in total:
		var char_instance = character_scenes[i].instantiate() as Node3D
		add_child(char_instance)
		characters.append(char_instance)

		# Position in circle
		var angle = i * (TAU / total)  # TAU = 2π
		char_instance.transform.origin = Vector3(sin(angle) * radius, 0, cos(angle) * radius)
		char_instance.look_at(Vector3.ZERO, Vector3.UP)  # face the center

		# Only show the first character at start
		char_instance.visible = (i == 0)

	_update_ui()

# Cycle to next character
func next_character():
	if characters.size() == 0:
		return
	characters[current_index].visible = false
	current_index = (current_index + 1) % characters.size()
	characters[current_index].visible = true
	_update_ui()

# Cycle to previous character
func prev_character():
	if characters.size() == 0:
		return
	characters[current_index].visible = false
	current_index = (current_index - 1 + characters.size()) % characters.size()
	characters[current_index].visible = true
	_update_ui()

func _update_ui():
	if characters.size() == 0:
		return
	var current_char = characters[current_index]
	char_name_label.text = current_char.name
	abilities_label.clear()  # clear previous
	if current_char.has_meta("abilities"):
		abilities_label.bbcode_text = current_char.get_meta("abilities")
