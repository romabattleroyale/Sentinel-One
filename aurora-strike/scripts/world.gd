extends Node3D
const MAP_SIZE := 2000.0
const BLOCK_SPACING := 170.0
var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var capture_camera: Camera3D
var map_overlay: CanvasLayer
var current_capture_view := "player"
var hud_layer: CanvasLayer
var using_blender_map := false

func _ready() -> void:
	rng.seed = 271023
	_build_environment()
	if _try_load_blender_map():
		_build_blender_map_architecture()
		_build_player()
		_build_hud()
		_apply_capture_view()
		print("AURORA_RUNTIME_READY | Blender-generated master island loaded into Godot")
		return
	_build_terrain()
	_build_biomes()
	_build_nature()
	_build_terrain_relief()
	_build_roads()
	_build_country_roads()
	_build_winding_roads()
	_build_city_blocks()
	_build_landmarks()
	_build_district_details()
	_build_player()
	_build_hud()
	_apply_capture_view()
	print("AURORA_RUNTIME_READY | procedural fallback island, biomes, POIs and city generated")

func _try_load_blender_map() -> bool:
	var asset_path := "res://world/generated_blender/AURORA_STRIKE_Master_Preview.glb"
	if not ResourceLoader.exists(asset_path):
		print("AURORA_MAP_SOURCE | procedural fallback")
		return false
	var packed := load(asset_path) as PackedScene
	if packed == null:
		push_warning("AURORA_MAP_SOURCE | GLB exists but did not import as a PackedScene; using procedural fallback")
		return false
	var map_instance := packed.instantiate()
	map_instance.name = "BlenderGeneratedIsland"
	add_child(map_instance)
	using_blender_map = true
	_add_master_terrain_collision(map_instance)
	print("AURORA_MAP_SOURCE | ", asset_path)
	return true

func _add_master_terrain_collision(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.name == "Island_Terrain_2000m":
			mesh_node.create_trimesh_collision()
			print("AURORA_COLLISION | master terrain collision generated")
		elif mesh_node.name.begins_with("River_Bridge_"):
			mesh_node.create_trimesh_collision()
			print("AURORA_COLLISION | bridge deck generated: ", mesh_node.name)
	for child in node.get_children():
		_add_master_terrain_collision(child)

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
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.055,0.19,0.43)
	sky_material.sky_horizon_color = Color(0.47,0.67,0.83)
	sky_material.ground_bottom_color = Color(0.16,0.21,0.24)
	sky_material.ground_horizon_color = Color(0.44,0.51,0.54)
	sky_material.sun_angle_max = 18.0
	env.sky.sky_material = sky_material
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
	var ocean_material := _mat(Color(0.015,0.18,0.31),0.48,0.0)
	ocean_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sea.material_override = ocean_material
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
	var outline_triangles := Geometry2D.triangulate_polygon(outline)
	var outline_vertices := PackedVector3Array()
	for point in outline:
		outline_vertices.append(Vector3(point.x,0.08,point.y))
	# Dense island grid lets biomes blend naturally instead of using hard polygon plates.
	const TERRAIN_STEP := 28.0
	var min_x := -950.0
	var max_x := 950.0
	var min_z := -965.0
	var max_z := 967.0
	var columns := int(ceil((max_x-min_x)/TERRAIN_STEP))+1
	var rows := int(ceil((max_z-min_z)/TERRAIN_STEP))+1
	var mesh_vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var inside := PackedByteArray()
	var color_noise := FastNoiseLite.new()
	color_noise.seed = 211
	color_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	color_noise.frequency = 0.009
	color_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	color_noise.fractal_octaves = 4
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 715
	detail_noise.frequency = 0.075
	for iz in range(rows):
		var z := min_z + float(iz)*TERRAIN_STEP
		for ix in range(columns):
			var x := min_x + float(ix)*TERRAIN_STEP
			var valid := Geometry2D.is_point_in_polygon(Vector2(x,z),outline)
			inside.append(1 if valid else 0)
			mesh_vertices.append(Vector3(x,0.08,z))
			normals.append(Vector3.UP)
			uv.append(Vector2(x/34.0,z/34.0))
			colors.append(_terrain_color_at(x,z,color_noise.get_noise_2d(x,z),detail_noise.get_noise_2d(x,z)))
	var indices := PackedInt32Array()
	for iz in range(rows-1):
		for ix in range(columns-1):
			var i00 := iz*columns+ix
			var i10 := i00+1
			var i01 := i00+columns
			var i11 := i01+1
			if inside[i00] == 1 and inside[i10] == 1 and inside[i01] == 1 and inside[i11] == 1:
				indices.append(i00)
				indices.append(i01)
				indices.append(i10)
				indices.append(i10)
				indices.append(i01)
				indices.append(i11)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh_vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var terrain_material := _terrain_mat(Color(0.91,0.91,0.91),Color(1.0,1.0,1.0),211)
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain_material.roughness = 0.98
	var land := MeshInstance3D.new()
	land.name = "Procedural_Biome_Terrain"
	land.mesh = terrain_mesh
	land.material_override = terrain_material
	add_child(land)
	# Collision remains aligned with the island perimeter; the shaded terrain uses the dense grid.
	var faces := PackedVector3Array()
	for i in range(0,outline_triangles.size(),3):
		faces.append(outline_vertices[outline_triangles[i]])
		faces.append(outline_vertices[outline_triangles[i+2]])
		faces.append(outline_vertices[outline_triangles[i+1]])
	var collision := StaticBody3D.new()
	collision.name = "Island_Collision"
	var collision_shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	concave.backface_collision = true
	collision_shape.shape = concave
	collision.add_child(collision_shape)
	add_child(collision)
	_add_coast_ring(outline,0.962,1.0,0.105,false)
	_add_coast_ring(outline,1.0,1.035,-0.035,true)

