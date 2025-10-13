extends CharacterBody3D

@onready var alien_instance: Node3D = $"Alien Animal Baked"
@onready var anim_player: AnimationPlayer = alien_instance.get_node("AnimationPlayer")
@export var death_spawn_scene: PackedScene
@export var evaporate_rise_speed := 2.0
@export var evaporate_scale_min := 0.05
@onready var player: CharacterBody3D = null  # Will be set in _ready()
@onready var attack_area: Area3D = $AttackRange  # The Area3D for detecting player hits

# UI Elements
@onready var health_bar: ProgressBar = $BossUI/HealthBar
@onready var health_label: Label = $BossUI/HealthBar/HealthLabel

# --- Stats ---
var max_health := 1000.0
var health := 1000.0
var speed := 5.0
var rotation_speed := 5.0  # How fast the boss turns to face direction
var gravity := 10.0  # Add gravity to keep boss grounded

# --- AI ---
var detection_radius := 100.0
var attack_range := 6.0  # Increased to account for collision body sizes
var attack_cooldown := 2.5  # Slower attacks - 2.5 seconds between attacks
var attack_timer := 0.0
var bite_count := 0
var swipe_every_bites := 5
var healthbar_show_radius := 50.0  # Show health bar within this distance

# Optional: Set to null to allow boss to chase anywhere, or define boundaries
var restricted_area: AABB = AABB(Vector3(-500, -10, -500), Vector3(1000, 100, 1000))
var use_restricted_area := false  # Set to true if you want boundaries

# --- Attack ratios ---
var bite_damage_ratio := 0.05
var swipe_damage_ratio := 0.10

# --- State ---
enum State { IDLE, PATROL, CHASE, ATTACK }
var state := State.PATROL  # Start in patrol mode
var patrol_target: Vector3 = Vector3.ZERO
var patrol_wait_timer := 0.0
var patrol_wait_duration := 0.0
var is_waiting := false

var strafe_timer := 0.0
var strafe_duration_range := Vector2(1.0, 2.0)
var strafe_direction := 1
var is_strafing := false
var reposition_cooldown := 0.0
var reposition_interval := Vector2(3.0, 6.0)
var reposition_target: Vector3 = Vector3.ZERO
var chase_speed_multiplier := 1.6
var move_speed_multiplier := 1.0

var dash_duration := 0.45
var dash_timer := 0.0
var dash_speed := 14.0
var dash_direction := Vector3.ZERO
var dash_cooldown_range := Vector2(5.0, 8.0)
var dash_cooldown := 0.0
var dash_trigger_distance := Vector2(7.0, 16.0)

var damage_flash_duration := 0.25
var damage_flash_timer := 0.0
var damage_flash_active := false
var mesh_nodes: Array = []
var mesh_default_colors: Array = []
var mesh_materials: Array = []
var damage_flash_color := Color(1.0, 0.2, 0.2)

var current_time_scale: float = 1.0
var is_active := false
var default_collision_layer: int = 0
var default_collision_mask: int = 0

# Health bar styling
var health_stylebox: StyleBoxFlat

# Fade out
var is_dying := false
var fade_timer := 0.0
var fade_duration := 2.0
var death_spawned := false
var death_spawn_position := Vector3.ZERO

func _ready():
	anim_player.play("01_Idle_Aggressive")
	call_deferred("_find_player")
	
	default_collision_layer = collision_layer
	default_collision_mask = collision_mask
	
	# Set up attack area to detect player
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_entered)
		attack_area.body_exited.connect(_on_attack_area_exited)
	
	# Add boss to a group so player can detect it
	add_to_group("enemies")
	
	# Set up health bar styling
	_setup_health_bar()
	update_health_ui()
	
	# Hide health bar initially
	if health_bar:
		health_bar.visible = false

	strafe_timer = randf_range(strafe_duration_range.x, strafe_duration_range.y)
	reposition_cooldown = randf_range(reposition_interval.x, reposition_interval.y)
	dash_cooldown = randf_range(dash_cooldown_range.x, dash_cooldown_range.y)
	_cache_boss_meshes()
	_set_current_time_scale(1.0)
	call_deferred("_snap_to_ground")
	_set_active_state(false)


func _snap_to_ground() -> void:
	if not is_inside_tree():
		return
	var space_state := get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3.UP * 10.0
	var to: Vector3 = global_position + Vector3.DOWN * 500.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := space_state.intersect_ray(query)
	if result:
		var hit_position: Vector3 = result.position
		var desired_height: float = maxf(hit_position.y + 0.5, 50.0)
		global_position = Vector3(hit_position.x, desired_height, hit_position.z)
		velocity = Vector3.ZERO
		print("[Boss] Snapped to ground at ", global_position)
	else:
		global_position.y = maxf(global_position.y, 50.0)
		print("[Boss] No ground detected beneath boss (", from, " -> ", to, ") | Forcing height to ", global_position.y)


