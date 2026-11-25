extends Node3D
## Boneco humanoide procedural articulado (frente = -Z).
## Substituível por um modelo GLB com Skeleton3D quando houver arte final:
## basta manter os métodos build(), update_pose(), set_ssj() e set_aura().

var J := {}
var tail: Array = []
var hair_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var fx_mat: StandardMaterial3D
var aura_mat: StandardMaterial3D
var hair_node: Node3D
var aura_root: Node3D
var aura_shell: MeshInstance3D
var aura_fx: CPUParticles3D
var base_hair := Color(0.04, 0.04, 0.05)
var base_eye := Color(0.05, 0.03, 0.02)
var anim_t := 0.0
var atk_t := -1.0
var atk_kind := 0
var dodge_t := -1.0
var was_dodge := false
var saiyan := false
var ssj := false

static func mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

static func blob_mat() -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0.3)
	return m

func _mi(parent: Node, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation_degrees = rot
	n.scale = scl
	parent.add_child(n)
	return n

func _pivot(parent: Node, pos: Vector3, key := "") -> Node3D:
	var n = Node3D.new()
	n.position = pos
	parent.add_child(n)
	if key != "":
		J[key] = n
	return n

func _cap(r: float, h: float) -> CapsuleMesh:
	var c = CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.01)
	c.radial_segments = 10
	c.rings = 4
	return c

func _sph(r: float) -> SphereMesh:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s

func _box(v: Vector3) -> BoxMesh:
	var b = BoxMesh.new()
	b.size = v
	return b

func _cyl(rt: float, rb: float, h: float, seg := 10) -> CylinderMesh:
	var c = CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

func _spike(parent: Node, base: Vector3, d: Vector3, L: float, r: float) -> void:
	var n = MeshInstance3D.new()
	n.mesh = _cyl(0.0, r, L, 5)
	n.material_override = hair_mat
	n.position = base + d * (L * 0.5)
	n.basis = Basis(Quaternion(Vector3.UP, d))
	parent.add_child(n)

func _spiky_hair(parent: Node3D) -> void:
	_mi(parent, _sph(0.135), Vector3(0, -0.01, 0.0), hair_mat, Vector3.ZERO, Vector3(1.0, 0.85, 1.05))
	var dirs := [Vector3(0, 1, 0.1), Vector3(0.45, 0.9, 0), Vector3(-0.45, 0.9, 0), Vector3(0.8, 0.55, 0.1),
		Vector3(-0.8, 0.55, 0.1), Vector3(0.3, 0.75, 0.6), Vector3(-0.3, 0.75, 0.6), Vector3(0, 0.5, 0.9),
		Vector3(0.65, 0.45, 0.6), Vector3(-0.65, 0.45, 0.6)]
	var lens := [0.3, 0.26, 0.26, 0.22, 0.22, 0.24, 0.24, 0.2, 0.2, 0.2]
	for i in dirs.size():
		var d: Vector3 = dirs[i].normalized()
		_spike(parent, d * 0.1, d, lens[i], 0.055)
	_spike(parent, Vector3(0, 0.05, -0.115), Vector3(0, -0.35, -1).normalized(), 0.14, 0.04)
	_spike(parent, Vector3(0.06, 0.07, -0.1), Vector3(0.5, -0.3, -0.9).normalized(), 0.12, 0.035)
	_spike(parent, Vector3(-0.06, 0.07, -0.1), Vector3(-0.5, -0.3, -0.9).normalized(), 0.12, 0.035)

func _glow_tex() -> GradientTexture2D:
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t

