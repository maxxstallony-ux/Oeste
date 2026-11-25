extends CharacterBody3D
## NPC com aparência própria, animações e comportamento básico.
## Papéis: villager/merchant/sheriff (amistosos, interativos) e bandit (hostil).

const Rig = preload("res://rig.gd")
const Proj = preload("res://proj.gd")

var npc_name := "Aldeão"
var role := "villager"
var lines: Array = []
var look_text := ""
var shop: Array = []
var look_cfg := {}
var interactive := true
var team := "npc"
var hp := 40.0
var max_hp := 40.0
var dead := false
var home := Vector3.ZERO
var wander_r := 7.0
var squash := 0.5
var gun := false
var speed := 1.5
var rig: Node3D
var target := Vector3.ZERO
var state := "idle"
var state_t := 2.0
var talking := false
var player = null
var atk_cd := 1.0
var atk_anim := -1.0
var shoot_t := 0.0
var hurt_t := 0.0
var respawn_t := 0.0
var aggro := false
var chase_face := 0.0

func setup(cfg: Dictionary) -> void:
	npc_name = cfg.get("name", npc_name)
	role = cfg.get("role", role)
	lines = cfg.get("lines", [])
	look_text = cfg.get("look", "")
	shop = cfg.get("shop", [])
	look_cfg = cfg.get("look_cfg", {})
	wander_r = cfg.get("wander", wander_r)
	squash = cfg.get("squash", squash)
	gun = cfg.get("gun", false)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.5
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.35
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	add_child(cs)
	rig = Rig.new()
	add_child(rig)
	rig.build(look_cfg)
	rig.rotation.y = randf() * TAU
	home = global_position
	var lb := Label3D.new()
	lb.text = npc_name
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.pixel_size = 0.006
	lb.font_size = 56
	lb.outline_size = 10
	lb.position = Vector3(0, 2.15, 0)
	lb.visibility_range_end = 22.0
	add_child(lb)
	if role == "bandit":
		team = "bandit"
		interactive = false
		hp = 45.0
		max_hp = 45.0
		lb.modulate = Color(1.0, 0.45, 0.4)
		add_to_group("hurtable")
	else:
		lb.modulate = Color(1.0, 0.95, 0.7)
		add_to_group("npc")
	state_t = randf_range(0.5, 4.0)

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	if global_position.distance_squared_to(player.global_position) > 100.0 * 100.0:
		return
	if dead:
		respawn_t -= delta
		velocity = Vector3(0, velocity.y - 24.0 * delta, 0)
		move_and_slide()
		rig.update_pose(delta, 0.0, "dead", 0.0)
		if respawn_t <= 0.0:
			_revive()
		return
	hurt_t -= delta
	atk_cd -= delta
	shoot_t -= delta
	var want := Vector3.ZERO
	aggro = false
	if talking:
		want = Vector3.ZERO
	elif role == "bandit":
		want = _bandit_ai()
	else:
		want = _wander(delta)
	var a := clampf(delta * 8.0, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, want.x, a)
	velocity.z = lerpf(velocity.z, want.z, a)
	velocity.y -= 24.0 * delta
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z).length()
	var face := rig.rotation.y
	if talking:
		var d: Vector3 = player.global_position - global_position
		face = atan2(-d.x, -d.z)
	elif aggro:
		face = chase_face
	elif hs > 0.3:
		face = atan2(-velocity.x, -velocity.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, face, clampf(delta * 8.0, 0.0, 1.0))
	var m := "idle"
	if hurt_t > 0.0:
		m = "hurt"
	elif shoot_t > 0.0:
		m = "blast"
	elif talking:
		m = "talk"
	elif hs > 3.0:
		m = "run"
	elif hs > 0.4:
		m = "walk"
	if atk_anim >= 0.0:
		atk_anim += delta / 0.4
		rig.atk_t = atk_anim
		if atk_anim > 1.0:
			atk_anim = -1.0
			rig.atk_t = -1.0
	rig.update_pose(delta, hs, m, 0.0)

func _wander(delta: float) -> Vector3:
	state_t -= delta
	if state == "idle":
		if state_t <= 0.0:
			var ang := randf() * TAU
			var r := randf_range(1.5, wander_r)
			target = home + Vector3(cos(ang) * r, 0, sin(ang) * r * squash)
			state = "walk"
			state_t = 8.0
		return Vector3.ZERO
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.7 or state_t <= 0.0:
		state = "idle"
		state_t = randf_range(2.0, 6.0)
		return Vector3.ZERO
	return to.normalized() * speed

