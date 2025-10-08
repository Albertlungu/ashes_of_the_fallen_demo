@tool
extends EditorScript

func _run():
	var root = get_scene()
	
	# Find or create the StaticBody3D
	var static_body = null
	for child in root.get_children():
		if child is StaticBody3D:
			static_body = child
			break
	
	if static_body == null:
		static_body = StaticBody3D.new()
		static_body.name = "BuildingCollision"
		root.add_child(static_body)
		static_body.owner = root
	
	# Add collision shapes for all meshes
	var count = add_collision_to_body(root, static_body)
	print("Added " + str(count) + " collision shapes to StaticBody3D")

func add_collision_to_body(node, static_body):
	var count = 0
	
	if node is MeshInstance3D and node.mesh != null:
		# Create a CollisionShape3D for this mesh
		var collision_shape = CollisionShape3D.new()
		var shape = node.mesh.create_trimesh_shape()
		collision_shape.shape = shape
		
		# Match the transform of the mesh
		collision_shape.transform = node.global_transform
		collision_shape.name = node.name + "_Collision"
		
		static_body.add_child(collision_shape)
		collision_shape.owner = get_scene()
		count += 1
		print("Added collision for: " + node.name)
	
	# Recursively process children
	for child in node.get_children():
		if child != static_body:  # Don't process the StaticBody3D itself
			count += add_collision_to_body(child, static_body)
	
	return count
