@tool
class_name InputIconOnScreenKeyboard
extends VBoxContainer

## Controller-friendly on-screen keyboard for text entry. Renders a QWERTY grid
## of focusable buttons that show the plugin's mapped key icons (text fallback
## when a key has no icon). Navigate with ui_left/right/up/down and ui_accept;
## a controller drives it with no extra input code. Read the typed string from
## `text` and listen to `text_changed` / `submitted`.

signal text_changed(text: String)
signal submitted(text: String)

## Maximum key row height; key widths scale from each icon's aspect ratio. The
## actual height shrinks below this to fit `max_width` / `max_height`.
@export var key_height: int = 56:
	set(value):
		key_height = value
		_rebuild()

## Gap between keys and rows.
@export var key_separation: int = 4:
	set(value):
		key_separation = value
		_rebuild()

## Echo the typed text on a line above the keys, so it stays visible even when
## the keyboard covers the target field (mirrors how console keyboards work).
@export var show_preview: bool = true:
	set(value):
		show_preview = value
		_rebuild()

## Fit bounds, usually set by the popup manager to the viewport size. 0 means no
## limit (use key_height directly).
var max_width: float = 0.0:
	set(value):
		max_width = value
		_rebuild()
var max_height: float = 0.0:
	set(value):
		max_height = value
		_rebuild()

## The current text buffer.
var text: String = "":
	set(value):
		text = value
		if _preview:
			_preview.text = value
		text_changed.emit(text)

# Key spec fields: c = character to insert (icon slot defaults to it), icon =
# slot suffix override, label = text fallback, action = special behavior,
# expand = stretch to fill remaining row width (the space bar).
const ROWS: Array = [
	[{c = "1"}, {c = "2"}, {c = "3"}, {c = "4"}, {c = "5"}, {c = "6"}, {c = "7"}, {c = "8"}, {c = "9"}, {c = "0"},
		{action = "backspace", icon = "backspace", label = "Bksp"}],
	[{c = "q"}, {c = "w"}, {c = "e"}, {c = "r"}, {c = "t"}, {c = "y"}, {c = "u"}, {c = "i"}, {c = "o"}, {c = "p"}],
	[{c = "a"}, {c = "s"}, {c = "d"}, {c = "f"}, {c = "g"}, {c = "h"}, {c = "j"}, {c = "k"}, {c = "l"}],
	[{action = "shift", icon = "shift", label = "Shift"},
		{c = "z"}, {c = "x"}, {c = "c"}, {c = "v"}, {c = "b"}, {c = "n"}, {c = "m"},
		{c = ",", icon = "comma"}, {c = ".", icon = "period"}],
	[{action = "space", icon = "space", label = "Space", expand = true},
		{action = "enter", icon = "enter", label = "Enter"}],
]

var _resolver: InputIconResolver = InputIconResolver.new()
var _flat_style: StyleBoxEmpty = StyleBoxEmpty.new()
var _shift: bool = false
var _has_shift: bool = false
var _char_buttons: Array = []  # [{button = Button, c = String}]
var _shift_button: Button = null
var _first_button: Button = null
var _preview: Label = null

func _ready() -> void:
	# Keep pixel-art keycaps crisp when scaled up to fill cells.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rebuild()
	if not Engine.is_editor_hint() and _first_button:
		_first_button.grab_focus()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_char_buttons.clear()
	_shift_button = null
	_first_button = null
	_preview = null
	_shift = false
	_has_shift = _resolver.has_keyboard_uppercase()

	var resolved := _resolve_rows()
	var height := _fit_height(resolved)
	add_theme_constant_override("separation", key_separation)
	if show_preview:
		_add_preview()
	for row in resolved:
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", key_separation)
		add_child(line)
		for entry in row:
			line.add_child(_make_key(entry, height))

## Adds the preview line that echoes the typed text above the keys.
func _add_preview() -> void:
	var panel := PanelContainer.new()
	_preview = Label.new()
	_preview.text = text
	_preview.clip_text = true
	panel.add_child(_preview)
	add_child(panel)