func build(o: Dictionary) -> void:
	saiyan = o.get("saiyan", false)
	scale = Vector3.ONE * float(o.get("scale", 0.88))
	var bulk: float = o.get("bulk", 1.0)
	var skin := mat(o.get("skin", Color(0.9, 0.7, 0.55)), 0.7)
	base_hair = o.get("hair", base_hair)
	hair_mat = mat(base_hair, 0.45)
	base_eye = o.get("eye", base_eye)
	var coat_m := mat(o.get("coat", Color(0.4, 0.26, 0.15)), 0.9)
	var shirt_m := mat(o.get("shirt", Color(0.15, 0.15, 0.2)))
	var pants_m := mat(o.get("pants", Color(0.22, 0.24, 0.34)))
	var boot_m := mat(Color(0.17, 0.1, 0.06), 0.6)
	var gold_m := mat(Color(0.9, 0.75, 0.25), 0.3)
	var has_coat: bool = o.get("has_coat", false)
	var tank: bool = o.get("tank", false)
	var rolled: bool = o.get("rolled", false)
	var female: bool = o.get("female", false)
	var dress_m := mat(o.get("dress", Color(0.6, 0.25, 0.3)))

	_mi(self, _cyl(0.5, 0.5, 0.02, 16), Vector3(0, 0.03, 0), blob_mat())
	var body := _pivot(self, Vector3(0, 0.95, 0), "body")
	_mi(body, _sph(0.2), Vector3.ZERO, pants_m, Vector3.ZERO, Vector3(1.25 * bulk, 0.8, 0.95))
	var spine := _pivot(body, Vector3(0, 0.08, 0), "spine")
	_mi(spine, _cap(0.24, 0.74), Vector3(0, 0.34, 0), shirt_m, Vector3.ZERO, Vector3(1.2 * bulk, 1, 0.8))
	if bulk > 1.05:
		for s in [1, -1]:
			_mi(spine, _sph(0.13 * bulk), Vector3(s * 0.13 * bulk, 0.5, -0.1), shirt_m, Vector3.ZERO, Vector3(1, 0.8, 0.7))
		_mi(spine, _sph(0.16), Vector3(0, 0.12, -0.1), shirt_m, Vector3.ZERO, Vector3(1.1, 1, 0.6))

	# pescoço e cabeça
	_mi(spine, _cyl(0.065, 0.075, 0.14), Vector3(0, 0.74, 0), skin)
	var head := _pivot(spine, Vector3(0, 0.8, 0), "head")
	_mi(head, _sph(0.125), Vector3(0, 0.12, 0), skin, Vector3.ZERO, Vector3(0.92, 1.1, 1.0))
	_mi(head, _sph(0.085), Vector3(0, 0.05, -0.025), skin, Vector3.ZERO, Vector3(1.05, 0.75, 0.95))
	_mi(head, _box(Vector3(0.026, 0.04, 0.045)), Vector3(0, 0.1, -0.128), skin)
	eye_mat = mat(base_eye, 0.3)
	var white := mat(Color(0.95, 0.95, 0.95), 0.4)
	for s in [1, -1]:
		_mi(head, _sph(0.024), Vector3(s * 0.05, 0.14, -0.12), white, Vector3.ZERO, Vector3(1, 0.8, 0.4))
		_mi(head, _sph(0.014), Vector3(s * 0.05, 0.14, -0.127), eye_mat, Vector3.ZERO, Vector3(1, 1, 0.4))
		_mi(head, _box(Vector3(0.065, 0.014, 0.014)), Vector3(s * 0.052, 0.176, -0.122), hair_mat, Vector3(0, 0, s * 18))
		_mi(head, _sph(0.03), Vector3(s * 0.115, 0.12, 0.0), skin, Vector3.ZERO, Vector3(0.4, 1, 0.7))
	_mi(head, _box(Vector3(0.05, 0.007, 0.01)), Vector3(0, 0.055, -0.112), mat(Color(0.35, 0.12, 0.1)))
	var facial: String = o.get("facial", "")
	if facial != "":
		_mi(head, _box(Vector3(0.11, 0.025, 0.03)), Vector3(0, 0.075, -0.115), hair_mat)
		if facial == "beard":
			_mi(head, _box(Vector3(0.15, 0.09, 0.05)), Vector3(0, 0.03, -0.08), hair_mat)
	if o.get("mask", false):
		_mi(head, _box(Vector3(0.2, 0.075, 0.07)), Vector3(0, 0.06, -0.085), mat(Color(0.7, 0.15, 0.12)))

	var style: String = o.get("hair_style", "short")
	hair_node = _pivot(head, Vector3(0, 0.145, 0.02))
	if style == "spiky":
		_spiky_hair(hair_node)
	else:
		_mi(hair_node, _sph(0.135), Vector3(0, -0.01, 0.0), hair_mat, Vector3.ZERO, Vector3(1.0, 0.85, 1.05))
		if style == "long":
			_mi(hair_node, _box(Vector3(0.24, 0.5, 0.08)), Vector3(0, -0.25, 0.1), hair_mat)
	if o.get("hat", false):
		var hm := mat(o.get("hat_col", Color(0.3, 0.2, 0.12)), 0.8)
		_mi(head, _cyl(0.3, 0.3, 0.015, 16), Vector3(0, 0.235, 0), hm)
		_mi(head, _cyl(0.13, 0.15, 0.14, 12), Vector3(0, 0.3, 0), hm)

	# braços
	for s in [1, -1]:
		var k: String = "P" if s == 1 else "N"
		var sp := _pivot(spine, Vector3(s * 0.33 * bulk, 0.64, 0), "arm" + k)
		var up_m: StandardMaterial3D = coat_m if has_coat else (skin if tank else shirt_m)
		var fo_m: StandardMaterial3D = skin if (tank or rolled) else up_m
		_mi(sp, _sph(0.1 * bulk), Vector3.ZERO, up_m)
		_mi(sp, _cap(0.075 * bulk, 0.36), Vector3(0, -0.16, 0), up_m)
		var el := _pivot(sp, Vector3(0, -0.31, 0), "elb" + k)
		_mi(el, _cap(0.065 * bulk, 0.32), Vector3(0, -0.14, 0), fo_m)
		_mi(el, _sph(0.068), Vector3(0, -0.3, 0), skin)

	# pernas e botas
	for s in [1, -1]:
		var k: String = "P" if s == 1 else "N"
		var hp := _pivot(body, Vector3(s * 0.12 * bulk, -0.02, 0), "leg" + k)
		_mi(hp, _cap(0.105 * bulk, 0.46), Vector3(0, -0.2, 0), dress_m if female else pants_m)
		var kn := _pivot(hp, Vector3(0, -0.42, 0), "knee" + k)
		_mi(kn, _cap(0.078 * bulk, 0.42), Vector3(0, -0.2, 0), pants_m)
		_mi(kn, _box(Vector3(0.15, 0.28, 0.17)), Vector3(0, -0.34, 0), boot_m)
		_mi(kn, _box(Vector3(0.14, 0.1, 0.16)), Vector3(0, -0.45, -0.1), boot_m)
		_mi(kn, _cyl(0.02, 0.02, 0.04, 6), Vector3(0, -0.42, 0.1), gold_m, Vector3(90, 0, 0))
	if female:
		_mi(body, _cyl(0.17, 0.4, 0.62, 12), Vector3(0, -0.3, 0), dress_m)

	# cinto, fivela, coldre
	if o.get("belt", true):
		_mi(body, _cyl(0.2, 0.2, 0.07, 12), Vector3(0, 0.06, 0), mat(Color(0.25, 0.15, 0.08), 0.6), Vector3.ZERO, Vector3(1.28 * bulk, 1, 0.95))
		_mi(body, _box(Vector3(0.07, 0.06, 0.02)), Vector3(0, 0.06, -0.2), gold_m)
	if o.get("holster", false):
		_mi(body, _box(Vector3(0.05, 0.18, 0.08)), Vector3(0.27 * bulk, -0.06, -0.03), mat(Color(0.2, 0.12, 0.07)))
		_mi(body, _box(Vector3(0.03, 0.07, 0.04)), Vector3(0.27 * bulk, 0.06, -0.03), mat(Color(0.1, 0.1, 0.1)))

	# sobretudo
	if has_coat:
		_mi(spine, _box(Vector3(0.52 * bulk, 0.1, 0.34)), Vector3(0, 0.66, 0), coat_m)
		for s in [1, -1]:
			_mi(spine, _box(Vector3(0.12, 0.62, 0.05)), Vector3(s * 0.16 * bulk, 0.34, -0.2), coat_m, Vector3(0, 0, -s * 4))
		var back := _pivot(body, Vector3(0, 0.02, 0.16), "coatB")
		_mi(back, _box(Vector3(0.5 * bulk, 0.9, 0.04)), Vector3(0, -0.45, 0), coat_m)
		for s in [1, -1]:
			var side := _pivot(body, Vector3(s * 0.26 * bulk, 0.02, -0.02), "coat" + ("P" if s == 1 else "N"))
			_mi(side, _box(Vector3(0.05, 0.85, 0.34)), Vector3(0, -0.42, 0), coat_m)

	# cauda saiyajin
	if saiyan:
		var tm := mat(Color(0.4, 0.24, 0.1), 0.9)
		var parent: Node3D = _pivot(body, Vector3(0, -0.02, 0.17))
		for i in 7:
			var seg := _pivot(parent, Vector3(0, 0, 0) if i == 0 else Vector3(0, 0, 0.16))
			_mi(seg, _cap(0.05 - i * 0.004, 0.2), Vector3(0, 0, 0.08), tm, Vector3(90, 0, 0))
			tail.append(seg)
			parent = seg

	# aura
	if o.get("aura", false):
		aura_root = _pivot(body, Vector3.ZERO)
		aura_root.visible = false
		aura_mat = StandardMaterial3D.new()
		aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		aura_mat.albedo_color = Color(1, 1, 1, 0.2)
		aura_shell = _mi(aura_root, _cap(0.7, 2.2), Vector3.ZERO, aura_mat)
		aura_fx = CPUParticles3D.new()
		aura_fx.amount = 28
		aura_fx.lifetime = 0.9
		aura_fx.local_coords = false
		aura_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		aura_fx.emission_sphere_radius = 0.5
		aura_fx.direction = Vector3.UP
		aura_fx.spread = 15.0
		aura_fx.gravity = Vector3(0, 2.0, 0)
		aura_fx.initial_velocity_min = 1.0
		aura_fx.initial_velocity_max = 2.5
		aura_fx.scale_amount_min = 0.6
		aura_fx.scale_amount_max = 1.2
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.5)
		fx_mat = StandardMaterial3D.new()
		fx_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fx_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fx_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fx_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		fx_mat.billboard_keep_scale = true
		fx_mat.vertex_color_use_as_albedo = true
		fx_mat.albedo_texture = _glow_tex()
		q.material = fx_mat
		aura_fx.mesh = q
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.9))
		g.set_color(1, Color(1, 1, 1, 0.0))
		aura_fx.color_ramp = g
		aura_fx.emitting = false
		aura_root.add_child(aura_fx)