func _terrain_color_at(x: float, z: float, broad_noise: float, detail_noise: float) -> Color:
	var color := Color(0.29,0.45,0.20)
	var mask := exp(-0.5*(pow((x+620.0)/285.0,2.0)+pow((z+690.0)/230.0,2.0)))
	color = color.lerp(Color(0.82,0.87,0.89),clampf(mask*1.08,0.0,1.0))
	mask = exp(-0.5*(pow((x-320.0)/300.0,2.0)+pow((z+415.0)/295.0,2.0)))
	color = color.lerp(Color(0.12,0.30,0.15),clampf(mask*1.12,0.0,1.0))
	mask = exp(-0.5*(pow((x+555.0)/310.0,2.0)+pow((z-315.0)/250.0,2.0)))
	color = color.lerp(Color(0.36,0.51,0.23),clampf(mask*0.92,0.0,1.0))
	mask = exp(-0.5*(pow((x+800.0)/190.0,2.0)+pow((z-430.0)/275.0,2.0)))
	color = color.lerp(Color(0.76,0.68,0.48),clampf(mask*0.88,0.0,1.0))
	mask = exp(-0.5*(pow((x+110.0)/225.0,2.0)+pow((z-405.0)/195.0,2.0)))
	color = color.lerp(Color(0.38,0.40,0.36),clampf(mask*0.94,0.0,1.0))
	mask = exp(-0.5*(pow((x-650.0)/255.0,2.0)+pow((z-230.0)/200.0,2.0)))
	color = color.lerp(Color(0.49,0.48,0.23),clampf(mask*0.98,0.0,1.0))
	mask = exp(-0.5*(pow((x-5.0)/285.0,2.0)+pow((z-690.0)/250.0,2.0)))
	color = color.lerp(Color(0.75,0.60,0.38),clampf(mask*1.05,0.0,1.0))
	mask = exp(-0.5*(pow((x-575.0)/295.0,2.0)+pow((z-655.0)/270.0,2.0)))
	color = color.lerp(Color(0.77,0.32,0.15),clampf(mask*1.15,0.0,1.0))
	var variation := clampf(0.98+broad_noise*0.13+detail_noise*0.055,0.74,1.12)
	return Color(clampf(color.r*variation,0.0,1.0),clampf(color.g*variation,0.0,1.0),clampf(color.b*variation,0.0,1.0),1.0)

func _add_coast_ring(outline: PackedVector2Array, inner_scale: float, outer_scale: float, y: float, water_ring: bool) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for point in outline:
		var inner := point*inner_scale
		var outer := point*outer_scale
		vertices.append(Vector3(inner.x,0,inner.y))
		vertices.append(Vector3(outer.x,0,outer.y))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uv.append(Vector2(inner.x/32.0,inner.y/32.0))
		uv.append(Vector2(outer.x/32.0,outer.y/32.0))
		if water_ring:
			colors.append(Color(0.06,0.77,0.82))
			colors.append(Color(0.015,0.27,0.47))
		else:
			var shore := Color(0.82,0.71,0.50)
			if point.y < -560.0 and point.x < -200.0:
				shore = Color(0.83,0.88,0.89)
			elif point.y > 350.0 and point.x > 320.0:
				shore = Color(0.75,0.35,0.19)
			elif point.x > 550.0 and point.y < 200.0:
				shore = Color(0.53,0.53,0.30)
			colors.append(shore.lightened(0.05))
			colors.append(shore.darkened(0.08))
	for i in range(outline.size()):
		var nxt := (i+1)%outline.size()
		indices.append(i*2)
		indices.append(i*2+1)
		indices.append(nxt*2)
		indices.append(i*2+1)
		indices.append(nxt*2+1)
		indices.append(nxt*2)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var ring_mesh := ArrayMesh.new()
	ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.93 if not water_ring else 0.26
	material.metallic = 0.01 if not water_ring else 0.08
	var ring := MeshInstance3D.new()
	ring.name = "Island_Shoreline_Beach" if not water_ring else "Turquoise_Shallow_Water_Ring"
	ring.mesh = ring_mesh
	ring.material_override = material
	ring.position.y = y
	add_child(ring)

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
	# Biome ground is blended on the detailed terrain grid; this function adds distinct lakes and water channels.
	var lake_mat := _mat(Color(0.015,0.53,0.78),0.22,0.08)
	lake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lake_mesh := CylinderMesh.new()
	lake_mesh.top_radius = 118
	lake_mesh.bottom_radius = 118
	lake_mesh.height = 0.08
	var lake := MeshInstance3D.new()
	lake.name = "Lago_Azzurro"
	lake.mesh = lake_mesh
	lake.scale = Vector3(1.0,1.0,0.76)
	lake.position = Vector3(-220,0.14,-610)
	lake.material_override = lake_mat
	add_child(lake)
	# Curved river down the middle-to-east corridor, with short overlapping segments.
	var river_mat := _mat(Color(0.015,0.47,0.68),0.2,0.04)
	river_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
		cap_mesh.bottom_radius = radius*0.33
		cap_mesh.height = height*0.25
		cap_mesh.radial_segments = 7
		cap_mesh.rings = 2
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.position = Vector3(pos.x,height*0.86+0.08,pos.y)
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
	# Northern woodland fills the broad green transition between the alpine range and the lake basin.
	for i in range(125):
		var x := rng.randf_range(-445.0,175.0)
		var z := rng.randf_range(-865.0,-515.0)
		var mountain_clearance := Vector2(x,z).distance_to(Vector2(-620,-690))
		var lake_clearance := Vector2(x,z).distance_to(Vector2(-220,-610))
		if mountain_clearance > 165.0 and lake_clearance > 150.0 and not _is_urban_block(x,z):
			_tree(self,Vector3(x,0.09,z),rng.randf_range(0.55,1.0))
	# Dense shadow forest. Tree clusters are deterministic to keep the island layout stable.
	for i in range(180):
		var x := rng.randf_range(115,520)
		var z := rng.randf_range(-625,-205)
		if Vector2(x,z).distance_to(Vector2(310,-410)) < 260 and not _is_urban_block(x,z):
			_tree(self,Vector3(x,0.09,z),rng.randf_range(0.65,1.25))
	# Mixed green hills and autumn groves along the west side.
	for i in range(95):
		var x := rng.randf_range(-790,-330)
		var z := rng.randf_range(100,550)
		if not _is_urban_block(x,z):
			_tree(self,Vector3(x,0.09,z),rng.randf_range(0.55,1.05),z>430)
	# Smaller trees frame roads without filling the built-up centre.
	for i in range(70):
		var x := rng.randf_range(-650,650)
		var z := rng.randf_range(-640,620)
		if (abs(x)>565 or abs(z)>560) and not _is_urban_block(x,z):
			_tree(self,Vector3(x,0.09,z),rng.randf_range(0.45,0.8))