## Resolves each key's icon and aspect ratio once so layout can size to fit.
func _resolve_rows() -> Array:
	var resolved: Array = []
	for row in ROWS:
		var line: Array = []
		for spec in row:
			if spec.get("action", "") == "shift" and not _has_shift:
				continue
			var slot: String = spec.get("icon", spec.get("c", ""))
			var icon := _resolver.get_raw_key_icon(slot)
			var aspect := 1.0
			if icon:
				var size := icon.get_size()
				if size.y > 0:
					aspect = size.x / size.y
			line.append({spec = spec, icon = icon, aspect = aspect})
		resolved.append(line)
	return resolved

## Largest key height that keeps the widest fixed row within max_width and all
## rows within max_height, capped at key_height. Expanding rows (the space bar)
## flex to fit, so they don't constrain width.
func _fit_height(resolved: Array) -> float:
	var height := float(key_height)
	if max_width > 0:
		for row in resolved:
			if _row_has_expand(row):
				continue
			var fixed := 0.0
			for entry in row:
				fixed += entry.aspect
			if fixed > 0:
				var gaps: int = key_separation * (row.size() - 1)
				height = minf(height, (max_width - gaps) / fixed)
	if max_height > 0 and resolved.size() > 0:
		var vgaps := key_separation * (resolved.size() - 1)
		height = minf(height, (max_height - vgaps) / resolved.size())
	return maxf(height, 8.0)

func _row_has_expand(row: Array) -> bool:
	for entry in row:
		if entry.spec.get("expand", false):
			return true
	return false

func _make_key(entry: Dictionary, height: float) -> Button:
	var spec: Dictionary = entry.spec
	var button := Button.new()
	button.size_flags_vertical = Control.SIZE_FILL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if spec.get("expand", false) else Control.SIZE_FILL
	button.expand_icon = true
	# Drop the default button chrome so only the keycap icon shows; the focus
	# outline stays for navigation.
	button.add_theme_stylebox_override("normal", _flat_style)
	button.add_theme_stylebox_override("hover", _flat_style)
	button.add_theme_stylebox_override("pressed", _flat_style)
	button.add_theme_stylebox_override("disabled", _flat_style)

	# Width tracks the icon's aspect so wide keys stay proportional; text-fallback
	# keys are square.
	if entry.icon:
		button.icon = entry.icon
	else:
		button.text = _fallback_label(spec)
	button.custom_minimum_size = Vector2(height * entry.aspect, height)

	if spec.has("action"):
		var action: String = spec.action
		button.pressed.connect(func(): _on_action(action))
		if action == "shift":
			button.toggle_mode = true
			_shift_button = button
	else:
		var character: String = spec.c
		var slot: String = spec.get("icon", character)
		button.pressed.connect(func(): _on_char(character))
		_char_buttons.append({button = button, c = character, slot = slot})

	if _first_button == null:
		_first_button = button
	return button

func _fallback_label(spec: Dictionary) -> String:
	if spec.has("label"):
		return spec.label
	var character: String = spec.get("c", "")
	return character.to_upper() if _shift else character

func _on_char(character: String) -> void:
	text += character.to_upper() if _shift else character

func _on_action(action: String) -> void:
	match action:
		"backspace":
			if not text.is_empty():
				text = text.substr(0, text.length() - 1)
		"space":
			text += " "
		"enter":
			submitted.emit(text)
		"shift":
			_shift = not _shift
			_refresh_char_keys()

## Swaps letter keys for the shift state: uppercase glyph when authored, else the
## uppercase text. Digits and punctuation are unaffected by shift.
func _refresh_char_keys() -> void:
	for entry in _char_buttons:
		var character: String = entry.c
		# Only letters have a case; leave digits/punctuation as built.
		if character.to_lower() == character.to_upper():
			continue
		var button: Button = entry.button
		var slot: String = entry.slot
		var icon := _resolver.get_uppercase_key_icon(slot) if _shift else _resolver.get_raw_key_icon(slot, false)
		if icon:
			button.icon = icon
			button.text = ""
		else:
			button.icon = null
			button.text = character.to_upper() if _shift else character

## Deletes the last character (e.g. bound to a controller button).
func backspace() -> void:
	_on_action("backspace")

## Inserts a space (e.g. bound to a controller button).
func insert_space() -> void:
	_on_action("space")

## Moves focus to the first key (e.g. when the keyboard is shown).
func focus_first() -> void:
	if _first_button:
		_first_button.grab_focus()

## Clears the buffer.
func clear() -> void:
	text = ""
