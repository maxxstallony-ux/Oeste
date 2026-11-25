extends Control
## Controles touch multitoque: joystick flutuante (esquerda), câmera (direita) e botões.
## Teclado para testes no PC: WASD, setas (câmera), Espaço, J, K, L, C, F, G, R, E.

const JR := 90.0
const KEYS := {KEY_SPACE: "jump", KEY_J: "atk", KEY_K: "ki", KEY_L: "dodge", KEY_C: "charge",
	KEY_F: "fly", KEY_G: "ssj", KEY_R: "run", KEY_E: "interact"}

var BTNS := [
	{"n": "atk", "o": Vector2(120, 120), "r": 60.0, "t": "SOCO", "c": Color(0.9, 0.25, 0.2)},
	{"n": "jump", "o": Vector2(255, 80), "r": 44.0, "t": "PULO", "c": Color(0.3, 0.8, 0.35)},
	{"n": "ki", "o": Vector2(245, 215), "r": 46.0, "t": "KI", "c": Color(0.3, 0.7, 1.0)},
	{"n": "dodge", "o": Vector2(110, 255), "r": 42.0, "t": "ESQUIVA", "c": Color(0.95, 0.8, 0.2)},
	{"n": "run", "o": Vector2(385, 80), "r": 38.0, "t": "CORRER", "c": Color(0.8, 0.8, 0.85)},
	{"n": "charge", "o": Vector2(375, 195), "r": 38.0, "t": "CARGA", "c": Color(0.5, 0.5, 1.0)},
	{"n": "fly", "o": Vector2(80, 385), "r": 40.0, "t": "VOO", "c": Color(0.5, 0.9, 0.95)},
	{"n": "ssj", "o": Vector2(80, 490), "r": 40.0, "t": "SSJ", "c": Color(1.0, 0.85, 0.2)},
]

var enabled := true
var move_vec := Vector2.ZERO
var cam_acc := Vector2.ZERO
var held_d := {}
var pressed_d := {}
var latched := {}
var fingers := {}
var blockers: Array = []
var joy_active := false
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO

func set_enabled(v: bool) -> void:
	enabled = v
	visible = v
	if not v:
		fingers.clear()
		held_d.clear()
		pressed_d.clear()
		move_vec = Vector2.ZERO
		joy_active = false

func pop(n: String) -> bool:
	var r: bool = pressed_d.get(n, false)
	pressed_d[n] = false
	return r

func held(n: String) -> bool:
	return held_d.get(n, false)

func take_cam() -> Vector2:
	var c := cam_acc
	cam_acc = Vector2.ZERO
	return c

func _bpos(b) -> Vector2:
	return Vector2(size.x - b.o.x, size.y - b.o.y)

func _input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventKey:
		if e.echo:
			return
		if KEYS.has(e.keycode):
			var n: String = KEYS[e.keycode]
			held_d[n] = e.pressed
			if e.pressed:
				pressed_d[n] = true
		return
	if e is InputEventScreenTouch:
		var ev = make_input_local(e)
		if ev.pressed:
			_down(ev.index, ev.position)
		else:
			_up(ev.index)
	elif e is InputEventScreenDrag:
		var ed = make_input_local(e)
		_drag(ed.index, ed.position)

func _down(idx: int, p: Vector2) -> void:
	for bl in blockers:
		if bl.visible and bl.get_global_rect().has_point(p):
			return
	for b in BTNS:
		if p.distance_to(_bpos(b)) <= b.r * 1.2:
			fingers[idx] = {"k": "btn", "n": b.n}
			held_d[b.n] = true
			pressed_d[b.n] = true
			return
	if p.x < size.x * 0.45 and p.y > size.y * 0.2:
		fingers[idx] = {"k": "joy"}
		joy_active = true
		joy_origin = p
		joy_pos = p
	else:
		fingers[idx] = {"k": "cam", "last": p}

func _drag(idx: int, p: Vector2) -> void:
	if not fingers.has(idx):
		return
	var f = fingers[idx]
	if f.k == "joy":
		joy_pos = joy_origin + (p - joy_origin).limit_length(JR)
		var v := (joy_pos - joy_origin) / JR
		move_vec = v if v.length() > 0.15 else Vector2.ZERO
	elif f.k == "cam":
		cam_acc += p - f.last
		f.last = p

func _up(idx: int) -> void:
	if not fingers.has(idx):
		return
	var f = fingers[idx]
	if f.k == "btn":
		held_d[f.n] = false
	elif f.k == "joy":
		joy_active = false
		move_vec = Vector2.ZERO
	fingers.erase(idx)

func _process(_d: float) -> void:
	if not enabled:
		return
	if not joy_active:
		var kv := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		move_vec = kv.normalized()
	cam_acc += Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))) * 14.0
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var base := joy_origin if joy_active else Vector2(190, size.y - 170)
	var knob := joy_pos if joy_active else base
	draw_circle(base, JR, Color(1, 1, 1, 0.12))
	draw_arc(base, JR, 0, TAU, 40, Color(1, 1, 1, 0.5), 3.0)
	draw_circle(knob, 38.0, Color(1, 1, 1, 0.35))
	for b in BTNS:
		var p := _bpos(b)
		var on: bool = held_d.get(b.n, false) or latched.get(b.n, false)
		var c: Color = b.c
		draw_circle(p, b.r, Color(c.r, c.g, c.b, 0.65 if on else 0.28))
		draw_arc(p, b.r, 0, TAU, 32, Color(c.r, c.g, c.b, 0.9), 3.0)
		draw_string(font, p + Vector2(-b.r, 7), b.t, HORIZONTAL_ALIGNMENT_CENTER, b.r * 2.0, 18, Color(1, 1, 1, 0.95))