func _is_urban_block(x: float, z: float) -> bool:
	var nearest_gx := roundi(x/BLOCK_SPACING)
	var nearest_gz := roundi(z/BLOCK_SPACING)
	for gx in range(nearest_gx-1,nearest_gx+2):
		for gz in range(nearest_gz-1,nearest_gz+2):
			var cx := float(gx)*BLOCK_SPACING
			var cz := float(gz)*BLOCK_SPACING
			if abs(cx)<70.0 or abs(cz)<70.0:
				continue
			if abs(x-cx)<62.0 and abs(z-cz)<62.0:
				return true
	return false

func _build_terrain_relief() -> void:
	# Soft overlapping mounds provide readable contour changes between the flat road corridors.
	var hill_mats: Array[Material] = [
		_mat(Color(0.16,0.31,0.14),0.98),
		_mat(Color(0.22,0.36,0.16),0.98),
		_mat(Color(0.28,0.39,0.18),0.98)
	]
	var forest_mats: Array[Material] = [
		_mat(Color(0.045,0.16,0.075),0.98),
		_mat(Color(0.07,0.20,0.09),0.98)
	]
	var dune_mats: Array[Material] = [
		_mat(Color(0.68,0.43,0.24),0.98),
		_mat(Color(0.78,0.54,0.29),0.98)
	]
	var red_mats: Array[Material] = [
		_mat(Color(0.56,0.20,0.10),0.98),
		_mat(Color(0.70,0.27,0.12),0.98),
		_mat(Color(0.81,0.36,0.16),0.98)
	]
	for i in range(34):
		var x := rng.randf_range(-820.0,-340.0)
		var z := rng.randf_range(130.0,570.0)
		if not _is_urban_block(x,z):
			_make_terrain_mound(Vector3(x,0,z),rng.randf_range(20.0,48.0),rng.randf_range(4.0,13.0),rng.randf_range(26.0,52.0),hill_mats[rng.randi_range(0,hill_mats.size()-1)],"Green_Rolling_Hill")
	for i in range(24):
		var x := rng.randf_range(120.0,540.0)
		var z := rng.randf_range(-650.0,-200.0)
		if not _is_urban_block(x,z):
			_make_terrain_mound(Vector3(x,0,z),rng.randf_range(24.0,55.0),rng.randf_range(4.0,10.0),rng.randf_range(22.0,48.0),forest_mats[rng.randi_range(0,forest_mats.size()-1)],"Forest_Undulation")
	for i in range(28):
		var x := rng.randf_range(-190.0,330.0)
		var z := rng.randf_range(565.0,855.0)
		if not _is_urban_block(x,z):
			_make_terrain_mound(Vector3(x,0,z),rng.randf_range(24.0,60.0),rng.randf_range(3.0,10.0),rng.randf_range(24.0,60.0),dune_mats[rng.randi_range(0,dune_mats.size()-1)],"Quarry_Dune")
	for i in range(24):
		var x := rng.randf_range(395.0,785.0)
		var z := rng.randf_range(560.0,815.0)
		if not _is_urban_block(x,z):
			_make_terrain_mound(Vector3(x,0,z),rng.randf_range(26.0,58.0),rng.randf_range(5.0,15.0),rng.randf_range(28.0,64.0),red_mats[rng.randi_range(0,red_mats.size()-1)],"Red_Desert_Mesa_Slope")

