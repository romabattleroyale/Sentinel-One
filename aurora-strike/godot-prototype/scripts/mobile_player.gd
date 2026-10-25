extends CharacterBody3D

@export var move_speed := 7.0
@export var jump_velocity := 5.5
@export var look_sensitivity := 0.006
var gravity := 18.0
var move_input := Vector2.ZERO
var look_delta := Vector2.ZERO
var jump_requested := false
var pitch := 0.0
var camera: Camera3D

func _ready() -> void:
	camera = get_node_or_null("Camera3D")
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_requested:
		velocity.y = jump_velocity
	jump_requested = false
	rotate_y(-look_delta.x * look_sensitivity)
	pitch = clamp(pitch - look_delta.y * look_sensitivity, deg_to_rad(-75), deg_to_rad(75))
	if camera:
		camera.rotation.x = pitch
	look_delta = Vector2.ZERO
	var direction := (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	move_and_slide()

func set_move_input(value: Vector2) -> void:
	move_input = value.limit_length(1.0)

func add_look_delta(value: Vector2) -> void:
	look_delta += value

func request_jump() -> void:
	jump_requested = true
