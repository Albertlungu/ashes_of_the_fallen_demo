extends Node3D

@onready var terrain = $Terrain
@onready var tree_multimesh_instance: MultiMeshInstance3D = $TreeMultiMesh
@onready var tree_collision_root = $TreeCollision

const TREE_SCENE = preload("res://ashes-of-the-fallen-assets/Environment/Spruce Tree 3D Model (1).glb")
const TREE_COLLISION_SCENE = preload("res://ashes-of-the-fallen-assets/Environment/Spruce Tree 3D Model (1).glb")
const TREE_COUNT = 200

func _ready():
	spawn_trees_on_terrain()


func spawn_trees_on_terrain():
	# ✅ Create and assign a brand-new MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D

	# ✅ Load the tree mesh from the .glb scene
	var temp_tree_scene = TREE_SCENE.instantiate()
	var mesh_node: MeshInstance3D = temp_tree_scene.get_node_or_null(".")
	if mesh_node and mesh_node.mesh:
		mm.mesh = mesh_node.mesh
	else:
		# Sometimes .glb root is a Node3D with a MeshInstance child
		for child in temp_tree_scene.get_children():
			if child is MeshInstance3D:
				mm.mesh = child.mesh
				break

	# ✅ Now we can safely set instance_count
	mm.instance_count = TREE_COUNT
	tree_multimesh_instance.multimesh = mm

	# ✅ Place trees
	var rng = RandomNumberGenerator.new()
	for i in TREE_COUNT:
		var x = rng.randf_range(-100, 100)
		var z = rng.randf_range(-100, 100)
		var y = terrain.get_height(Vector3(x, 0, z))

		var transform = Transform3D(Basis(), Vector3(x, y, z))
		transform.basis = Basis().rotated(Vector3.UP, rng.randf_range(0, TAU))
		mm.set_instance_transform(i, transform)

		# Optional collisions
		var tree_col = TREE_COLLISION_SCENE.instantiate()
		tree_col.global_position = Vector3(x, y, z)
		tree_collision_root.add_child(tree_col)

	temp_tree_scene.queue_free()  # Clean up
