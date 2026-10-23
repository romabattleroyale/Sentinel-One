extends Node3D
const MAP_SIZE := 2000.0
const BLOCK_SPACING := 170.0
var rng := RandomNumberGenerator.new()
var player: CharacterBody3D

func _ready() -> void:
	rng.seed = 271023
	_build_environment()
	_build_terrain()
	_build_biomes()
	_build_nature()
	_build_roads()
	_build_country_roads()
	_build_city_blocks()
	_build_landmarks()
	_build_district_details()
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
	_box(self, "Urban_Base", Vector3(1420,1.2,1420), Vector3(0,0.15,0), _mat(Color(0.20,0.31,0.19),0.96), true)
	var water := _mat(Color(0.055,0.23,0.34),0.24,0.12)
	_box(self,"North_Water",Vector3(2000,0.6,290),Vector3(0,-0.4,-855),water)
	_box(self,"South_Water",Vector3(2000,0.6,290),Vector3(0,-0.4,855),water)
	_box(self,"West_Water",Vector3(290,0.6,1420),Vector3(-855,-0.4,0),water)
	_box(self,"East_Water",Vector3(290,0.6,1420),Vector3(855,-0.4,0),water)


func _patch(node_name: String, size: Vector2, center: Vector2, material: Material, y: float = 0.79) -> void:
	_box(self, node_name, Vector3(size.x, 0.035, size.y), Vector3(center.x, y, center.y), material)

func _build_biomes() -> void:
	# Color-coded landform zones break up the giant flat center into recognizable regions.
	var meadow := _mat(Color(0.20,0.37,0.19))
	var forest_floor := _mat(Color(0.105,0.25,0.13))
	var snow := _mat(Color(0.73,0.79,0.82))
	var rock := _mat(Color(0.35,0.37,0.37))
	var sand := _mat(Color(0.72,0.57,0.34))
	var red_sand := _mat(Color(0.65,0.28,0.14))
	var farm := _mat(Color(0.39,0.42,0.20))
	var industry := _mat(Color(0.27,0.30,0.29))
	_patch("Green_Hills_Biome",Vector2(570,480),Vector2(-430,320),meadow)
	_patch("Shadow_Forest_Biome",Vector2(470,480),Vector2(320,-410),forest_floor)
	_patch("Snowfield_Biome",Vector2(470,390),Vector2(-565,-650),snow)
	_patch("Mountain_Rock_Biome",Vector2(470,350),Vector2(-475,-485),rock)
	_patch("Desolate_Quarry_Biome",Vector2(540,450),Vector2(0,690),sand)
	_patch("Red_Desert_Biome",Vector2(500,470),Vector2(570,650),red_sand)
	_patch("Agriculture_Biome",Vector2(320,350),Vector2(615,220),farm)
	_patch("Industrial_District_Ground",Vector2(310,260),Vector2(-110,400),industry)
	var lake_mat := _mat(Color(0.035,0.38,0.55),0.22,0.12)
	var lake_mesh := CylinderMesh.new()
	lake_mesh.top_radius = 118
	lake_mesh.bottom_radius = 118
	lake_mesh.height = 0.55
	var lake := MeshInstance3D.new()
	lake.name = "Lago_Azzurro"
	lake.mesh = lake_mesh
	lake.scale = Vector3(1.0,1.0,0.76)
	lake.position = Vector3(-250,0.86,-455)
	lake.material_override = lake_mat
	add_child(lake)
	# Curved river down the middle-to-east corridor, with short overlapping segments.
	var river_mat := _mat(Color(0.035,0.40,0.58),0.2,0.08)
	for i in range(18):
		var z := -340.0 + float(i) * 63.0
		var x := 185.0 + sin(float(i)*0.48)*95.0
		var angle := cos(float(i)*0.48)*0.45
		var seg := _box(self,"River_Channel_%02d" % i,Vector3(34,0.12,78),Vector3(x,0.86,z),river_mat)
		seg.rotation.y = angle
	# Sea inlets and small offshore islets.
	var isle_mat := _mat(Color(0.28,0.38,0.22))
	for p in [Vector2(-900,370),Vector2(-850,600),Vector2(-915,665),Vector2(895,-650),Vector2(935,-575),Vector2(865,-510),Vector2(910,360)]:
		var island := _box(self,"Coastal_Islet",Vector3(rng.randf_range(28,55),2,rng.randf_range(24,46)),Vector3(p.x,-0.1,p.y),isle_mat)
		island.rotation.y = rng.randf_range(-0.5,0.5)

func _tree(parent: Node3D, pos: Vector3, scale_factor: float = 1.0, autumn: bool = false) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.45 * scale_factor
	trunk_mesh.bottom_radius = 0.7 * scale_factor
	trunk_mesh.height = 5.0 * scale_factor
	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position = pos + Vector3(0,2.5*scale_factor,0)
	trunk.material_override = _mat(Color(0.25,0.16,0.095))
	parent.add_child(trunk)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 3.2 * scale_factor
	crown_mesh.height = 6.4 * scale_factor
	var crown := MeshInstance3D.new()
	crown.mesh = crown_mesh
	crown.position = pos + Vector3(0,6.5*scale_factor,0)
	crown.material_override = _mat(Color(0.75,0.26,0.09) if autumn else Color(0.12+rng.randf()*0.06,0.29+rng.randf()*0.12,0.13))
	parent.add_child(crown)