func set_ssj(on: bool) -> void:
	ssj = on
	hair_mat.albedo_color = Color(1.0, 0.88, 0.2) if on else base_hair
	hair_mat.emission_enabled = on
	hair_mat.emission = Color(1.0, 0.8, 0.1)
	hair_mat.emission_energy_multiplier = 0.7
	eye_mat.albedo_color = Color(0.2, 0.9, 0.85) if on else base_eye
	if hair_node:
		hair_node.scale = Vector3(1.15, 1.3, 1.15) if on else Vector3.ONE

func set_aura(on: bool, col: Color) -> void:
	if aura_root == null:
		return
	aura_root.visible = on
	aura_fx.emitting = on
	aura_mat.albedo_color = Color(col.r, col.g, col.b, 0.2)
	fx_mat.albedo_color = Color(col.r, col.g, col.b, 0.8)

func _default_pose() -> Dictionary:
	return {"body": Vector3.ZERO, "spine": Vector3.ZERO, "head": Vector3.ZERO,
		"armP": Vector3(0, 0, 7), "armN": Vector3(0, 0, -7), "elbP": Vector3(14, 0, 0), "elbN": Vector3(14, 0, 0),
		"legP": Vector3(0, 0, 2), "legN": Vector3(0, 0, -2), "kneeP": Vector3.ZERO, "kneeN": Vector3.ZERO,
		"coatB": Vector3.ZERO, "coatP": Vector3.ZERO, "coatN": Vector3.ZERO}