func _set_active_state(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	if alien_instance:
		alien_instance.visible = active
	if attack_area:
		attack_area.monitoring = active
	if not active and health_bar:
		health_bar.visible = false
	if not active and health_label:
		health_label.visible = false
	if active:
		collision_layer = default_collision_layer
		collision_mask = default_collision_mask
	else:
		collision_layer = 0
		collision_mask = 0
	velocity = Vector3.ZERO
	print("[Boss] Active state set to ", active)

func _find_player():
	# Try to get autoloaded Player
	player = get_node_or_null("/root/Player")
	
	if player:
		print("✅ Boss found autoloaded player: ", player.name)
		_connect_player_signals()
		_update_activation_state()
		return
	
	# If no autoload, search the scene for player group
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame to ensure player is ready
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("✅ Boss found player in scene: ", player.name)
		_connect_player_signals()
		_update_activation_state()
	else:
		print("❌ WARNING: Boss couldn't find player!")


func _connect_player_signals() -> void:
	if not player:
		return
	if not player.has_signal("gem_time_changed"):
		return
	if player.gem_time_changed.is_connected(_on_player_gem_time_changed):
		return
	player.gem_time_changed.connect(_on_player_gem_time_changed)
	if player.has_signal("inventory_changed") and not player.inventory_changed.is_connected(_on_player_inventory_changed):
		player.inventory_changed.connect(_on_player_inventory_changed)
	_on_player_gem_time_changed(player.gem_active, player.gem_time_scale)


func _exit_tree() -> void:
	if player and player.has_signal("gem_time_changed") and player.gem_time_changed.is_connected(_on_player_gem_time_changed):
		player.gem_time_changed.disconnect(_on_player_gem_time_changed)
	if player and player.has_signal("inventory_changed") and player.inventory_changed.is_connected(_on_player_inventory_changed):
		player.inventory_changed.disconnect(_on_player_inventory_changed)


func _on_player_gem_time_changed(active: bool, time_scale: float) -> void:
	_set_current_time_scale(time_scale if active else 1.0)
	_update_activation_state()


func _on_player_inventory_changed() -> void:
	_update_activation_state()


func _update_activation_state() -> void:
	if not player or not player.has_method("has_gem_of_wit"):
		_set_active_state(false)
		return
	_set_active_state(player.has_gem_of_wit())


func _set_current_time_scale(scale: float) -> void:
	var clamped: float = clampf(scale, 0.05, 1.0)
	current_time_scale = clamped
	if anim_player:
		anim_player.speed_scale = clamped


func _physics_process(delta):
	if is_dying:
		_handle_death_fade(delta)
		return
		
	if not is_active:
		return
	
	if health <= 0:
		_die()
		return

	if not player or not is_instance_valid(player):
		print("WARNING: Player reference lost!")
		return

	var scaled_delta: float = delta * current_time_scale

	var to_player = player.global_position - global_position
	var distance = to_player.length()
	
	# Show/hide health bar based on distance
	_update_healthbar_visibility(distance)
	
	# DEBUG: Print distance every second
	if Engine.get_frames_drawn() % 60 == 0:
		print("Distance: ", distance, " | State: ", State.keys()[state], " | Attack Timer: ", "%.2f" % attack_timer)
		print("Boss position: ", global_transform.origin)

	attack_timer -= scaled_delta
	_update_damage_flash(scaled_delta)
	_update_combat_behavior(scaled_delta, to_player, distance)
	
	# Apply gravity to keep boss on ground
	if not is_on_floor():
		velocity.y -= gravity * scaled_delta
	else:
		velocity.y = 0.0  # Reset vertical velocity when on ground

	# --- State machine ---
	match state:
		State.IDLE:
			move_speed_multiplier = 1.0
			velocity.x = 0
			velocity.z = 0
			anim_player.play("01_Idle_Aggressive")
			
			if distance <= detection_radius:
				print("Player detected! Switching to CHASE")
				state = State.CHASE

		State.PATROL:
			move_speed_multiplier = 1.0
			if distance <= detection_radius:
				print("Player detected during patrol! Switching to CHASE")
				state = State.CHASE
				reposition_target = Vector3.ZERO
			else:
				_patrol(scaled_delta)

		State.CHASE:
			move_speed_multiplier = chase_speed_multiplier
			if distance > detection_radius:
				print("Player out of range, returning to PATROL")
				state = State.PATROL
				patrol_target = Vector3.ZERO  # Reset patrol
				reposition_target = Vector3.ZERO
			elif distance <= attack_range:
				# Stop moving when in attack range
				velocity.x = 0
				velocity.z = 0
				
				# Face the player
				var to_player_2d = player.global_position - global_position
				to_player_2d.y = 0
				if to_player_2d.length() > 0.01:
					var target_rotation = atan2(to_player_2d.x, to_player_2d.z)
					rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * scaled_delta)
				
				# Attack if cooldown is ready
				if attack_timer <= 0:
					print("Player in attack range! Distance: ", distance)
					_attack_player()
					attack_timer = attack_cooldown
				else:
					# Play idle while waiting for cooldown
					if not anim_player.is_playing() or anim_player.current_animation == "01_Run":
						anim_player.play("01_Idle_Aggressive")
			else:
				_approach_player(to_player, distance, scaled_delta)
	
	# Always move and slide (includes gravity)
	if dash_timer > 0.0:
		dash_timer -= scaled_delta
		velocity = dash_direction * dash_speed * current_time_scale
		if dash_timer <= 0.0:
			dash_direction = Vector3.ZERO
	move_and_slide()

