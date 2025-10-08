extends CharacterBody3D

# --- Movement ---
const SPEED := 7.0
const SPRINT_MULTIPLIER := 1.8
const JUMP_VELOCITY := 4.0
const STEP_HEIGHT := 1
var gravity: float = 19.6

# --- Mouse look ---
var mouse_sensitivity := 0.15
var rotation_x := 0.0
var tp_pitch := 0.0
var fv_pitch := 0.0
var max_look_up := 90
var max_look_down := -90

# --- Camera ---
enum CameraMode { FIRST_PERSON, THIRD_PERSON, FRONT_VIEW }
var camera_mode := CameraMode.FIRST_PERSON

@onready var fp_cam: Camera3D = $CameraPivot/FP_Camera
@onready var tp_cam: Camera3D = $CameraPivot/TP_Camera
@onready var fv_cam: Camera3D = $CameraPivot/FV_Camera
@onready var camera_pivot: Node3D = $CameraPivot

var mouse_captured := true

# --- Animation ---
@onready var anim_player: AnimationPlayer = $Barbarian/AnimationPlayer
var current_anim := ""

# --- Input flags ---
var attacking := false
var attack_timer := 0.0
var attack_threshold := 0.25
var blocking := false

# --- Health ---
var max_health := 100.0
var health := 100.0
const HEALTH_REGEN_RATE := 10.0 / 60.0  # 10% per minute = (max_health * 0.1) / 60 seconds

# --- Stamina ---
var max_stamina := 100.0
var stamina := 100.0
var stamina_regen_rate := 5.0      # fills 10 s from 0 → 100
var stamina_drain_rate := 100.0/60.0 # drains over 60 s
var sprint_disabled := false
var cooldown_timer := 0.0
const STAMINA_LOCK_SECONDS := 20.0
var _pulse_time := 0.0

# --- Sprint toggle ---
var sprint_toggled := false

# --- Carrying System ---
var is_carrying := false
var carried_item: Node3D = null
const CARRY_SPEED_MULTIPLIER := 0.6  # Player moves at 60% speed when carrying
const CARRY_SPRINT_MULTIPLIER := 1.2  # Reduced sprint multiplier when carrying (instead of 1.8)

# --- UI nodes (CanvasLayer) ---
@export var health_bar: ProgressBar
@export var stamina_bar: ProgressBar
@export var health_label: Label
@export var stamina_label: Label

# Add these variables to cache the styleboxes
var health_stylebox: StyleBoxFlat
var stamina_stylebox: StyleBoxFlat

# --- Fall damage ---
var fall_start_y := 0.0
var is_falling := false
const SAFE_FALL_DISTANCE := 5
const DAMAGE_MULTIPLIER := 2.5

# --- Camera shake ---
var shake_timer := 0.0
var shake_duration := 0.2
var shake_strength := 0.15
var original_camera_pos: Vector3

# --- Damage tint ---
@onready var damage_overlay: ColorRect = $"../UI/DamageFlash"
var tint_timer := 0.0
var tint_duration := 0.2

# --- Swimming ---
var is_swimming := false
var swim_speed := 5.0  # Slower than walking
const SWIM_SURFACE_OFFSET := 0.5  # How high player floats
@export var water_overlay: ColorRect  # Assign in inspector

