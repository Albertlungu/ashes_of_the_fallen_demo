extends Area3D

@export var item_data: ItemData
@export var slot_data: SlotData

var player_in_range = false
var player: CharacterBody3D = null

@onready var label: Label3D = $PickupLabel
@onready var mesh: Node3D = $GemModel


func _ready() -> void:
	if label:
		label.visible = false
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player = body
		if label:
			label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player = null
		if label:
			label.visible = false


func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		pickup()


func pickup() -> void:
	if player and player.has_method("pickup_gem"):
		if player.pickup_gem(slot_data):
			queue_free()
