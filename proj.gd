extends Node3D
## Projétil de ki / bala. Também fornece efeito de explosão (burst).

var vel := Vector3.ZERO
var dmg := 10.0
var team := "player"
var life := 3.0
var explode_r := 2.5
var size := 0.25
var color := Color(0.35, 0.75, 1.0)
var done := false

static func glow_mat(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	return m

static func burst(parent: Node, pos: Vector3, col: Color, r: float, t := 0.3) -> void:
	var m = MeshInstance3D.new()
	var s = SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 5
	var mt = glow_mat(Color(col.r, col.g, col.b, 0.8))
	m.mesh = s
	m.material_override = mt
	m.scale = Vector3.ONE * 0.3
	parent.add_child(m)
	m.global_position = pos
	var tw = m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * r * 2.0, t)
	tw.tween_property(mt, "albedo_color:a", 0.0, t)
	tw.chain().tween_callback(m.queue_free)

func _ready() -> void:
	var core = MeshInstance3D.new()
	var s = SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	s.radial_segments = 10
	s.rings = 5
	core.mesh = s
	core.material_override = glow_mat(Color(1, 1, 1, 1))
	add_child(core)
	var glow = MeshInstance3D.new()
	var s2 = SphereMesh.new()
	s2.radius = size * 1.8
	s2.height = size * 3.6
	s2.radial_segments = 10
	s2.rings = 5
	glow.mesh = s2
	glow.material_override = glow_mat(Color(color.r, color.g, color.b, 0.45))
	add_child(glow)
	var fx = CPUParticles3D.new()
	fx.amount = 10
	fx.lifetime = 0.4
	fx.local_coords = false
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fx.emission_sphere_radius = size * 0.6
	fx.gravity = Vector3.ZERO
	fx.initial_velocity_min = 0.2
	fx.initial_velocity_max = 0.6
	var ps = SphereMesh.new()
	ps.radius = size * 0.6
	ps.height = size * 1.2
	ps.radial_segments = 6
	ps.rings = 3
	var pm = glow_mat(Color(color.r, color.g, color.b, 0.7))
	pm.vertex_color_use_as_albedo = true
	ps.material = pm
	fx.mesh = ps
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.8))
	g.set_color(1, Color(1, 1, 1, 0.0))
	fx.color_ramp = g
	add_child(fx)

func _physics_process(delta: float) -> void:
	if done:
		return
	life -= delta
	var from = global_position
	var to = from + vel * delta
	var q = PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position
		_explode()
		return
	global_position = to
	for e in get_tree().get_nodes_in_group("hurtable"):
		if e.team == team or e.dead:
			continue
		var c: Vector3 = e.global_position + Vector3(0, 1.0, 0)
		if c.distance_to(to) < size + 0.8:
			_explode()
			return
	if life <= 0.0:
		_explode()

func _explode() -> void:
	done = true
	for e in get_tree().get_nodes_in_group("hurtable"):
		if e.team == team or e.dead:
			continue
		var d: float = (e.global_position + Vector3(0, 1, 0)).distance_to(global_position)
		var rr: float = explode_r + 0.6
		if d < rr:
			e.take_damage(dmg * (1.0 - clampf(d / rr, 0.0, 1.0) * 0.5), global_position, 9.0)
	burst(get_tree().current_scene, global_position, color, explode_r, 0.3)
	queue_free()
