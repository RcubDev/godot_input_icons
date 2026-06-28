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

## Insert newlines instead of hiding the newline key (set for multiline fields).
var multiline: bool = false:
	set(value):
		multiline = value
		_rebuild()

var _text: String = ""
var _caret: int = 0

## The current text buffer.
var text: String:
	get:
		return _text
	set(value):
		_text = value
		_caret = _text.length()
		_after_change()

## Caret position (insertion index) within the text.
var caret: int:
	get:
		return _caret

# Key spec fields: c = character to insert (icon slot defaults to it), icon =
# slot suffix override, label = text fallback, action = special behavior,
# target = page to switch to (for the "page" action), expand = stretch to fill
# remaining row width (the space bar).
const LETTER_ROWS: Array = [
	[{c = "1"}, {c = "2"}, {c = "3"}, {c = "4"}, {c = "5"}, {c = "6"}, {c = "7"}, {c = "8"}, {c = "9"}, {c = "0"},
		{action = "backspace", icon = "backspace", label = "Bksp"}],
	[{c = "q"}, {c = "w"}, {c = "e"}, {c = "r"}, {c = "t"}, {c = "y"}, {c = "u"}, {c = "i"}, {c = "o"}, {c = "p"}],
	[{c = "a"}, {c = "s"}, {c = "d"}, {c = "f"}, {c = "g"}, {c = "h"}, {c = "j"}, {c = "k"}, {c = "l"}],
	[{action = "shift", icon = "shift", label = "Shift"},
		{c = "z"}, {c = "x"}, {c = "c"}, {c = "v"}, {c = "b"}, {c = "n"}, {c = "m"},
		{c = ",", icon = "comma"}, {c = ".", icon = "period"}],
	[{action = "page", target = "symbols", label = "?123"},
		{action = "left", icon = "arrow_left", label = "<"},
		{action = "right", icon = "arrow_right", label = ">"},
		{action = "space", icon = "space", label = "Space", expand = true},
		{action = "newline", label = "New"},
		{action = "enter", icon = "enter", label = "Enter"}],
]

const SYMBOL_ROWS: Array = [
	[{c = "1"}, {c = "2"}, {c = "3"}, {c = "4"}, {c = "5"}, {c = "6"}, {c = "7"}, {c = "8"}, {c = "9"}, {c = "0"},
		{action = "backspace", icon = "backspace", label = "Bksp"}],
	[{c = "@", icon = "at"}, {c = "#", icon = "hash"}, {c = "$", icon = "dollar"}, {c = "_", icon = "underscore"},
		{c = "&", icon = "ampersand"}, {c = "-", icon = "minus"}, {c = "+", icon = "plus"},
		{c = "(", icon = "paren_left"}, {c = ")", icon = "paren_right"}, {c = "/", icon = "slash"}],
	[{c = "*", icon = "asterisk"}, {c = "\"", icon = "quote"}, {c = "'", icon = "apostrophe"},
		{c = ":", icon = "colon"}, {c = ";", icon = "semicolon"}, {c = "!", icon = "exclaim"},
		{c = "?", icon = "question"}, {c = "=", icon = "equal"}, {c = "%", icon = "percent"}, {c = "^", icon = "caret"}],
	[{action = "page", target = "letters", label = "ABC"},
		{action = "page", target = "symbols2", label = "=\\<"},
		{action = "left", icon = "arrow_left", label = "<"},
		{action = "right", icon = "arrow_right", label = ">"},
		{action = "space", icon = "space", label = "Space", expand = true},
		{action = "newline", label = "New"},
		{action = "enter", icon = "enter", label = "Enter"}],
]

const SYMBOL2_ROWS: Array = [
	[{c = "1"}, {c = "2"}, {c = "3"}, {c = "4"}, {c = "5"}, {c = "6"}, {c = "7"}, {c = "8"}, {c = "9"}, {c = "0"},
		{action = "backspace", icon = "backspace", label = "Bksp"}],
	[{c = "{", icon = "brace_left"}, {c = "}", icon = "brace_right"}, {c = "[", icon = "bracketleft"},
		{c = "]", icon = "bracketright"}, {c = "|", icon = "pipe"}, {c = "\\", icon = "backslash"},
		{c = "<", icon = "less"}, {c = ">", icon = "greater"}, {c = "~", icon = "tilde"}, {c = "`", icon = "quoteleft"}],
	[{action = "page", target = "letters", label = "ABC"},
		{action = "page", target = "symbols", label = "?123"},
		{action = "left", icon = "arrow_left", label = "<"},
		{action = "right", icon = "arrow_right", label = ">"},
		{action = "space", icon = "space", label = "Space", expand = true},
		{action = "newline", label = "New"},
		{action = "enter", icon = "enter", label = "Enter"}],
]

var _resolver: InputIconResolver = InputIconResolver.new()
var _flat_style: StyleBoxEmpty = StyleBoxEmpty.new()
var _shift: bool = false
var _sticky_shift: bool = false
var _has_shift: bool = false
var _page: String = "letters"
var _char_buttons: Array = []  # [{button = Button, c = String}]
var _shift_button: Button = null
var _first_button: Button = null
var _preview: Label = null
var _preview_holder: Control = null
var _caret_rect: ColorRect = null
var _caret_on: bool = true
var _blink_accum: float = 0.0
const CARET_BLINK := 0.53