func _mountain(pos: Vector3, radius: float, height: float, snow_cap: bool = false, red_rock: bool = false) -> void:
	var mesh := ConeMesh.new()
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	mesh.rings = 3
	var node := MeshInstance3D.new()
	node.name = "Mountain_Peak"
	node.mesh = mesh
	node.position = Vector3(pos.x,height/2.0+0.8,pos.y)
	node.material_override = _mat(Color(0.63,0.28,0.14) if red_rock else (Color(0.32,0.34,0.34) if not snow_cap else Color(0.43,0.48,0.51)))
	add_child(node)
	if snow_cap:
		var cap_mesh := ConeMesh.new()
		cap_mesh.bottom_radius = radius*0.45
		cap_mesh.height = height*0.38
		cap_mesh.radial_segments = 7
		cap_mesh.rings = 2
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.position = Vector3(pos.x,height*0.81+0.8,pos.y)
		cap.material_override = _mat(Color(0.90,0.94,0.96))
		add_child(cap)

func _build_nature() -> void:
	# Alpine skyline in the north-west.
	for p in [
		Vector2(-780,-790),Vector2(-675,-745),Vector2(-575,-790),
		Vector2(-505,-710),Vector2(-625,-625),Vector2(-820,-650),
		Vector2(-460,-610),Vector2(-700,-545)
	]:
		_mountain(p,rng.randf_range(55,95),rng.randf_range(90,180),true)
	# Broken rocky ridge and red mesas in the southern biomes.
	for p in [Vector2(-240,700),Vector2(-95,760),Vector2(70,720),Vector2(170,775),Vector2(520,680),Vector2(640,730),Vector2(760,620),Vector2(680,820)]:
		_mountain(p,rng.randf_range(38,70),rng.randf_range(35,90),false,p.x>400)
	# Dense shadow forest. Tree clusters are deterministic to keep the island layout stable.
	for i in range(180):
		var x := rng.randf_range(115,520)
		var z := rng.randf_range(-625,-205)
		if Vector2(x,z).distance_to(Vector2(310,-410)) < 260:
			_tree(self,Vector3(x,0.82,z),rng.randf_range(0.65,1.25))
	# Mixed green hills and autumn groves along the west side.
	for i in range(95):
		var x := rng.randf_range(-790,-330)
		var z := rng.randf_range(100,550)
		_tree(self,Vector3(x,0.82,z),rng.randf_range(0.55,1.05),z>430)
	# Smaller trees frame roads without filling the built-up centre.
	for i in range(70):
		var x := rng.randf_range(-650,650)
		var z := rng.randf_range(-640,620)
		if abs(x)>565 or abs(z)>560:
			_tree(self,Vector3(x,0.82,z),rng.randf_range(0.45,0.8))

func _build_district_details() -> void:
	var concrete := _mat(Color(0.42,0.43,0.41))
	var metal := _mat(Color(0.23,0.27,0.28),0.48,0.38)
	var crop_colors := [_mat(Color(0.51,0.47,0.19)),_mat(Color(0.38,0.34,0.14)),_mat(Color(0.61,0.51,0.24))]
	# Port piers, quay walls, containers and small boats on the western shore.
	for i in range(5):
		var z := -30.0 + float(i)*54.0
		_box(self,"Port_Pier",Vector3(105,2,13),Vector3(-895,1.1,z),concrete,true)
		for j in range(4):
			var cmat: Material = crop_colors[(i+j)%crop_colors.size()]
			_box(self,"Shipping_Container",Vector3(12,8,10),Vector3(-870+float(j)*23,5.8,z),cmat)
		_box(self,"Harbor_Boat",Vector3(20,3,8),Vector3(-780,1.2,z+14),metal)
	# Agriculture rows and a silo group in the east.
	for field in range(4):
		for row in range(8):
			_box(self,"Crop_Row",Vector3(5,0.5,62),Vector3(515+float(field)*30,1.05,110+float(row)*18),crop_colors[(field+row)%3])
	for i in range(3):
		var silo := CylinderMesh.new()
		silo.top_radius = 8
		silo.bottom_radius = 8
		silo.height = 24
		var silo_node := MeshInstance3D.new()
		silo_node.name = "Farm_Silo"
		silo_node.mesh = silo
		silo_node.position = Vector3(660,13,250+float(i)*25)
		silo_node.material_override = metal
		add_child(silo_node)
	# Industrial tanks, halls, stacks and fenced compound.
	for i in range(4):
		var tank_mesh := CylinderMesh.new()
		tank_mesh.top_radius = 12
		tank_mesh.bottom_radius = 12
		tank_mesh.height = 20
		var tank := MeshInstance3D.new()
		tank.name = "Industrial_Tank"
		tank.mesh = tank_mesh
		tank.position = Vector3(-155+float(i)*42,11,390)
		tank.material_override = metal
		add_child(tank)
	_box(self,"Factory_Hall",Vector3(105,18,48),Vector3(-120,10,470),_mat(Color(0.34,0.37,0.36)),true)
	_box(self,"Factory_Roof",Vector3(109,2,52),Vector3(-120,20,470),_mat(Color(0.18,0.22,0.23),0.55,0.25))
	# Military runway, hangars and watch towers.
	_box(self,"Military_Runway",Vector3(24,0.35,290),Vector3(-630,0.92,610),_mat(Color(0.17,0.19,0.20)))
	_box(self,"Runway_Centreline",Vector3(0.6,0.45,255),Vector3(-630,1.1,610),_mat(Color(0.86,0.84,0.71)))
	for i in range(3):
		_box(self,"Military_Hangar",Vector3(44,16,31),Vector3(-710+float(i)*65,9,590),metal,true)
		_box(self,"Guard_Tower",Vector3(5,17,5),Vector3(-760+float(i)*120,9,530),concrete,true)
	# Small residential blocks and rooftop details.
	for i in range(18):
		var x := 500.0 + float(i%6)*25.0
		var z := -30.0 + float(i/6)*28.0
		_box(self,"Residential_House",Vector3(18,8,18),Vector3(x,4.8,z),_mat(Color(0.61,0.51,0.39)),true)
		_box(self,"House_Roof",Vector3(20,1.2,20),Vector3(x,9.4,z),_mat(Color(0.28,0.19,0.15)))

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


