extends Node3D

@export var flow_speed := 0.001  # Main texture speed
@export var flow_direction := Vector2(1, 0)

@onready var river_mesh: MeshInstance3D = $MeshInstance3D
@onready var water_area: Area3D = $WaterArea
#@onready var camera_water_area: Area3D = $CameraWaterArea
var material: ShaderMaterial

func _ready():
	material = river_mesh.get_surface_override_material(0)
	if material == null:
		push_error("No shader material found on river mesh!")
	
	if water_area:
		water_area.body_entered.connect(_on_body_entered)
		water_area.body_exited.connect(_on_body_exited)
	
	#if camera_water_area:
		#camera_water_area.area_entered.connect(_on_camera_area_entered)
		#camera_water_area.area_exited.connect(_on_camera_area_exited)

func _process(delta):
	if material:
		var current_offset = material.get_shader_parameter("uv_offset")
		if current_offset == null:
			current_offset = Vector2.ZERO
		current_offset += flow_direction * flow_speed * delta
		material.set_shader_parameter("uv_offset", current_offset)

func _on_body_entered(body):
	if body.has_method("enter_water"):
		body.enter_water()

func _on_body_exited(body):
	if body.has_method("exit_water"):
		body.exit_water()

func _on_camera_area_entered(area):
	var owner_node = area.get_parent()
	if owner_node and owner_node.has_method("camera_enter_water"):
		owner_node.camera_enter_water()

func _on_camera_area_exited(area):
	var owner_node = area.get_parent()
	if owner_node and owner_node.has_method("camera_exit_water"):
		owner_node.camera_exit_water()
