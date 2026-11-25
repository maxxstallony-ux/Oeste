extends Node3D
## Mundo aberto procedural de Velho Oeste: terreno, cidade, fazenda, natureza.

const N := 151
const CELL := 4.0
const FARM := Vector2(-40.0, 150.0)

var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var wood_tex: ImageTexture
var wood_cache := {}
var blades: Node3D
var camps: Array = [Vector3(-170, 0, -40), Vector3(150, 0, 70), Vector3(70, 0, -150)]

func _ready() -> void:
	rng.seed = 1860
	noise.seed = 7
	noise.frequency = 0.004
	noise.fractal_octaves = 3
	noise2.seed = 11
	noise2.frequency = 0.006
	wood_tex = _make_wood()
	_environment()
	_terrain()
	_town()
	_farm()
	_camps()
	_nature()

func _process(delta: float) -> void:
	if blades:
		blades.rotation.z += delta * 0.8

# ---------------------------------------------------------------- terreno
func road_dist(x: float, z: float) -> float:
	var amp := smoothstep(70.0, 160.0, absf(x)) * 28.0
	var d1 := absf(z - sin(x * 0.02) * amp)
	var amp2 := smoothstep(70.0, 160.0, absf(z)) * 28.0
	var d2 := absf(x - sin(z * 0.017 + 1.0) * amp2)
	return minf(d1, d2)

func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := noise.get_noise_2d(x, z) * 14.0 + 4.0
	h += smoothstep(110.0, 230.0, -z) * (50.0 + (noise2.get_noise_2d(x, z) * 0.5 + 0.5) * 90.0)
	var ce := smoothstep(110.0, 170.0, x)
	var cv := absf(noise2.get_noise_2d(x * 0.6 + 100.0, z * 0.6))
	h += ce * (12.0 - (1.0 - smoothstep(0.0, 0.1, cv)) * 38.0)
	var de := smoothstep(110.0, 200.0, -x)
	h = lerpf(h, noise.get_noise_2d(x * 2.0, z * 2.0) * 5.0 + 1.0, de * 0.8)
	var flat := minf(smoothstep(85.0, 125.0, p.length()), smoothstep(45.0, 80.0, p.distance_to(FARM)))
	h *= flat
	var rd := smoothstep(3.5, 9.0, road_dist(x, z))
	return lerpf(h * 0.25, h, rd)

func _color_at(x: float, z: float, h: float) -> Color:
	var c := Color(0.80, 0.64, 0.40)
	var n := noise2.get_noise_2d(x * 3.0, z * 3.0) * 0.06
	c = c.lerp(Color(0.62, 0.42, 0.28), smoothstep(8.0, 30.0, h))
	c = c.lerp(Color(0.45, 0.43, 0.42), smoothstep(45.0, 90.0, h))
	c = c.lerp(Color(0.8, 0.84, 0.88), smoothstep(100.0, 130.0, h))
	c = c.lerp(Color(0.72, 0.32, 0.2), smoothstep(-2.0, -14.0, h) * 0.7)
	c = c.lerp(Color(0.45, 0.58, 0.28), (1.0 - smoothstep(40.0, 85.0, Vector2(x, z).distance_to(FARM))) * 0.85)
	c = c.lerp(Color(0.48, 0.34, 0.22), (1.0 - smoothstep(2.5, 5.5, road_dist(x, z))) * 0.9)
	return Color(c.r + n, c.g + n, c.b + n)

func _terrain() -> void:
	var half := (N - 1) / 2
	var heights := PackedFloat32Array()
	heights.resize(N * N)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in N:
		for i in N:
			var x := (i - half) * CELL
			var z := (j - half) * CELL
			var h := height_at(x, z)
			heights[j * N + i] = h
			st.set_color(_color_at(x, z, h))
			st.add_vertex(Vector3(x, h, z))
	for j in N - 1:
		for i in N - 1:
			var a := j * N + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + N)
			st.add_index(a + 1)
			st.add_index(a + N + 1)
			st.add_index(a + N)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = N
	hs.map_depth = N
	hs.map_data = heights
	cs.shape = hs
	cs.scale = Vector3(CELL, 1.0, CELL)
	body.add_child(cs)
	add_child(body)

