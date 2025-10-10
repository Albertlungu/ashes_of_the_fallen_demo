extends CharacterBody3D

# ============================================================
# 🚨 DEBUG FLYING MODE - REMOVE BEFORE SUBMISSION! 🚨
# ============================================================
const DEBUG_FLYING_ENABLED = true  # Set to false to disable
const FLY_SPEED = 15.0
const FLY_SPRINT_MULTIPLIER = 2.5
var is_flying = false
# Double-tap detection
var space_tap_count = 0
var space_tap_timer = 0.0
const DOUBLE_TAP_TIME = 0.3
# ============================================================


# --- Movement ---
const SPEED := 4.0
const SPRINT_MULTIPLIER := 1.8
const JUMP_VELOCITY := 4.0
var gravity: float = 10.0

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
const HEALTH_REGEN_RATE := 10.0 / 60.0

# --- Stamina ---
var max_stamina := 100.0
var stamina := 100.0
var stamina_regen_rate := 5.0
var stamina_drain_rate := 100.0/60.0
var sprint_disabled := false
var cooldown_timer := 0.0
const STAMINA_LOCK_SECONDS := 20.0
var _pulse_time := 0.0

# --- Sprint toggle ---
var sprint_toggled := false

# --- Carrying System ---
var is_carrying := false
var carried_item: Node3D = null
const CARRY_SPEED_MULTIPLIER := 0.6
const CARRY_SPRINT_MULTIPLIER := 1.2

# --- UI nodes ---
@onready var health_bar: ProgressBar = $HealthStamina/HealthBar
@onready var stamina_bar: ProgressBar = $HealthStamina/StaminaBar
@onready var health_label: Label = $HealthStamina/HealthLabel
@onready var stamina_label: Label = $HealthStamina/StaminaLabel
@onready var damage_overlay: ColorRect = $HealthStamina/DamageFlash
@onready var water_overlay: ColorRect = $HealthStamina/WaterOverlay

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
var shake_offset := Vector3.ZERO
# IMPORTANT: Set this to match your scene! Change (0,1,0) if your pivot is at a different height
const CAMERA_PIVOT_HEIGHT := Vector3(0, 1, 0)  # This is what you see in the editor

# --- Damage tint ---
var tint_timer := 0.0
var tint_duration := 0.2

# --- Swimming ---
var is_swimming := false
var swim_speed := 5.0
const SWIM_SURFACE_OFFSET := 0.5

# --- Portal ---
@onready var ground_raycast: RayCast3D = $GroundRaycast
var is_teleporting := false
var last_portal_used: String = ""  # Add this as a class variable at the top



func _ready():
	print("\n========== PLAYER _ready() START ==========")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# FORCE the camera pivot to correct height
	if camera_pivot:
		camera_pivot.position = CAMERA_PIVOT_HEIGHT
		print("CameraPivot position set to: ", CAMERA_PIVOT_HEIGHT)
		print("CameraPivot actual position: ", camera_pivot.position)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_camera_current()
	
	var active_cam = get_active_camera()
	if active_cam:
		active_cam.make_current()
		print("Active camera set to: ", active_cam.name)
	
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)

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

	if water_overlay:
		water_overlay.visible = false
		
	if not ground_raycast:
		ground_raycast = RayCast3D.new()
		add_child(ground_raycast)
		ground_raycast.target_position = Vector3(0, -1.5, 0)
		ground_raycast.enabled = true

	call_deferred("_move_to_spawn_point")

	update_health_ui()
	update_stamina_ui()
	
	print("========== PLAYER _ready() END ==========\n")


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
		
# ============================================================
	# 🚨 DEBUG FLYING MODE - REMOVE BEFORE SUBMISSION! 🚨
	# ============================================================
	if DEBUG_FLYING_ENABLED and event.is_action_pressed("jump"):
		space_tap_count += 1
		space_tap_timer = DOUBLE_TAP_TIME
		
		if space_tap_count >= 2:
			is_flying = !is_flying
			space_tap_count = 0
			space_tap_timer = 0.0
			if is_flying:
				print("🚨 DEBUG: FLYING MODE ENABLED 🚨")
				velocity.y = 0  # Stop falling immediately
			else:
				print("🚨 DEBUG: FLYING MODE DISABLED 🚨")
	# ============================================================


