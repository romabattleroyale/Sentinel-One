extends CharacterBody3D
@export var walk_speed: float = 7.0
@export var sprint_speed: float = 12.0
@export var jump_velocity: float = 5.2
@export var look_sensitivity: float = 0.0025
var gravity: float = 18.0
var camera_pivot: Node3D
var touch_move := Vector2.ZERO

func _ready() -> void:
	camera_pivot = get_node_or_null("CameraPivot")
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and camera_pivot:
		rotate_y(-event.relative.x * look_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * look_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-65), deg_to_rad(35))
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var move := Vector2(float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")), float(Input.is_action_pressed("move_back")) - float(Input.is_action_pressed("move_forward")))
	if touch_move.length() > 0.1:
		move = touch_move
	move = move.normalized()
	var direction := (transform.basis * Vector3(move.x,0,move.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x,0,walk_speed*delta*5)
		velocity.z = move_toward(velocity.z,0,walk_speed*delta*5)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	move_and_slide()
