extends CharacterBody3D

# ============================================================
# 🚨 DEBUG FLYING MODE - REMOVE BEFORE SUBMISSION! 🚨
# ============================================================
const DEBUG_FLYING_ENABLED = true  # Set to false to disable
const FLY_SPEED = 30.0
const FLY_SPRINT_MULTIPLIER = 2.5
var is_flying = false
# Double-tap detection
var space_tap_count = 0
var space_tap_timer = 0.0
const DOUBLE_TAP_TIME = 0.3
# ============================================================

var inventory_data: InventoryData

var light_attack_damage := 10.0
var heavy_attack_damage := 25.0
var attack_reach := 5.0  # How far the player can hit


# --- Gem of Wit Ability ---
var gem_active := false
var gem_duration := 3.0             # seconds the effect lasts
var gem_cooldown := 5.0             # seconds before reuse
var gem_timer := 0.0
var gem_cooldown_timer := 0.0
var gem_time_scale := 0.5            # slow everything else to 50%
var global_time_scale := 1.0

# --- Movement ---
const SPEED := 4.0
const SPRINT_MULTIPLIER := 1.8
const JUMP_VELOCITY := 4.0
var gravity: float = 15.0

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
@onready var crosshair: TextureRect = $HealthStamina/Crosshair

var health_stylebox: StyleBoxFlat
var stamina_stylebox: StyleBoxFlat

# --- Fall damage ---
var fall_start_y := 0.0
var is_falling := false
const SAFE_FALL_DISTANCE := 5
const DAMAGE_MULTIPLIER := 2.5

const RESPAWN_HISTORY_SECONDS := 20.0
const RESPAWN_SCREEN_SCENE := preload("res://UI/RespawnScreen.tscn")

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
var last_portal_used: String = ""
# --- Knockback System ---
var knockback_velocity := Vector3.ZERO
var knockback_decay_rate := 5.0  # How quickly knockback fades (units per second)

var transform_history: Array = []
var history_elapsed := 0.0
var respawn_screen: RespawnScreen
var last_damage_cause := "Unknown"



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
	
	if not inventory_data:
		inventory_data = load("res://UI/Inventory/Inventories/player_inventory.tres")
		
	# Add player to group for detection
	add_to_group("player")
	_ensure_respawn_screen()
	transform_history.clear()
	history_elapsed = 0.0
	_update_transform_history(0.0)
	
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
		
	# Gem of Wit activation
	if event.is_action_pressed("use_gem") and has_gem_of_wit():
		if not gem_active and gem_cooldown_timer <= 0.0:
			_activate_gem_of_wit()
		
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
	
	if gem_active:
		gem_timer -= delta
		if gem_timer <= 0.0:
			gem_active = false
			Engine.time_scale = 1.0  # Reset time
			# Remove any aura particles
			for child in get_children():
				if child is GPUParticles3D:
					child.queue_free()

	if gem_cooldown_timer > 0.0:
		gem_cooldown_timer -= delta
	
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

	# Apply knockback if present
	if knockback_velocity.length() > 0.01:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, knockback_decay_rate * delta)  # Decay knockback over time

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
	_update_transform_history(delta)

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


func _update_crosshair():
	if not crosshair:
		return
	var cam = get_active_camera()
	if not cam:
		return
	var viewport_size = get_viewport().size
	var fallback = viewport_size * 0.5 - crosshair.size * 0.5
	var aim_origin = camera_pivot.global_position if camera_pivot else global_position
	var aim_direction = -global_transform.basis.z
	var aim_point = aim_origin + aim_direction * 20.0
	if cam.is_position_behind(aim_point):
		crosshair.position = fallback
		return
	var projected = cam.unproject_position(aim_point)
	if not projected.is_finite():
		crosshair.position = fallback
		return
	var screen_pos = Vector2(projected.x, projected.y)
	crosshair.position = screen_pos - crosshair.size * 0.5


func _update_transform_history(delta: float) -> void:
	history_elapsed += delta
	transform_history.append({
		"transform": global_transform,
		"position": global_position,
		"forward": -global_transform.basis.z,
		"time": history_elapsed
	})
	var cutoff_time = history_elapsed - RESPAWN_HISTORY_SECONDS
	while transform_history.size() > 1 and transform_history[1]["time"] < cutoff_time:
		transform_history.remove_at(0)


func _get_respawn_state() -> Dictionary:
	if transform_history.is_empty():
		return {
			"transform": global_transform,
			"position": global_position,
			"forward": -global_transform.basis.z
		}
	for i in range(transform_history.size() - 1, -1, -1):
		if history_elapsed - transform_history[i]["time"] >= RESPAWN_HISTORY_SECONDS:
			return transform_history[i]
	return transform_history.front()


func _ensure_respawn_screen() -> void:
	if respawn_screen and is_instance_valid(respawn_screen):
		return
	respawn_screen = RESPAWN_SCREEN_SCENE.instantiate()
	get_tree().root.add_child(respawn_screen)
	respawn_screen.respawn_requested.connect(_on_respawn_screen_respawn_requested)
	respawn_screen.quit_requested.connect(_on_respawn_screen_quit_requested)


func _on_respawn_screen_respawn_requested(respawn_transform: Transform3D) -> void:
	get_tree().paused = false
	global_transform = respawn_transform
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	health = max_health
	stamina = max_stamina
	sprint_disabled = false
	cooldown_timer = 0.0
	mouse_captured = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_health_ui_after_respawn()
	_update_transform_history(0.0)


func _update_health_ui_after_respawn() -> void:
	transform_history.clear()
	history_elapsed = 0.0
	update_health_ui()
	update_stamina_ui()


