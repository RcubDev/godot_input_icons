@tool
class_name InputIconRichTextLabel
extends RichTextLabel

@export var display_device: InputIconConstants.InputTypes = InputIconConstants.InputTypes.Keyboard:
	set(value):
		display_device = value
		_request_render()

const TOKEN_PREFIX := "[action:"
const TOKEN_SUFFIX := "]"
@export var show_action_name_when_missing_icon := true
@export var icon_size: int = 32:
	set(value):
		icon_size = value
		_request_render()

var _icon_resolver: InputIconResolver = InputIconResolver.new()
var input_helper_adapter: InputHelperAdapter = null
var is_input_helper_adapter_enabled: bool = false
var _raw_text: String = ""

const RENDER_DEBOUNCE_SECONDS := 0.5
var _render_debounce_timer: Timer = null

#region Editor custom property variables
var _action_property_name: String = "action_name"
var _action_property_default: StringName = "--select--"
var action_name: StringName = _action_property_default: set = set_action_property_value
var device_indexes: PackedInt32Array = []
## User override for disabling the helper for this node instance while
## keeping the adapter enabled for the entire plugin.
## NOTE: Done by overriding _get_property_list, _get, _set, etc
var enable_input_helper: bool = true
#endregion

func _init() -> void:
	is_input_helper_adapter_enabled = ProjectSettings.get_setting(InputIconConstants.INPUT_HELPER_ADAPTER_SETTING_NAME, false)

func _ready() -> void:
	bbcode_enabled = true
	if Engine.is_editor_hint():
		_render_debounce_timer = Timer.new()
		_render_debounce_timer.one_shot = true
		_render_debounce_timer.timeout.connect(_render_from_raw_text)
		# Internal so it isn't saved into the user's scene or shown in the tree.
		add_child(_render_debounce_timer, false, Node.INTERNAL_MODE_FRONT)
	if is_input_helper_adapter_enabled and enable_input_helper:
		input_helper_adapter = InputHelperAdapter.new(action_name, _render_from_raw_text, set_display_device)
		input_helper_adapter.device_indexes = device_indexes
		
	# If text was set in editor/scene, treat it as initial raw text.
	if _raw_text.is_empty() and not text.is_empty():
		_raw_text = text
	_render_from_raw_text()

## Public API for C# (or GDScript) callers.
## Call this instead of assigning `text` directly.
func set_rich_input_text(value: String) -> void:
	_raw_text = value
	_render_from_raw_text()

## Optional getter for external systems.
func get_rich_input_text() -> String:
	return _raw_text

## Optional: if someone assigns label.text directly from script,
## keep parser behavior by syncing it and re-rendering.
func _set(property: StringName, value: Variant) -> bool:
	if property == "text":
		_raw_text = str(value)
		_request_render()
		return true
	return false

func _get(property: StringName) -> Variant:
	if property == "text":
		return _raw_text
	return null

## Debounced entry point for re-rendering; restarts a single timer so a burst of
## edits only renders once, after the text settles.
func _request_render() -> void:
	# No timer outside the editor: render immediately. In the editor, debounce.
	if _render_debounce_timer == null:
		_render_from_raw_text()
		return
	_render_debounce_timer.start(RENDER_DEBOUNCE_SECONDS)

func _render_from_raw_text() -> void:
	if not is_inside_tree():
		return

	clear()
	_append_parsed(_raw_text)

## Walks the raw text, appending plain segments as BBCode and replacing each
## [action:<name>] token with its resolved icon.
func _append_parsed(input: String) -> void:
	if input.is_empty():
		return

	var i := 0
	var p_len := TOKEN_PREFIX.length()
	var s_len := TOKEN_SUFFIX.length()

	while i < input.length():
		var start := input.find(TOKEN_PREFIX, i)
		if start == -1:
			append_text(input.substr(i))
			break

		if start > i:
			append_text(input.substr(i, start - i))

		var action_start := start + p_len
		var end := input.find(TOKEN_SUFFIX, action_start)
		if end == -1:
			append_text(input.substr(start))
			break

		var action := input.substr(action_start, end - action_start).strip_edges()
		_append_action(action)
		i = end + s_len

func _append_action(token: String) -> void:
	if token.is_empty():
		return

	var action := token
	var index := 0
	var sep := token.rfind(":")
	if sep != -1 and token.substr(sep + 1).is_valid_int():
		action = token.substr(0, sep).strip_edges()
		index = token.substr(sep + 1).to_int()

	if action.is_empty():
		return

	var icon: Texture2D = _icon_resolver.get_icon(display_device, StringName(action), index)
	if icon:
		# Constrain height so every icon shares the text line-height; width scales.
		add_image(icon, 0, icon_size)
		return

	if show_action_name_when_missing_icon:
		append_text(action)

func set_action_property_value(value: Variant) -> void:
	action_name = value
	if input_helper_adapter != null:
		input_helper_adapter.action_name = value
	_request_render()

## Sets the display_device and updates the controls texture
func set_display_device(value: InputIconConstants.InputTypes) -> void:
	display_device = value
