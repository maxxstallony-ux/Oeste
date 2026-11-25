extends CharacterBody3D
## Protagonista Saiyajin: terceira pessoa, combate, ki, voo e Super Saiyajin.

const Rig = preload("res://rig.gd")
const Proj = preload("res://proj.gd")

var ui
var rig: Node3D
var cam_pivot: Node3D
var arm: SpringArm3D
var cam: Camera3D
var orb: MeshInstance3D = null

var yaw := 0.0
var pitch := -0.2
var hp := 100.0
var max_hp := 100.0
var ki := 100.0
var max_ki := 100.0
var money := 50
var team := "player"
var dead := false
var ssj := false
var flying := false
var charging := false
var running := false

var atk_time := -1.0
var atk_dur := 0.38
var atk_hit := true
var atk_kind := 0
var combo_reset := 0.0
var fight_face := 0.0
var dodge_time := -1.0
var dodge_cd := 0.0
var dodge_dir := Vector3.ZERO
var ki_hold := -1.0
var blast_t := 0.0
var hurt_t := 0.0
var respawn_t := 0.0
var shake := 0.0
var fly_pitch := 0.0
var aura_state := -1
var spawn_point := Vector3(0, 1.0, 4)

func _ready() -> void:
	add_to_group("player")
	add_to_group("hurtable")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(58.0)
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.35
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	add_child(cs)
	rig = Rig.new()
	add_child(rig)
	rig.build({"saiyan": true, "aura": true, "hair_style": "spiky", "bulk": 1.18, "scale": 0.9,
		"skin": Color(0.93, 0.74, 0.6), "hair": Color(0.04, 0.04, 0.05), "eye": Color(0.04, 0.03, 0.02),
		"shirt": Color(0.1, 0.12, 0.2), "pants": Color(0.2, 0.2, 0.28), "coat": Color(0.42, 0.27, 0.15),
		"has_coat": true, "rolled": true, "holster": true})
	cam_pivot = Node3D.new()
	cam_pivot.top_level = true
	add_child(cam_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 5.5
	arm.collision_mask = 1
	arm.margin = 0.3
	cam_pivot.add_child(arm)
	cam = Camera3D.new()
	cam.far = 600.0
	cam.fov = 70.0
	arm.add_child(cam)
	cam.current = true
	cam_pivot.global_position = global_position + Vector3(0, 1.6, 0)

func _power() -> float:
	return 2.6 if ssj else 1.0

func _physics_process(delta: float) -> void:
	var cd: Vector2 = ui.take_cam()
	yaw -= cd.x * 0.006
	pitch = clampf(pitch - cd.y * 0.005, -1.25, 0.55)
	if dead:
		respawn_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= 26.0 * delta
		move_and_slide()
		rig.update_pose(delta, 0.0, "dead", 0.0)
		_update_camera(delta)
		if respawn_t <= 0.0:
			_respawn()
		return
	var blocked: bool = ui.dialog_open
	var mv: Vector2 = Vector2.ZERO if blocked else ui.move_vec
	if blocked:
		ui.clear_pressed()
	_timers(delta)
	if not blocked:
		_buttons(delta)
	_move(delta, mv, blocked)
	_animate(delta)
	_update_camera(delta)
	_check_interact()
	global_position.x = clampf(global_position.x, -290.0, 290.0)
	global_position.z = clampf(global_position.z, -290.0, 290.0)
	global_position.y = minf(global_position.y, 260.0)
	if global_position.y < -80.0:
		global_position = spawn_point
		velocity = Vector3.ZERO
	ui.set_latched("run", running)

func _timers(delta: float) -> void:
	if atk_time >= 0.0:
		atk_time += delta
		if not atk_hit and atk_time / atk_dur >= 0.4:
			_melee()
		if atk_time >= atk_dur:
			atk_time = -1.0
	combo_reset -= delta
	dodge_cd -= delta
	if dodge_time >= 0.0:
		dodge_time += delta
		if dodge_time > 0.4:
			dodge_time = -1.0
			dodge_cd = 0.6
	blast_t -= delta
	hurt_t -= delta
	shake = maxf(0.0, shake - delta * 1.5)
	if ssj:
		ki -= 2.5 * delta
		if ki <= 0.0:
			ki = 0.0
			_set_ssj(false)
			ui.toast("A transformação acabou: sem ki")
	elif not charging:
		ki = minf(max_ki, ki + 4.0 * delta)
		hp = minf(max_hp, hp + 0.4 * delta)

func _buttons(delta: float) -> void:
	if ui.pop("run"):
		running = not running
	if ui.pop("fly"):
		if flying:
			flying = false
		else:
			flying = true
			velocity.y = 7.0
			Proj.burst(get_tree().current_scene, global_position, Color(1, 1, 1), 1.5, 0.25)
	if ui.pop("ssj"):
		_toggle_ssj()
	charging = ui.held("charge") and atk_time < 0.0 and dodge_time < 0.0
	if charging:
		ki = minf(max_ki, ki + (40.0 if ssj else 28.0) * delta)
		hp = minf(max_hp, hp + 2.0 * delta)
	if ui.pop("jump") and is_on_floor() and not flying and not charging:
		velocity.y = 11.0 if ssj else 9.5
	if ui.pop("dodge") and not flying and dodge_cd <= 0.0 and dodge_time < 0.0 and not charging:
		_start_dodge()
	if ui.pop("atk") and atk_time < 0.0 and not charging and dodge_time < 0.0:
		_start_attack()
	var kh: bool = ui.held("ki")
	if ui.pop("ki") and not charging and ki >= 5.0:
		ki_hold = 0.0
	if ki_hold >= 0.0:
		if kh:
			ki_hold += delta
			_orb_update(ki_hold)
		else:
			_fire_ki(ki_hold)
			ki_hold = -1.0
			_orb_hide()

func _toggle_ssj() -> void:
	if ssj:
		_set_ssj(false)
		return
	if ki < 40.0:
		ui.toast("Ki insuficiente para transformar (40)")
		return
	ki -= 25.0
	_set_ssj(true)
	hp = minf(max_hp, hp + 30.0)
	Proj.burst(get_tree().current_scene, global_position + Vector3(0, 1, 0), Color(1.0, 0.85, 0.2), 6.0, 0.6)
	ui.flash(Color(1.0, 0.9, 0.3))
	shake = 0.6

func _set_ssj(on: bool) -> void:
	ssj = on
	rig.set_ssj(on)
	ui.set_ssj(on)

func _start_dodge() -> void:
	var mv: Vector2 = ui.move_vec
	var d := Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, mv.y)
	if d.length() < 0.1:
		d = rig.global_transform.basis.z
	dodge_dir = d.normalized()
	dodge_time = 0.0
	rig.dodge_t = 0.0