func _move_toward_player(direction: Vector3, delta: float):
	# Check if next position would be in bounds (if using restricted area)
	var next_pos = global_position + direction * speed * delta * move_speed_multiplier
	
	if use_restricted_area and not restricted_area.has_point(next_pos):
		print("WARNING: Next position out of bounds: ", next_pos)
		velocity.x = 0
		velocity.z = 0
		anim_player.play("01_Idle_Aggressive")
		return
	
	# Smoothly rotate to face the direction of movement
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	
	# Only set horizontal velocity (gravity handles vertical)
	var effective_speed = speed * move_speed_multiplier * current_time_scale
	velocity.x = direction.x * effective_speed
	velocity.z = direction.z * effective_speed
	
	# Only play run animation if not already playing an attack
	var current_anim = anim_player.current_animation
	if not current_anim.begins_with("01_Attack"):
		anim_player.play("01_Run")


func _approach_player(to_player: Vector3, distance: float, delta: float):
	var direction = to_player.normalized()
	if reposition_target != Vector3.ZERO:
		if global_position.distance_to(reposition_target) > 1.0:
			direction = (reposition_target - global_position).normalized()
		else:
			reposition_target = Vector3.ZERO
	elif is_strafing:
		var right = Vector3.UP.cross(direction).normalized()
		if right.length() > 0.01:
			direction = (direction + right * strafe_direction * 0.7).normalized()
	_move_toward_player(direction, delta)


func _update_combat_behavior(delta: float, to_player: Vector3, distance: float):
	if state != State.CHASE:
		is_strafing = false
		reposition_target = Vector3.ZERO
		strafe_timer = randf_range(strafe_duration_range.x, strafe_duration_range.y)
		return

	var desired_strafe = distance > attack_range * 0.8 and distance < detection_radius * 0.9
	if desired_strafe:
		strafe_timer -= delta
		if strafe_timer <= 0.0:
			is_strafing = randf() > 0.3
			if randf() > 0.5:
				strafe_direction = 1
			else:
				strafe_direction = -1
			strafe_timer = randf_range(strafe_duration_range.x, strafe_duration_range.y)
	else:
		is_strafing = false

	reposition_cooldown -= delta
	if reposition_cooldown <= 0.0:
		reposition_cooldown = randf_range(reposition_interval.x, reposition_interval.y)
		var candidate = _choose_reposition_target(to_player)
		if candidate != Vector3.ZERO:
			reposition_target = candidate

	if dash_timer <= 0.0:
		dash_cooldown -= delta
		if dash_cooldown <= 0.0 and distance > dash_trigger_distance.x and distance < dash_trigger_distance.y:
			dash_cooldown = randf_range(dash_cooldown_range.x, dash_cooldown_range.y)
			dash_timer = dash_duration
			dash_direction = to_player.normalized()
			move_speed_multiplier = chase_speed_multiplier * 1.2


