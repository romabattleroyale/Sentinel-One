extends Node3D
const MAP_SIZE := 2000.0
const BLOCK_SPACING := 170.0
var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var capture_camera: Camera3D
var map_overlay: CanvasLayer
var current_capture_view := "player"

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
	print("AURORA_RUNTIME_READY | procedural island, biomes, POIs and detailed city generated")

func _mat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _terrain_mat(base_color: Color, accent_color: Color, seed_value: int) -> StandardMaterial3D:
	# Generated albedo maps give biomes natural color variation without external dependencies.
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.032
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	var image := Image.create(192,192,false,Image.FORMAT_RGBA8)
	for y in range(192):
		for x in range(192):
			var broad := noise.get_noise_2d(float(x),float(y))
			var fine := noise.get_noise_2d(float(x)*2.7+19.0,float(y)*2.7-13.0)
			var value := clampf(0.50 + broad*0.34 + fine*0.14,0.0,1.0)
			image.set_pixel(x,y,base_color.lerp(accent_color,value))
	var m := _mat(Color.WHITE,0.98,0.0)
	m.albedo_texture = ImageTexture.create_from_image(image)
	m.uv1_scale = Vector3.ONE
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	# Underwater collision bed and a continuous sea plane; land is an irregular triangulated island.
	var seabed := StaticBody3D.new()
	seabed.name = "Seabed_Collision"
	add_child(seabed)
	var seabed_shape := CollisionShape3D.new()
	var seabed_box := BoxShape3D.new()
	seabed_box.size = Vector3(2250,2,2250)
	seabed_shape.shape = seabed_box
	seabed_shape.position = Vector3(0,-1.35,0)
	seabed.add_child(seabed_shape)
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(2250,2250)
	var sea := MeshInstance3D.new()
	sea.name = "Open_Ocean"
	sea.mesh = sea_mesh
	sea.position.y = -0.12
	sea.material_override = _mat(Color(0.018,0.19,0.34),0.2,0.12)
	add_child(sea)
	_build_island_surface()

