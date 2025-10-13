extends Node3D

@onready var sun: DirectionalLight3D = $Sun
@onready var moon: DirectionalLight3D = $Moon

@export var boss_scene: PackedScene

const DAY_LENGTH: float = 600.0  # 10 minutes full cycle
var time_passed: float = 0.0


func _ready() -> void:
	print("[Main] _ready called, spawning boss")
	_spawn_boss()


func _spawn_boss() -> void:
	print("[Main] _spawn_boss invoked")
	if not boss_scene:
		print("[Main] boss_scene export is null")
		push_warning("No boss scene assigned to main.gd; boss will not spawn.")
		return
	if get_node_or_null("boss_enemy"):
		print("[Main] Boss already present, skipping spawn")
		return
	var spawn_point: Node3D = find_child("BossSpawnPoint", true, false)
	if not spawn_point:
		print("[Main] BossSpawnPoint not found")
		push_warning("BossSpawnPoint not found in main scene; boss will not spawn.")
		return
	var boss_instance: Node = boss_scene.instantiate()
	if not boss_instance:
		print("[Main] Failed to instantiate boss_scene")
		push_warning("Failed to instantiate boss scene.")
		return
	print("[Main] Boss instantiated, adding to scene")
	add_child(boss_instance)
	if boss_instance is Node3D:
		(boss_instance as Node3D).global_transform = spawn_point.global_transform
		print("[Main] Boss positioned at spawn point: ", spawn_point.global_transform.origin)
	boss_instance.name = "boss_enemy"
	print("[Main] Boss spawn complete")

func _process(delta: float) -> void:
	time_passed += delta
	if time_passed > DAY_LENGTH:
		time_passed = 0.0  # restart cycle

	# Normalized time (0..1)
	var t: float = time_passed / DAY_LENGTH
	
	# Rotate both lights (opposite directions)
	var sun_angle: float = t * 360.0 - 90.0
	var moon_angle: float = sun_angle + 180.0
	
	sun.rotation_degrees = Vector3(sun_angle, 0.0, 0.0)
	moon.rotation_degrees = Vector3(moon_angle, 0.0, 0.0)

	# Smooth fade in/out
	var sun_strength: float = max(0.0, cos(deg_to_rad(sun_angle)))
	var moon_strength: float = max(0.0, cos(deg_to_rad(moon_angle)))
	
	sun.light_energy = sun_strength  # full brightness at peak
	moon.light_energy = moon_strength # dimmer moonlight