func _start_attack() -> void:
	if combo_reset > 0.0:
		atk_kind = (atk_kind + 1) % 3
	else:
		atk_kind = 0
	combo_reset = 0.8
	atk_time = 0.0
	atk_hit = false
	atk_dur = 0.38 / (1.4 if ssj else 1.0)
	rig.atk_kind = atk_kind
	fight_face = yaw
	var best := 7.0
	for e in get_tree().get_nodes_in_group("hurtable"):
		if e == self or e.team == team or e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		var dist := Vector2(to.x, to.z).length()
		if dist < best:
			best = dist
			fight_face = atan2(-to.x, -to.z)
	var fwd := Vector3(-sin(fight_face), 0, -cos(fight_face))
	velocity.x += fwd.x * 4.0
	velocity.z += fwd.z * 4.0

func _melee() -> void:
	atk_hit = true
	var fwd: Vector3 = -rig.global_transform.basis.z
	var hit_any := false
	for e in get_tree().get_nodes_in_group("hurtable"):
		if e == self or e.team == team or e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() < 2.6 and absf(to.y) < 2.5 and flat.normalized().dot(fwd) > 0.2:
			e.take_damage((8.0 if atk_kind < 2 else 13.0) * _power(), global_position, 7.0 if atk_kind < 2 else 11.0)
			hit_any = true
			Proj.burst(get_tree().current_scene, e.global_position + Vector3(0, 1.1, 0), Color(1, 1, 0.7), 0.6, 0.15)
	if hit_any:
		shake = 0.25

