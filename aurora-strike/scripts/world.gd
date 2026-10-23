extends Node3D
const MAP_SIZE := 2000.0
const BLOCK_SPACING := 170.0
var rng := RandomNumberGenerator.new()
var player: CharacterBody3D

func _ready() -> void:
	rng.seed = 271023
	_build_environment()
	_build_terrain()
	_build_roads()
	_build_city_blocks()
	_build_landmarks()
	_build_player()
	_build_hud()
	_apply_capture_view()

func _mat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, material: Material, collision := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	if collision:
		var body := StaticBody3D.new()
		body.name = node_name + "_Collision"
		parent.add_child(body)
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position = pos
		body.add_child(shape)
	return node

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.57, 0.68)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)

func _build_terrain() -> void:
	_box(self, "Ground_2km", Vector3(MAP_SIZE, 3, MAP_SIZE), Vector3(0,-1.5,0), _mat(Color(0.19,0.30,0.22)), true)
	_box(self, "Urban_Base", Vector3(1420,1.2,1420), Vector3(0,0.15,0), _mat(Color(0.29,0.31,0.32),0.96), true)
	var water := _mat(Color(0.055,0.23,0.34),0.24,0.12)
	_box(self,"North_Water",Vector3(2000,0.6,290),Vector3(0,-0.4,-855),water)
	_box(self,"South_Water",Vector3(2000,0.6,290),Vector3(0,-0.4,855),water)
	_box(self,"West_Water",Vector3(290,0.6,1420),Vector3(-855,-0.4,0),water)
	_box(self,"East_Water",Vector3(290,0.6,1420),Vector3(855,-0.4,0),water)

func _build_roads() -> void:
	var road := _mat(Color(0.075,0.085,0.095))
	var line := _mat(Color(0.96,0.77,0.32),0.6)
	var sidewalk := _mat(Color(0.52,0.52,0.49))
	for x in [-510.0,-170.0,170.0,510.0]:
		_box(self,"Road_NS",Vector3(24,0.18,1420),Vector3(x,0.85,0),road)
		_box(self,"Sidewalk",Vector3(5,0.25,1420),Vector3(x-15,0.92,0),sidewalk)
		_box(self,"Sidewalk",Vector3(5,0.25,1420),Vector3(x+15,0.92,0),sidewalk)
		for z in range(-680,681,48):
			_box(self,"LaneDash",Vector3(0.35,0.22,18),Vector3(x,0.98,z),line)
	for z in [-510.0,-170.0,170.0,510.0]:
		_box(self,"Road_EW",Vector3(1420,0.18,24),Vector3(0,0.85,z),road)
		_box(self,"Sidewalk",Vector3(1420,0.25,5),Vector3(0,0.92,z-15),sidewalk)
		_box(self,"Sidewalk",Vector3(1420,0.25,5),Vector3(0,0.92,z+15),sidewalk)
		for x in range(-680,681,48):
			_box(self,"LaneDash",Vector3(18,0.22,0.35),Vector3(x,0.98,z),line)

func _build_city_blocks() -> void:
	var palettes: Array[Material] = [
		_mat(Color(0.62,0.56,0.46)), _mat(Color(0.48,0.51,0.52)),
		_mat(Color(0.72,0.67,0.56)), _mat(Color(0.35,0.40,0.43)),
		_mat(Color(0.64,0.43,0.31)), _mat(Color(0.76,0.74,0.66))
	]
	var glass := _mat(Color(0.12,0.25,0.32),0.28,0.22)
	var roof := _mat(Color(0.19,0.20,0.20))
	for gx in range(-3,4):
		for gz in range(-3,4):
			var cx := float(gx) * BLOCK_SPACING
			var cz := float(gz) * BLOCK_SPACING
			if abs(cx) < 70 or abs(cz) < 70:
				continue
			var block := Node3D.new()
			block.name = "Block_%d_%d" % [gx,gz]
			block.position = Vector3(cx,0,cz)
			add_child(block)
			for i in range(rng.randi_range(2,4)):
				var w := rng.randf_range(22,43)
				var d := rng.randf_range(24,42)
				var h := rng.randf_range(12,52)
				var bx := rng.randf_range(-48,48)
				var bz := rng.randf_range(-48,48)
				var body_mat: Material = palettes[rng.randi_range(0,palettes.size()-1)]
				_box(block,"Building_%d" % i,Vector3(w,h,d),Vector3(bx,h/2+1,bz),body_mat,true)
				_box(block,"Roof_%d" % i,Vector3(w+1,1,d+1),Vector3(bx,h+1.5,bz),roof)
				for floor_idx in range(1,int(h/4.0)):
					for side in [-1.0,1.0]:
						_box(block,"WindowBand",Vector3(w*0.68,0.85,0.22),Vector3(bx,h/2+1+float(floor_idx)*3.5,bz+side*(d/2+0.13)),glass)
				if rng.randf() > 0.45:
					_box(block,"Shopfront",Vector3(w*0.72,2.6,0.28),Vector3(bx,2.7,bz+d/2+0.18),glass)