func _physics_process(delta: float):
# ============================================================
	# 🚨 DEBUG FLYING MODE - REMOVE BEFORE SUBMISSION! 🚨
	# ============================================================
	# Handle double-tap timer
	if DEBUG_FLYING_ENABLED and space_tap_timer > 0.0:
		space_tap_timer -= delta
		if space_tap_timer <= 0.0:
			space_tap_count = 0
	
	if DEBUG_FLYING_ENABLED and is_flying:
		_handle_flying_mode(delta)
		return  # Skip all normal physics
	# ============================================================
	
	if health <= 0:
		return

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

	var sprinting := sprint_toggled and not sprint_disabled and direction != Vector3.ZERO and not is_swimming

	if sprinting:
		stamina -= stamina_drain_rate * delta
	else:
		if not sprint_disabled:
			stamina += stamina_regen_rate * delta

	stamina = clamp(stamina, 0.0, max_stamina)

	if stamina <= 0.0 and not sprint_disabled:
		sprint_disabled = true
		cooldown_timer = STAMINA_LOCK_SECONDS
		sprint_toggled = false
	if sprint_disabled:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			sprint_disabled = false
			cooldown_timer = 0.0

	var current_speed := SPEED
	
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

	if is_swimming:
		var reduced_gravity = gravity * 0.1
		velocity.y -= reduced_gravity * delta
		
		if Input.is_action_pressed("jump"):
			velocity.y = 2.0
		elif Input.is_action_pressed("move_backward") and direction.length() < 0.1:
			velocity.y = -1.0
		
		if velocity.y < 0:
			velocity.y *= 0.95
			
	else:
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
			
	_check_for_portal()

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


func pickup_item(item: Node3D) -> bool:
	if is_carrying:
		return false
	
	is_carrying = true
	carried_item = item
	sprint_toggled = false
	
	if carried_item.get_parent():
		carried_item.get_parent().remove_child(carried_item)
	add_child(carried_item)
	
	_update_carried_item_position()
	return true


func drop_item() -> void:
	if not is_carrying or not carried_item:
		return
	
	remove_child(carried_item)
	get_parent().add_child(carried_item)
	
	carried_item.global_position = global_position + (-transform.basis.z * 2.0)
	
	is_carrying = false
	carried_item = null


func _update_carried_item_position():
	if not is_carrying or not carried_item:
		return
	
	var carry_offset = Vector3(0, 1.0, -1.0)
	carried_item.position = carry_offset


func update_health_ui():
	if health_bar and health_stylebox:
		health_bar.value = health
		var ratio := health / max_health
		var custom_red = Color(219.0/255.0, 197.0/255.0, 51.0/255.0)
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
		var custom_blue = Color(14.0/255.0, 121.0/255.0, 175.0/255.0)
		if stamina <= 0.0 and sprint_disabled:
			var pulse := (sin(_pulse_time * 6.0) + 1.0) * 0.5
			stamina_stylebox.bg_color = Color.RED.lerp(Color(1, 0, 0, 0.5), pulse)
		else:
			stamina_stylebox.bg_color = custom_blue.lerp(Color.RED, 1.0 - ratio)
	if stamina_label:
		stamina_label.text = "Stamina"


func take_damage(amount: int) -> void:
	health -= amount
	health = clamp(health, 0, max_health)
	_start_camera_shake()
	_start_damage_tint()
	update_health_ui()
	if health <= 0:
		_die()


func _die():
	if is_carrying:
		drop_item()
	get_tree().paused = true


func _check_fall_damage():
	var fall_distance = fall_start_y - global_position.y
	if fall_distance > SAFE_FALL_DISTANCE:
		var damage = (fall_distance - SAFE_FALL_DISTANCE) * DAMAGE_MULTIPLIER
		take_damage(int(damage))


func _update_animation(direction: Vector3, sprinting: bool):
	var on_floor := is_on_floor()
	var is_moving := direction.length() > 0.1
	var new_anim := ""

	var forward_dot := direction.dot(-transform.basis.z)
	var right_dot := direction.dot(transform.basis.x)
	
	var moving_forward := forward_dot > 0.5
	var moving_backward := forward_dot < -0.5
	var moving_right := right_dot > 0.5
	var moving_left := right_dot < -0.5

	if is_carrying:
		if is_moving:
			new_anim = "Walking_A"
		else:
			new_anim = "Idle"
	elif blocking:
		new_anim = "Block"
	elif not on_floor:
		if velocity.y > 0:
			new_anim = "Jump_Start"
		else:
			new_anim = "Jump_Land"
	elif sprinting and is_moving:
		if moving_forward:
			new_anim = "Running_B"
		elif moving_right:
			new_anim = "Running_Strafe_Right"
		elif moving_left:
			new_anim = "Running_Strafe_Left"
		elif moving_backward:
			new_anim = "Walking_Backwards"
		else:
			new_anim = "Running_B"
	elif is_moving:
		if moving_forward:
			new_anim = "Walking_A"
		elif moving_backward:
			new_anim = "Walking_Backwards"
		else:
			new_anim = "Walking_A"
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


func _update_camera_current():
	if fp_cam:
		fp_cam.current = camera_mode == CameraMode.FIRST_PERSON
	if tp_cam:
		tp_cam.current = camera_mode == CameraMode.THIRD_PERSON
	if fv_cam:
		fv_cam.current = camera_mode == CameraMode.FRONT_VIEW


