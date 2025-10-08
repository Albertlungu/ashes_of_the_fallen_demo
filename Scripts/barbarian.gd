extends CharacterBody3D

# --- Movement ---
const SPEED = 5.0
const JUMP_HEIGHT = 0.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var JUMP_VELOCITY = sqrt(2 * gravity * JUMP_HEIGHT)

# --- Mouse look ---
var mouse_sensitivity = 0.15
var rotation_x = 0.0 # FP vertical rotation
var tp_pitch = 0.0
var max_look_up = 90
var max_look_down = -90

# --- POV toggle ---
var first_person = true

# --- Camera references ---
@onready var fp_cam: Camera3D = $FP_Camera
@onready var tp_cam: Camera3D = $TP_Camera

# --- Mouse control ---
var mouse_captured = true

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_camera_current()

func _input(event):
	if mouse_captured and event is InputEventMouseMotion:
		# Horizontal rotation (player rotates)
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))

		if first_person:
			# FP vertical rotation
			rotation_x += -event.relative.y * mouse_sensitivity
			rotation_x = clamp(rotation_x, max_look_down, max_look_up)
			fp_cam.rotation_degrees.x = rotation_x
		if not first_person:
			tp_pitch += -event.relative.y * mouse_sensitivity
			tp_pitch = clamp(tp_pitch, -80, 10)  # allows looking over the player
			tp_cam.rotation_degrees.x = tp_pitch

	# POV toggle
	if event.is_action_pressed("toggle_pov"):
		first_person = !first_person
		_update_camera_current()

	# ESC releases/captures mouse
	if event.is_action_pressed("ui_cancel"):
		mouse_captured = !mouse_captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("move_left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		direction += transform.basis.x

	direction = direction.normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	# Gravity + jump
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()

func _process(delta):
	if not first_person:
		# TP camera already positioned; just look at player's head
		#tp_cam.look_at(global_transform.origin + Vector3(0, 1.5, 0), Vector3.UP)
		pass
		
func _update_camera_current():
	fp_cam.current = first_person
	tp_cam.current = not first_person