# --- Ready ---
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_camera_current()
	anim_player.animation_finished.connect(_on_animation_finished)
	original_camera_pos = camera_pivot.position

	# Create styleboxes for fill (foreground)
	health_stylebox = StyleBoxFlat.new()
	health_stylebox.corner_radius_top_left = 30
	health_stylebox.corner_radius_top_right = 30
	health_stylebox.corner_radius_bottom_left = 30
	health_stylebox.corner_radius_bottom_right = 30
	
	stamina_stylebox = StyleBoxFlat.new()
	stamina_stylebox.corner_radius_top_left = 30
	stamina_stylebox.corner_radius_top_right = 30
	stamina_stylebox.corner_radius_bottom_left = 30
	stamina_stylebox.corner_radius_bottom_right = 30
	
	# Create transparent/custom background styleboxes
	var health_bg_stylebox = StyleBoxFlat.new()
	health_bg_stylebox.bg_color = Color(0, 0, 0, 0)
	health_bg_stylebox.corner_radius_top_left = 30
	health_bg_stylebox.corner_radius_top_right = 30
	health_bg_stylebox.corner_radius_bottom_left = 30
	health_bg_stylebox.corner_radius_bottom_right = 30
	
	var stamina_bg_stylebox = StyleBoxFlat.new()
	stamina_bg_stylebox.bg_color = Color(0, 0, 0, 0)
	stamina_bg_stylebox.corner_radius_top_left = 30
	stamina_bg_stylebox.corner_radius_top_right = 30
	stamina_bg_stylebox.corner_radius_bottom_left = 30
	stamina_bg_stylebox.corner_radius_bottom_right = 30
	
	if health_bar:
		health_bar.add_theme_stylebox_override("fill", health_stylebox)
		health_bar.add_theme_stylebox_override("background", health_bg_stylebox)
	if stamina_bar:
		stamina_bar.add_theme_stylebox_override("fill", stamina_stylebox)
		stamina_bar.add_theme_stylebox_override("background", stamina_bg_stylebox)

	# Initialize water overlay as hidden
	if water_overlay:
		water_overlay.visible = false

	update_health_ui()
	update_stamina_ui()

# --- Input ---
func _input(event):
	if mouse_captured and event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		if camera_mode == CameraMode.FIRST_PERSON and fp_cam:
			rotation_x += -event.relative.y * mouse_sensitivity
			rotation_x = clamp(rotation_x, max_look_down, max_look_up)
			fp_cam.rotation_degrees.x = rotation_x
		elif camera_mode == CameraMode.THIRD_PERSON and tp_cam:
			tp_pitch += -event.relative.y * mouse_sensitivity
			tp_pitch = clamp(tp_pitch, -80, 30)
			tp_cam.rotation_degrees.x = tp_pitch
		elif camera_mode == CameraMode.FRONT_VIEW and fv_cam:
			fv_pitch += -event.relative.y * mouse_sensitivity
			fv_pitch = clamp(fv_pitch, -80, 30)
			fv_cam.rotation_degrees.x = fv_pitch

	if event.is_action_pressed("toggle_pov"):
		camera_mode = (int(camera_mode) + 1) % 3
		_update_camera_current()

	if event.is_action_pressed("ui_cancel"):
		mouse_captured = !mouse_captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE)

	# Toggle sprint
	if event.is_action_pressed("sprint"):
		sprint_toggled = !sprint_toggled

	if event.is_action_pressed("attack") and not attacking and not is_carrying:
		attack_timer = 0.0
		attacking = true
	elif event.is_action_released("attack") and attacking:
		if attack_timer < attack_threshold:
			_perform_light_attack()
		else:
			_perform_heavy_attack()

	if event.is_action_pressed("block") and not is_carrying:
		blocking = true
	elif event.is_action_released("block"):
		blocking = false

