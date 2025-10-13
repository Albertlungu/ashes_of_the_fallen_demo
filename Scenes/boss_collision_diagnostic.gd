extends Node
# Boss Collision Diagnostic Script
# Attach this to your main scene or any Node in the scene tree
# It will run diagnostics on the boss and terrain to find collision issues

func _ready():
	# Wait a few frames for everything to load
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("\n============================================================")
	print("🔍 BOSS COLLISION DIAGNOSTIC REPORT")
	print("============================================================\n")
	
	_check_boss()
	_check_terrain()
	_check_player()
	_test_raycast()
	
	print("\n============================================================")
	print("📋 DIAGNOSTIC COMPLETE")
	print("============================================================\n")


func _check_boss():
	print("🦖 BOSS CHECKS:")
	print("----------------------------------------")
	
	var boss = get_tree().get_first_node_in_group("enemies")
	if not boss:
		print("❌ CRITICAL: Boss not found in 'enemies' group!")
		print("   Solution: Make sure boss.gd adds boss to group with add_to_group('enemies')")
		return
	
	print("✅ Boss found: ", boss.name)
	print("   Position: ", boss.global_position)
	
	if not boss is CharacterBody3D:
		print("❌ CRITICAL: Boss is not a CharacterBody3D!")
		return
	
	print("✅ Boss is CharacterBody3D")
	
	# Check collision layers
	var boss_body = boss as CharacterBody3D
	print("   Collision Layer: ", boss_body.collision_layer, " (binary: ", _to_binary(boss_body.collision_layer), ")")
	print("   Collision Mask: ", boss_body.collision_mask, " (binary: ", _to_binary(boss_body.collision_mask), ")")
	
	if boss_body.collision_layer == 0:
		print("   ⚠️  WARNING: Boss collision layer is 0 (won't be detected by others)")
	if boss_body.collision_mask == 0:
		print("   ❌ CRITICAL: Boss collision mask is 0 (can't detect anything!)")
		print("      Solution: Set collision mask to include terrain layer (usually layer 1)")
	
	# Check for CollisionShape3D
	var collision_shape = null
	for child in boss_body.get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break
	
	if not collision_shape:
		print("❌ CRITICAL: Boss has NO CollisionShape3D child!")
		print("   Solution: Add a CollisionShape3D as a child of the boss CharacterBody3D")
		print("   Recommended: CapsuleShape3D or BoxShape3D")
	else:
		print("✅ Boss has CollisionShape3D: ", collision_shape.name)
		if collision_shape.shape == null:
			print("   ❌ CRITICAL: CollisionShape3D has NO shape assigned!")
			print("      Solution: Assign a CapsuleShape3D or BoxShape3D in inspector")
		else:
			print("   ✅ Shape assigned: ", collision_shape.shape.get_class())
			if collision_shape.disabled:
				print("   ❌ CRITICAL: CollisionShape3D is DISABLED!")
				print("      Solution: Enable the collision shape in inspector")
			else:
				print("   ✅ CollisionShape3D is enabled")
	
	# Check floor detection
	print("   is_on_floor(): ", boss_body.is_on_floor())
	if not boss_body.is_on_floor():
		print("   ⚠️  Boss is NOT on floor (may be falling)")
	
	print()


func _check_terrain():
	print("🏔️ TERRAIN CHECKS:")
	print("----------------------------------------")
	
	# Check for Terrain3D
	var terrain = get_tree().current_scene.find_child("Terrain3D", true, false)
	if terrain:
		print("✅ Terrain3D found: ", terrain.name)
		print("   Position: ", terrain.global_position if terrain is Node3D else "N/A")
		
		# Check if it's a StaticBody3D or has collision
		if terrain is StaticBody3D:
			var static_body = terrain as StaticBody3D
			print("   Type: StaticBody3D")
			print("   Collision Layer: ", static_body.collision_layer, " (binary: ", _to_binary(static_body.collision_layer), ")")
			print("   Collision Mask: ", static_body.collision_mask, " (binary: ", _to_binary(static_body.collision_mask), ")")
			
			if static_body.collision_layer == 0:
				print("   ❌ CRITICAL: Terrain collision layer is 0 (invisible to physics!)")
				print("      Solution: Set terrain collision layer to 1 or 4")
		else:
			print("   Type: ", terrain.get_class())
			print("   ℹ️  Terrain3D plugin may handle collision differently")
			print("      Check plugin settings for collision generation")
	else:
		print("⚠️  Terrain3D not found")
	
	# Check for any StaticBody3D (ground plane)
	var static_bodies = []
	_find_static_bodies(get_tree().current_scene, static_bodies)
	
	if static_bodies.size() > 0:
		print("\n📦 Found ", static_bodies.size(), " StaticBody3D nodes (potential ground):")
		for body in static_bodies:
			print("   - ", body.name)
			print("     Layer: ", body.collision_layer, " Mask: ", body.collision_mask)
			
			var has_collision = false
			for child in body.get_children():
				if child is CollisionShape3D:
					has_collision = true
					var shape = child as CollisionShape3D
					if shape.shape:
						print("     ✅ Has collision shape: ", shape.shape.get_class())
					else:
						print("     ❌ CollisionShape3D has no shape!")
			
			if not has_collision:
				print("     ❌ No CollisionShape3D found!")
	else:
		print("⚠️  No StaticBody3D nodes found (no physics ground)")
		print("   If using Terrain3D plugin, check if collision is enabled in terrain settings")
	
	print()


