extends CharacterBody3D
@export var walk_speed: float = 7.0
@export var sprint_speed: float = 12.0
@export var jump_velocity: float = 5.2
@export var look_sensitivity: float = 0.0025
var gravity: float = 18.0
var camera_pivot: Node3D
var touch_look_active := false
var last_touch_position := Vector2.ZERO

func _ready() -> void:
	camera_pivot = get_node_or_null("CameraPivot")
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_build_touch_controls()

func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MobileControls"
	get_tree().current_scene.add_child(layer)
	var move_panel := PanelContainer.new()
	move_panel.position = Vector2(22, get_viewport().get_visible_rect().size.y - 208)
	move_panel.custom_minimum_size = Vector2(190,180)
	layer.add_child(move_panel)
	var grid := GridContainer.new()
	grid.columns = 3
	move_panel.add_child(grid)
	for item in [
		{"text":"", "action":""},
		{"text":"▲", "action":"move_forward"},
		{"text":"", "action":""},
		{"text":"◀", "action":"move_left"},
		{"text":"●", "action":""},
		{"text":"▶", "action":"move_right"},
		{"text":"", "action":""},
		{"text":"▼", "action":"move_back"},
		{"text":"", "action":""}
	]:
		var button := Button.new()
		button.text = item.text
		button.custom_minimum_size = Vector2(54,48)
		grid.add_child(button)
		if item.action != "":
			button.button_down.connect(_press_action.bind(item.action))
			button.button_up.connect(_release_action.bind(item.action))
	var jump := Button.new()
	jump.text = "SALTA"
	jump.position = Vector2(get_viewport().get_visible_rect().size.x - 145, get_viewport().get_visible_rect().size.y - 125)
	jump.custom_minimum_size = Vector2(120,60)
	layer.add_child(jump)
	jump.button_down.connect(_press_action.bind("jump"))
	jump.button_up.connect(_release_action.bind("jump"))
	var sprint := Button.new()
	sprint.text = "CORRI"
	sprint.position = Vector2(get_viewport().get_visible_rect().size.x - 145, get_viewport().get_visible_rect().size.y - 195)
	sprint.custom_minimum_size = Vector2(120,55)
	layer.add_child(sprint)
	sprint.button_down.connect(_press_action.bind("sprint"))
	sprint.button_up.connect(_release_action.bind("sprint"))

func _press_action(action: String) -> void:
	Input.action_press(action)

func _release_action(action: String) -> void:
	Input.action_release(action)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and camera_pivot:
		_rotate_camera(event.relative)
	elif event is InputEventScreenTouch:
		touch_look_active = event.pressed
		last_touch_position = event.position
	elif event is InputEventScreenDrag and camera_pivot:
		var delta := event.position - last_touch_position
		last_touch_position = event.position
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
			_rotate_camera(delta)

func _rotate_camera(delta: Vector2) -> void:
	rotate_y(-delta.x * look_sensitivity)
	if camera_pivot:
		camera_pivot.rotate_x(-delta.y * look_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-65), deg_to_rad(35))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var move := Vector2(float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left")), float(Input.is_action_pressed("move_back")) - float(Input.is_action_pressed("move_forward")))
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
