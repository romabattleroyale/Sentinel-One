extends Node3D

const MAP_SIZE := 2000.0
const GRID := 101
const STEP := MAP_SIZE / float(GRID - 1)
const POIS := [
	{"name":"MONTE NEVOSO","x":-531.0,"z":-719.0,"kind":"snow"},
	{"name":"LAGO AZZURRO","x":-94.0,"z":-633.0,"kind":"lake"},
	{"name":"BOSCO OMBRA","x":227.0,"z":-703.0,"kind":"forest"},
	{"name":"ISOLE DEL RELITTO","x":719.0,"z":-734.0,"kind":"islands"},
	{"name":"PORTO","x":-766.0,"z":-250.0,"kind":"port"},
	{"name":"CITTÀ CENTRALE","x":-297.0,"z":-250.0,"kind":"city"},
	{"name":"STAZIONE TERMINI","x":195.0,"z":-242.0,"kind":"station"},
	{"name":"QUARTIERE RESIDENZIALE","x":703.0,"z":-375.0,"kind":"residential"},
	{"name":"COLLINE VERDI","x":-594.0,"z":39.0,"kind":"hills"},
	{"name":"RIVIERA","x":-766.0,"z":289.0,"kind":"riviera"},
	{"name":"ZONA INDUSTRIALE","x":31.0,"z":70.0,"kind":"industry"},
	{"name":"CENTRO COMMERCIALE","x":406.0,"z":78.0,"kind":"commercial"},
	{"name":"ZONA AGRICOLA","x":719.0,"z":78.0,"kind":"farm"},
	{"name":"BASE MILITARE","x":-367.0,"z":422.0,"kind":"military"},
	{"name":"CAVA DESOLATA","x":31.0,"z":523.0,"kind":"quarry"},
	{"name":"DESERTO ROSSO","x":641.0,"z":438.0,"kind":"desert"}
]

func _ready() -> void:
	_build_environment()
	_build_ocean()
	_build_terrain()
	_build_lake()
	_build_pois()
	_build_roads()
	_build_player()
	print("AURORA STRIKE prototype ready: terrain + 16 POIs + touch controls.")

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.66, 0.78)
	e.ambient_light_energy = 0.65
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

func _build_ocean() -> void:
	var ocean := MeshInstance3D.new()
	ocean.name = "DeepOcean"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	ocean.mesh = plane
	ocean.position.y = -3.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.005, 0.12, 0.28)
	mat.roughness = 0.24
	mat.metallic = 0.05
	ocean.material_override = mat
	add_child(ocean)

func _inside_island(x: float, z: float) -> bool:
	# Elliptical island with an irregular coastline, leaving deep ocean outside.
	var nx := x / 960.0
	var nz := z / 960.0
	var edge := 1.0 + 0.045 * sin(x * 0.012) + 0.035 * cos(z * 0.016) + 0.025 * sin((x + z) * 0.021)
	return nx * nx + nz * nz < edge * edge

func _gauss(x: float, z: float, cx: float, cz: float, sx: float, sz: float) -> float:
	return exp(-0.5 * (pow((x - cx) / sx, 2.0) + pow((z - cz) / sz, 2.0)))

func _height(x: float, z: float) -> float:
	var h := 8.0 + 2.0 * sin(x * 0.018) * cos(z * 0.014)
	h += 32.0 * _gauss(x, z, -594, 39, 285, 255)
	h += 20.0 * _gauss(x, z, 227, -703, 300, 265)
	h += 24.0 * _gauss(x, z, 641, 438, 260, 245)
	# Jagged alpine ridge field around Monte Nevoso.
	for p in [Vector3(-575, 0, -770), Vector3(-510, 0, -705), Vector3(-650, 0, -680), Vector3(-445, 0, -780), Vector3(-690, 0, -575)]:
		h += 235.0 * _gauss(x, z, p.x, p.z, 120, 140)
	var alpine := max(_gauss(x, z, -575, -770, 245, 240), _gauss(x, z, -510, -705, 220, 245))
	h += alpine * (pow(abs(sin(x * 0.047 + z * 0.019) * cos(z * 0.039 - x * 0.013)), 3.0) * 24.0)
	h += 7.0 * sin(x * 0.052) * cos(z * 0.047) * max(_gauss(x, z, -594, 39, 285, 255), _gauss(x, z, 641, 438, 260, 245))
	# Flatten the central urban corridor without erasing the terrain silhouette.
	var urban := min(0.72, (_gauss(x, z, -297, -250, 310, 185) + _gauss(x, z, 195, -242, 220, 120)) * 0.6)
	h = lerp(h, 8.0, urban)
	return max(1.8, min(420.0, h))