func _start_camera_shake():
	shake_timer = shake_duration


func _update_camera_shake(delta):
	if not camera_pivot:
		return
		
	if shake_timer > 0.0:
		shake_timer -= delta
		shake_offset = Vector3(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		# Apply shake to the constant base height
		camera_pivot.position = CAMERA_PIVOT_HEIGHT + shake_offset
	else:
		shake_offset = Vector3.ZERO
		# Reset to constant base height
		camera_pivot.position = CAMERA_PIVOT_HEIGHT


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


func enter_water():
	if not is_swimming:
		is_swimming = true
		is_falling = false
		sprint_toggled = false
		
		if water_overlay:
			water_overlay.visible = true


func exit_water():
	if is_swimming:
		is_swimming = false
		
		if water_overlay:
			water_overlay.visible = false


func _check_for_portal():
	if is_teleporting:
		return
		
	if not ground_raycast:
		return
	
	ground_raycast.force_raycast_update()
		
	if ground_raycast.is_colliding():
		var collider = ground_raycast.get_collider()
		
		if collider and collider.is_in_group("portal"):
			if collider.has_meta("portal_script"):
				var portal = collider.get_meta("portal_script") as Portal
				
				if portal:
					if portal.can_teleport(self) and portal.destination_scene != "":
						if portal.portal_id != last_portal_used:
							portal.start_cooldown(self)
							last_portal_used = portal.portal_id
							change_level(portal.destination_scene)



func change_level(level_path: String):
	is_teleporting = true
	set_physics_process(false)
	
	# Reset velocity and fall tracking BEFORE changing scenes
	velocity = Vector3.ZERO
	is_falling = false
	
	get_tree().change_scene_to_file(level_path)
	
	# Wait for scene to load
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	var spawn = get_tree().current_scene.find_child("PlayerSpawnPoint", true, false)
	if spawn:
		global_position = spawn.global_position
		print("Moved player to spawn: ", global_position)
	else:
		print("WARNING: No PlayerSpawnPoint found!")
	
	# CRITICAL: Reset fall_start_y AFTER setting position
	fall_start_y = global_position.y
	is_falling = false
	velocity = Vector3.ZERO
	
	# Restore camera pivot to correct height
	if camera_pivot:
		camera_pivot.position = CAMERA_PIVOT_HEIGHT
	
	# Clear the last portal after a delay to allow the cooldown system to work
	await get_tree().create_timer(0.5).timeout
	
	is_teleporting = false
	set_physics_process(true)
	
	var active_camera = get_active_camera()
	if active_camera:
		active_camera.make_current()
	
	await get_tree().process_frame
	
	var terrain = get_tree().current_scene.find_child("Terrain3D", true, false)
	if terrain and active_camera:
		terrain.set_camera(active_camera)



func _move_to_spawn_point():
	await get_tree().process_frame
	
	var spawn = get_tree().current_scene.find_child("PlayerSpawnPoint", true, false)
	if spawn:
		global_position = spawn.global_position
	
	# Ensure camera pivot is at correct height
	if camera_pivot:
		camera_pivot.position = CAMERA_PIVOT_HEIGHT
	
	var active_cam = get_active_camera()
	if active_cam:
		active_cam.make_current()
		await get_tree().process_frame
	
	var terrain = get_tree().current_scene.find_child("Terrain3D", true, false)
	if terrain and active_cam:
		terrain.set_camera(active_cam)


func get_active_camera() -> Camera3D:
	match camera_mode:
		CameraMode.FIRST_PERSON:
			return fp_cam
		CameraMode.THIRD_PERSON:
			return tp_cam
		CameraMode.FRONT_VIEW:
			return fv_cam
	return fp_cam

# ============================================================
# 🚨 DEBUG FLYING MODE - REMOVE BEFORE SUBMISSION! 🚨
# ============================================================
func _handle_flying_mode(delta: float):
	var direction := Vector3.ZERO
	
	# Forward/Backward
	if Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		direction += transform.basis.z
	
	# Left/Right
	if Input.is_action_pressed("move_left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		direction += transform.basis.x
	
	# Up (Space - but only if not double-tapping)
	if Input.is_action_pressed("jump") and space_tap_timer <= 0.0:
		direction.y += 1.0
	
	# Down (Shift key)
	if Input.is_key_pressed(KEY_SHIFT):
		direction.y -= 1.0
	
	direction = direction.normalized()
	
	# Sprint with Ctrl
	var fly_speed = FLY_SPEED
	if Input.is_key_pressed(KEY_CTRL):
		fly_speed *= FLY_SPRINT_MULTIPLIER
	
	velocity = direction * fly_speed
	move_and_slide()
	
	# Update UI
	update_health_ui()
	update_stamina_ui()
	
	# Show flying indicator
	if health_label:
		health_label.text = "🚨 FLYING MODE 🚨"
# ============================================================