# --- Physics ---
func _physics_process(delta: float):
	if health <= 0:
		return

	# Health regeneration
	if health < max_health:
		health += HEALTH_REGEN_RATE * delta
		health = min(health, max_health)

	var direction := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("move_left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		direction += transform.basis.x
	direction = direction.normalized()

	# Sprinting logic
	var sprinting := sprint_toggled and not sprint_disabled and direction != Vector3.ZERO and not is_swimming

	if sprinting:
		stamina -= stamina_drain_rate * delta
	else:
		if not sprint_disabled:
			stamina += stamina_regen_rate * delta

	stamina = clamp(stamina, 0.0, max_stamina)

	# Cooldown / lock
	if stamina <= 0.0 and not sprint_disabled:
		sprint_disabled = true
		cooldown_timer = STAMINA_LOCK_SECONDS
		sprint_toggled = false
	if sprint_disabled:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			sprint_disabled = false
			cooldown_timer = 0.0

	# Compute movement speed
	var current_speed := SPEED
	
	# Swimming overrides other speed modifiers
	if is_swimming:
		current_speed = swim_speed
	else:
		if sprinting:
			if is_carrying:
				current_speed *= CARRY_SPRINT_MULTIPLIER
			else:
				current_speed *= SPRINT_MULTIPLIER
		
		if is_carrying:
			current_speed *= CARRY_SPEED_MULTIPLIER
		
		if sprint_disabled:
			current_speed *= 0.5

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	# Swimming vs Regular Movement
	if is_swimming:
		# Swimming physics
		var reduced_gravity = gravity * 0.1  # Very light sinking
		velocity.y -= reduced_gravity * delta
		
		# Swim up/down
		if Input.is_action_pressed("jump"):
			velocity.y = 2.0  # Swim up
		elif Input.is_action_pressed("move_backward") and direction.length() < 0.1:
			velocity.y = -1.0  # Swim down when pressing back without movement
		
		# Keep player near surface (buoyancy)
		if velocity.y < 0:
			velocity.y *= 0.95  # Slow sinking
			
	else:
		# Normal gravity and jumping
		if not is_on_floor():
			if not is_falling:
				is_falling = true
				fall_start_y = global_position.y
			velocity.y -= gravity * delta
		else:
			if is_falling:
				is_falling = false
				_check_fall_damage()
			if Input.is_action_just_pressed("jump"):
				velocity.y = JUMP_VELOCITY

	move_and_slide()
	if is_on_floor() and direction.length() > 0:
		var test_motion = PhysicsTestMotionParameters3D.new()
		test_motion.from = global_transform
		test_motion.motion = Vector3(0, STEP_HEIGHT, 0)
	
		if PhysicsServer3D.body_test_motion(get_rid(), test_motion):
			position.y += STEP_HEIGHT * 0.5  # Smooth step up


	if attacking:
		attack_timer += delta

	_update_animation(direction, sprinting)
	_update_camera_shake(delta)
	_update_damage_tint(delta)
	_update_carried_item_position()

	if stamina <= 0.0 and sprint_disabled:
		_pulse_time += delta
	else:
		_pulse_time = 0.0

	update_health_ui()
	update_stamina_ui()

# --- Carrying System ---
func pickup_item(item: Node3D) -> bool:
	if is_carrying:
		return false
	
	is_carrying = true
	carried_item = item
	
	# Disable sprint when picking up item
	sprint_toggled = false
	
	# Reparent item to player (optional, depending on your setup)
	if carried_item.get_parent():
		carried_item.get_parent().remove_child(carried_item)
	add_child(carried_item)
	
	# Position item in front of player
	_update_carried_item_position()
	
	print("Picked up item: ", item.name)
	return true

func drop_item() -> void:
	if not is_carrying or not carried_item:
		return
	
	# Remove from player and add back to scene
	remove_child(carried_item)
	get_parent().add_child(carried_item)
	
	# Position item in front of player
	carried_item.global_position = global_position + (-transform.basis.z * 2.0)
	
	print("Dropped item: ", carried_item.name)
	
	is_carrying = false
	carried_item = null

func _update_carried_item_position():
	if not is_carrying or not carried_item:
		return
	
	# Position item in front of player at chest height
	var carry_offset = Vector3(0, 1.0, -1.0)  # Adjust these values as needed
	carried_item.position = carry_offset

# --- Health & Stamina UI using StyleBoxFlat ---
func update_health_ui():
	if health_bar and health_stylebox:
		health_bar.value = health
		var ratio := health / max_health
		var custom_red = Color(219.0/255.0, 197.0/255.0, 51.0/255.0)  # Your custom color
		if ratio > 0.5:
			health_stylebox.bg_color = custom_red.lerp(Color.YELLOW, 1.0 - ratio * 2.0)
		else:
			health_stylebox.bg_color = Color.YELLOW.lerp(Color.RED, 1.0 - ratio * 2.0)
	if health_label:
		health_label.text = "Health"

func update_stamina_ui():
	if stamina_bar and stamina_stylebox:
		stamina_bar.value = stamina
		var ratio := stamina / max_stamina
		var custom_blue = Color(14.0/255.0, 121.0/255.0, 175.0/255.0)  # Your custom color
		if stamina <= 0.0 and sprint_disabled:
			var pulse := (sin(_pulse_time * 6.0) + 1.0) * 0.5
			stamina_stylebox.bg_color = Color.RED.lerp(Color(1, 0, 0, 0.5), pulse)
		else:
			stamina_stylebox.bg_color = custom_blue.lerp(Color.RED, 1.0 - ratio)
	if stamina_label:
		stamina_label.text = "Stamina"

# --- Damage & Fall ---
func take_damage(amount: int) -> void:
	health -= amount
	health = clamp(health, 0, max_health)
	_start_camera_shake()
	_start_damage_tint()
	update_health_ui()
	if health <= 0:
		_die()

func _die():
	print("Player has died!")
	if is_carrying:
		drop_item()
	get_tree().paused = true  # stop the game

func _check_fall_damage():
	var fall_distance = fall_start_y - global_position.y
	if fall_distance > SAFE_FALL_DISTANCE:
		var damage = (fall_distance - SAFE_FALL_DISTANCE) * DAMAGE_MULTIPLIER
		take_damage(int(damage))

# --- Animation ---
func _update_animation(direction: Vector3, sprinting: bool):
	var on_floor := is_on_floor()
	var is_moving := direction.length() > 0.1
	var new_anim := ""

	# Calculate movement direction relative to where player is facing
	var forward_dot := direction.dot(-transform.basis.z)
	var right_dot := direction.dot(transform.basis.x)
	
	var moving_forward := forward_dot > 0.5
	var moving_backward := forward_dot < -0.5
	var moving_right := right_dot > 0.5
	var moving_left := right_dot < -0.5

	if is_carrying:
		# Use different animations when carrying (you'll need to add these)
		if is_moving:
			new_anim = "Walking_A"  # Replace with carrying walk animation if available
		else:
			new_anim = "Idle"  # Replace with carrying idle animation if available
	elif blocking:
		new_anim = "Block"
	elif not on_floor:
		if velocity.y > 0:
			new_anim = "Jump_Start"
		else:
			new_anim = "Jump_Land"
	elif sprinting and is_moving:
		# Running animations
		if moving_forward:
			new_anim = "Running_B"
		elif moving_right:
			new_anim = "Running_Strafe_Right"
		elif moving_left:
			new_anim = "Running_Strafe_Left"
		elif moving_backward:
			new_anim = "Walking_Backwards"  # or add a running backwards animation
		else:
			new_anim = "Running_B"  # Default run animation
	elif is_moving:
		# Walking animations
		if moving_forward:
			new_anim = "Walking_A"
		elif moving_backward:
			new_anim = "Walking_Backwards"
		else:
			new_anim = "Walking_A"  # Default walk for strafing
	else:
		new_anim = "Idle"

	if new_anim != current_anim:
		anim_player.play(new_anim)
		current_anim = new_anim

func _perform_light_attack():
	attacking = true
	anim_player.play("1H_Melee_Attack_Chop")

func _perform_heavy_attack():
	attacking = true
	anim_player.play("2H_Melee_Attack_Chop")

func _on_animation_finished(anim_name: String):
	if anim_name.begins_with("1H_Melee_Attack") or anim_name.begins_with("2H_Melee_Attack"):
		attacking = false

# --- Camera ---
func _update_camera_current():
	if fp_cam:
		fp_cam.current = camera_mode == CameraMode.FIRST_PERSON
	if tp_cam:
		tp_cam.current = camera_mode == CameraMode.THIRD_PERSON
	if fv_cam:
		fv_cam.current = camera_mode == CameraMode.FRONT_VIEW

# --- Camera shake ---
func _start_camera_shake():
	shake_timer = shake_duration

func _update_camera_shake(delta):
	if shake_timer > 0.0:
		shake_timer -= delta
		var offset := Vector3(randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength))
		camera_pivot.position = original_camera_pos + offset
	else:
		camera_pivot.position = original_camera_pos

# --- Damage tint ---
func _start_damage_tint():
	tint_timer = tint_duration
	if damage_overlay:
		damage_overlay.color = Color(1, 0, 0, 0.4)
		damage_overlay.visible = true

func _update_damage_tint(delta):
	if tint_timer > 0.0:
		tint_timer -= delta
	else:
		if damage_overlay:
			damage_overlay.visible = false
			
# --- Swimming System ---
func enter_water():
	if not is_swimming:
		is_swimming = true
		is_falling = false  # Cancel fall damage
		sprint_toggled = false  # Can't sprint in water
		
		if water_overlay:
			water_overlay.visible = true
		
		print("Entered water - Swimming mode")

func exit_water():
	if is_swimming:
		is_swimming = false
		
		if water_overlay:
			water_overlay.visible = false
		
		print("Exited water")
