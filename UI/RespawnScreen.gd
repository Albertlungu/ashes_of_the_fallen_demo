extends CanvasLayer
class_name RespawnScreen

signal respawn_requested(respawn_transform: Transform3D)
signal quit_requested

@export var default_respawn_delay := 5.0
@export var bird_view_height := 25.0
@export var bird_view_angle_offset := Vector3(0.0, 0.0, 0.0)

@onready var root: Control = $Root
@onready var background: TextureRect = $Root/Background
@onready var cause_label: Label = $CauseLabel
@onready var timer_label: Label = $TimerLabel
@onready var respawn_button: Button = $RespawnButton
@onready var quit_button: Button = $QuitButton
@onready var title_label: Label = $Title
@onready var flash_rect: ColorRect = $FlashRect
@onready var panel_body: VBoxContainer = $PanelBody
@onready var buttons_container: HBoxContainer = $Buttons
@onready var animation_player: AnimationPlayer = $Root/AnimationPlayer
@onready var death_viewport: SubViewport = $DeathViewport
@onready var death_camera: Camera3D = $DeathViewport/DeathCamera

var countdown_time := 0.0
var respawn_transform: Transform3D = Transform3D.IDENTITY
var is_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if death_viewport and get_viewport():
		death_viewport.world_3d = get_viewport().world_3d
		death_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_viewport_size()
	if background and death_viewport:
		background.texture = death_viewport.get_texture()
		background.stretch_mode = TextureRect.STRETCH_SCALE
	if respawn_button:
		respawn_button.pressed.connect(_on_respawn_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	hide_screen()

func show_screen(cause: String, death_position: Vector3, death_forward: Vector3, countdown_seconds: float = default_respawn_delay, new_respawn_transform: Transform3D = Transform3D.IDENTITY) -> void:
	respawn_transform = new_respawn_transform
	countdown_time = max(countdown_seconds, 0.0)
	_update_timer_label()
	_update_cause_text(cause)
	_position_death_camera(death_position, death_forward)
	_update_viewport_size()
	is_active = true
	set_process(true)
	_set_ui_visible(true)
	if animation_player and not animation_player.is_playing():
		animation_player.play("idle")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_screen() -> void:
	is_active = false
	set_process(false)
	_set_ui_visible(false)

func set_respawn_transform(new_transform: Transform3D) -> void:
	respawn_transform = new_transform

func set_countdown(seconds: float) -> void:
	countdown_time = max(seconds, 0.0)
	_update_timer_label()

func set_cause_of_death(cause: String) -> void:
	_update_cause_text(cause)

func _process(delta: float) -> void:
	if not is_active:
		return
	if countdown_time > 0.0:
		countdown_time = max(countdown_time - delta, 0.0)
		_update_timer_label()

func _position_death_camera(death_position: Vector3, death_forward: Vector3) -> void:
	if not death_camera:
		return
	var forward := death_forward.normalized()
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	var camera_position := death_position + Vector3(0.0, bird_view_height, 0.0)
	death_camera.global_position = camera_position
	death_camera.look_at(death_position, Vector3.UP)
	if bird_view_angle_offset.length() > 0.0:
		death_camera.rotate_object_local(Vector3.RIGHT, deg_to_rad(bird_view_angle_offset.x))
		death_camera.rotate_object_local(Vector3.UP, deg_to_rad(bird_view_angle_offset.y))
		death_camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(bird_view_angle_offset.z))

func _on_respawn_pressed() -> void:
	emit_signal("respawn_requested", respawn_transform)
	hide_screen()

func _on_quit_pressed() -> void:
	emit_signal("quit_requested")
	hide_screen()

func _update_timer_label() -> void:
	if not timer_label:
		return
	if countdown_time > 0.0:
		timer_label.text = "Respawning in %0.1f" % countdown_time
	else:
		timer_label.text = "Ready to respawn"

func _update_cause_text(cause: String) -> void:
	if not cause_label:
		return
	if cause.strip_edges() == "":
		cause_label.text = "Cause of death: Unknown"
	else:
		cause_label.text = "Cause of death: %s" % cause


func _set_ui_visible(is_visible: bool) -> void:
	if root:
		root.visible = is_visible
	var nodes = [flash_rect, panel_body, title_label, cause_label, timer_label, buttons_container, respawn_button, quit_button]
	for node in nodes:
		if node:
			node.visible = is_visible


func _update_viewport_size() -> void:
	if not death_viewport or not get_viewport():
		return
	var viewport_size = get_viewport().get_visible_rect().size
	death_viewport.size = viewport_size
	if background:
		background.custom_minimum_size = viewport_size
		background.size = viewport_size


func _on_viewport_size_changed() -> void:
	_update_viewport_size()