func _find_static_bodies(node: Node, list: Array):
	if node is StaticBody3D:
		list.append(node)
	for child in node.get_children():
		_find_static_bodies(child, list)


func _check_player():
	print("🎮 PLAYER CHECKS:")
	print("----------------------------------------")
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("⚠️  Player not found in 'player' group")
		return
	
	print("✅ Player found: ", player.name)
	print("   Position: ", player.global_position)
	
	if player is CharacterBody3D:
		var player_body = player as CharacterBody3D
		print("   is_on_floor(): ", player_body.is_on_floor())
		
		if player_body.is_on_floor():
			print("   ✅ Player IS on floor (collision working for player)")
		else:
			print("   ❌ Player is NOT on floor (player also has collision issues!)")
	
	print()


func _test_raycast():
	print("🎯 RAYCAST TESTS:")
	print("----------------------------------------")
	
	var boss = get_tree().get_first_node_in_group("enemies")
	if not boss:
		print("❌ Cannot test raycast - boss not found")
		return
	
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var boss_pos = boss.global_position
	
	print("Testing raycast from boss position...")
	print("   From: ", boss_pos + Vector3.UP * 10.0)
	print("   To: ", boss_pos + Vector3.DOWN * 500.0)
	
	# Test 1: Boss's current collision mask
	var query1 = PhysicsRayQueryParameters3D.create(
		boss_pos + Vector3.UP * 10.0,
		boss_pos + Vector3.DOWN * 500.0
	)
	query1.collide_with_areas = false
	query1.collide_with_bodies = true
	if boss is CharacterBody3D:
		query1.collision_mask = (boss as CharacterBody3D).collision_mask
	
	var result1 = space_state.intersect_ray(query1)
	
	if result1.is_empty():
		print("❌ TEST 1: Boss collision mask detected NOTHING")
		print("   Current mask: ", (boss as CharacterBody3D).collision_mask if boss is CharacterBody3D else "N/A")
	else:
		print("✅ TEST 1: Boss collision mask detected ground!")
		print("   Hit: ", result1.collider.name if result1.collider else "Unknown")
		print("   Position: ", result1.position)
		print("   Distance: ", boss_pos.distance_to(result1.position), " units")
	
	# Test 2: All layers
	var query2 = PhysicsRayQueryParameters3D.create(
		boss_pos + Vector3.UP * 10.0,
		boss_pos + Vector3.DOWN * 500.0
	)
	query2.collide_with_areas = false
	query2.collide_with_bodies = true
	query2.collision_mask = 0xFFFFFFFF  # All layers
	
	var result2 = space_state.intersect_ray(query2)
	
	if result2.is_empty():
		print("❌ TEST 2: ALL layers detected NOTHING")
		print("   ⚠️  This means there is NO collision geometry below the boss at all!")
		print("   Solution: Add a ground plane with StaticBody3D + CollisionShape3D")
	else:
		print("✅ TEST 2: All-layer raycast detected ground!")
		print("   Hit: ", result2.collider.name if result2.collider else "Unknown")
		print("   Collider type: ", result2.collider.get_class() if result2.collider else "Unknown")
		print("   Collider layer: ", result2.collider.collision_layer if result2.collider is CollisionObject3D else "N/A")
		
		if result1.is_empty() and not result2.is_empty():
			print("\n💡 DIAGNOSIS: Ground exists but boss mask doesn't include it!")
			print("   The ground is on layer: ", result2.collider.collision_layer if result2.collider is CollisionObject3D else "Unknown")
			print("   Boss mask should include this layer")
			print("   SOLUTION: Set boss collision_mask to include layer ", _get_first_layer(result2.collider.collision_layer if result2.collider is CollisionObject3D else 1))
	
	print()


func _to_binary(num: int) -> String:
	var binary = ""
	for i in range(32):
		if num & (1 << i):
			binary = "1" + binary
		else:
			binary = "0" + binary
	# Trim leading zeros for readability
	binary = binary.trim_prefix("0")
	if binary == "":
		return "0"
	return binary


func _get_first_layer(mask: int) -> int:
	for i in range(32):
		if mask & (1 << i):
			return i + 1
	return 1


