extends Node

## Autoload that pops the on-screen keyboard when a text field gains focus while a
## controller is the active device, and routes the virtual keys into that field.
## Register a field's opt-out with `set_meta("disable_on_screen_keyboard", true)`
## or by adding it to the "input_icon_no_keyboard" group.

const InputIconOnScreenKeyboard = preload("res://addons/godot_input_icons/input_icon_on_screen_keyboard.gd")
const NO_KEYBOARD_GROUP := "input_icon_no_keyboard"

var _enabled: bool = true
var _controller_active: bool = false
var _layer: CanvasLayer = null
var _keyboard: InputIconOnScreenKeyboard = null
var _target: Control = null
var _ignore_focus: Control = null
var _restore_virtual_keyboard: bool = false

func _ready() -> void:
	_enabled = ProjectSettings.get_setting(InputIconConstants.AUTO_KEYBOARD_SETTING_NAME, true)
	if not _enabled:
		return
	_build_layer()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _build_layer() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)

	# Hug the keyboard's content and sit bottom-center rather than stretching.
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_bottom = -24
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_layer.add_child(panel)

	_keyboard = InputIconOnScreenKeyboard.new()
	_keyboard.text_changed.connect(_on_keyboard_text_changed)
	_keyboard.submitted.connect(_on_keyboard_submitted)
	panel.add_child(_keyboard)
	_layer.visible = false

	get_viewport().size_changed.connect(_update_keyboard_bounds)
	_update_keyboard_bounds()

## Keeps the keyboard sized to fit the current viewport.
func _update_keyboard_bounds() -> void:
	if _keyboard == null:
		return
	var view := get_viewport().get_visible_rect().size
	_keyboard.max_width = view.x * 0.9
	_keyboard.max_height = view.y * 0.4

## Tracks which device is currently driving input. Swapping to a controller while
## a text field is focused pops the keyboard; swapping back dismisses it.
func _input(event: InputEvent) -> void:
	var was_controller := _controller_active
	if event is InputEventJoypadButton:
		_controller_active = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_controller_active = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_controller_active = false
	if _controller_active != was_controller:
		_on_device_changed()
	# Controller shortcuts while the keyboard is open: left deletes, top spaces,
	# Start submits, B cancels.
	if _target != null and event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_X:
			_keyboard.backspace()
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_Y:
			_keyboard.insert_space()
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_START:
			_keyboard.submit()
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_B:
			_close(true)
			get_viewport().set_input_as_handled()

func _on_device_changed() -> void:
	if _controller_active:
		if _target == null and _can_edit(get_viewport().gui_get_focus_owner()):
			_open(get_viewport().gui_get_focus_owner())
	elif _target != null:
		_close(true)

func _on_focus_changed(control: Control) -> void:
	if control == _ignore_focus:
		_ignore_focus = null
		return
	# Focus moving into the keyboard means we're still editing the same field.
	if _is_in_keyboard(control):
		return
	if _target != null:
		_close(false)
	if _controller_active and _can_edit(control):
		_open(control)

func _can_edit(control: Control) -> bool:
	if not (control is LineEdit or control is TextEdit):
		return false
	if control.get_meta("disable_on_screen_keyboard", false):
		return false
	if control.is_in_group(NO_KEYBOARD_GROUP):
		return false
	return true

func _is_in_keyboard(control: Control) -> bool:
	var node: Node = control
	while node:
		if node == _keyboard:
			return true
		node = node.get_parent()
	return false

func _open(field: Control) -> void:
	_target = field
	# Suppress the OS virtual keyboard (touch platforms) so it doesn't fight ours.
	_restore_virtual_keyboard = field.virtual_keyboard_enabled
	field.virtual_keyboard_enabled = false
	DisplayServer.virtual_keyboard_hide()
	_keyboard.text = field.text
	_layer.visible = true
	_keyboard.focus_first()

func _close(return_focus: bool) -> void:
	var field := _target
	_target = null
	_layer.visible = false
	if is_instance_valid(field):
		field.virtual_keyboard_enabled = _restore_virtual_keyboard
		if return_focus:
			_ignore_focus = field
			field.grab_focus()

func _on_keyboard_text_changed(text: String) -> void:
	if not is_instance_valid(_target):
		return
	_target.text = text
	_move_caret_to_end(_target)

func _on_keyboard_submitted(_text: String) -> void:
	_close(true)

func _move_caret_to_end(field: Control) -> void:
	if field is LineEdit:
		var line_edit := field as LineEdit
		line_edit.caret_column = line_edit.text.length()
	elif field is TextEdit:
		var text_edit := field as TextEdit
		var last_line: int = text_edit.get_line_count() - 1
		text_edit.set_caret_line(last_line)
		text_edit.set_caret_column(text_edit.get_line(last_line).length())