func _aim() -> Vector3:
	var origin: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_transform.basis.z
	var target: Vector3 = origin + fwd * 60.0
	var best_d := 1e9
	for e in get_tree().get_nodes_in_group("hurtable"):
		if e == self or e.team == team or e.dead:
			continue
		var c: Vector3 = e.global_position + Vector3(0, 1.0, 0)
		var to: Vector3 = c - origin
		var dist := to.length()
		if dist < 45.0 and dist > 1.0 and to.normalized().dot(fwd) > 0.93 and dist < best_d:
			target = c
			best_d = dist
	return (target - (global_position + Vector3(0, 1.3, 0))).normalized()

func _fire_ki(h: float) -> void:
	var big := h > 0.6
	var cost := 5.0 if not big else minf(15.0 + h * 15.0, 40.0)
	if ki < cost:
		ui.toast("Ki insuficiente!")
		return
	ki -= cost
	var dir := _aim()
	var p = Proj.new()
	p.team = team
	p.dmg = (10.0 if not big else 28.0 + minf(h, 2.0) * 10.0) * _power()
	p.size = 0.22 if not big else 0.5 + minf(h, 2.0) * 0.2
	p.explode_r = 2.0 if not big else 5.5
	p.vel = dir * (45.0 if not big else 30.0)
	p.color = Color(1.0, 0.85, 0.25) if ssj else Color(0.35, 0.75, 1.0)
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + Vector3(0, 1.3, 0) + dir * 0.9
	blast_t = 0.35
	fight_face = atan2(-dir.x, -dir.z)

func _orb_update(h: float) -> void:
	if orb == null:
		orb = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 5
		orb.mesh = s
		add_child(orb)
	orb.visible = true
	var c := Color(1.0, 0.85, 0.25, 0.8) if ssj else Color(0.4, 0.8, 1.0, 0.8)
	orb.material_override = Proj.glow_mat(c)
	orb.scale = Vector3.ONE * (0.25 + minf(h, 2.0) * 0.4)
	var f: Vector3 = -rig.global_transform.basis.z
	orb.global_position = global_position + Vector3(0, 1.3, 0) + f * 1.0

func _orb_hide() -> void:
	if orb:
		orb.visible = false

func _move(delta: float, mv: Vector2, blocked: bool) -> void:
	var dir: Vector3 = Basis(Vector3.UP, yaw) * Vector3(mv.x, 0.0, mv.y)
	var mag := mv.length()
	var sm := 1.5 if ssj else 1.0
	if dodge_time >= 0.0:
		velocity.x = dodge_dir.x * 17.0 * sm
		velocity.z = dodge_dir.z * 17.0 * sm
		rig.dodge_t = dodge_time / 0.4
		velocity.y -= 26.0 * delta
	else:
		rig.dodge_t = -1.0
		if flying:
			var f: Vector3 = -cam.global_transform.basis.z
			var rt: Vector3 = cam.global_transform.basis.x
			rt.y = 0.0
			rt = rt.normalized()
			var v: Vector3 = f * (-mv.y) + rt * mv.x
			if not blocked:
				if ui.held("jump"):
					v.y += 1.0
				if ui.held("dodge"):
					v.y -= 1.0
			v = v.limit_length(1.0)
			var sp := 15.0 * sm * (1.8 if running else 1.0)
			velocity = velocity.lerp(v * sp, clampf(delta * 5.0, 0.0, 1.0))
			if charging or ki_hold > 0.3:
				velocity *= 0.9
		else:
			var sp := (9.5 if running else 5.0) * sm
			if atk_time >= 0.0:
				sp *= 0.35
			if charging:
				sp = 0.0
			elif ki_hold > 0.3:
				sp *= 0.3
			var tgt := dir * sp * minf(mag * 1.15, 1.0)
			var a := clampf(delta * 12.0, 0.0, 1.0)
			velocity.x = lerpf(velocity.x, tgt.x, a)
			velocity.z = lerpf(velocity.z, tgt.z, a)
			velocity.y -= 26.0 * delta
	move_and_slide()
	if flying and is_on_floor() and (ui.held("dodge") or mag < 0.2) and velocity.y <= 0.5:
		flying = false
	# direção do corpo
	var face := rig.rotation.y
	var fv := Vector3(velocity.x, 0, velocity.z)
	if atk_time >= 0.0 or blast_t > 0.0 or ki_hold >= 0.0:
		face = fight_face
	elif fv.length() > 0.8 and not charging:
		face = atan2(-fv.x, -fv.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, face, clampf(delta * 14.0, 0.0, 1.0))

