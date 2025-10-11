extends CharacterBody3D

@onready var alien_instance: Node3D = $"Alien Animal Baked"
@onready var anim_player: AnimationPlayer = alien_instance.get_node("AnimationPlayer")
@onready var player: Node = Player  # autoloaded player

# --- Stats ---
var max_health := 1000.0
var health := 1000.0
var speed := 4.0

# --- AI ---
var detection_radius := 20.0
var attack_range := 3.0
var attack_cooldown := 1.0
var attack_timer := 0.0
var bite_count := 0
var swipe_every_bites := 5

var restricted_area: AABB = AABB(Vector3(-50,0,-50), Vector3(100,10,100)) # adjust to your map

# --- Attack ratios ---
var bite_damage_ratio := 0.05
var swipe_damage_ratio := 0.10

# --- State ---
enum State { IDLE, PATROL, CHASE, ATTACK }
var state := State.IDLE
var patrol_target: Vector3 = Vector3.ZERO

func _ready():
	anim_player.play("01_Idle_Aggressive")

func _physics_process(delta):
	if health <= 0:
		_die()
		return

	if not player:
		return

	var to_player = player.global_position - global_position
	var distance = to_player.length()

	# Slow-time effect
	var time_multiplier := 1.0
	if player.has_method("gem_active") and player.gem_active:
		time_multiplier = player.gem_time_scale

	attack_timer -= delta * time_multiplier

	# --- State machine ---
	match state:
		State.IDLE:
			anim_player.play("01_Idle_Aggressive")
			if distance <= detection_radius:
				state = State.CHASE
			else:
				_patrol(delta * time_multiplier)

		State.PATROL:
			_patrol(delta * time_multiplier)
			if distance <= detection_radius:
				state = State.CHASE

		State.CHASE:
			if distance > detection_radius:
				state = State.IDLE
			else:
				_move_toward_player(to_player.normalized(), delta * time_multiplier)
				if distance <= attack_range and attack_timer <= 0:
					_attack_player()
					attack_timer = attack_cooldown

func _move_toward_player(direction: Vector3, delta: float):
	var next_pos = global_position + direction * speed * delta
	if restricted_area.has_point(next_pos):
		velocity = direction * speed
		move_and_slide()
		anim_player.play("01_Run")
	else:
		velocity = Vector3.ZERO
		anim_player.play("01_Idle_Aggressive")

func _attack_player():
	bite_count += 1
	var damage_ratio = bite_damage_ratio
	var attack_anim = "01_Attack_Bite_B"

	if bite_count >= swipe_every_bites:
		damage_ratio = swipe_damage_ratio
		attack_anim = "01_Attack_Hit"
		bite_count = 0

	anim_player.play(attack_anim)

	if player.has_method("take_damage"):
		var damage = player.max_health * damage_ratio
		if player.blocking:
			damage *= 0.5
		player.take_damage(damage)

func take_damage(amount: float):
	health -= amount
	if health < 0:
		health = 0

func _die():
	anim_player.play("01_Die_1")
	set_physics_process(false)

func _patrol(delta: float):
	if patrol_target == Vector3.ZERO or global_position.distance_to(patrol_target) < 1.0:
		var min_bound = restricted_area.position
		var max_bound = restricted_area.position + restricted_area.size
		patrol_target = Vector3(
			randf_range(min_bound.x, max_bound.x),
			global_position.y,
			randf_range(min_bound.z, max_bound.z)
		)
	var dir = (patrol_target - global_position).normalized()
	var next_pos = global_position + dir * speed * delta
	if restricted_area.has_point(next_pos):
		velocity = dir * speed
		move_and_slide()
		anim_player.play("01_Run")
	else:
		velocity = Vector3.ZERO
		anim_player.play("01_Idle_Aggressive")
