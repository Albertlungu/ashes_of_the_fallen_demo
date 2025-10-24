# res://autoload/pack_loader.gd
extends Node

func _ready() -> void:
	# Load auxiliary resource packs you exported separately
	# For desktop: these are res://graphics.pck and res://audio.pck
	# For web: see later (you may need to download them first)
	if ProjectSettings.load_resource_pack("res://graphics.pck"):
		print("Loaded graphics.pck")
	else:
		push_warning("Failed to load graphics.pck")

	if ProjectSettings.load_resource_pack("res://audio.pck"):
		print("Loaded audio.pck")
	else:
		push_warning("Failed to load audio.pck")

	# Now switch to actual main scene. In Godot 4 use change_scene_to_file
	get_tree().change_scene_to_file("res://Main.tscn")