func _animate(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	var m := "idle"
	var pt := 0.0
	if hurt_t > 0.0:
		m = "hurt"
	elif charging:
		m = "charge"
	elif blast_t > 0.0 or ki_hold >= 0.0:
		m = "blast"
	elif flying:
		if hs > 3.0:
			m = "fly"
			pt = -80.0 * clampf(hs / 6.0, 0.0, 1.0)
		else:
			m = "fly_idle"
	elif not is_on_floor():
		m = "jump" if velocity.y > 0.5 else "fall"
	elif hs > 0.6:
		m = "run" if hs > 6.5 else "walk"
	rig.atk_t = (atk_time / atk_dur) if atk_time >= 0.0 else -1.0
	rig.update_pose(delta, hs, m, pt)
	var want := 2 if ssj else (1 if charging else 0)
	if want != aura_state:
		aura_state = want
		rig.set_aura(want > 0, Color(1.0, 0.85, 0.2) if ssj else Color(0.5, 0.8, 1.0))

func _update_camera(delta: float) -> void:
	var target := global_position + Vector3(0, 1.6, 0)
	cam_pivot.global_position = cam_pivot.global_position.lerp(target, clampf(delta * 10.0, 0.0, 1.0))
	cam_pivot.rotation = Vector3(pitch, yaw, 0)
	cam.h_offset = randf_range(-1.0, 1.0) * shake * 0.2
	cam.v_offset = randf_range(-1.0, 1.0) * shake * 0.2
	cam.fov = lerpf(cam.fov, 80.0 if (flying and velocity.length() > 12.0) else 70.0, clampf(delta * 3.0, 0.0, 1.0))

func _check_interact() -> void:
	if ui.dialog_open:
		return
	var best = null
	var bd := 3.4
	if not flying:
		for n in get_tree().get_nodes_in_group("npc"):
			var d: float = n.global_position.distance_to(global_position)
			if d < bd and n.interactive:
				best = n
				bd = d
	ui.set_target(best)

func take_damage(amount: float, from: Vector3, knock := 0.0) -> void:
	if dead or dodge_time >= 0.0:
		return
	hp -= amount * (0.55 if ssj else 1.0)
	hurt_t = 0.25
	shake = 0.3
	var kb := global_position - from
	kb.y = 0.0
	if kb.length() > 0.01:
		velocity += kb.normalized() * knock * 0.6
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	hp = 0.0
	flying = false
	charging = false
	ki_hold = -1.0
	_orb_hide()
	rig.set_aura(false, Color.WHITE)
	aura_state = -1
	if ssj:
		_set_ssj(false)
	respawn_t = 4.0
	money = maxi(0, money - 10)
	ui.toast("Você foi derrotado... voltando à cidade (-$10)", 3.5)

func _respawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	hp = max_hp
	ki = max_ki
	dead = false
	atk_time = -1.0