func _process(delta):
	# Show real-time status in output every second
	if Engine.get_frames_drawn() % 60 == 0:
		var boss = get_tree().get_first_node_in_group("enemies")
		if boss and boss is CharacterBody3D:
			var boss_body = boss as CharacterBody3D
			
			# Check if boss is falling through world
			if boss.global_position.y < -50:
				print("\n⚠️⚠️⚠️ BOSS IS FALLING THROUGH WORLD! ⚠️⚠️⚠️")
				print("Current Y position: ", boss.global_position.y)
				print("This indicates collision is not working properly!")
				_perform_deep_diagnosis()
			
			print("[LIVE] Boss Y: %.2f | On Floor: %s | Velocity Y: %.2f" % [
				boss.global_position.y,
				boss_body.is_on_floor(),
				boss_body.velocity.y
			])


func _perform_deep_diagnosis():
	print("\n🔬 DEEP DIAGNOSIS - CHECKING PHYSICS ISSUES:")
	print("============================================================")
	
	var boss = get_tree().get_first_node_in_group("enemies")
	if not boss or not boss is CharacterBody3D:
		return
	
	var boss_body = boss as CharacterBody3D
	
	# Check 1: Is move_and_slide being called?
	print("\n1️⃣ Checking if boss physics is processing...")
	print("   Boss physics_process enabled: ", not boss.is_physics_processing())
	if not boss.is_physics_processing():
		print("   ❌ CRITICAL: Boss physics is NOT processing!")
		print("      Solution: Make sure set_physics_process(false) is not being called")
	
	# Check 2: Collision shape position
	print("\n2️⃣ Checking collision shape position...")
	var collision_shape = null
	for child in boss_body.get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break
	
	if collision_shape:
		print("   Shape global position: ", collision_shape.global_position)
		print("   Shape local position: ", collision_shape.position)
		
		# Check if shape is way below the boss
		if collision_shape.position.y < -5:
			print("   ⚠️ WARNING: Collision shape is positioned below the boss!")
			print("      This can cause floor detection issues")
	
	# Check 3: Floor detection parameters
	print("\n3️⃣ Checking CharacterBody3D floor detection...")
	print("   floor_stop_on_slope: ", boss_body.floor_stop_on_slope)
	print("   floor_max_angle: ", rad_to_deg(boss_body.floor_max_angle), " degrees")
	print("   floor_snap_length: ", boss_body.floor_snap_length)
	
	if boss_body.floor_snap_length < 0.1:
		print("   ⚠️ WARNING: floor_snap_length is too small!")
		print("      Increase to at least 0.5 for better floor detection")
	
	# Check 4: Velocity issues
	print("\n4️⃣ Checking velocity...")
	print("   Current velocity: ", boss_body.velocity)
	print("   Velocity magnitude: ", boss_body.velocity.length())
	
	if boss_body.velocity.y < -50:
		print("   ⚠️ WARNING: Boss is falling very fast!")
		print("      Gravity may be too high or something is forcing downward velocity")
	
	# Check 5: Check for interfering scripts
	print("\n5️⃣ Checking for script issues...")
	var scripts = boss.get_script()
	if scripts:
		print("   Boss has script attached: ", scripts.resource_path)
	
	# Check 6: Collision exceptions
	print("\n6️⃣ Checking collision exceptions...")
	var exception_count = boss_body.get_collision_exceptions().size()
	print("   Collision exceptions: ", exception_count)
	if exception_count > 0:
		print("   Exceptions list:")
		for exception in boss_body.get_collision_exceptions():
			print("     - ", exception.name if exception else "null")
	
	# Check 7: Test manual collision at current position
	print("\n7️⃣ Testing collision at current position...")
	var space_state = get_tree().root.get_world_3d().direct_space_state
	
	# Shape cast downward
	var shape_rid = PhysicsServer3D.capsule_shape_create()
	PhysicsServer3D.shape_set_data(shape_rid, {"radius": 1.0, "height": 2.0})
	
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape_rid = shape_rid
	params.transform = boss.global_transform
	params.motion = Vector3.DOWN * 10.0
	params.collision_mask = 0xFFFFFFFF
	
	var result = space_state.cast_motion(params)
	print("   Shape cast result: ", result)
	
	if result[0] == 1.0:
		print("   ❌ CRITICAL: No collision detected below boss!")
		print("      The boss is in free space with no ground underneath")
	else:
		print("   ✅ Collision detected at: ", result[0] * 100, "% of motion")
	
	PhysicsServer3D.free_rid(shape_rid)
	
	# Check 8: Terrain3D specific checks
	print("\n8️⃣ Checking Terrain3D plugin collision...")
	var terrain = get_tree().current_scene.find_child("Terrain3D", true, false)
	if terrain:
		print("   Terrain3D found")
		# Check if Terrain3D has collision enabled
		if terrain.has_method("get_collision_enabled"):
			print("   Collision enabled: ", terrain.get_collision_enabled())
		else:
			print("   ℹ️  Cannot check Terrain3D collision settings directly")
			print("      Make sure 'Show Collision' is enabled in Terrain3D settings")
	
	print("\n============================================================")
	print("🔬 DEEP DIAGNOSIS COMPLETE")
	print("============================================================\n")