func _build_island_surface() -> void:
	var outline := PackedVector2Array([
		Vector2(-420,-965),Vector2(-625,-910),Vector2(-790,-790),Vector2(-855,-620),
		Vector2(-950,-430),Vector2(-930,-265),Vector2(-855,-95),Vector2(-900,105),
		Vector2(-930,300),Vector2(-850,495),Vector2(-790,650),Vector2(-660,820),
		Vector2(-510,930),Vector2(-320,967),Vector2(-155,922),Vector2(25,955),
		Vector2(210,920),Vector2(390,952),Vector2(575,905),Vector2(745,805),
		Vector2(875,655),Vector2(950,465),Vector2(910,290),Vector2(952,105),
		Vector2(900,-95),Vector2(930,-290),Vector2(850,-495),Vector2(720,-690),
		Vector2(575,-835),Vector2(400,-925),Vector2(220,-885),Vector2(35,-930),
		Vector2(-150,-875),Vector2(-300,-925)
	])
	var triangles := Geometry2D.triangulate_polygon(outline)
	var vertices := PackedVector3Array()
	var land_uv := PackedVector2Array()
	for point in outline:
		vertices.append(Vector3(point.x,0.08,point.y))
		land_uv.append(Vector2(point.x/48.0,point.y/48.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var normals := PackedVector3Array()
	for _point in outline:
		normals.append(Vector3.UP)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = land_uv
	arrays[Mesh.ARRAY_INDEX] = triangles
	var land_material := _terrain_mat(Color(0.12,0.25,0.12),Color(0.29,0.39,0.17),211)
	land_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var island_mesh := ArrayMesh.new()
	island_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var land := MeshInstance3D.new()
	land.name = "Irregular_Island_Landmass"
	land.mesh = island_mesh
	land.material_override = land_material
	add_child(land)
	var faces := PackedVector3Array()
	for i in range(0,triangles.size(),3):
		# Reverse winding in X/Z so collision triangle normals face upward.
		faces.append(vertices[triangles[i]])
		faces.append(vertices[triangles[i+2]])
		faces.append(vertices[triangles[i+1]])
	var collision := StaticBody3D.new()
	collision.name = "Island_Collision"
	var collision_shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	concave.backface_collision = true
	collision_shape.shape = concave
	collision.add_child(collision_shape)
	add_child(collision)


func _patch(node_name: String, size: Vector2, center: Vector2, material: Material, y: float = 0.105) -> void:
	# Rough-edged mesh patches look organic in the map overview rather than like rectangles.
	const SEGMENTS := 32
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	uv.append(Vector2.ZERO)
	for i in range(SEGMENTS):
		var angle := TAU * float(i) / float(SEGMENTS)
		var jitter := rng.randf_range(0.88,1.12)
		var local_x := cos(angle) * size.x * 0.5 * jitter
		var local_z := sin(angle) * size.y * 0.5 * jitter
		vertices.append(Vector3(local_x,0,local_z))
		normals.append(Vector3.UP)
		uv.append(Vector2(local_x/42.0,local_z/42.0))
	for i in range(SEGMENTS):
		indices.append(0)
		indices.append(((i+1)%SEGMENTS)+1)
		indices.append(i+1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var patch_mesh := ArrayMesh.new()
	patch_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var patch := MeshInstance3D.new()
	patch.name = node_name
	patch.mesh = patch_mesh
	if material is StandardMaterial3D:
		(material as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	patch.position = Vector3(center.x,y,center.y)
	patch.material_override = material
	add_child(patch)

func _build_biomes() -> void:
	# Color-coded landform zones break up the giant flat center into recognizable regions.
	var meadow := _terrain_mat(Color(0.13,0.29,0.12),Color(0.31,0.42,0.18),101)
	var forest_floor := _terrain_mat(Color(0.045,0.15,0.075),Color(0.15,0.29,0.11),102)
	var snow := _terrain_mat(Color(0.78,0.82,0.84),Color(1.0,1.0,0.99),103)
	var rock := _terrain_mat(Color(0.22,0.23,0.22),Color(0.44,0.43,0.40),104)
	var sand := _terrain_mat(Color(0.66,0.45,0.23),Color(0.92,0.75,0.45),105)
	var red_sand := _terrain_mat(Color(0.57,0.18,0.08),Color(0.92,0.39,0.16),106)
	var farm := _terrain_mat(Color(0.27,0.29,0.12),Color(0.52,0.47,0.20),107)
	var industry := _terrain_mat(Color(0.20,0.22,0.22),Color(0.43,0.44,0.41),108)
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
	lake_mesh.height = 0.08
	var lake := MeshInstance3D.new()
	lake.name = "Lago_Azzurro"
	lake.mesh = lake_mesh
	lake.scale = Vector3(1.0,1.0,0.76)
	lake.position = Vector3(-250,0.14,-455)
	lake.material_override = lake_mat
	add_child(lake)
	# Curved river down the middle-to-east corridor, with short overlapping segments.
	var river_mat := _mat(Color(0.035,0.40,0.58),0.2,0.08)
	for i in range(18):
		var z := -340.0 + float(i) * 63.0
		var x := 185.0 + sin(float(i)*0.48)*95.0
		var angle := cos(float(i)*0.48)*0.45
		var seg := _box(self,"River_Channel_%02d" % i,Vector3(34,0.12,78),Vector3(x,0.14,z),river_mat)
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

func _mountain(pos: Vector2, radius: float, height: float, snow_cap: bool = false, red_rock: bool = false) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	mesh.rings = 3
	var node := MeshInstance3D.new()
	node.name = "Mountain_Peak"
	node.mesh = mesh
	node.position = Vector3(pos.x,height/2.0+0.08,pos.y)
	node.material_override = _mat(Color(0.63,0.28,0.14) if red_rock else (Color(0.32,0.34,0.34) if not snow_cap else Color(0.43,0.48,0.51)))
	add_child(node)
	if snow_cap:
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.0
		cap_mesh.bottom_radius = radius*0.45
		cap_mesh.height = height*0.38
		cap_mesh.radial_segments = 7
		cap_mesh.rings = 2
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.position = Vector3(pos.x,height*0.81+0.08,pos.y)
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
			_tree(self,Vector3(x,0.09,z),rng.randf_range(0.65,1.25))
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
			_box(self,"Crop_Row",Vector3(5,0.5,62),Vector3(515+float(field)*30,0.36,110+float(row)*18),crop_colors[(field+row)%3])
	for i in range(3):
		var silo := CylinderMesh.new()
		silo.top_radius = 8
		silo.bottom_radius = 8
		silo.height = 24
		var silo_node := MeshInstance3D.new()
		silo_node.name = "Farm_Silo"
		silo_node.mesh = silo
		silo_node.position = Vector3(660,12.08,250+float(i)*25)
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
		tank.position = Vector3(-155+float(i)*42,10.08,390)
		tank.material_override = metal
		add_child(tank)
	_box(self,"Factory_Hall",Vector3(105,18,48),Vector3(-120,9.08,470),_mat(Color(0.34,0.37,0.36)),true)
	_box(self,"Factory_Roof",Vector3(109,2,52),Vector3(-120,18.08,470),_mat(Color(0.18,0.22,0.23),0.55,0.25))
	# Military runway, hangars and watch towers.
	_box(self,"Military_Runway",Vector3(24,0.35,290),Vector3(-630,0.17,610),_mat(Color(0.17,0.19,0.20)))
	_box(self,"Runway_Centreline",Vector3(0.6,0.45,255),Vector3(-630,0.36,610),_mat(Color(0.86,0.84,0.71)))
	for i in range(3):
		_box(self,"Military_Hangar",Vector3(44,16,31),Vector3(-710+float(i)*65,8.08,590),metal,true)
		_box(self,"Guard_Tower",Vector3(5,17,5),Vector3(-760+float(i)*120,8.58,530),concrete,true)
	# Small residential blocks and rooftop details.
	for i in range(18):
		var x := 500.0 + float(i%6)*25.0
		var z := -30.0 + float(i/6)*28.0
		_box(self,"Residential_House",Vector3(18,8,18),Vector3(x,4.08,z),_mat(Color(0.61,0.51,0.39)),true)
		_box(self,"House_Roof",Vector3(20,1.2,20),Vector3(x,8.7,z),_mat(Color(0.28,0.19,0.15)))

func _build_roads() -> void:
	var road := _mat(Color(0.075,0.085,0.095))
	var line := _mat(Color(0.96,0.77,0.32),0.6)
	var sidewalk := _mat(Color(0.52,0.52,0.49))
	for x in [-595.0,-425.0,-255.0,-85.0,85.0,255.0,425.0,595.0]:
		_box(self,"Road_NS",Vector3(24,0.18,1420),Vector3(x,0.16,0),road)
		_box(self,"Sidewalk",Vector3(5,0.25,1420),Vector3(x-15,0.21,0),sidewalk)
		_box(self,"Sidewalk",Vector3(5,0.25,1420),Vector3(x+15,0.21,0),sidewalk)
		for z in range(-680,681,48):
			_box(self,"LaneDash",Vector3(0.35,0.22,18),Vector3(x,0.27,z),line)
	for z in [-595.0,-425.0,-255.0,-85.0,85.0,255.0,425.0,595.0]:
		_box(self,"Road_EW",Vector3(1420,0.18,24),Vector3(0,0.16,z),road)
		_box(self,"Sidewalk",Vector3(1420,0.25,5),Vector3(0,0.21,z-15),sidewalk)
		_box(self,"Sidewalk",Vector3(1420,0.25,5),Vector3(0,0.21,z+15),sidewalk)
		for x in range(-680,681,48):
			_box(self,"LaneDash",Vector3(18,0.22,0.35),Vector3(x,0.27,z),line)


func _road_segment(a: Vector2, b: Vector2, width: float, material: Material, node_name: String) -> void:
	var delta := b-a
	var length := delta.length()
	var mid := (a+b)*0.5
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(width,0.16,length)
	var road_node := MeshInstance3D.new()
	road_node.name = node_name
	road_node.mesh = road_mesh
	road_node.position = Vector3(mid.x,0.16,mid.y)
	road_node.rotation.y = atan2(delta.x,delta.y)
	road_node.material_override = material
	add_child(road_node)

func _build_country_roads() -> void:
	var asphalt := _mat(Color(0.12,0.14,0.15),0.94)
	var shoulder := _mat(Color(0.48,0.46,0.38))
	# Roads leave the city grid and lead to the major locations visible in the reference map.
	var routes := [
		[Vector2(-595,-425),Vector2(-640,-610)],
		[Vector2(-640,-610),Vector2(-720,-760)],
		[Vector2(-255,-425),Vector2(-225,-455)],
		[Vector2(-225,-455),Vector2(-440,-540)],
		[Vector2(255,-425),Vector2(330,-575)],
		[Vector2(330,-575),Vector2(700,-650)],
		[Vector2(-595,255),Vector2(-665,190)],
		[Vector2(-665,190),Vector2(-865,120)],
		[Vector2(-595,425),Vector2(-630,600)],
		[Vector2(-630,600),Vector2(-700,735)],
		[Vector2(255,425),Vector2(260,625)],
		[Vector2(260,625),Vector2(530,700)],
		[Vector2(595,425),Vector2(610,330)],
		[Vector2(610,330),Vector2(800,250)],
		[Vector2(255,255),Vector2(360,240)],
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
	map_overlay = canvas
	# Atlas-style coordinates inspired by the supplied map reference.
	var grid_left := 50.0
	var grid_top := 58.0
	var grid_width := 1180.0
	var grid_height := 1180.0
	var grid_color := Color(0.16,0.55,0.70,0.48)
	for n in range(11):
		var vx := grid_left + grid_width*float(n)/10.0
		var hz := grid_top + grid_height*float(n)/10.0
		var vertical := ColorRect.new()
		vertical.position = Vector2(vx,grid_top)
		vertical.size = Vector2(1.4,grid_height)
		vertical.color = grid_color
		canvas.add_child(vertical)
		var horizontal := ColorRect.new()
		horizontal.position = Vector2(grid_left,hz)
		horizontal.size = Vector2(grid_width,1.4)
		horizontal.color = grid_color
		canvas.add_child(horizontal)
	var letters := ["A","B","C","D","E","F","G","H","I","J"]
	for n in range(10):
		var column := Label.new()
		column.text = letters[n]
		column.position = Vector2(grid_left+grid_width*(float(n)+0.5)/10.0-12.0,14)
		column.size = Vector2(24,30)
		column.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_theme_font_size_override("font_size",15)
		column.add_theme_color_override("font_color",Color(0.92,0.96,1.0))
		canvas.add_child(column)
		var row_label := Label.new()
		row_label.text = str(n+1)
		row_label.position = Vector2(12,grid_top+grid_height*(float(n)+0.5)/10.0-12.0)
		row_label.size = Vector2(24,26)
		row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row_label.add_theme_font_size_override("font_size",14)
		row_label.add_theme_color_override("font_color",Color(0.92,0.96,1.0))
		canvas.add_child(row_label)
	var title := Label.new()
	title.text = "MAPPA DI GIOCO"
	title.position = Vector2(38,1138)
	title.size = Vector2(360,58)
	title.add_theme_font_size_override("font_size",38)
	title.add_theme_color_override("font_color",Color(1.0,0.98,0.91))
	title.add_theme_color_override("font_outline_color",Color(0.02,0.04,0.06))
	title.add_theme_constant_override("outline_size",6)
	canvas.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "2000 × 2000 m"
	subtitle.position = Vector2(44,1190)
	subtitle.size = Vector2(200,26)
	subtitle.add_theme_font_size_override("font_size",18)
	subtitle.add_theme_color_override("font_color",Color(0.83,0.89,0.93))
	canvas.add_child(subtitle)
	var compass := Label.new()
	compass.text = "N\n✦\nO  +  E\nS"
	compass.position = Vector2(1110,1053)
	compass.size = Vector2(90,120)
	compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass.add_theme_font_size_override("font_size",22)
	compass.add_theme_color_override("font_color",Color(0.96,0.98,1.0))
	compass.add_theme_color_override("font_outline_color",Color(0.02,0.05,0.07))
	compass.add_theme_constant_override("outline_size",4)
	canvas.add_child(compass)
	var scale_label := Label.new()
	scale_label.text = "0      250     500             1.000                    2.000 m\n|---------|---------|----------------|------------------------|"
	scale_label.position = Vector2(770,1200)
	scale_label.size = Vector2(465,60)
	scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scale_label.add_theme_font_size_override("font_size",13)
	scale_label.add_theme_color_override("font_color",Color(0.97,0.98,1.0))
	canvas.add_child(scale_label)
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
		label.position = Vector2(520.0+float(item[1])*0.55,623.0+float(item[2])*0.55)
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
	var building_slots: Array[Vector2] = [Vector2(-32,-32),Vector2(32,-32),Vector2(-32,32),Vector2(32,32)]
	for gx in range(-4,5):
		for gz in range(-3,4):
			var cx := float(gx) * BLOCK_SPACING
			var cz := float(gz) * BLOCK_SPACING
			if abs(cx) < 70 or abs(cz) < 70:
				continue
			var block := Node3D.new()
			block.name = "Block_%d_%d" % [gx,gz]
			block.position = Vector3(cx,0,cz)
			add_child(block)
			for i in range(rng.randi_range(3,4)):
				var slot_pos: Vector2 = building_slots[i]
				var bx: float = slot_pos.x + rng.randf_range(-4.0,4.0)
				var bz: float = slot_pos.y + rng.randf_range(-4.0,4.0)
				# Prefer detailed baked Roman architecture from the existing project library.
				# These scenes carry facade meshes, roof details, UVs, texture and collision resources.
				var archetype_id: int = absi(gx*17 + gz*11 + i*7) % 27
				var archetype_path := "res://baked_city/archetypes_587/archetype_%02d.tscn" % archetype_id
				var archetype := load(archetype_path) as PackedScene
				if archetype != null and rng.randf() < 0.82:
					var detailed := archetype.instantiate() as Node3D
					if detailed != null:
						detailed.name = "Detailed_Roman_Building_%02d" % archetype_id
						var scale_factor := rng.randf_range(2.6,3.35)
						detailed.position = Vector3(bx,0.09,bz)
						detailed.scale = Vector3(scale_factor,scale_factor,scale_factor)
						detailed.rotation.y = rng.randf_range(0.0,TAU)
						block.add_child(detailed)
						continue
				var w := rng.randf_range(22,43)
				var d := rng.randf_range(24,42)
				var h := rng.randf_range(12,52)
				var body_mat: Material = palettes[rng.randi_range(0,palettes.size()-1)]
				_box(block,"Building_%d" % i,Vector3(w,h,d),Vector3(bx,h/2+0.1,bz),body_mat,true)
				_box(block,"Roof_%d" % i,Vector3(w+1,1,d+1),Vector3(bx,h+0.65,bz),roof)
				for floor_idx in range(1,int(h/4.0)):
					for side in [-1.0,1.0]:
						_box(block,"WindowBand",Vector3(w*0.68,0.85,0.22),Vector3(bx,h/2+0.1+float(floor_idx)*3.5,bz+side*(d/2+0.13)),glass)
				if rng.randf() > 0.45:
					_box(block,"Shopfront",Vector3(w*0.72,2.6,0.28),Vector3(bx,1.7,bz+d/2+0.18),glass)

func _build_landmarks() -> void:
	var stone := _mat(Color(0.69,0.62,0.49))
	var dark := _mat(Color(0.15,0.18,0.19),0.55,0.2)
	var red := _mat(Color(0.72,0.19,0.12))
	var station := Node3D.new()
	station.name = "Aurora_Central_Station"
	add_child(station)
	_box(station,"Station_Main_Hall",Vector3(118,20,48),Vector3(0,10.1,0),stone,true)
	_box(station,"Station_Glass_Front",Vector3(96,12,0.7),Vector3(0,11.1,24.4),dark)
	_box(station,"Station_Roof",Vector3(126,2,54),Vector3(0,21.1,0),_mat(Color(0.22,0.25,0.27),0.4,0.35))
	for x in range(-48,49,16):
		_box(station,"Facade_Pillar",Vector3(1.5,15,1.5),Vector3(x,7.6,25),stone)
	_box(station,"Sign_Red",Vector3(30,3,0.6),Vector3(0,17.1,25.2),red)
	_box(self,"Civic_Tower",Vector3(28,96,28),Vector3(-270,49,270),_mat(Color(0.48,0.53,0.55)),true)
	for y in range(12,94,12):
		_box(self,"Tower_Window_Band",Vector3(28.4,2,28.4),Vector3(-270,float(y),270),dark)
	_box(self,"Tower_Cap",Vector3(34,3,34),Vector3(-270,98,270),stone)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0,2.5,90)
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
	camera.name = "CaptureCamera"
	capture_camera = camera
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
	if args.size() > 0 or OS.get_environment("AURORA_CAPTURE") == "1":
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(1280,1280)
		get_window().position = Vector2i(0,0)
	for arg in args:
		if arg.begins_with("--view="):
			view = arg.trim_prefix("--view=")
	if capture_camera == null:
		capture_camera = get_node_or_null("Player/CameraPivot/CaptureCamera") as Camera3D
	if capture_camera == null:
		push_error("Capture camera was not created.")
		return
	if view == "top":
		_build_map_overlay_labels()
	_set_capture_view(view)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _set_capture_view("top")
			KEY_2: _set_capture_view("player")
			KEY_3: _set_capture_view("station")
			KEY_4: _set_capture_view("industrial")
			KEY_5: _set_capture_view("coast")

func _set_capture_view(view: String) -> void:
	print("AURORA_VIEW | ", view, " | ", get_window().size, " | ", get_window().position)
	if capture_camera == null:
		return
	if view == "top" and map_overlay == null:
		_build_map_overlay_labels()
	current_capture_view = view
	if map_overlay != null:
		map_overlay.visible = (view == "top")
	capture_camera.current = true
	if view == "player":
		capture_camera.set_as_top_level(false)
		capture_camera.position = Vector3(0,2.4,7.5)
		capture_camera.rotation_degrees = Vector3(-12,0,0)
		return
	capture_camera.set_as_top_level(true)
	match view:
		"top":
			capture_camera.global_position = Vector3(0,1550,0)
			capture_camera.look_at(Vector3(0,0,0),Vector3(0,0,-1))
			capture_camera.fov = 70
		"station":
			capture_camera.global_position = Vector3(220,190,300)
			capture_camera.look_at(Vector3(0,8,0))
			capture_camera.fov = 65
		"industrial":
			capture_camera.global_position = Vector3(-470,180,420)
			capture_camera.look_at(Vector3(0,15,170))
			capture_camera.fov = 68
		"coast":
			capture_camera.global_position = Vector3(-650,260,450)
			capture_camera.look_at(Vector3(-800,0,0))
			capture_camera.fov = 68