func _road_segment(a: Vector2, b: Vector2, width: float, material: Material, node_name: String) -> void:
	var delta := b-a
	var length := delta.length()
	var mid := (a+b)*0.5
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(width,0.16,length)
	var road_node := MeshInstance3D.new()
	road_node.name = node_name
	road_node.mesh = road_mesh
	road_node.position = Vector3(mid.x,0.90,mid.y)
	road_node.rotation.y = atan2(delta.x,delta.y)
	road_node.material_override = material
	add_child(road_node)

func _build_country_roads() -> void:
	var asphalt := _mat(Color(0.12,0.14,0.15),0.94)
	var shoulder := _mat(Color(0.48,0.46,0.38))
	# Roads leave the city grid and lead to the major locations visible in the reference map.
	var routes := [
		[Vector2(-510,-510),Vector2(-640,-610)],
		[Vector2(-640,-610),Vector2(-720,-760)],
		[Vector2(-170,-510),Vector2(-225,-455)],
		[Vector2(-225,-455),Vector2(-440,-540)],
		[Vector2(170,-510),Vector2(330,-575)],
		[Vector2(330,-575),Vector2(700,-650)],
		[Vector2(-510,170),Vector2(-665,190)],
		[Vector2(-665,190),Vector2(-865,120)],
		[Vector2(-510,510),Vector2(-630,600)],
		[Vector2(-630,600),Vector2(-700,735)],
		[Vector2(170,510),Vector2(260,625)],
		[Vector2(260,625),Vector2(530,700)],
		[Vector2(510,510),Vector2(610,330)],
		[Vector2(610,330),Vector2(800,250)],
		[Vector2(170,170),Vector2(360,240)],
		[Vector2(360,240),Vector2(570,200)]
	]
	for route in routes:
		_road_segment(route[0],route[1],19.0,shoulder,"Route_Shoulder")
		_road_segment(route[0],route[1],13.0,asphalt,"Route_Connector")

func _build_map_overlay_labels() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Top_Down_Map_Labels"
	canvas.layer = 4
	add_child(canvas)
	var labels := [
		["MONTE NEVOSO",-645,-710],
		["LAGO AZZURRO",-250,-455],
		["BOSCO OMBRA",315,-430],
		["ISOLE DEL RELITTO",820,-660],
		["PORTO",-865,60],
		["CITTÀ CENTRALE",-320,15],
		["STAZIONE TERMINI",20,62],
		["QUARTIERE RESIDENZIALE",570,-120],
		["COLLINE VERDI",-545,325],
		["RIVIERA",-795,520],
		["BASE MILITARE",-650,655],
		["ZONA INDUSTRIALE",-130,400],
		["CENTRO COMMERCIALE",270,410],
		["ZONA AGRICOLA",650,220],
		["CAVA DESOLATA",35,690],
		["DESERTO ROSSO",580,640]
	]
	for item in labels:
		var label := Label.new()
		label.text = item[0]
		label.position = Vector2(640.0+float(item[1])*0.55,640.0+float(item[2])*0.55)
		label.size = Vector2(245,34)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",15)
		label.add_theme_color_override("font_color",Color(1.0,0.98,0.87))
		label.add_theme_color_override("font_outline_color",Color(0.025,0.045,0.055,1.0))
		label.add_theme_constant_override("outline_size",5)
		canvas.add_child(label)

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
			camera.global_position = Vector3(0, 1550, 0)
			camera.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
			camera.fov = 70
			get_window().size = Vector2i(1280, 1280)
			_build_map_overlay_labels()
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