func _choose_reposition_target(to_player: Vector3) -> Vector3:
	if not player:
		return Vector3.ZERO
	var forward = to_player.normalized()
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	var right = forward.cross(Vector3.UP).normalized()
	var player_pos = player.global_position
	var candidates = [
		player_pos + right * 6.0,
		player_pos - right * 6.0,
		player_pos - forward * 4.0,
		player_pos - forward * 3.0 + right * 3.0,
		player_pos - forward * 3.0 - right * 3.0
	]
	var best = Vector3.ZERO
	var best_score := -1.0e20
	for candidate in candidates:
		candidate.y = global_position.y
		if use_restricted_area and not restricted_area.has_point(candidate):
			continue
		var score = -candidate.distance_to(global_position) + randf_range(0.0, 2.0)
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _attack_player():
	# Stop movement during attack
	velocity.x = 0
	velocity.z = 0
	
	# Face the player when attacking
	var to_player = player.global_position - global_position
	to_player.y = 0  # Keep rotation on horizontal plane
	if to_player.length() > 0.01:
		var target_rotation = atan2(to_player.x, to_player.z)
		rotation.y = target_rotation
	
	bite_count += 1
	var damage_ratio = bite_damage_ratio
	var attack_anim = "01_Attack_Bite_B"

	if bite_count >= swipe_every_bites:
		damage_ratio = swipe_damage_ratio
		attack_anim = "01_Attack_Hit"
		bite_count = 0

	print("Boss attacking with: ", attack_anim)
	
	# Force play the animation (stop current one first)
	anim_player.stop()
	anim_player.play(attack_anim)
	
	# Wait for attack animation to reach damage frame (usually mid-animation)
	await get_tree().create_timer(0.5).timeout

	# Deal damage to player if they're still in range
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range and distance > 0.01:  # Avoid zero-distance errors
			var damage = player.max_health * damage_ratio
			if player.blocking:
				damage *= 0.5
			
			# Calculate knockback: direction away from boss, with upward component for realism
			var knockback_direction = (player.global_position - global_position).normalized()
			var knockback_strength = 2.0  # Knockback distance in units
			var knockback_force = Vector3(knockback_direction.x * 30, 0.5, knockback_direction.z) * knockback_strength  # Emphasize x-component for horizontal push
			
			player.take_damage(int(damage), knockback_force)
			print("Dealt ", damage, " damage to player with knockback: ", knockback_force)  # Enhanced debug
		else:
			print("Attack missed or too close: Distance = ", distance)  # Debug: Explain misses

func take_damage(amount: float):
	health -= amount
	if health < 0:
		health = 0
	print("Boss took ", amount, " damage. Health: ", health)
	update_health_ui()
	_trigger_damage_flash()

func _die():
	if is_dying:
		return
		
	print("Boss died!")
	is_dying = true
	death_spawn_position = global_position
	
	# Play death animation
	anim_player.play("01_Die_1")
	
	# Start fade out
	fade_timer = fade_duration

func _handle_death_fade(delta: float):
	fade_timer -= delta
	if alien_instance:
		alien_instance.translate(Vector3.UP * evaporate_rise_speed * delta)
		var t: float = max(fade_timer / fade_duration, evaporate_scale_min)
		alien_instance.scale = Vector3.ONE * t
	
	if fade_timer <= 0:
		if not death_spawned:
			_spawn_death_scene()
		queue_free()
		return
	
	# Calculate fade alpha
	var alpha = fade_timer / fade_duration
	
	# Fade out the mesh
	if alien_instance:
		for child in alien_instance.get_children():
			if child is MeshInstance3D:
				var mat = child.get_active_material(0)
				if mat:
					# Create a new material if it's not already a StandardMaterial3D
					if not mat is StandardMaterial3D:
						mat = StandardMaterial3D.new()
						child.set_surface_override_material(0, mat)
					
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = alpha

func _patrol(delta: float):
	# Handle waiting state
	if is_waiting:
		patrol_wait_timer -= delta
		velocity.x = 0
		velocity.z = 0
		
		if not anim_player.is_playing() or anim_player.current_animation == "01_Run":
			anim_player.play("01_Idle_Aggressive")
		
		if patrol_wait_timer <= 0:
			is_waiting = false
			patrol_target = Vector3.ZERO  # Get new target
		return
	
	# Get new patrol target if needed
	if patrol_target == Vector3.ZERO or global_position.distance_to(patrol_target) < 2.0:
		# Randomly decide to wait or move
		if randf() > 0.6:  # 40% chance to wait
			is_waiting = true
			patrol_wait_timer = randf_range(2.0, 5.0)  # Wait 2-5 seconds
			print("Boss waiting for: ", patrol_wait_timer, " seconds")
			return
		
		if use_restricted_area:
			var min_bound = restricted_area.position
			var max_bound = restricted_area.position + restricted_area.size
			patrol_target = Vector3(
				randf_range(min_bound.x, max_bound.x),
				global_position.y,
				randf_range(min_bound.z, max_bound.z)
			)
		else:
			# Patrol in a larger area around spawn point
			patrol_target = global_position + Vector3(
				randf_range(-15, 15),
				0,
				randf_range(-15, 15)
			)
		print("New patrol target: ", patrol_target)
	
	var dir = (patrol_target - global_position).normalized()
	var next_pos = global_position + dir * speed * delta
	
	if use_restricted_area and not restricted_area.has_point(next_pos):
		velocity.x = 0
		velocity.z = 0
		patrol_target = Vector3.ZERO  # Get new target
		return
	
	# Rotate to face patrol direction
	if dir.length() > 0.01:
		var target_rotation = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	
	velocity.x = dir.x * speed * 0.5  # Patrol at half speed
	velocity.z = dir.z * speed * 0.5
	
	# Play run animation while moving
	if not anim_player.is_playing() or anim_player.current_animation == "01_Idle_Aggressive":
		anim_player.play("01_Run")