func _environment() -> void:
	var sky_m := ProceduralSkyMaterial.new()
	sky_m.sky_top_color = Color(0.3, 0.5, 0.85)
	sky_m.sky_horizon_color = Color(0.86, 0.8, 0.7)
	sky_m.ground_horizon_color = Color(0.86, 0.8, 0.7)
	sky_m.ground_bottom_color = Color(0.6, 0.5, 0.4)
	var sky := Sky.new()
	sky.sky_material = sky_m
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.78, 0.66)
	env.fog_density = 0.0011
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.95, 0.85)
	add_child(sun)

# ---------------------------------------------------------------- helpers
func _make_wood() -> ImageTexture:
	var img := Image.create(64, 64, true, Image.FORMAT_RGB8)
	var rn := RandomNumberGenerator.new()
	rn.seed = 5
	for y in 64:
		var plank := int(y / 8.0)
		var base := 0.78 + 0.1 * sin(plank * 2.3)
		for x in 64:
			var g := base + rn.randf_range(-0.04, 0.04)
			if y % 8 == 0:
				g *= 0.55
			img.set_pixel(x, y, Color(g, g, g))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func wood(c: Color) -> StandardMaterial3D:
	var key := str(c)
	if wood_cache.has(key):
		return wood_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = wood_tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.4, 0.4, 0.4)
	m.roughness = 0.95
	wood_cache[key] = m
	return m

