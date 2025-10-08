extends Node3D

@onready var sun: DirectionalLight3D = $Sun
@onready var moon: DirectionalLight3D = $Moon

const DAY_LENGTH: float = 600.0  # 10 minutes full cycle
var time_passed: float = 0.0

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
