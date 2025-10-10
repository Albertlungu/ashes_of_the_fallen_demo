extends StaticBody3D
class_name Portal

@export var destination_scene: String = ""
@export var portal_id: String = ""  # Unique identifier for this portal
@export var cooldown_time: float = 2.0  # Prevent immediate re-teleportation

var players_on_cooldown: Dictionary = {}

func _ready():
	add_to_group("portal")

func _process(delta):
	# Clean up expired cooldowns
	var to_remove = []
	for player in players_on_cooldown:
		players_on_cooldown[player] -= delta
		if players_on_cooldown[player] <= 0:
			to_remove.append(player)
	
	for player in to_remove:
		players_on_cooldown.erase(player)

func can_teleport(player) -> bool:
	return not players_on_cooldown.has(player)

func start_cooldown(player):
	players_on_cooldown[player] = cooldown_time
