extends CanvasLayer
## HUD, controles touch, menu de interação, diálogos em texto e comércio.

const Touch = preload("res://touch.gd")

var player
var touch: Control
var root: Control
var dialog_open := false
var cur_npc = null
var _target = null
var hp_bar: ProgressBar
var ki_bar: ProgressBar
var money_lbl: Label
var fps_lbl: Label
var ssj_lbl: Label
var toast_lbl: Label
var toast_t := 0.0
var interact_btn: Button
var menu_c: CenterContainer
var menu_title: Label
var btn_shop: Button
var dlg_c: MarginContainer
var dlg_name: Label
var dlg_text: RichTextLabel
var shop_c: CenterContainer
var shop_title: Label
var shop_list: VBoxContainer
var shop_msg: Label
var flash_rect: ColorRect
var lines: Array = []
var li := 0
var chars := 0.0
var move_vec: Vector2:
	get:
		return touch.move_vec

func pop(n: String) -> bool:
	return touch.pop(n)
func held(n: String) -> bool:
	return touch.held(n)
func take_cam() -> Vector2:
	return touch.take_cam()
func clear_pressed() -> void:
	touch.pressed_d.clear()
func set_latched(n: String, v: bool) -> void:
	touch.latched[n] = v

func _style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(12)
	s.set_border_width_all(3)
	s.border_color = Color(0.85, 0.65, 0.3)
	s.set_content_margin_all(14)
	return s

func _bar(pos: Vector2, col: Color, txt: String) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.position = pos
	pb.size = Vector2(320, 26)
	pb.show_percentage = false
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(6)
	pb.add_theme_stylebox_override("fill", fg)
	pb.add_theme_stylebox_override("background", bg)
	var l := Label.new()
	l.text = txt
	l.position = Vector2(8, -4)
	l.add_theme_font_size_override("font_size", 20)
	pb.add_child(l)
	root.add_child(pb)
	return pb

func _btn(text: String, parent: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 70)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _ready() -> void:
	layer = 10
	var th := Theme.new()
	th.default_font_size = 28
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = th
	add_child(root)
	touch = Touch.new()
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch)

	hp_bar = _bar(Vector2(24, 22), Color(0.85, 0.2, 0.2), "VIDA")
	ki_bar = _bar(Vector2(24, 56), Color(0.25, 0.65, 1.0), "KI")
	money_lbl = Label.new()
	money_lbl.position = Vector2(24, 90)
	root.add_child(money_lbl)
	ssj_lbl = Label.new()
	ssj_lbl.text = "SUPER SAIYAJIN"
	ssj_lbl.position = Vector2(24, 128)
	ssj_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	ssj_lbl.visible = false
	root.add_child(ssj_lbl)
	fps_lbl = Label.new()
	fps_lbl.anchor_left = 1.0
	fps_lbl.anchor_right = 1.0
	fps_lbl.offset_left = -110
	fps_lbl.offset_right = -14
	fps_lbl.offset_top = 10
	fps_lbl.add_theme_font_size_override("font_size", 20)
	root.add_child(fps_lbl)
	toast_lbl = Label.new()
	toast_lbl.anchor_left = 0.5
	toast_lbl.anchor_right = 0.5
	toast_lbl.offset_left = -400
	toast_lbl.offset_right = 400
	toast_lbl.offset_top = 70
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_lbl.add_theme_constant_override("outline_size", 8)
	root.add_child(toast_lbl)

	interact_btn = Button.new()
	interact_btn.anchor_left = 1.0
	interact_btn.anchor_right = 1.0
	interact_btn.anchor_top = 0.5
	interact_btn.anchor_bottom = 0.5
	interact_btn.offset_left = -520
	interact_btn.offset_right = -200
	interact_btn.offset_top = -120
	interact_btn.offset_bottom = -50
	interact_btn.visible = false
	interact_btn.pressed.connect(_on_interact)
	root.add_child(interact_btn)
	touch.blockers.append(interact_btn)

	# menu de interação
	menu_c = CenterContainer.new()
	menu_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_c.visible = false
	root.add_child(menu_c)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.05, 0.92)))
	menu_c.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	menu_title = Label.new()
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vb.add_child(menu_title)
	_btn("Conversar", vb, _on_talk)
	_btn("Observar", vb, _on_look)
	btn_shop = _btn("Comércio", vb, _on_shop)
	_btn("Sair", vb, close_all)

	# caixa de diálogo
	dlg_c = MarginContainer.new()
	dlg_c.anchor_left = 0.0
	dlg_c.anchor_right = 1.0
	dlg_c.anchor_top = 1.0
	dlg_c.anchor_bottom = 1.0
	dlg_c.offset_left = 40
	dlg_c.offset_right = -40
	dlg_c.offset_top = -250
	dlg_c.offset_bottom = -24
	dlg_c.visible = false
	root.add_child(dlg_c)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.05, 0.94)))
	dlg_c.add_child(dp)
	var dv := VBoxContainer.new()
	dp.add_child(dv)
	dlg_name = Label.new()
	dlg_name.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	dv.add_child(dlg_name)
	dlg_text = RichTextLabel.new()
	dlg_text.custom_minimum_size = Vector2(0, 90)
	dlg_text.fit_content = true
	dlg_text.add_theme_font_size_override("normal_font_size", 28)
	dv.add_child(dlg_text)
	var nb := Button.new()
	nb.text = "Continuar >>"
	nb.size_flags_horizontal = Control.SIZE_SHRINK_END
	nb.custom_minimum_size = Vector2(240, 60)
	nb.pressed.connect(_on_next)
	dv.add_child(nb)

	# loja
	shop_c = CenterContainer.new()
	shop_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_c.visible = false
	root.add_child(shop_c)
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.05, 0.94)))
	shop_c.add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sp.add_child(sv)
	shop_title = Label.new()
	shop_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	sv.add_child(shop_title)
	shop_list = VBoxContainer.new()
	shop_list.add_theme_constant_override("separation", 8)
	sv.add_child(shop_list)
	shop_msg = Label.new()
	sv.add_child(shop_msg)
	_btn("Voltar", sv, _on_shop_back)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	root.add_child(flash_rect)