func _add(P: Dictionary, k: String, v: Vector3) -> void:
	P[k] = P[k] + v

func update_pose(delta: float, spd: float, m: String, pitch := 0.0) -> void:
	anim_t += delta
	var t := anim_t
	var P := _default_pose()
	var by := 0.95
	var r: float = clampf(spd / 9.0, 0.0, 1.0)
	P["body"] = Vector3(pitch, 0, 0)
	match m:
		"idle", "talk":
			var br := sin(t * 2.0)
			P["spine"] = Vector3(br * 1.5, 0, 0)
			P["head"] = Vector3(sin(t * 0.7) * 2.0, sin(t * 0.5) * 3.0, 0)
			by += br * 0.004
			P["armP"] = Vector3(0, 0, 8 + br)
			P["armN"] = Vector3(0, 0, -8 - br)
			if m == "talk":
				P["armP"] = Vector3(30 + sin(t * 3.0) * 14, 0, 10)
				P["elbP"] = Vector3(75 + sin(t * 5.0) * 15, 0, 0)
				P["head"] = Vector3(sin(t * 4.0) * 4.0, 0, 0)
		"walk", "run":
			var ph := t * (spd * 1.15 + 2.0)
			var A := 28.0 + 22.0 * r
			var s := sin(ph)
			var K := 35.0 + 45.0 * r
			P["legP"] = Vector3(s * A, 0, 2)
			P["legN"] = Vector3(-s * A, 0, -2)
			P["kneeP"] = Vector3(-maxf(0.0, cos(ph)) * K - 4.0, 0, 0)
			P["kneeN"] = Vector3(-maxf(0.0, -cos(ph)) * K - 4.0, 0, 0)
			P["armP"] = Vector3(-s * A * 0.9, 0, 8)
			P["armN"] = Vector3(s * A * 0.9, 0, -8)
			P["elbP"] = Vector3(25 + 55 * r, 0, 0)
			P["elbN"] = Vector3(25 + 55 * r, 0, 0)
			P["spine"] = Vector3(-(2.0 + 14.0 * r), s * 5.0, 0)
			P["head"] = Vector3((2.0 + 14.0 * r) * 0.6, 0, 0)
			by += (absf(cos(ph)) - 0.6) * 0.05 - r * 0.04
			P["coatB"] = Vector3(-(6.0 + spd * 2.5), 0, 0)
			P["coatP"] = Vector3(-spd * 1.5 + s * 6.0, 0, 0)
			P["coatN"] = Vector3(-spd * 1.5 - s * 6.0, 0, 0)
		"jump":
			P["legP"] = Vector3(40, 0, 3)
			P["kneeP"] = Vector3(-70, 0, 0)
			P["legN"] = Vector3(-10, 0, -3)
			P["kneeN"] = Vector3(-30, 0, 0)
			P["armP"] = Vector3(30, 0, 40)
			P["armN"] = Vector3(30, 0, -40)
			P["coatB"] = Vector3(-25, 0, 0)
		"fall":
			P["legP"] = Vector3(15, 0, 6)
			P["kneeP"] = Vector3(-25, 0, 0)
			P["legN"] = Vector3(-10, 0, -6)
			P["kneeN"] = Vector3(-15, 0, 0)
			P["armP"] = Vector3(0, 0, 55)
			P["armN"] = Vector3(0, 0, -55)
			P["elbP"] = Vector3(20, 0, 0)
			P["elbN"] = Vector3(20, 0, 0)
			P["coatB"] = Vector3(-35, 0, 0)
		"fly":
			P["armP"] = Vector3(175, 0, 3)
			P["armN"] = Vector3(-25, 0, -10)
			P["elbP"] = Vector3(5, 0, 0)
			P["elbN"] = Vector3(25, 0, 0)
			P["legP"] = Vector3(10, 0, 2)
			P["legN"] = Vector3(-6, 0, -2)
			P["kneeP"] = Vector3(-10, 0, 0)
			P["kneeN"] = Vector3(-28, 0, 0)
			P["head"] = Vector3(45, 0, 0)
			P["coatB"] = Vector3(-10, 0, 0)
		"fly_idle":
			by += sin(t * 2.0) * 0.05
			P["armP"] = Vector3(0, 0, 20)
			P["armN"] = Vector3(0, 0, -20)
			P["elbP"] = Vector3(25, 0, 0)
			P["elbN"] = Vector3(25, 0, 0)
			P["legP"] = Vector3(6 + sin(t * 2.0) * 4.0, 0, 4)
			P["legN"] = Vector3(-4 - sin(t * 2.0) * 4.0, 0, -4)
			P["kneeP"] = Vector3(-20, 0, 0)
			P["kneeN"] = Vector3(-26, 0, 0)
			P["coatB"] = Vector3(-15 + sin(t * 2.5) * 6.0, 0, 0)
		"charge":
			by = 0.88
			P["legP"] = Vector3(-5, 0, 18)
			P["legN"] = Vector3(-5, 0, -18)
			P["kneeP"] = Vector3(-30, 0, 0)
			P["kneeN"] = Vector3(-30, 0, 0)
			P["armP"] = Vector3(-10, 0, 28)
			P["armN"] = Vector3(-10, 0, -28)
			P["elbP"] = Vector3(55, 0, 0)
			P["elbN"] = Vector3(55, 0, 0)
			P["spine"] = Vector3(-6 + sin(t * 55.0) * 1.0, sin(t * 47.0) * 1.5, 0)
			P["head"] = Vector3(18, 0, 0)
			P["coatB"] = Vector3(-25 + sin(t * 9.0) * 8.0, 0, 0)
		"blast":
			P["armP"] = Vector3(92, 0, -8)
			P["armN"] = Vector3(92, 0, 8)
			P["elbP"] = Vector3(6, 0, 0)
			P["elbN"] = Vector3(6, 0, 0)
			P["legP"] = Vector3(10, 0, 6)
			P["legN"] = Vector3(-25, 0, -6)
			P["kneeP"] = Vector3(-15, 0, 0)
			P["kneeN"] = Vector3(-15, 0, 0)
			P["spine"] = Vector3(-4, 0, 0)
		"hurt":
			by -= 0.03
			P["spine"] = Vector3(14, 0, 0)
			P["head"] = Vector3(18, 0, 0)
			P["armP"] = Vector3(0, 0, 35)
			P["armN"] = Vector3(0, 0, -35)
			P["elbP"] = Vector3(30, 0, 0)
			P["elbN"] = Vector3(30, 0, 0)
			P["kneeP"] = Vector3(-10, 0, 0)
			P["kneeN"] = Vector3(-10, 0, 0)
		"dead":
			by = 0.2
			P["body"] = Vector3(88, 0, 0)
			P["armP"] = Vector3(0, 0, 30)
			P["armN"] = Vector3(0, 0, -30)
			P["legP"] = Vector3(0, 0, 8)
			P["legN"] = Vector3(0, 0, -8)

	if atk_t >= 0.0:
		var k := sin(clampf(atk_t, 0.0, 1.0) * PI)
		match atk_kind:
			0:
				P["armP"] = P["armP"].lerp(Vector3(98, 0, -4), k)
				P["elbP"] = P["elbP"].lerp(Vector3(5, 0, 0), k)
				P["armN"] = P["armN"].lerp(Vector3(-20, 0, -25), k)
				P["elbN"] = P["elbN"].lerp(Vector3(110, 0, 0), k)
				_add(P, "spine", Vector3(0, 28.0 * k, 0))
				_add(P, "legN", Vector3(-14.0 * k, 0, 0))
			1:
				P["armN"] = P["armN"].lerp(Vector3(98, 0, 4), k)
				P["elbN"] = P["elbN"].lerp(Vector3(5, 0, 0), k)
				P["armP"] = P["armP"].lerp(Vector3(-20, 0, 25), k)
				P["elbP"] = P["elbP"].lerp(Vector3(110, 0, 0), k)
				_add(P, "spine", Vector3(0, -28.0 * k, 0))
				_add(P, "legP", Vector3(-14.0 * k, 0, 0))
			_:
				P["legN"] = P["legN"].lerp(Vector3(105, 0, -4), k)
				P["kneeN"] = P["kneeN"].lerp(Vector3(-8, 0, 0), k)
				P["kneeP"] = P["kneeP"].lerp(Vector3(-12, 0, 0), k)
				_add(P, "spine", Vector3(14.0 * k, 0, 0))
				_add(P, "armP", Vector3(0, 0, 40.0 * k))
				_add(P, "armN", Vector3(0, 0, -40.0 * k))
				by -= 0.06 * k
	if dodge_t >= 0.0:
		P["legP"] = Vector3(80, 0, 2)
		P["legN"] = Vector3(70, 0, -2)
		P["kneeP"] = Vector3(-110, 0, 0)
		P["kneeN"] = Vector3(-110, 0, 0)
		P["armP"] = Vector3(60, 0, 20)
		P["armN"] = Vector3(60, 0, -20)
		P["spine"] = Vector3(-30, 0, 0)

	var a := clampf(delta * 20.0, 0.0, 1.0)
	for key in P:
		var n: Node3D = J.get(key)
		if n:
			n.rotation_degrees = n.rotation_degrees.lerp(P[key], a)
	var bn: Node3D = J["body"]
	bn.position.y = by
	if dodge_t >= 0.0:
		bn.rotation_degrees = Vector3(-360.0 * dodge_t, 0, 0)
		was_dodge = true
	elif was_dodge:
		bn.rotation_degrees = Vector3.ZERO
		was_dodge = false

	for i in tail.size():
		var sw := sin(t * 2.4 - i * 0.6) * (8.0 + r * 10.0)
		tail[i].rotation_degrees = Vector3((-38.0 if i == 0 else -9.0) + sin(t * 1.7 - i * 0.5) * 3.0, sw, 0.0)
	if aura_root and aura_root.visible:
		aura_shell.scale = Vector3.ONE * (1.0 + 0.06 * sin(t * 14.0))
		aura_root.rotation.y += delta * 3.0