func flat_mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func add_box(parent: Node, pos: Vector3, size: Vector3, m: Material, rot_y := 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

func add_cyl(parent: Node, pos: Vector3, rt: float, rb: float, h: float, m: Material, seg := 10) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func add_collider(parent: Node, pos: Vector3, size: Vector3, rot_y := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation.y = rot_y
	parent.add_child(cs)

func solid_box(pos: Vector3, size: Vector3, m: Material, rot_y := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation.y = rot_y
	add_child(b)
	add_box(b, Vector3(0, size.y / 2.0, 0), size, m)
	add_collider(b, Vector3(0, size.y / 2.0, 0), size)
	return b

func label3d(parent: Node, text: String, pos: Vector3, col := Color(0.18, 0.1, 0.05)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.012
	l.modulate = Color(0.96, 0.9, 0.72)
	l.outline_size = 14
	l.outline_modulate = col
	l.position = pos
	l.visibility_range_end = 70.0
	parent.add_child(l)

func building(pos: Vector3, size: Vector3, col: Color, rot: float, text: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation.y = rot
	add_child(b)
	var wm := wood(col)
	add_box(b, Vector3(0, size.y / 2.0, 0), size, wm)
	add_collider(b, Vector3(0, size.y / 2.0, 0), size)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(size.z + 0.6, 1.6, size.x + 0.6)
	roof.mesh = pm
	roof.material_override = flat_mat(Color(0.33, 0.2, 0.13))
	roof.position = Vector3(0, size.y + 0.8, 0)
	roof.rotation.y = PI / 2.0
	b.add_child(roof)
	var zf := size.z / 2.0
	add_box(b, Vector3(0, size.y + 0.9, zf + 0.12), Vector3(size.x, 1.8, 0.24), wm)
	var porch := flat_mat(Color(0.45, 0.32, 0.2))
	add_box(b, Vector3(0, 0.06, zf + 1.4), Vector3(size.x + 0.4, 0.12, 2.8), porch)
	add_box(b, Vector3(0, 3.4, zf + 1.4), Vector3(size.x + 0.6, 0.15, 2.8), porch)
	for sx in [-1, 1]:
		add_cyl(b, Vector3(sx * size.x / 2.0, 1.7, zf + 2.5), 0.1, 0.1, 3.4, porch, 6)
	var dark := flat_mat(Color(0.2, 0.12, 0.07))
	add_box(b, Vector3(0, 1.2, zf + 0.06), Vector3(1.4, 2.4, 0.12), dark)
	var glass := flat_mat(Color(0.7, 0.82, 0.88), 0.3)
	for sx in [-1, 1]:
		add_box(b, Vector3(sx * size.x * 0.3, 2.0, zf + 0.05), Vector3(1.3, 1.1, 0.1), glass)
	if text != "":
		label3d(b, text, Vector3(0, size.y + 0.9, zf + 0.27))
	return b

func fence(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var ln := d.length()
	var ang := atan2(-d.z, d.x)
	var mid := (a + b) / 2.0
	var m := flat_mat(Color(0.5, 0.36, 0.22))
	var holder := StaticBody3D.new()
	holder.position = mid
	holder.rotation.y = ang
	add_child(holder)
	for k in [0.35, 0.8]:
		add_box(holder, Vector3(0, k, 0), Vector3(ln, 0.08, 0.06), m)
	for i in int(ln / 3.0) + 1:
		add_box(holder, Vector3(-ln / 2.0 + i * 3.0, 0.5, 0), Vector3(0.1, 1.0, 0.1), m)
	add_collider(holder, Vector3(0, 0.55, 0), Vector3(ln, 1.1, 0.15))

func barrel(pos: Vector3) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	add_child(b)
	add_cyl(b, Vector3(0, 0.45, 0), 0.38, 0.38, 0.9, wood(Color(0.55, 0.38, 0.22)), 10)
	add_collider(b, Vector3(0, 0.45, 0), Vector3(0.75, 0.9, 0.75))

func crate(pos: Vector3, rot_y := 0.0) -> void:
	solid_box(pos, Vector3(0.9, 0.9, 0.9), wood(Color(0.62, 0.48, 0.3)), rot_y)

func hitch(pos: Vector3) -> void:
	var m := flat_mat(Color(0.4, 0.28, 0.18))
	var b := StaticBody3D.new()
	b.position = pos
	add_child(b)
	for sx in [-1.5, 1.5]:
		add_cyl(b, Vector3(sx, 0.7, 0), 0.08, 0.08, 1.4, m, 6)
	add_box(b, Vector3(0, 1.2, 0), Vector3(3.2, 0.1, 0.1), m)
	add_collider(b, Vector3(0, 0.7, 0), Vector3(3.2, 1.4, 0.2))

func horse(pos: Vector3, rot_y: float, col: Color) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation.y = rot_y
	add_child(b)
	var m := flat_mat(col)
	add_box(b, Vector3(0, 1.2, 0), Vector3(0.6, 0.7, 1.6), m)
	var neck := add_box(b, Vector3(0, 1.7, -0.85), Vector3(0.28, 0.8, 0.32), m)
	neck.rotation.x = deg_to_rad(-25)
	add_box(b, Vector3(0, 2.0, -1.2), Vector3(0.22, 0.28, 0.55), m)
	add_box(b, Vector3(0, 1.3, 0.9), Vector3(0.12, 0.7, 0.12), flat_mat(Color(0.1, 0.07, 0.05)))
	for sx in [-0.2, 0.2]:
		for sz in [-0.6, 0.6]:
			add_box(b, Vector3(sx, 0.45, sz), Vector3(0.16, 0.9, 0.16), m)
	add_collider(b, Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 1.8))

func well(pos: Vector3) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	add_child(b)
	add_cyl(b, Vector3(0, 0.5, 0), 1.0, 1.1, 1.0, flat_mat(Color(0.55, 0.52, 0.48)), 12)
	var m := flat_mat(Color(0.4, 0.28, 0.18))
	for sx in [-0.9, 0.9]:
		add_cyl(b, Vector3(sx, 1.6, 0), 0.07, 0.07, 2.2, m, 6)
	add_box(b, Vector3(0, 2.8, 0), Vector3(2.4, 0.15, 1.6), flat_mat(Color(0.33, 0.2, 0.13)))
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.1
	sh.height = 1.2
	cs.shape = sh
	cs.position = Vector3(0, 0.6, 0)
	b.add_child(cs)

func wagon(pos: Vector3, rot_y: float) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation.y = rot_y
	add_child(b)
	add_box(b, Vector3(0, 1.0, 0), Vector3(3.2, 0.5, 1.5), wood(Color(0.5, 0.35, 0.2)))
	add_box(b, Vector3(0, 1.5, 0.7), Vector3(3.2, 0.6, 0.1), wood(Color(0.5, 0.35, 0.2)))
	add_box(b, Vector3(0, 1.5, -0.7), Vector3(3.2, 0.6, 0.1), wood(Color(0.5, 0.35, 0.2)))
	for sx in [-1.0, 1.0]:
		for sz in [-0.85, 0.85]:
			var w := add_cyl(b, Vector3(sx, 0.55, sz), 0.55, 0.55, 0.1, flat_mat(Color(0.3, 0.2, 0.12)), 12)
			w.rotation.x = PI / 2.0
	add_collider(b, Vector3(0, 1.0, 0), Vector3(3.3, 1.8, 1.9))

func water_tower(pos: Vector3) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	add_child(b)
	var m := wood(Color(0.45, 0.32, 0.2))
	for sx in [-1.5, 1.5]:
		for sz in [-1.5, 1.5]:
			add_cyl(b, Vector3(sx, 3.5, sz), 0.15, 0.15, 7.0, m, 6)
	add_cyl(b, Vector3(0, 8.0, 0), 2.2, 2.2, 3.0, m, 14)
	add_cyl(b, Vector3(0, 10.2, 0), 0.0, 2.5, 1.6, flat_mat(Color(0.33, 0.2, 0.13)), 14)
	add_collider(b, Vector3(0, 4.0, 0), Vector3(3.4, 8.0, 3.4))

# ---------------------------------------------------------------- cidade
func _town() -> void:
	building(Vector3(-36, 0, -15), Vector3(14, 6, 10), Color(0.6, 0.38, 0.22), 0.0, "SALOON")
	building(Vector3(-12, 0, -14), Vector3(10, 5, 8), Color(0.55, 0.5, 0.42), 0.0, "DELEGACIA")
	building(Vector3(10, 0, -14), Vector3(10, 5, 8), Color(0.65, 0.5, 0.3), 0.0, "LOJA GERAL")
	building(Vector3(32, 0, -14), Vector3(11, 5.5, 8), Color(0.5, 0.36, 0.25), 0.0, "BANCO")
	building(Vector3(-38, 0, 16), Vector3(16, 5, 12), Color(0.55, 0.28, 0.2), PI, "ESTÁBULO")
	building(Vector3(-14, 0, 14), Vector3(9, 4.5, 8), Color(0.7, 0.62, 0.45), PI, "")
	building(Vector3(6, 0, 14), Vector3(9, 4.5, 8), Color(0.6, 0.5, 0.4), PI, "")
	building(Vector3(28, 0, 15), Vector3(12, 4.5, 10), Color(0.4, 0.34, 0.3), PI, "FERRARIA")
	var church := building(Vector3(-16, 0, -58), Vector3(10, 6, 14), Color(0.85, 0.82, 0.76), 0.0, "IGREJA")
	add_box(church, Vector3(0, 8.5, 0), Vector3(3, 6, 3), wood(Color(0.85, 0.82, 0.76)))
	add_cyl(church, Vector3(0, 12.5, 0), 0.0, 2.2, 2.5, flat_mat(Color(0.33, 0.2, 0.13)), 4)
	var spots := [Vector2(-62, -22), Vector2(-60, 24), Vector2(60, -24), Vector2(62, 22),
		Vector2(-26, -44), Vector2(22, -46), Vector2(-30, 46), Vector2(32, 48)]
	var cols := [Color(0.62, 0.45, 0.3), Color(0.7, 0.6, 0.45), Color(0.5, 0.4, 0.32), Color(0.66, 0.52, 0.36)]
	for i in spots.size():
		var s: Vector2 = spots[i]
		var d := -s.normalized()
		building(Vector3(s.x, 0, s.y), Vector3(8, 4.2, 7), cols[i % 4], atan2(d.x, d.y), "")
	for x in [-40.0, -33.0]:
		hitch(Vector3(x, 0, -6.2))
	horse(Vector3(-39.2, 0, -6.2), PI / 2.0, Color(0.45, 0.28, 0.15))
	horse(Vector3(-33.6, 0, -6.2), -PI / 2.0, Color(0.15, 0.12, 0.1))
	horse(Vector3(-44, 0, 8), 0.4, Color(0.8, 0.75, 0.65))
	hitch(Vector3(-12, 0, -6.2))
	well(Vector3(4, 0, 5))
	wagon(Vector3(22, 0, 5), 0.3)
	water_tower(Vector3(58, 0, -32))
	for p in [Vector3(-28, 0, -9), Vector3(-44.5, 0, -9), Vector3(4, 0, -9), Vector3(40, 0, -9), Vector3(-6, 0, 9), Vector3(14, 0, 9)]:
		barrel(p)
	for p in [Vector3(-27, 0, -9.2), Vector3(5, 0, -9.3), Vector3(41, 0, -9.2), Vector3(16.5, 0, 9.2)]:
		crate(p, rng.randf() * 3.0)

# ---------------------------------------------------------------- fazenda
func _farm() -> void:
	var fx := FARM.x
	var fz := FARM.y
	building(Vector3(fx, 0, fz - 20), Vector3(16, 8, 12), Color(0.6, 0.18, 0.14), 0.0, "CELEIRO")
	building(Vector3(fx + 28, 0, fz), Vector3(9, 4.5, 8), Color(0.75, 0.7, 0.6), -PI / 2.0, "")
	var green := flat_mat(Color(0.38, 0.52, 0.22))
	for i in 4:
		var mi := add_box(self, Vector3(fx - 20 + i * 12, 0.05, fz + 10), Vector3(9, 0.1, 22), flat_mat(Color(0.35 + i * 0.03, 0.5, 0.2)))
		mi.name = "Campo%d" % i
	fence(Vector3(fx - 32, 0, fz - 4), Vector3(fx + 18, 0, fz - 4))
	fence(Vector3(fx - 32, 0, fz + 28), Vector3(fx + 18, 0, fz + 28))
	fence(Vector3(fx - 32, 0, fz - 4), Vector3(fx - 32, 0, fz + 28))
	fence(Vector3(fx + 18, 0, fz - 4), Vector3(fx + 18, 0, fz + 28))
	for i in 5:
		var h := StaticBody3D.new()
		h.position = Vector3(fx - 8 + i * 5, 0, fz - 32)
		add_child(h)
		add_cyl(h, Vector3(0, 0.9, 0), 1.2, 1.4, 1.8, flat_mat(Color(0.85, 0.7, 0.3)), 8)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 1.4
		sh.height = 1.8
		cs.shape = sh
		cs.position = Vector3(0, 0.9, 0)
		h.add_child(cs)
	var wm := StaticBody3D.new()
	wm.position = Vector3(fx - 36, 0, fz + 10)
	add_child(wm)
	add_cyl(wm, Vector3(0, 5, 0), 1.0, 2.0, 10, wood(Color(0.7, 0.65, 0.55)), 8)
	add_collider(wm, Vector3(0, 5, 0), Vector3(3.6, 10, 3.6))
	blades = Node3D.new()
	blades.position = Vector3(0, 9.5, -2.2)
	wm.add_child(blades)
	for i in 4:
		var bl := add_box(blades, Vector3.ZERO, Vector3(0.5, 7, 0.1), wood(Color(0.8, 0.75, 0.6)))
		bl.rotation.z = i * PI / 2.0
		bl.position = Vector3(0, 0, 0)

# ---------------------------------------------------------------- acampamentos
func _camps() -> void:
	for c in camps:
		var y := height_at(c.x, c.z)
		var fire := add_cyl(self, Vector3(c.x, y + 0.3, c.z), 0.0, 0.5, 0.9, Proj_glow(), 6)
		fire.name = "Fogueira"
		for k in 6:
			var a := k * TAU / 6.0
			var s := add_cyl(self, Vector3(c.x + cos(a) * 1.0, y + 0.15, c.z + sin(a) * 1.0), 0.25, 0.3, 0.3, flat_mat(Color(0.4, 0.4, 0.4)), 5)
			s.name = "Pedra%d" % k
		for t in 2:
			var tp := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(3.2, 2.2, 3.5)
			tp.mesh = pm
			tp.material_override = flat_mat(Color(0.75, 0.68, 0.5))
			var ang := t * PI + 0.6
			var tx: float = c.x + cos(ang) * 6.0
			var tz: float = c.z + sin(ang) * 6.0
			tp.position = Vector3(tx, height_at(tx, tz) + 1.0, tz)
			tp.rotation.y = ang
			add_child(tp)

func Proj_glow() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.55, 0.15)
	return m

# ---------------------------------------------------------------- natureza
func _mm(mesh: Mesh, m: Material, xf: Array) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	add_child(mi)

func _nature() -> void:
	var cactus := CapsuleMesh.new()
	cactus.radius = 0.3
	cactus.height = 3.2
	cactus.radial_segments = 6
	cactus.rings = 2
	var arm := CapsuleMesh.new()
	arm.radius = 0.17
	arm.height = 1.0
	arm.radial_segments = 6
	arm.rings = 2
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.35
	trunk.height = 2.0
	trunk.radial_segments = 6
	var pine := CylinderMesh.new()
	pine.top_radius = 0.0
	pine.bottom_radius = 1.7
	pine.height = 5.0
	pine.radial_segments = 7
	var oak := SphereMesh.new()
	oak.radius = 2.4
	oak.height = 4.0
	oak.radial_segments = 8
	oak.rings = 4
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 7
	rock.rings = 4
	var cx: Array = []
	var ax: Array = []
	var tx: Array = []
	var px: Array = []
	var ox: Array = []
	var ot: Array = []
	var rx: Array = []
	var body := StaticBody3D.new()
	add_child(body)
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.55
	cyl.height = 3.0
	for i in 2400:
		var x := rng.randf_range(-285.0, 285.0)
		var z := rng.randf_range(-285.0, 285.0)
		var p := Vector2(x, z)
		var near_farm := p.distance_to(FARM) < 60.0
		if p.length() < 95.0 and not near_farm:
			continue
		if road_dist(x, z) < 8.0:
			continue
		var h := height_at(x, z)
		var yaw := rng.randf() * TAU
		var s := rng.randf_range(0.7, 1.4)
		var bas := Basis(Vector3.UP, yaw)
		var kind := ""
		if near_farm:
			if p.distance_to(FARM) > 38.0 and ox.size() < 40:
				kind = "oak"
		elif z < -110.0 and h > 6.0 and h < 90.0:
			if px.size() < 200 and rng.randf() < 0.5:
				kind = "pine"
		elif h > -1.0 and h < 25.0:
			if cx.size() < 140 and rng.randf() < 0.45:
				kind = "cactus"
		if kind == "" and rx.size() < 170 and rng.randf() < 0.12:
			kind = "rock"
		match kind:
			"cactus":
				cx.append(Transform3D(bas.scaled(Vector3.ONE * s), Vector3(x, h + 1.6 * s, z)))
				ax.append(Transform3D(bas * Basis(Vector3(0, 0, 1), PI / 2.0), Vector3(x, h + 1.7 * s, z) + bas * Vector3(0.55 * s, 0, 0)))
				ax.append(Transform3D(bas, Vector3(x, h + 2.3 * s, z) + bas * Vector3(1.0 * s, 0, 0)))
			"pine":
				var ps := s * 1.3
				tx.append(Transform3D(bas.scaled(Vector3.ONE * ps), Vector3(x, h + 1.0 * ps, z)))
				px.append(Transform3D(bas.scaled(Vector3.ONE * ps), Vector3(x, h + 4.2 * ps, z)))
			"oak":
				tx.append(Transform3D(bas.scaled(Vector3(1.2, 1.5, 1.2) * s), Vector3(x, h + 1.5 * s, z)))
				ox.append(Transform3D(bas.scaled(Vector3(1, 0.8, 1) * s), Vector3(x, h + 4.2 * s, z)))
			"rock":
				var big := rng.randf_range(0.8, 3.2)
				rx.append(Transform3D(bas.scaled(Vector3(big, big * rng.randf_range(0.5, 0.9), big * rng.randf_range(0.8, 1.2))), Vector3(x, h + big * 0.2, z)))
				if big > 1.8:
					var cs := CollisionShape3D.new()
					var sh := SphereShape3D.new()
					sh.radius = big * 0.8
					cs.shape = sh
					cs.position = Vector3(x, h + big * 0.2, z)
					body.add_child(cs)
		if kind == "cactus" or kind == "pine" or kind == "oak":
			var cs2 := CollisionShape3D.new()
			cs2.shape = cyl
			cs2.position = Vector3(x, h + 1.5, z)
			body.add_child(cs2)
	_mm(cactus, flat_mat(Color(0.25, 0.5, 0.25)), cx)
	_mm(arm, flat_mat(Color(0.25, 0.5, 0.25)), ax)
	_mm(trunk, flat_mat(Color(0.35, 0.22, 0.12)), tx)
	_mm(pine, flat_mat(Color(0.12, 0.32, 0.18)), px)
	_mm(oak, flat_mat(Color(0.3, 0.5, 0.2)), ox)
	_mm(rock, flat_mat(Color(0.5, 0.43, 0.38), 1.0), rx)