func _make_terrain_mound(origin: Vector3, width: float, height: float, depth: float, material: Material, node_name: String) -> void:
	var mesh: PrimitiveMesh
	if node_name.contains("Dune") or node_name.contains("Mesa"):
		var mesa := CylinderMesh.new()
		mesa.top_radius = 0.72
		mesa.bottom_radius = 1.0
		mesa.height = 2.0
		mesa.radial_segments = 9
		mesa.rings = 3
		mesh = mesa
	else:
		var rolling := SphereMesh.new()
		rolling.radius = 1.0
		rolling.height = 2.0
		rolling.radial_segments = 16
		rolling.rings = 8
		mesh = rolling
	var mound := MeshInstance3D.new()
	mound.name = node_name
	mound.mesh = mesh
	mound.position = Vector3(origin.x,height*0.50+0.12,origin.z)
	mound.scale = Vector3(width*0.50,height*0.50,depth*0.50)
	mound.material_override = material
	mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mound)

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
	var sidewalk := _mat(Color(0.34,0.35,0.33))
	for x in [-595.0,-425.0,-255.0,-85.0,85.0,255.0,425.0,595.0]:
		_box(self,"Road_NS",Vector3(24,0.18,1250),Vector3(x,0.16,0),road)
		_box(self,"Sidewalk",Vector3(2.6,0.22,1250),Vector3(x-13.3,0.20,0),sidewalk)
		_box(self,"Sidewalk",Vector3(2.6,0.22,1250),Vector3(x+13.3,0.20,0),sidewalk)
		for z in range(-600,601,48):
			_box(self,"LaneDash",Vector3(0.35,0.22,18),Vector3(x,0.27,z),line)
	for z in [-595.0,-425.0,-255.0,-85.0,85.0,255.0,425.0,595.0]:
		_box(self,"Road_EW",Vector3(1420,0.18,24),Vector3(0,0.16,z),road)
		_box(self,"Sidewalk",Vector3(1420,0.22,2.6),Vector3(0,0.20,z-13.3),sidewalk)
		_box(self,"Sidewalk",Vector3(1420,0.22,2.6),Vector3(0,0.20,z+13.3),sidewalk)
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
		[Vector2(-255,-425),Vector2(-240,-505)],
		[Vector2(-330,-610),Vector2(-440,-650)],
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
	title.position = Vector2(38,1120)
	title.size = Vector2(360,58)
	title.add_theme_font_size_override("font_size",38)
	title.add_theme_color_override("font_color",Color(1.0,0.98,0.91))
	title.add_theme_color_override("font_outline_color",Color(0.02,0.04,0.06))
	title.add_theme_constant_override("outline_size",6)
	canvas.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "2000 × 2000 m"
	subtitle.position = Vector2(44,1172)
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
	scale_label.position = Vector2(760,1180)
	scale_label.size = Vector2(465,60)
	scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scale_label.add_theme_font_size_override("font_size",13)
	scale_label.add_theme_color_override("font_color",Color(0.97,0.98,1.0))
	canvas.add_child(scale_label)
	var labels := [
		["MONTE NEVOSO",-645,-710],
		["LAGO AZZURRO",-220,-610],
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
		label.position = Vector2(640.0+float(item[1])*0.60-122.5,647.0+float(item[2])*0.60-17.0)
		label.size = Vector2(245,34)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",15)
		label.add_theme_color_override("font_color",Color(1.0,0.98,0.87))
		label.add_theme_color_override("font_outline_color",Color(0.025,0.045,0.055,1.0))
		label.add_theme_constant_override("outline_size",5)
		canvas.add_child(label)

func _build_winding_roads() -> void:
	var asphalt := _mat(Color(0.14,0.15,0.15),0.93)
	var shoulder := _mat(Color(0.39,0.38,0.32),0.98)
	var paths: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-425,-425),Vector2(-425,-485),Vector2(-410,-530),Vector2(-390,-570),Vector2(-355,-600)]),
		PackedVector2Array([Vector2(-595,255),Vector2(-660,262),Vector2(-720,285),Vector2(-775,325),Vector2(-810,375),Vector2(-820,425),Vector2(-805,468)]),
		PackedVector2Array([Vector2(-595,425),Vector2(-660,425),Vector2(-725,425),Vector2(-785,425),Vector2(-820,455),Vector2(-825,510),Vector2(-800,555)]),
		PackedVector2Array([Vector2(-595,595),Vector2(-635,620),Vector2(-675,655),Vector2(-705,690),Vector2(-710,725)]),
		PackedVector2Array([Vector2(85,595),Vector2(75,635),Vector2(42,668),Vector2(10,700),Vector2(5,735)]),
		PackedVector2Array([Vector2(425,595),Vector2(470,622),Vector2(520,650),Vector2(585,680),Vector2(650,715),Vector2(690,755)]),
		PackedVector2Array([Vector2(595,255),Vector2(655,255),Vector2(715,270),Vector2(765,300),Vector2(800,340)]),
		PackedVector2Array([Vector2(595,-425),Vector2(680,-425),Vector2(750,-425),Vector2(815,-425),Vector2(835,-470),Vector2(850,-525),Vector2(865,-585)]),
		PackedVector2Array([Vector2(-425,-595),Vector2(-465,-640),Vector2(-510,-690),Vector2(-565,-735)])
	]
	for path_index in range(paths.size()):
		var path: PackedVector2Array = paths[path_index]
		for i in range(path.size()-1):
			_road_segment(path[i],path[i+1],17.0,shoulder,"POI_Road_Shoulder_%02d" % path_index)
			_road_segment(path[i],path[i+1],11.0,asphalt,"POI_Winding_Road_%02d" % path_index)