func _on_respawn_screen_quit_requested() -> void:
	get_tree().paused = false
	get_tree().quit()


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


func take_damage(amount: int, knockback_force: Vector3 = Vector3.ZERO, cause: String = "Unknown") -> void:
	if amount > 0:
		last_damage_cause = cause
	health -= amount
	health = clamp(health, 0, max_health)
	if knockback_force != Vector3.ZERO:
		knockback_velocity = knockback_force  # Set knockback velocity for gradual application
		print("Knockback applied: ", knockback_force)  # Debug: Confirm knockback is set
	_start_camera_shake()
	_start_damage_tint()
	update_health_ui()
	if health <= 0:
		_die()



func _die():
	if is_carrying:
		drop_item()
	_ensure_respawn_screen()
	var respawn_state := _get_respawn_state()
	var respawn_transform: Transform3D = respawn_state.get("transform", global_transform)
	var death_position := global_position
	var death_forward := -global_transform.basis.z
	if respawn_screen:
		respawn_screen.show_screen(last_damage_cause, death_position, death_forward, 0.0, respawn_transform)
	get_tree().paused = true


func _check_fall_damage():
	var fall_distance = fall_start_y - global_position.y
	if fall_distance > SAFE_FALL_DISTANCE:
		var damage = (fall_distance - SAFE_FALL_DISTANCE) * DAMAGE_MULTIPLIER
		take_damage(int(damage), Vector3.ZERO, "Fall damage")


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
	print("🗡️ Player performing LIGHT attack")
	_check_for_hit(light_attack_damage)


func _perform_heavy_attack():
	attacking = true
	anim_player.play("2H_Melee_Attack_Chop")
	print("🗡️ Player performing HEAVY attack")
	_check_for_hit(heavy_attack_damage)


func _check_for_hit(damage: float):
	print("🎯 Checking for hit with damage: ", damage)
	
	# Wait a tiny bit for the animation to start (simulates swing time)
	await get_tree().create_timer(0.2).timeout
	
	print("⏰ Attack swing executed, checking for enemies...")
	
	# Get all enemies in the scene
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("👹 Found ", enemies.size(), " enemies in scene")
	
	if enemies.size() == 0:
		print("❌ NO ENEMIES FOUND! Make sure boss is in 'enemies' group")
		return
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			print("⚠️ Invalid enemy reference, skipping")
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		print("📏 Distance to enemy '", enemy.name, "': ", distance, " (reach: ", attack_reach, ")")
		
		# Check if enemy is within reach
		if distance <= attack_reach:
			print("✅ Enemy is within reach!")
			
			# Check if enemy is roughly in front of the player
			var to_enemy = (enemy.global_position - global_position).normalized()
			var forward = -transform.basis.z
			var dot = to_enemy.dot(forward)
			
			print("🎯 Dot product (facing): ", dot, " (need > 0.5)")
			
			# dot > 0.5 means enemy is roughly in front (within ~60 degree cone)
			if dot > 0.5:
				print("✅ Enemy is in front of player!")
				
				if enemy.has_method("take_damage"):
					print("💥 HITTING ENEMY FOR ", damage, " DAMAGE!")
					enemy.take_damage(damage)
					_play_hit_effect(enemy.global_position)
					return  # Only hit one enemy per attack
				else:
					print("❌ Enemy doesn't have 'take_damage' method!")
			else:
				print("❌ Enemy is NOT in front (behind or to the side)")
		else:
			print("❌ Enemy too far away")
	
	print("💨 Attack missed - no valid targets")


func _play_hit_effect(hit_position: Vector3):
	# Create a simple particle effect at hit location
	var particles = GPUParticles3D.new()
	get_parent().add_child(particles)
	particles.global_position = hit_position
	
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 45
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, -9.8, 0)
	material.color = Color.ORANGE_RED
	
	particles.process_material = material
	particles.emitting = true
	
	# Clean up after effect finishes
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()




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

func pickup_gem(slot_data: SlotData) -> bool:
	if inventory_data.add_item(slot_data):
		print("Picked up: ", slot_data.item_data.name)
		_play_pickup_effect()
		return true
	else:
		print("Inventory full!")
		return false


func _play_pickup_effect() -> void:
	# Placeholder for Phase 3
	print("✨ Blue aura effect would play here")

func has_gem_of_wit() -> bool:
	if inventory_data:
		print("📦 Checking inventory for 'Gem of Wit'...")
		print("   Inventory slots: ", inventory_data.slot_datas.size())
		
		for i in range(inventory_data.slot_datas.size()):
			var slot = inventory_data.slot_datas[i]
			if slot and slot.item_data:
				print("   Slot ", i, ": ", slot.item_data.name)
				if slot.item_data.name == "Gem of Wit":
					print("   ✅ FOUND GEM!")
					return true
		
		print("   ❌ No gem found")
		return false
	
	print("❌ No inventory_data!")
	return false

func _activate_gem_of_wit() -> void:
	if gem_active:
		return

	gem_active = true
	gem_timer = gem_duration
	gem_cooldown_timer = gem_cooldown

	# Deduct 5% HP
	take_damage(int(max_health * 0.05))

	# Slow everything else
	global_time_scale = gem_time_scale

	_show_gem_aura()

func _show_gem_aura() -> void:
	# Create a simple visual aura around the player
	var aura = GPUParticles3D.new()
	aura.amount = 150
	aura.lifetime = gem_duration
	aura.one_shot = true
	
	var material = ParticleProcessMaterial.new()
	material.color = Color(0.2, 0.6, 1.0, 0.8)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 1.5
	aura.process_material = material
	
	add_child(aura)
	aura.restart()