func _terrain_color(x: float, z: float, h: float) -> Color:
	var c := Color(0.22, 0.38, 0.14)
	var forest := _gauss(x, z, 227, -703, 315, 280)
	c = c.lerp(Color(0.045, 0.17, 0.075), forest * 0.95)
	c = c.lerp(Color(0.38, 0.50, 0.22), _gauss(x, z, -594, 39, 300, 250) * 0.8)
	c = c.lerp(Color(0.64, 0.25, 0.13), _gauss(x, z, 641, 438, 280, 250) * 0.95)
	c = c.lerp(Color(0.69, 0.55, 0.34), _gauss(x, z, 31, 523, 265, 235) * 0.8)
	if h > 75.0:
		c = c.lerp(Color(0.31, 0.30, 0.29), clamp((h - 75.0) / 100.0, 0.0, 0.9))
	if h > 175.0:
		c = c.lerp(Color(0.90, 0.94, 0.98), clamp((h - 175.0) / 115.0, 0.0, 1.0))
	var variation := 0.93 + 0.07 * sin(x * 0.038 + z * 0.021) * sin(z * 0.044 - x * 0.015)
	return Color(c.r * variation, c.g * variation, c.b * variation)

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(GRID - 1):
		for ix in range(GRID - 1):
			var x0 := -MAP_SIZE * 0.5 + ix * STEP
			var x1 := x0 + STEP
			var z0 := -MAP_SIZE * 0.5 + iz * STEP
			var z1 := z0 + STEP
			var pts := [Vector2(x0, z0), Vector2(x0, z1), Vector2(x1, z0), Vector2(x1, z1)]
			var valid := true
			for p in pts:
				if not _inside_island(p.x, p.y):
					valid = false
					break
			if not valid:
				continue
			_add_terrain_vertex(st, x0, z0)
			_add_terrain_vertex(st, x0, z1)
			_add_terrain_vertex(st, x1, z0)
			_add_terrain_vertex(st, x1, z0)
			_add_terrain_vertex(st, x0, z1)
			_add_terrain_vertex(st, x1, z1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "IslandTerrain_BiomeVertexColors"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.94
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var shape := CollisionShape3D.new()
	var trimesh := mi.mesh.create_trimesh_shape()
	shape.shape = trimesh
	body.add_child(shape)
	add_child(body)

func _add_terrain_vertex(st: SurfaceTool, x: float, z: float) -> void:
	var h := _height(x, z)
	st.set_color(_terrain_color(x, z, h))
	st.add_vertex(Vector3(x, h, z))

func _build_lake() -> void:
	var lake := MeshInstance3D.new()
	lake.name = "LagoAzzurro"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 145
	cyl.bottom_radius = 145
	cyl.height = 0.8
	cyl.radial_segments = 64
	lake.mesh = cyl
	lake.position = Vector3(-94, 31, -633)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.42, 0.62, 0.88)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.22
	lake.material_override = mat
	add_child(lake)

func _build_roads() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.10, 0.115, 0.12)
	road_mat.roughness = 0.94
	var roads := [
		[Vector2(-850,-250), Vector2(-700,-250), Vector2(-520,-250), Vector2(-297,-250), Vector2(-50,-245), Vector2(195,-242), Vector2(450,-290), Vector2(703,-375)],
		[Vector2(-594,39), Vector2(-680,85), Vector2(-735,160), Vector2(-766,289), Vector2(-670,280), Vector2(-594,210), Vector2(-450,70), Vector2(-297,-250)],
		[Vector2(31,70), Vector2(40,170), Vector2(10,260), Vector2(-95,335), Vector2(-225,390), Vector2(-367,422), Vector2(-200,480), Vector2(31,523), Vector2(330,480), Vector2(641,438)],
		[Vector2(406,78), Vector2(530,78), Vector2(719,78), Vector2(760,0), Vector2(760,-170), Vector2(703,-375)]
	]
	for path in roads:
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var length := a.distance_to(b)
			var pieces := maxi(2, int(length / 14.0))
			for j in range(pieces):
				var t0 := float(j) / pieces
				var t1 := float(j + 1) / pieces
				var p0 := a.lerp(b, t0)
				var p1 := a.lerp(b, t1)
				var mid := p0.lerp(p1, 0.5)
				var road := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(10.0, 0.7, p0.distance_to(p1) + 1.0)
				road.mesh = box
				road.position = Vector3(mid.x, _height(mid.x, mid.y) + 0.8, mid.y)
				road.look_at(Vector3(p1.x, road.position.y, p1.y), Vector3.UP)
				road.material_override = road_mat
				add_child(road)

func _build_pois() -> void:
	for poi in POIS:
		var root := Node3D.new()
		root.name = str(poi.name).replace(" ", "_")
		root.position = Vector3(poi.x, _height(poi.x, poi.z), poi.z)
		add_child(root)
		var marker := MeshInstance3D.new()
		var shape: Mesh
		if poi.kind == "snow":
			var peak := ConeMesh.new()
			peak.bottom_radius = 54
			peak.top_radius = 1.5
			peak.height = 145
			shape = peak
		elif poi.kind == "forest" or poi.kind == "hills":
			var tree := SphereMesh.new()
			tree.radius = 5.0
			tree.height = 13.0
			shape = tree
		else:
			var building := BoxMesh.new()
			building.size = Vector3(34, 18, 28)
			shape = building
		marker.mesh = shape
		marker.position.y = 10
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _poi_color(str(poi.kind))
		mat.roughness = 0.85
		marker.material_override = mat
		root.add_child(marker)
		var label := Label3D.new()
		label.text = str(poi.name)
		label.position = Vector3(0, 28, 0)
		label.font_size = 48
		label.pixel_size = 0.10
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(label)

func _poi_color(kind: String) -> Color:
	match kind:
		"snow": return Color(0.9, 0.95, 1.0)
		"forest", "hills": return Color(0.07, 0.3, 0.12)
		"desert", "quarry": return Color(0.72, 0.28, 0.12)
		"lake", "islands", "riviera": return Color(0.05, 0.55, 0.65)
		"industry", "military", "station": return Color(0.35, 0.38, 0.4)
		_: return Color(0.72, 0.61, 0.44)

func _build_player() -> void:
	var player_script := load("res://scripts/mobile_player.gd")
	var player := CharacterBody3D.new()
	player.name = "MobilePlayer"
	player.set_script(player_script)
	player.position = Vector3(-390, _height(-390, -320) + 3.0, -320)
	add_child(player)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 1.55, 0)
	camera.current = true
	player.add_child(camera)
	var ui_script := load("res://scripts/mobile_hud.gd")
	var hud := CanvasLayer.new()
	hud.name = "MobileHUD"
	hud.set_script(ui_script)
	add_child(hud)