func _process(delta: float) -> void:
	if player == null:
		return
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	ki_bar.max_value = player.max_ki
	ki_bar.value = player.ki
	money_lbl.text = "$ %d" % player.money
	fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			toast_lbl.text = ""
	if dlg_c.visible and dlg_text.visible_characters != -1:
		chars += delta * 50.0
		dlg_text.visible_characters = int(chars)
		if int(chars) >= dlg_text.text.length():
			dlg_text.visible_characters = -1
	if _target != null and not dialog_open and touch.pop("interact"):
		_on_interact()

func toast(t: String, secs := 2.5) -> void:
	toast_lbl.text = t
	toast_t = secs

func flash(c: Color) -> void:
	flash_rect.color = Color(c.r, c.g, c.b, 0.8)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.6)

func set_ssj(on: bool) -> void:
	ssj_lbl.visible = on

func set_target(npc) -> void:
	if dialog_open:
		return
	_target = npc
	if npc == null:
		interact_btn.visible = false
	else:
		interact_btn.text = "Falar: %s" % npc.npc_name
		interact_btn.visible = true

func _on_interact() -> void:
	if _target == null:
		return
	cur_npc = _target
	dialog_open = true
	touch.set_enabled(false)
	interact_btn.visible = false
	cur_npc.talking = true
	_open_menu()

func _open_menu() -> void:
	menu_title.text = cur_npc.npc_name
	btn_shop.visible = cur_npc.shop.size() > 0
	menu_c.visible = true
	dlg_c.visible = false
	shop_c.visible = false

func close_all() -> void:
	menu_c.visible = false
	dlg_c.visible = false
	shop_c.visible = false
	if cur_npc:
		cur_npc.talking = false
	cur_npc = null
	dialog_open = false
	touch.set_enabled(true)

func _show_lines(arr: Array, who: String) -> void:
	lines = arr
	li = 0
	dlg_name.text = who
	menu_c.visible = false
	dlg_c.visible = true
	_show_line()

func _show_line() -> void:
	dlg_text.text = lines[li]
	chars = 0.0
	dlg_text.visible_characters = 0

func _on_talk() -> void:
	if cur_npc.lines.is_empty():
		_show_lines(["..."], cur_npc.npc_name)
	else:
		_show_lines(cur_npc.lines, cur_npc.npc_name)

func _on_look() -> void:
	_show_lines(["(" + cur_npc.look_text + ")"], "Observar")

func _on_next() -> void:
	if dlg_text.visible_characters != -1:
		dlg_text.visible_characters = -1
		return
	li += 1
	if li >= lines.size():
		_open_menu()
	else:
		_show_line()

func _on_shop() -> void:
	menu_c.visible = false
	shop_c.visible = true
	shop_title.text = "Comércio - %s" % cur_npc.npc_name
	shop_msg.text = "Dinheiro: $%d" % player.money
	for c in shop_list.get_children():
		c.queue_free()
	for it in cur_npc.shop:
		var fx: Array = []
		if it.hp > 0:
			fx.append("+%d vida" % it.hp)
		if it.ki > 0:
			fx.append("+%d ki" % it.ki)
		var b := Button.new()
		b.text = "%s  $%d  (%s)" % [it.name, it.price, ", ".join(fx)]
		b.custom_minimum_size = Vector2(520, 66)
		b.pressed.connect(_buy.bind(it))
		shop_list.add_child(b)

func _buy(it: Dictionary) -> void:
	if player.money < it.price:
		shop_msg.text = "Dinheiro insuficiente."
		return
	player.money -= it.price
	player.hp = minf(player.max_hp, player.hp + it.hp)
	player.ki = minf(player.max_ki, player.ki + it.ki)
	shop_msg.text = "Comprado: %s. Dinheiro: $%d" % [it.name, player.money]

func _on_shop_back() -> void:
	_open_menu()
