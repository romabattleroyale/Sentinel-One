extends CanvasLayer

var player: CharacterBody3D
var stick_center := Vector2.ZERO
var stick_touch := -1
var look_touch := -1
var jump_button: Button
var stick_base: Control
var stick_knob: Control
var look_area: Control
var radius := 78.0

func _ready() -> void:
	player = get_parent().get_node_or_null("MobilePlayer")
	_build_hud()
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()

func _build_hud() -> void:
	var root := Control.new()
	root.name = "TouchControls"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	look_area = Control.new()
	look_area.name = "LookArea"
	look_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(look_area)
	stick_base = _circle_control(150, Color(0.08, 0.12, 0.16, 0.48))
	stick_base.name = "JoystickBase"
	root.add_child(stick_base)
	stick_knob = _circle_control(72, Color(0.82, 0.88, 0.94, 0.72))
	stick_knob.name = "JoystickKnob"
	root.add_child(stick_knob)
	jump_button = Button.new()
	jump_button.text = "SALTA"
	jump_button.custom_minimum_size = Vector2(108, 76)
	jump_button.add_theme_font_size_override("font_size", 22)
	jump_button.modulate = Color(1, 1, 1, 0.88)
	jump_button.pressed.connect(_on_jump)
	root.add_child(jump_button)
	var hint := Label.new()
	hint.text = "SINISTRA: MUOVI   •   DESTRA: GUARDA"
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.75)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_left = 12
	hint.offset_top = 10
	hint.offset_bottom = 38
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

func _circle_control(diameter: float, color: Color) -> Control:
	var c := ColorRect.new()
	c.custom_minimum_size = Vector2(diameter, diameter)
	c.color = color
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _layout_hud() -> void:
	var size := get_viewport().get_visible_rect().size
	stick_center = Vector2(132, size.y - 132)
	if stick_base:
		stick_base.position = stick_center - Vector2(75, 75)
	if stick_knob:
		stick_knob.position = stick_center - Vector2(36, 36)
	if jump_button:
		jump_button.position = Vector2(size.x - 145, size.y - 120)
	if look_area:
		look_area.position = Vector2(size.x * 0.42, 0)
		look_area.size = Vector2(size.x * 0.58, size.y)

func _input(event: InputEvent) -> void:
	if player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x * 0.45 and stick_touch == -1:
				stick_touch = event.index
				_update_stick(event.position)
			elif event.position.x >= get_viewport().get_visible_rect().size.x * 0.45 and look_touch == -1:
				look_touch = event.index
		else:
			if event.index == stick_touch:
				stick_touch = -1
				player.set_move_input(Vector2.ZERO)
				if stick_knob:
					stick_knob.position = stick_center - Vector2(36, 36)
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == stick_touch:
			_update_stick(event.position)
		elif event.index == look_touch:
			player.add_look_delta(event.relative)

func _update_stick(position: Vector2) -> void:
	var offset := position - stick_center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	player.set_move_input(Vector2(offset.x / radius, offset.y / radius))
	if stick_knob:
		stick_knob.position = stick_center + offset - Vector2(36, 36)

func _on_jump() -> void:
	if player:
		player.request_jump()