func _build_landmarks() -> void:
	var stone := _mat(Color(0.69,0.62,0.49))
	var dark := _mat(Color(0.15,0.18,0.19),0.55,0.2)
	var red := _mat(Color(0.72,0.19,0.12))
	var station := Node3D.new()
	station.name = "Aurora_Central_Station"
	add_child(station)
	_box(station,"Station_Main_Hall",Vector3(118,20,48),Vector3(0,11,0),stone,true)
	_box(station,"Station_Glass_Front",Vector3(96,12,0.7),Vector3(0,12,24.4),dark)
	_box(station,"Station_Roof",Vector3(126,2,54),Vector3(0,22,0),_mat(Color(0.22,0.25,0.27),0.4,0.35))
	for x in range(-48,49,16):
		_box(station,"Facade_Pillar",Vector3(1.5,15,1.5),Vector3(x,8.5,25),stone)
	_box(station,"Sign_Red",Vector3(30,3,0.6),Vector3(0,18,25.2),red)
	_box(self,"Civic_Tower",Vector3(28,96,28),Vector3(-270,49,270),_mat(Color(0.48,0.53,0.55)),true)
	for y in range(12,94,12):
		_box(self,"Tower_Window_Band",Vector3(28.4,2,28.4),Vector3(-270,float(y),270),dark)
	_box(self,"Tower_Cap",Vector3(34,3,34),Vector3(-270,98,270),stone)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0,3,90)
	add_child(player)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	player.add_child(shape)
	var body := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.52
	capsule_mesh.height = 1.85
	body.mesh = capsule_mesh
	body.position.y = 0.95
	body.material_override = _mat(Color(0.12,0.56,0.82),0.65)
	player.add_child(body)
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position.y = 1.5
	player.add_child(pivot)
	var camera := Camera3D.new()
	camera.position = Vector3(0,2.4,7.5)
	camera.rotation_degrees.x = -12
	camera.current = true
	pivot.add_child(camera)
	player.set_script(load("res://scripts/player.gd"))

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18,18)
	panel.custom_minimum_size = Vector2(330,76)
	canvas.add_child(panel)
	var label := Label.new()
	label.text = "AURORA STRIKE  /  BUILD 01\nNUOVA AURORA • MAPPA 2 × 2 KM"
	label.add_theme_font_size_override("font_size",18)
	panel.add_child(label)
	var hint := Label.new()
	hint.text = "WASD / joystick touch • Guarda ed esplora"
	hint.position = Vector2(20,104)
	canvas.add_child(hint)

func _apply_capture_view() -> void:
	var args := OS.get_cmdline_user_args()
	var view := "player"
	for arg in args:
		if arg.begins_with("--view="):
			view = arg.trim_prefix("--view=")
	var camera := get_node_or_null("Player/CameraPivot/Camera3D") as Camera3D
	if camera == null:
		return
	if view == "player":
		return
	camera.set_as_top_level(true)
	match view:
		"top":
			camera.global_position = Vector3(0, 1650, 0)
			camera.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
			camera.fov = 70
		"station":
			camera.global_position = Vector3(220, 190, 300)
			camera.look_at(Vector3(0, 8, 0))
			camera.fov = 65
		"industrial":
			camera.global_position = Vector3(-470, 180, 420)
			camera.look_at(Vector3(0, 15, 170))
			camera.fov = 68
		"coast":
			camera.global_position = Vector3(-650, 260, 450)
			camera.look_at(Vector3(-800, 0, 0))
			camera.fov = 68