func _cache_boss_meshes():
	mesh_nodes.clear()
	mesh_default_colors.clear()
	mesh_materials.clear()
	if not alien_instance:
		return
	_collect_meshes(alien_instance)


func _collect_meshes(node: Node):
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child
			var material = mesh.get_active_material(0)
			if not material:
				material = StandardMaterial3D.new()
				material.albedo_color = Color(1, 1, 1, 1)
				mesh.set_surface_override_material(0, material)
			mesh_nodes.append(mesh)
			mesh_materials.append(material)
			mesh_default_colors.append(material.albedo_color)
		_collect_meshes(child)


func _spawn_death_scene() -> void:
	death_spawned = true
	if not death_spawn_scene:
		return
	var instance = death_spawn_scene.instantiate()
	if not instance:
		return
	var parent = get_parent()
	if parent:
		parent.add_child(instance)
		if instance is Node3D:
			instance.global_transform = global_transform


func _trigger_damage_flash():
	if mesh_materials.is_empty():
		return
	damage_flash_timer = damage_flash_duration
	damage_flash_active = true
	for material in mesh_materials:
		material.albedo_color = damage_flash_color


func _update_damage_flash(delta: float):
	if not damage_flash_active:
		return
	damage_flash_timer -= delta
	if damage_flash_timer <= 0.0:
		_reset_mesh_colors()
		damage_flash_active = false


func _reset_mesh_colors():
	for i in range(mesh_materials.size()):
		var material = mesh_materials[i]
		if material and i < mesh_default_colors.size():
			material.albedo_color = mesh_default_colors[i]


# Called when player enters attack range
func _on_attack_area_entered(body):
	if body == player:
		print("Player entered boss attack range")


# Called when player exits attack range
func _on_attack_area_exited(body):
	if body == player:
		print("Player left boss attack range")


# Health bar UI functions
func _setup_health_bar():
	health_stylebox = StyleBoxFlat.new()
	health_stylebox.corner_radius_top_left = 10
	health_stylebox.corner_radius_top_right = 10
	health_stylebox.corner_radius_bottom_left = 10
	health_stylebox.corner_radius_bottom_right = 10
	
	var health_bg_stylebox = StyleBoxFlat.new()
	health_bg_stylebox.bg_color = Color(0.2, 0.0, 0.0, 0.8)  # Dark red background
	health_bg_stylebox.corner_radius_top_left = 10
	health_bg_stylebox.corner_radius_top_right = 10
	health_bg_stylebox.corner_radius_bottom_left = 10
	health_bg_stylebox.corner_radius_bottom_right = 10
	
	if health_bar:
		health_bar.add_theme_stylebox_override("fill", health_stylebox)
		health_bar.add_theme_stylebox_override("background", health_bg_stylebox)


func update_health_ui():
	if health_bar and health_stylebox:
		health_bar.value = health
		var ratio := health / max_health
		
		# Color gradient based on health
		if ratio > 0.5:
			health_stylebox.bg_color = Color.GREEN.lerp(Color.YELLOW, (1.0 - ratio) * 2.0)
		else:
			health_stylebox.bg_color = Color.YELLOW.lerp(Color.RED, (1.0 - ratio) * 2.0)
	
	if health_label:
		health_label.text = "Boss: %d / %d" % [int(health), int(max_health)]


func _update_healthbar_visibility(distance_to_player: float):
	if not health_bar:
		return
	
	# Show health bar only when player is within 50 units
	var should_show = distance_to_player <= healthbar_show_radius
	
	if health_bar.visible != should_show:
		health_bar.visible = should_show