func _build_city_blocks() -> void:
	var palettes: Array[Material] = [
		_mat(Color(0.62,0.56,0.46)), _mat(Color(0.48,0.51,0.52)),
		_mat(Color(0.72,0.67,0.56)), _mat(Color(0.35,0.40,0.43)),
		_mat(Color(0.64,0.43,0.31)), _mat(Color(0.76,0.74,0.66))
	]
	var glass := _mat(Color(0.12,0.25,0.32),0.28,0.22)
	var roof := _mat(Color(0.19,0.20,0.20))
	var building_slots: Array[Vector2] = [Vector2(-42,-36),Vector2(0,-36),Vector2(42,-36),Vector2(-42,36),Vector2(0,36),Vector2(42,36)]
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
			var lot_count := 6 if gx == 2 and gz == 2 else rng.randi_range(5,6)
			for i in range(lot_count):
				var slot_pos: Vector2 = building_slots[i]
				var bx: float = slot_pos.x + rng.randf_range(-4.0,4.0)
				var bz: float = slot_pos.y + rng.randf_range(-4.0,4.0)
				if gx == 2 and gz == 2:
					_build_commercial_tower(block,i,bx,bz)
					continue
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
						var quarter_turns: int = rng.randi_range(0,3)
						detailed.rotation.y = float(quarter_turns)*PI*0.5
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

func _build_commercial_tower(parent: Node3D, tower_id: int, x: float, z: float) -> void:
	var heights: Array[float] = [58.0,82.0,94.0,46.0,70.0,54.0]
	var widths: Array[float] = [30.0,34.0,29.0,35.0,31.0,37.0]
	var depths: Array[float] = [28.0,31.0,33.0,30.0,35.0,29.0]
	var h: float = heights[tower_id]
	var w: float = widths[tower_id]
	var d: float = depths[tower_id]
	var facade := _mat(Color(0.20,0.31,0.36),0.34,0.30)
	var window := _mat(Color(0.07,0.19,0.25),0.22,0.24)
	var frame := _mat(Color(0.58,0.60,0.57),0.68,0.12)
	var roof_mat := _mat(Color(0.20,0.23,0.25),0.48,0.25)
	_box(parent,"Commercial_Tower_%d" % tower_id,Vector3(w,h,d),Vector3(x,h*0.5+0.1,z),facade,true)
	_box(parent,"Commercial_Roof_%d" % tower_id,Vector3(w+1.2,1.2,d+1.2),Vector3(x,h+0.75,z),roof_mat)
	# A podium and repetitive glazing bands make these visibly different from the Roman residential blocks.
	_box(parent,"Commercial_Podium_%d" % tower_id,Vector3(w+1,3.8,d+1),Vector3(x,2.0,z),frame)
	_box(parent,"Commercial_Entry_%d" % tower_id,Vector3(w*0.52,2.5,0.3),Vector3(x,2.05,z+d*0.5+0.66),window)
	for floor_idx in range(1,int(h/4.5)):
		var fy: float = 3.4+float(floor_idx)*4.5
		_box(parent,"Office_Windows_Front",Vector3(w*0.78,1.65,0.24),Vector3(x,fy,z+d*0.5+0.15),window)
		_box(parent,"Office_Windows_Back",Vector3(w*0.78,1.65,0.24),Vector3(x,fy,z-d*0.5-0.15),window)
		_box(parent,"Office_Windows_Left",Vector3(0.24,1.65,d*0.76),Vector3(x-w*0.5-0.15,fy,z),window)
		_box(parent,"Office_Windows_Right",Vector3(0.24,1.65,d*0.76),Vector3(x+w*0.5+0.15,fy,z),window)
		if floor_idx % 4 == 0:
			_box(parent,"Office_Facade_Belt_F",Vector3(w+0.4,0.35,0.45),Vector3(x,fy+1.1,z+d*0.5),frame)
			_box(parent,"Office_Facade_Belt_B",Vector3(w+0.4,0.35,0.45),Vector3(x,fy+1.1,z-d*0.5),frame)
	for unit in range(3):
		_box(parent,"Rooftop_HVAC",Vector3(4.5,2.4,3.5),Vector3(x-6.0+float(unit)*6.0,h+2.6,z-3.0),frame)
	if tower_id == 2:
		_box(parent,"Office_Antenna",Vector3(0.7,12.0,0.7),Vector3(x,h+7.0,z),roof_mat)

func _build_blender_map_architecture() -> void:
	# Replace the primitive Blender blockouts for the three most visible POIs with existing Godot assets.
	# All locations remain aligned to the authored 2 km island anchors.
	var city := Node3D.new()
	city.name = "Detailed_Citta_Centrale"
	city.position = Vector3(-297.0, 8.0, -250.0)
	add_child(city)
	for i in range(24):
		var archetype_id: int = (i * 7 + 3) % 27
		var archetype_path := "res://baked_city/archetypes_587/archetype_%02d.tscn" % archetype_id
		var archetype := load(archetype_path) as PackedScene
		if archetype == null:
			push_warning("Missing detailed city archetype: " + archetype_path)
			continue
		var detailed := archetype.instantiate() as Node3D
		if detailed == null:
			continue
		detailed.name = "Detailed_Roman_Building_%02d" % archetype_id
		var local_x := float(i % 6) * 36.0 - 90.0
		var local_z := float(int(i / 6)) * 38.0 - 57.0
		var scale_factor := 2.6 + float((i * 3) % 8) * 0.1
		detailed.position = Vector3(local_x, 0.1, local_z)
		detailed.scale = Vector3.ONE * scale_factor
		detailed.rotation.y = float(i % 4) * PI * 0.5
		city.add_child(detailed)

	var commercial := Node3D.new()
	commercial.name = "Detailed_Centro_Commerciale"
	commercial.position = Vector3(406.0, 12.0, 78.0)
	add_child(commercial)
	for tower_id in range(6):
		var local_x := float(tower_id % 3) * 54.0 - 54.0
		var local_z := float(int(tower_id / 3)) * 56.0 - 28.0
		_build_commercial_tower(commercial, tower_id, local_x, local_z)

	_build_industrial_complex()
	_build_landmarks(true)