func _bandit_ai() -> Vector3:
	if player.dead:
		return _wander(0.033)
	var to: Vector3 = player.global_position - global_position
	var dist := Vector2(to.x, to.z).length()
	if dist > 28.0:
		return _wander(0.033)
	var dir := Vector3(to.x, 0, to.z).normalized()
	aggro = true
	chase_face = atan2(-dir.x, -dir.z)
	if gun:
		if dist > 14.0:
			return dir * 3.5
		if dist < 7.0:
			return -dir * 2.5
		if atk_cd <= 0.0:
			_shoot(to)
		return Vector3.ZERO
	if dist > 1.8:
		return dir * 4.2
	if atk_cd <= 0.0 and dist <= 2.3:
		atk_cd = 1.3
		atk_anim = 0.0
		rig.atk_kind = randi() % 3
		player.take_damage(7.0, global_position, 5.0)
	return Vector3.ZERO

func _shoot(to: Vector3) -> void:
	atk_cd = randf_range(1.6, 2.6)
	shoot_t = 0.35
	var p = Proj.new()
	p.team = team
	p.dmg = 6.0
	p.size = 0.12
	p.explode_r = 1.2
	p.life = 2.5
	p.color = Color(1.0, 0.55, 0.15)
	var from := global_position + Vector3(0, 1.3, 0)
	var aim: Vector3 = (player.global_position + Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1))) - from
	p.vel = aim.normalized() * 24.0
	get_tree().current_scene.add_child(p)
	p.global_position = from + aim.normalized() * 0.8

func take_damage(amount: float, from: Vector3, knock := 0.0) -> void:
	if dead:
		return
	hp -= amount
	hurt_t = 0.3
	var kb := global_position - from
	kb.y = 0.0
	if kb.length() > 0.01:
		velocity += kb.normalized() * knock
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	respawn_t = 30.0
	collision_layer = 0
	var gain := randi_range(5, 18)
	player.money += gain
	player.ui.toast("Bandido derrotado! +$%d" % gain)

func _revive() -> void:
	dead = false
	hp = max_hp
	collision_layer = 4
	global_position = home + Vector3(0, 1.0, 0)
	velocity = Vector3.ZERO

