extends Control
## Lapisan tutorial: menggelapkan layar kecuali elemen yang disorot, menampilkan
## dialog penasihat, dan maju saat pemain melakukan aksi yang diminta.
## Disembunyikan sementara bila ada panel/pop-up lain (grup "modal").

const Data := preload("res://scripts/core/game_data.gd")
const Art := preload("res://scripts/ui/art.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const PAD := 10.0

var main
var model
var _dims: Array[ColorRect] = []
var _frame: Panel
var _pointer: TextureRect
var _box: PanelContainer
var _text: Label
var _counter: Label
var _next: Button
var _shown_step := -1


func setup(owner_main) -> void:
	main = owner_main
	model = main.model
	# Sudah berada di scene tree, jadi offset juga harus disetel agar ukurannya penuh.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		var d := ColorRect.new()
		d.color = Color(0, 0, 0, 0.62)
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(d)
		_dims.append(d)

	_frame = Panel.new()
	var glow := UI.box(Color.TRANSPARENT, UI.GOLD, 5, 16)
	glow.shadow_color = Color(UI.GOLD, 0.7)
	glow.shadow_size = 12
	_frame.add_theme_stylebox_override("panel", glow)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var pulse := _frame.create_tween().set_loops()
	pulse.tween_property(_frame, "modulate:a", 0.45, 0.5)
	pulse.tween_property(_frame, "modulate:a", 1.0, 0.5)

	_pointer = TextureRect.new()
	_pointer.texture = Art.icon("pointer")
	_pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pointer.size = Vector2(70, 70)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pointer)

	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_box.add_child(row)
	var face := TextureRect.new()
	face.texture = Art.portrait(Data.TUTORIAL_GUIDE["portrait"])
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(120, 120)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var guide_name := Label.new()
	guide_name.text = Data.TUTORIAL_GUIDE["name"]
	guide_name.theme_type_variation = "CardTitle"
	guide_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(guide_name)
	_counter = Label.new()
	_counter.theme_type_variation = "SmallLabel"
	_counter.add_theme_color_override("font_color", UI.INK)
	head.add_child(_counter)
	_text = Label.new()
	_text.theme_type_variation = "CardLabel"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var skip := Button.new()
	skip.text = "Lewati tutorial"
	skip.flat = true
	skip.add_theme_color_override("font_color", Color("8a5a3a"))
	skip.add_theme_font_size_override("font_size", 18)
	skip.pressed.connect(_confirm_skip)
	buttons.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_next = Button.new()
	_next.theme_type_variation = "GreenButton"
	_next.custom_minimum_size = Vector2(170, 60)
	_next.pressed.connect(func():
		Audio.play("click")
		_advance())
	buttons.add_child(_next)

	var bob := _pointer.create_tween().set_loops()
	bob.tween_property(_pointer, "modulate", Color(1.25, 1.2, 1.0), 0.35)
	bob.tween_property(_pointer, "modulate", Color.WHITE, 0.35)
	model.tracked.connect(_on_tracked)


func on_page(key: String) -> void:
	if model.tutorial_active() and model.tutorial_step_def()["wait"] == "page:" + key:
		_advance()


func _on_tracked(event: String) -> void:
	if model.tutorial_active() and model.tutorial_step_def()["wait"] == event:
		_advance.call_deferred()


func _advance() -> void:
	var r: Dictionary = model.tutorial_advance()
	if r.get("done", false):
		Audio.play("promote", 0.0)
		main._show(r)
		main.tutorial_finished()


func _confirm_skip() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.add_to_group("modal")
	dlg.dialog_text = "Lewati tutorial? Hadiah tutorial (100 emas dan 2000 perak) tidak akan diberikan."
	dlg.ok_button_text = "Lewati"
	dlg.cancel_button_text = "Lanjutkan tutorial"
	dlg.confirmed.connect(func():
		main._show(model.skip_tutorial())
		main.tutorial_finished())
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


## Elemen yang disorot langkah ini; null bila tidak ada atau tidak bisa ditekan.
func _target(step: Dictionary) -> Control:
	if not step.has("target"):
		return null
	var t: Control = main.tutorial_target(step["target"])
	if t == null or not is_instance_valid(t) or not t.is_visible_in_tree():
		return null
	return t


func _process(_delta: float) -> void:
	if not model.tutorial_active():
		visible = false
		return
	visible = get_tree().get_nodes_in_group("modal").is_empty()
	if not visible:
		return
	var step: Dictionary = model.tutorial_step_def()
	var index: int = model.tutorial["step"]
	var target := _target(step)
	var needs_action: bool = step["wait"] != "next" and target != null \
		and not (target is BaseButton and target.disabled)
	if index != _shown_step:
		_shown_step = index
		_text.text = step["text"]
		_counter.text = "%d/%d" % [index + 1, Data.TUTORIAL_STEPS.size()]
		_box.modulate.a = 0.0
		create_tween().tween_property(_box, "modulate:a", 1.0, 0.2)
		if target:
			main.tutorial_reveal(target)
	var last: bool = index == Data.TUTORIAL_STEPS.size() - 1
	# Tombol "Lanjut" juga muncul bila elemen yang diminta tidak tersedia, agar tutorial tidak macet.
	_next.visible = not needs_action
	_next.text = "Selesai" if last else "Lanjut"

	var full := Rect2(Vector2.ZERO, size)
	var hole := Rect2(size / 2, Vector2.ZERO)
	if target:
		hole = target.get_global_rect().grow(PAD).intersection(full)
	_dims[0].position = Vector2.ZERO
	_dims[0].size = Vector2(size.x, hole.position.y)
	_dims[1].position = Vector2(0, hole.end.y)
	_dims[1].size = Vector2(size.x, size.y - hole.end.y)
	_dims[2].position = Vector2(0, hole.position.y)
	_dims[2].size = Vector2(hole.position.x, hole.size.y)
	_dims[3].position = Vector2(hole.end.x, hole.position.y)
	_dims[3].size = Vector2(size.x - hole.end.x, hole.size.y)
	_frame.visible = target != null
	_pointer.visible = target != null
	if target:
		_frame.position = hole.position
		_frame.size = hole.size
		var below := hole.position.y < 220
		_pointer.flip_v = below
		var bob := sin(Time.get_ticks_msec() / 160.0) * 8.0
		_pointer.position = Vector2(hole.get_center().x - 35,
			(hole.end.y + 6 + bob) if below else (hole.position.y - 76 + bob))

	var box_w := size.x * 0.94
	_box.size = Vector2(box_w, 0)
	_box.reset_size()
	_box.size.x = box_w
	var box_h := _box.size.y
	var at_top := target != null and hole.get_center().y > size.y * 0.5
	_box.position = Vector2((size.x - box_w) / 2, 150.0 if at_top else size.y - box_h - 140.0)
	if target and not at_top and _box.position.y < hole.end.y + 80:
		_box.position.y = minf(size.y - box_h - 10.0, hole.end.y + 90.0)