func _add_industrial_cylinder(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO, collision: bool = false) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 24
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = cylinder
	node.position = pos
	node.rotation_degrees = rotation
	node.material_override = material
	parent.add_child(node)
	if collision:
		var body := StaticBody3D.new()
		body.name = node_name + "_Collision"
		parent.add_child(body)
		var shape := CollisionShape3D.new()
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = radius
		cylinder_shape.height = height
		shape.shape = cylinder_shape
		shape.position = pos
		body.add_child(shape)
	return node

func _build_industrial_complex() -> void:
	# Detailed runtime replacement for the Blender box-and-cylinder blockout.
	var plant := Node3D.new()
	plant.name = "Detailed_Zona_Industriale"
	plant.position = Vector3(31.0, 8.0, 70.0)
	add_child(plant)

	var concrete := _mat(Color(0.34,0.36,0.35),0.92)
	var wall := _mat(Color(0.35,0.39,0.39),0.86)
	var roof := _mat(Color(0.14,0.18,0.19),0.72,0.18)
	var roof_light := _mat(Color(0.28,0.32,0.32),0.62,0.16)
	var glass := _mat(Color(0.055,0.15,0.19),0.26,0.2)
	var metal := _mat(Color(0.25,0.30,0.31),0.52,0.42)
	var tank_mat := _mat(Color(0.39,0.43,0.42),0.62,0.32)
	var tank_cap := _mat(Color(0.25,0.29,0.29),0.58,0.36)
	var rust := _mat(Color(0.48,0.22,0.13),0.76,0.18)
	var safety := _mat(Color(0.91,0.66,0.13),0.66,0.08)
	var dark := _mat(Color(0.075,0.09,0.095),0.76)

	_box(plant,"Industrial_Concrete_Yard",Vector3(150,0.8,126),Vector3(0,0.4,14),concrete,true)
	# Perimeter safety paint and drainage channels break up the bare foundation.
	_box(plant,"Yard_Safety_Line_Front",Vector3(146,0.08,0.7),Vector3(0,0.84,75),safety)
	_box(plant,"Yard_Safety_Line_Back",Vector3(146,0.08,0.7),Vector3(0,0.84,-47),safety)
	_box(plant,"Yard_Safety_Line_Left",Vector3(0.7,0.08,120),Vector3(-73,0.84,14),safety)
	_box(plant,"Yard_Safety_Line_Right",Vector3(0.7,0.08,120),Vector3(73,0.84,14),safety)

	# Main warehouse, segmented roof and visible structural ribs.
	_box(plant,"Factory_Main_Hall",Vector3(106,18,74),Vector3(0,10,-10),wall,true)
	_box(plant,"Factory_Roof_Main",Vector3(112,1.4,80),Vector3(0,19.6,-10),roof)
	for panel_x in range(-48,49,12):
		_box(plant,"Factory_Roof_Panel",Vector3(10.8,0.14,73),Vector3(float(panel_x),20.38,-10),roof_light if int((panel_x+48)/12)%2==0 else roof)
	for rib_x in range(-50,51,25):
		_box(plant,"Factory_Roof_Rib",Vector3(0.7,0.28,76),Vector3(float(rib_x),20.52,-10),metal)
	for vent_x in [-32.0,0.0,32.0]:
		_add_industrial_cylinder(plant,"Factory_Roof_Exhaust",2.0,3.0,Vector3(vent_x,22.5,-10),metal)
		_box(plant,"Factory_Exhaust_Cap",Vector3(5.5,0.35,5.5),Vector3(vent_x,24.0,-10),dark)

	# Four rolling doors and upper ribbon glazing on the front elevation.
	for door_idx in range(4):
		var door_x := -36.0 + float(door_idx)*24.0
		_box(plant,"Factory_Roller_Door",Vector3(10.5,7.5,0.42),Vector3(door_x,5.1,27.42),dark)
		_box(plant,"Factory_Door_Header",Vector3(11.4,0.45,0.7),Vector3(door_x,8.95,27.5),safety)
		_box(plant,"Factory_Door_Frame_Left",Vector3(0.4,7.9,0.6),Vector3(door_x-5.55,5.1,27.5),metal)
		_box(plant,"Factory_Door_Frame_Right",Vector3(0.4,7.9,0.6),Vector3(door_x+5.55,5.1,27.5),metal)
		for slat in range(8):
			_box(plant,"Roller_Door_Slat",Vector3(10.1,0.12,0.47),Vector3(door_x,1.8+float(slat)*0.9,27.72),roof_light)
	for window_x in range(-42,43,14):
		_box(plant,"Factory_Upper_Window",Vector3(10.5,2.3,0.35),Vector3(float(window_x),14.8,27.52),glass)
		_box(plant,"Factory_Window_Sill",Vector3(10.9,0.22,0.55),Vector3(float(window_x),13.55,27.55),metal)
	var plant_sign_panel := _box(plant,"Factory_Sign_Panel",Vector3(32,3.4,0.5),Vector3(0,17.4,27.65),dark)
	var plant_sign := Label3D.new()
	plant_sign.name = "Industrial_Zone_3D_Sign"
	plant_sign.text = "ZONA INDUSTRIALE"
	plant_sign.font_size = 58
	plant_sign.pixel_size = 0.018
	plant_sign.outline_size = 5
	plant_sign.modulate = Color(0.96,0.79,0.3)
	plant_sign.position = Vector3(0,17.15,27.95)
	plant.add_child(plant_sign)

	# Seven tanks with feet, caps, access ports, inspection bands and collision bodies.
	var tank_xs: Array[float] = []
	for tank_idx in range(7):
		var tank_x := -65.0 + float(tank_idx)*21.5
		tank_xs.append(tank_x)
		_box(plant,"Tank_Concrete_Footing",Vector3(17,0.45,17),Vector3(tank_x,0.95,49),concrete,true)
		_add_industrial_cylinder(plant,"Industrial_Process_Tank",7.5,18.0,Vector3(tank_x,10.0,49),tank_mat,Vector3.ZERO,true)
		_add_industrial_cylinder(plant,"Tank_Lower_Ring",7.95,0.42,Vector3(tank_x,4.0,49),metal)
		_add_industrial_cylinder(plant,"Tank_Upper_Ring",7.95,0.42,Vector3(tank_x,15.8,49),metal)
		_add_industrial_cylinder(plant,"Tank_Rust_Inspection_Band",7.82,0.26,Vector3(tank_x,8.0,49),rust)
		_add_industrial_cylinder(plant,"Tank_Top_Cap",7.1,0.55,Vector3(tank_x,19.25,49),tank_cap)
		_add_industrial_cylinder(plant,"Tank_Top_Vent",0.85,2.0,Vector3(tank_x,20.5,49),dark)
		_box(plant,"Tank_Identification_Panel",Vector3(3.4,1.5,0.42),Vector3(tank_x,11.5,56.42),safety)
		if tank_idx % 2 == 0:
			# Ladder rails and individual rungs on alternating tanks keep the asset set detailed but bounded.
			for side in [-1.0,1.0]:
				_box(plant,"Tank_Ladder_Rail",Vector3(0.28,14.6,0.32),Vector3(tank_x+side*1.25,9.0,56.55),metal)
			for rung_idx in range(2,17,2):
				_box(plant,"Tank_Ladder_Rung",Vector3(2.4,0.22,0.36),Vector3(tank_x,float(rung_idx),56.72),metal)

	# Pipe rack between the warehouse and tank farm: headers, supports, valves and pump skids.
	for support_x in range(-60,61,20):
		_box(plant,"Pipe_Rack_Column",Vector3(1.1,10.5,1.1),Vector3(float(support_x),6.1,34),metal,true)
		_box(plant,"Pipe_Rack_Crossbeam",Vector3(3.2,0.6,3.2),Vector3(float(support_x),11.3,34),safety)
	_add_industrial_cylinder(plant,"Pipe_Header_Main",0.95,138.0,Vector3(0,14.6,34),metal,Vector3(0,0,90))
	_add_industrial_cylinder(plant,"Pipe_Header_Return",0.62,136.0,Vector3(0,12.6,37.0),rust,Vector3(0,0,90))
	for pipe_x in tank_xs:
		_add_industrial_cylinder(plant,"Tank_Inlet_Riser",0.5,6.5,Vector3(pipe_x,8.0,39.0),metal)
		_box(plant,"Pipe_Valve_Handle",Vector3(1.6,0.25,1.6),Vector3(pipe_x,11.7,39.0),safety)
	for pump_x in [-45.0,-15.0,15.0,45.0]:
		_box(plant,"Pump_Skid_Base",Vector3(10,0.6,6),Vector3(pump_x,1.25,35),dark,true)
		_add_industrial_cylinder(plant,"Transfer_Pump",1.7,4.2,Vector3(pump_x,3.6,35),metal,Vector3(0,0,90))
		_box(plant,"Pump_Motor",Vector3(4.2,2.8,3.4),Vector3(pump_x+3.2,3.5,35),rust)

	# Auxiliary control room, mounted meters and small window panels on the yard edge.
	_box(plant,"Plant_Control_Room",Vector3(20,9,17),Vector3(59,5.3,-19),wall,true)
	_box(plant,"Control_Room_Roof",Vector3(21.5,1.0,18.5),Vector3(59,10.3,-19),roof)
	for control_x in [53.0,59.0,65.0]:
		_box(plant,"Control_Room_Window",Vector3(4.5,2.3,0.35),Vector3(control_x,6.4,-10.35),glass)
	_box(plant,"Control_Room_Door",Vector3(2.8,5.5,0.35),Vector3(59,3.6,-10.2),dark,true)