# ------------------------------------------------------------ população
static func populate(parent: Node, world: Node) -> void:
	var skins := [Color(0.93, 0.74, 0.6), Color(0.8, 0.6, 0.45), Color(0.6, 0.42, 0.3), Color(0.95, 0.8, 0.7)]
	var hairs := [Color(0.1, 0.07, 0.05), Color(0.3, 0.2, 0.1), Color(0.55, 0.4, 0.2), Color(0.6, 0.6, 0.6), Color(0.05, 0.05, 0.05)]
	var S = load("res://npc.gd")
	var data := [
		{"name": "Xerife Walker", "role": "sheriff", "pos": Vector3(-12, 0, -6), "wander": 5.0,
		 "look": "Queixo quadrado, estrela de latão no peito. A mão dele nunca se afasta do revólver.",
		 "lines": ["Bom dia, forasteiro. Não costumo ver rostos novos por aqui.", "Essa cauda e esse cabelo... prefiro não perguntar de onde você veio.", "Bandidos acampam no deserto a oeste, no cânion a leste e ao norte, perto das montanhas. Se puder dar um jeito neles, a cidade agradece.", "Mantenha a paz e ninguém sai ferido."],
		 "cfg": {"has_coat": true, "hat": true, "hat_col": Color(0.25, 0.2, 0.15), "shirt": Color(0.5, 0.5, 0.45), "pants": Color(0.2, 0.22, 0.3), "facial": "mustache", "holster": true, "bulk": 1.1}},
		{"name": "Jack, o Barman", "role": "merchant", "pos": Vector3(-36, 0, -7), "wander": 4.0,
		 "look": "Avental manchado, bigode enrolado e um pano sempre no ombro.",
		 "lines": ["Bem-vindo ao Saloon! Aqui a cerveja é gelada e a conversa é de graça.", "Dizem que um guerreiro de cabelos dourados brilhou nos céus do deserto uma noite dessas. Boato de bêbado, claro.", "Precisa se recuperar? Tenho algo para você."],
		 "shop": [{"name": "Cerveja gelada", "price": 5, "hp": 10, "ki": 5}, {"name": "Ensopado de feijão", "price": 12, "hp": 35, "ki": 0}],
		 "cfg": {"shirt": Color(0.9, 0.9, 0.85), "pants": Color(0.2, 0.2, 0.22), "facial": "mustache"}},
		{"name": "Dona Molly", "role": "merchant", "pos": Vector3(10, 0, -6), "wander": 4.0,
		 "look": "Óculos pequenos e um sorriso gentil. Conhece o preço de tudo.",
		 "lines": ["Loja Geral da Molly! De pregos a poções, tenho de tudo.", "Os cristais de ki vêm de uma mina lá no norte. Raros, mas valem cada moeda.", "Volte sempre, querido."],
		 "shop": [{"name": "Pão fresco", "price": 5, "hp": 15, "ki": 0}, {"name": "Poção de cura", "price": 20, "hp": 60, "ki": 0}, {"name": "Cristal de Ki", "price": 25, "hp": 0, "ki": 60}],
		 "cfg": {"female": true, "dress": Color(0.35, 0.5, 0.6), "hair_style": "long", "hair": Color(0.6, 0.6, 0.6), "bulk": 0.9}},
		{"name": "Tio Ezra", "role": "merchant", "pos": Vector3(-38, 0, 8), "wander": 5.0,
		 "look": "Cheira a feno e couro. Tem palha presa na barba.",
		 "lines": ["Estes são os melhores cavalos do condado. Nenhum à venda, infelizmente.", "Cavalo nenhum acompanha quem voa, não é mesmo?", "Aceita uma maçã? Faz bem."],
		 "shop": [{"name": "Maçã", "price": 3, "hp": 8, "ki": 0}],
		 "cfg": {"hat": true, "hat_col": Color(0.5, 0.4, 0.25), "facial": "beard", "hair": Color(0.6, 0.6, 0.6), "shirt": Color(0.6, 0.25, 0.2), "pants": Color(0.3, 0.3, 0.4)}},
		{"name": "Hank, o Ferreiro", "role": "villager", "pos": Vector3(28, 0, 9), "wander": 4.0,
		 "look": "Braços enormes, cobertos de fuligem. Cada martelada ecoa pela rua.",
		 "lines": ["Ferro bom não se apressa.", "Vi o seu tamanho... você parece capaz de entortar uma barra só com as mãos.", "Se algum dia precisar de ferradura, sabe onde me achar."],
		 "cfg": {"tank": true, "bulk": 1.3, "shirt": Color(0.25, 0.2, 0.15), "pants": Color(0.3, 0.25, 0.2), "facial": "beard", "hair": Color(0.1, 0.07, 0.05)}},
		{"name": "Fazendeira Rose", "role": "merchant", "pos": Vector3(-35, 0, 128), "wander": 14.0,
		 "look": "Chapéu de palha, mãos calejadas e cheiro de terra molhada.",
		 "lines": ["As colheitas este ano vieram boas, graças a Deus.", "O moinho nunca para. Parece que o vento nunca cansa por aqui.", "Leva um leite fresco? Acabei de tirar."],
		 "shop": [{"name": "Leite fresco", "price": 6, "hp": 15, "ki": 10}],
		 "cfg": {"female": true, "hat": true, "hat_col": Color(0.85, 0.75, 0.45), "dress": Color(0.55, 0.65, 0.4), "hair_style": "long", "hair": Color(0.45, 0.3, 0.15), "bulk": 0.9}},
		{"name": "Velho Silas", "role": "villager", "pos": Vector3(0, 0, 3), "wander": 9.0, "look": "Um velho encurvado, apoiado numa bengala torta.",
		 "lines": ["No meu tempo, a gente atravessava o deserto a pé.", "Cuidado com os cânions a leste. Ninguém volta de lá sem cicatriz.", "Hmm? Que cauda é essa? Bah, estou velho demais para me espantar."],
		 "cfg": {"hat": true, "hat_col": Color(0.3, 0.3, 0.3), "hair": Color(0.8, 0.8, 0.8), "facial": "beard", "scale": 0.82, "shirt": Color(0.4, 0.35, 0.3), "pants": Color(0.35, 0.3, 0.25)}},
		{"name": "Lily", "role": "villager", "pos": Vector3(6, 0, -3), "wander": 8.0, "look": "Uma menina de tranças que corre de um lado para o outro.",
		 "lines": ["Oi! Você é muito alto!", "Eu queria voar também. Me ensina?", "Mamãe diz que não posso chegar perto do deserto."],
		 "cfg": {"female": true, "scale": 0.6, "bulk": 0.8, "dress": Color(0.85, 0.5, 0.55), "hair_style": "long", "hair": Color(0.45, 0.25, 0.1)}},
		{"name": "Pequeno Tim", "role": "villager", "pos": Vector3(-20, 0, 4), "wander": 8.0, "look": "Um garoto de suspensórios, cheio de lama nos joelhos.",
		 "lines": ["Você viu um bando de bandidos lá no oeste? Eu vi!", "Quando eu crescer, vou ser xerife.", "Shhh... não conta pra mamãe que eu fui lá."],
		 "cfg": {"scale": 0.58, "bulk": 0.8, "hat": true, "hat_col": Color(0.4, 0.3, 0.2), "shirt": Color(0.8, 0.8, 0.7), "pants": Color(0.3, 0.35, 0.5)}},
		{"name": "Padre Tomás", "role": "villager", "pos": Vector3(-16, 0, -48), "wander": 6.0, "look": "Veste preta e um pequeno livro sempre aberto nas mãos.",
		 "lines": ["Que a paz esteja contigo, viajante.", "A igreja está sempre aberta, mesmo para almas que voam.", "Quem protege os fracos já cumpre metade do caminho."],
		 "cfg": {"has_coat": true, "coat": Color(0.1, 0.1, 0.12), "shirt": Color(0.9, 0.9, 0.9), "pants": Color(0.1, 0.1, 0.12), "hair": Color(0.5, 0.5, 0.5)}},
		{"name": "Dona Clara", "role": "villager", "pos": Vector3(14, 0, 8), "wander": 9.0, "look": "Segura uma sombrinha rendada contra o sol forte.",
		 "lines": ["Esse sol vai me matar.", "A cidade era mais tranquila antes dos bandidos.", "Aquele xerife é um homem bom, mas está sozinho demais."],
		 "cfg": {"female": true, "dress": Color(0.55, 0.3, 0.55), "hair_style": "long", "hair": Color(0.2, 0.12, 0.08), "bulk": 0.88}},
		{"name": "Viajante Rufus", "role": "villager", "pos": Vector3(40, 0, 3), "wander": 10.0, "look": "Poeira da estrada cobre as botas. Uma mochila enorme nas costas.",
		 "lines": ["Cruzei o cânion leste ontem. Quase não saí vivo.", "Se for explorar, leve ki de sobra. Não há lugar de descanso por lá.", "O norte tem montanhas tão altas que você só chega voando."],
		 "cfg": {"hat": true, "hat_col": Color(0.5, 0.45, 0.35), "has_coat": true, "coat": Color(0.35, 0.4, 0.3), "facial": "mustache"}},
	]
	for d in data:
		var n = S.new()
		var cfg: Dictionary = d.get("cfg", {})
		var look: Dictionary = {"skin": skins[randi() % skins.size()], "hair": hairs[randi() % hairs.size()]}
		look.merge(cfg, true)
		n.setup({"name": d.name, "role": d.role, "lines": d.lines, "look": d.look, "shop": d.get("shop", []),
			"look_cfg": look, "wander": d.get("wander", 7.0)})
		n.position = d.pos + Vector3(0, 0.5, 0)
		parent.add_child(n)
	# bandidos nos acampamentos
	var idx := 0
	for c in world.camps:
		for k in 4:
			var a := k * TAU / 4.0 + idx
			var px: float = c.x + cos(a) * 4.0
			var pz: float = c.z + sin(a) * 4.0
			var n = S.new()
			var isgun: bool = k % 2 == 1
			var look: Dictionary = {"skin": skins[randi() % skins.size()], "hair": hairs[randi() % hairs.size()],
				"hat": true, "hat_col": Color(0.15, 0.12, 0.1), "mask": true, "has_coat": k % 2 == 0,
				"coat": Color(0.25, 0.2, 0.18), "shirt": Color(0.35, 0.15, 0.12), "pants": Color(0.18, 0.18, 0.2),
				"holster": isgun, "bulk": 1.15 if not isgun else 1.0}
			n.setup({"name": "Bandido", "role": "bandit", "gun": isgun, "look_cfg": look, "wander": 8.0, "squash": 1.0})
			n.position = Vector3(px, world.height_at(px, pz) + 1.0, pz)
			parent.add_child(n)
		idx += 1