func _ready() -> void:
	# Keep pixel-art keycaps crisp when scaled up to fill cells.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rebuild()
	if not Engine.is_editor_hint() and _first_button:
		_first_button.grab_focus()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _caret_rect == null:
		return
	_blink_accum += delta
	if _blink_accum >= CARET_BLINK:
		_blink_accum = 0.0
		_caret_on = not _caret_on
		_caret_rect.visible = _caret_on

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_char_buttons.clear()
	_shift_button = null
	_first_button = null
	_preview = null
	_preview_holder = null
	_caret_rect = null
	_shift = false
	_sticky_shift = false
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

## Adds the preview line that echoes the typed text above the keys, with a thin
## drawn caret (a ColorRect) rather than a text character so there's no glyph gap.
## The holder clips so the text/caret can scroll left when input overflows.
func _add_preview() -> void:
	var panel := PanelContainer.new()
	_preview_holder = Control.new()
	_preview_holder.clip_contents = true
	panel.add_child(_preview_holder)
	_preview = Label.new()
	_preview_holder.add_child(_preview)
	_caret_rect = ColorRect.new()
	_caret_rect.color = Color(1, 1, 1, 0.85)
	_caret_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_holder.add_child(_caret_rect)
	add_child(panel)
	var font := _preview.get_theme_font("font")
	var font_size := _preview.get_theme_font_size("font_size")
	_preview_holder.custom_minimum_size = Vector2(0, font.get_height(font_size))
	_update_preview()

func _current_rows() -> Array:
	match _page:
		"symbols":
			return SYMBOL_ROWS
		"symbols2":
			return SYMBOL2_ROWS
		_:
			return LETTER_ROWS

## Resolves each key's icon and aspect ratio once so layout can size to fit.
func _resolve_rows() -> Array:
	var resolved: Array = []
	for row in _current_rows():
		var line: Array = []
		for spec in row:
			var action: String = spec.get("action", "")
			if action == "shift" and not _has_shift:
				continue
			if action == "newline" and not multiline:
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
		if action == "page":
			var target: String = spec.get("target", "letters")
			button.pressed.connect(func(): _set_page(target))
		else:
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
	_insert(character.to_upper() if _shift else character)
	# A one-shot shift (left trigger) reverts after the next character.
	if _sticky_shift:
		_sticky_shift = false
		_shift = false
		_refresh_char_keys()
		if _shift_button:
			_shift_button.button_pressed = false

func _on_action(action: String) -> void:
	match action:
		"backspace":
			_backspace()
		"space":
			_insert(" ")
		"newline":
			_insert("\n")
		"left":
			_move_caret(-1)
		"right":
			_move_caret(1)
		"enter":
			submitted.emit(_text)
		"shift":
			_shift = not _shift
			_refresh_char_keys()

## Inserts a string at the caret and advances it.
func _insert(value: String) -> void:
	_text = _text.substr(0, _caret) + value + _text.substr(_caret)
	_caret += value.length()
	_after_change()

## Deletes the character before the caret.
func _backspace() -> void:
	if _caret <= 0:
		return
	_text = _text.substr(0, _caret - 1) + _text.substr(_caret)
	_caret -= 1
	_after_change()

## Moves the caret by delta, clamped to the text bounds.
func _move_caret(delta: int) -> void:
	var target: int = clampi(_caret + delta, 0, _text.length())
	if target != _caret:
		_caret = target
		_after_change()

## Refreshes the preview after an edit (caret solid right after typing) and
## notifies listeners.
func _after_change() -> void:
	_caret_on = true
	_blink_accum = 0.0
	_update_preview()
	text_changed.emit(_text)

## Sets the preview text, then positions the caret at the measured text width and
## scrolls text + caret left so the caret stays visible when input overflows.
func _update_preview() -> void:
	if _preview == null:
		return
	_preview.text = _text
	if _caret_rect == null or _preview_holder == null:
		return
	var font := _preview.get_theme_font("font")
	var font_size := _preview.get_theme_font_size("font_size")
	var caret_x := font.get_string_size(_text.substr(0, _caret), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var margin := 4.0
	var avail := _preview_holder.size.x
	var scroll := maxf(0.0, caret_x - (avail - margin)) if avail > 0.0 else 0.0
	_preview.position = Vector2(-scroll, 0)
	_caret_rect.position = Vector2(caret_x - scroll, 0)
	_caret_rect.size = Vector2(2, font.get_height(font_size))
	_caret_rect.visible = _caret_on

## Switches the keyboard page and restores focus.
func _set_page(page: String) -> void:
	_page = page
	_rebuild()
	focus_first.call_deferred()

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

## Submits the current text (e.g. bound to a controller button).
func submit() -> void:
	_on_action("enter")

## Arms a one-shot shift for the next character (e.g. bound to a controller
## trigger). Toggling again before typing cancels it.
func toggle_shift_once() -> void:
	_shift = not _shift
	_sticky_shift = _shift
	_refresh_char_keys()
	if _shift_button:
		_shift_button.button_pressed = _shift

## Moves the caret left/right (e.g. bound to controller bumpers).
func cursor_left() -> void:
	_move_caret(-1)

func cursor_right() -> void:
	_move_caret(1)

## Moves focus to the first key (e.g. when the keyboard is shown).
func focus_first() -> void:
	if _first_button:
		_first_button.grab_focus()

## Clears the buffer.
func clear() -> void:
	_text = ""
	_caret = 0
	_after_change()