func _build_landmarks(use_blender_anchor: bool = false) -> void:
	var stone := _mat(Color(0.69,0.62,0.49))
	var dark := _mat(Color(0.15,0.18,0.19),0.55,0.2)
	var red := _mat(Color(0.72,0.19,0.12))
	var station := Node3D.new()
	station.name = "Aurora_Central_Station"
	if use_blender_anchor:
		station.position = Vector3(195.0, 8.0, -242.0)
	add_child(station)
	_box(station,"Station_Main_Hall",Vector3(118,20,48),Vector3(0,10.1,0),stone,true)
	_box(station,"Station_Glass_Front",Vector3(96,12,0.7),Vector3(0,11.1,24.4),dark)
	var roof_mat := _mat(Color(0.22,0.25,0.27),0.4,0.35)
	_box(station,"Station_Roof",Vector3(126,2,54),Vector3(0,21.1,0),roof_mat)
	var roof_glass := _mat(Color(0.065,0.14,0.18),0.22,0.24)
	var roof_rib := _mat(Color(0.39,0.42,0.42),0.52,0.18)
	for skylight_x in range(-40,41,20):
		_box(station,"Station_Roof_Skylight",Vector3(4.0,0.14,44.0),Vector3(float(skylight_x),22.18,0),roof_glass)
	for rib_x in range(-54,55,12):
		_box(station,"Station_Roof_Rib",Vector3(0.8,0.36,51.0),Vector3(float(rib_x),22.25,0),roof_rib)
	for x in range(-48,49,16):
		_box(station,"Facade_Pillar",Vector3(1.5,15,1.5),Vector3(x,7.6,25),stone)
	var facade_frame := _mat(Color(0.73,0.69,0.60),0.48,0.12)
	var entry_glass := _mat(Color(0.055,0.13,0.17),0.22,0.18)
	for mullion_x in range(-42,43,12):
		_box(station,"Station_Facade_Mullion",Vector3(0.42,11.6,0.38),Vector3(float(mullion_x),11.1,25.08),facade_frame)
	for door_x in [-18.0,-9.0,0.0,9.0,18.0]:
		_box(station,"Station_Entry_Door",Vector3(3.6,5.8,0.30),Vector3(door_x,4.4,25.24),entry_glass)
	_box(station,"Sign_Red",Vector3(36,3.2,0.6),Vector3(0,17.1,25.2),red)
	var station_sign := Label3D.new()
	station_sign.name = "Station_Termini_3D_Sign"
	station_sign.text = "STAZIONE TERMINI"
	station_sign.font_size = 112
	station_sign.pixel_size = 0.022
	station_sign.outline_size = 8
	station_sign.modulate = Color(1.0,0.98,0.88)
	station_sign.position = Vector3(0,17.0,25.65)
	station.add_child(station_sign)
	var platform_mat := _mat(Color(0.48,0.49,0.46),0.92)
	var canopy_mat := _mat(Color(0.25,0.29,0.31),0.46,0.27)
	var rail_mat := _mat(Color(0.10,0.12,0.13),0.36,0.58)
	var sleeper_mat := _mat(Color(0.22,0.18,0.13),0.92)
	for platform_z in [-58.0,-32.0,32.0,58.0]:
		_box(station,"Railway_Platform",Vector3(155,0.65,12),Vector3(0,0.48,platform_z),platform_mat,true)
		_box(station,"Platform_Canopy",Vector3(156,0.75,12),Vector3(0,9.0,platform_z),canopy_mat)
		_box(station,"Platform_Canopy_Glass",Vector3(146,0.08,3.0),Vector3(0,9.42,platform_z),roof_glass)
		_box(station,"Platform_Canopy_Fascia_Front",Vector3(156,0.36,0.55),Vector3(0,9.0,platform_z-5.8),facade_frame)
		_box(station,"Platform_Canopy_Fascia_Back",Vector3(156,0.36,0.55),Vector3(0,9.0,platform_z+5.8),facade_frame)
		for px in range(-70,71,35):
			_box(station,"Platform_Support",Vector3(1.4,8.0,1.4),Vector3(float(px),4.4,platform_z),canopy_mat)
			_box(station,"Platform_Light",Vector3(4.5,0.25,1.3),Vector3(float(px),9.45,platform_z),_mat(Color(0.87,0.81,0.59)))
	# Four parallel tracks and short cross-sleepers make the station readable from above.
	for track_z in [-68.0,-44.0,44.0,68.0]:
		_box(station,"Steel_Rail_Left",Vector3(158,0.28,0.38),Vector3(0,0.87,track_z-2.0),rail_mat)
		_box(station,"Steel_Rail_Right",Vector3(158,0.28,0.38),Vector3(0,0.87,track_z+2.0),rail_mat)
		for px in range(-76,77,8):
			_box(station,"Rail_Sleeper",Vector3(2.5,0.18,5.8),Vector3(float(px),0.64,track_z),sleeper_mat)
	for pz in [-63.0,-37.0,37.0,63.0]:
		_box(station,"Yellow_Platform_Edge",Vector3(152,0.12,0.65),Vector3(0,0.86,pz),_mat(Color(0.93,0.75,0.22)))
	_box(self,"Civic_Tower",Vector3(28,96,28),Vector3(-270,49,270),_mat(Color(0.48,0.53,0.55)),true)
	for y in range(12,94,12):
		_box(self,"Tower_Window_Band",Vector3(28.4,2,28.4),Vector3(-270,float(y),270),dark)
	_box(self,"Tower_Cap",Vector3(34,3,34),Vector3(-270,98,270),stone)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(300,35,-242) if using_blender_map else Vector3(0,2.5,90)
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
	hud_layer = canvas
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
			KEY_6: _set_capture_view("downtown")
			KEY_7: _set_capture_view("snow")

func _set_capture_view(view: String) -> void:
	print("AURORA_VIEW | ", view, " | ", get_window().size, " | ", get_window().position)
	if capture_camera == null:
		return
	if view == "top" and map_overlay == null:
		_build_map_overlay_labels()
	current_capture_view = view
	if map_overlay != null:
		map_overlay.visible = (view == "top")
	if hud_layer != null:
		hud_layer.visible = (view != "top")
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
			capture_camera.global_position = Vector3(335,78,-85)
			capture_camera.look_at(Vector3(195,14,-242))
			capture_camera.fov = 58
		"industrial":
			capture_camera.global_position = Vector3(-145,108,260)
			capture_camera.look_at(Vector3(31,12,70))
			capture_camera.fov = 60
		"coast":
			capture_camera.global_position = Vector3(-1035,95,-160)
			capture_camera.look_at(Vector3(-766,8,-250))
			capture_camera.fov = 62
		"downtown":
			capture_camera.global_position = Vector3(-70,100,-60)
			capture_camera.look_at(Vector3(-297,12,-250))
			capture_camera.fov = 62
		"snow":
			capture_camera.global_position = Vector3(-1150,630,-170)
			capture_camera.look_at(Vector3(-531,145,-719))
			capture_camera.fov = 58
