@tool
class_name InputIconRichTextLabel
extends RichTextLabel

@export var display_device: InputIconConstants.InputTypes = InputIconConstants.InputTypes.Keyboard:
	set(value):
		display_device = value
		_render_from_raw_text()

@export var action_index: int = 0:
	set(value):
		action_index = value
		_render_from_raw_text()

const TOKEN_PREFIX := "[action:"
const TOKEN_SUFFIX := "]"
@export var show_action_name_when_missing_icon := true
@export var icon_size: int = 32:
	set(value):
		icon_size = value
		_render_from_raw_text()

var _icon_resolver: InputIconResolver = InputIconResolver.new()
var input_helper_adapter: InputHelperAdapter = null
var is_input_helper_adapter_enabled: bool = false
var _raw_text: String = ""

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
		_render_from_raw_text()
		return true
	return false

func _get(property: StringName) -> Variant:
	if property == "text":
		return _raw_text
	return null

func _render_from_raw_text() -> void:
	if not is_inside_tree():
		return

	clear()
	append_text(_parse_to_bbcode(_raw_text))

func _parse_to_bbcode(input: String) -> String:
	if input.is_empty():
		return ""

	var out := ""
	var i := 0
	var p_len := TOKEN_PREFIX.length()
	var s_len := TOKEN_SUFFIX.length()

	while i < input.length():
		var start := input.find(TOKEN_PREFIX, i)
		if start == -1:
			out += input.substr(i)
			break

		if start > i:
			out += input.substr(i, start - i)

		var action_start := start + p_len
		var end := input.find(TOKEN_SUFFIX, action_start)
		if end == -1:
			out += input.substr(start)
			break

		var action := input.substr(action_start, end - action_start).strip_edges()
		out += _action_to_bbcode(action)
		i = end + s_len

	return out

func _action_to_bbcode(action: String) -> String:
	if action.is_empty():
		return ""

	var icon: Texture2D = _icon_resolver.get_icon(display_device, StringName(action), action_index)
	if icon and icon.resource_path != "":
		return "[img=" + str(icon_size) + "]%s[/img]" % icon.resource_path

	if show_action_name_when_missing_icon:
		return action
	return ""

func set_action_property_value(value: Variant) -> void:
	action_name = value
	if input_helper_adapter != null:
		input_helper_adapter.action_name = value
	_render_from_raw_text()

## Sets the display_device and updates the controls texture
func set_display_device(value: InputIconConstants.InputTypes) -> void:
	display_device = value
	_render_from_raw_text()
