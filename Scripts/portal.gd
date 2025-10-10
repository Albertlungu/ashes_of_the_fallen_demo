extends Node3D
class_name Portal

@export var destination_scene: String = ""
@export var portal_id: String = ""  # Unique identifier for this portal
@export var cooldown_time: float = 1.0  # Prevent immediate re-teleportation

var players_on_cooldown: Dictionary = {}
var static_body: StaticBody3D = null

func _ready():
	# Find the StaticBody3D child recursively
	static_body = _find_static_body(self)
	
	if static_body:
		static_body.add_to_group("portal")
		# Store a reference to this Portal script on the StaticBody3D
		static_body.set_meta("portal_script", self)
		print("✓ Portal '%s' initialized - Destination: '%s'" % [portal_id, destination_scene])
	else:
		push_error("✗ Portal '%s': No StaticBody3D found in children!" % portal_id)

func _find_static_body(node: Node) -> StaticBody3D:
	if node is StaticBody3D:
		return node
	
	for child in node.get_children():
		var result = _find_static_body(child)
		if result:
			return result
	
	return null

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
