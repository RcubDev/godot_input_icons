@tool
class_name InputIconTextureRect
extends TextureRect

## The display device for the texture rect
@export var display_device: InputIconConstants.InputTypes = InputIconConstants.InputTypes.Keyboard: set = set_display_device

## The input index to use when displaying this control for when there are multiple
## mappings for the same action and device type
@export var action_index: int = 0: set = set_action_index

var _icon_resolver: InputIconResolver = InputIconResolver.new()
var input_helper_adapter: InputHelperAdapter = null
var is_input_helper_adapter_enabled: bool = false

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
	if is_input_helper_adapter_enabled and enable_input_helper:
		input_helper_adapter = InputHelperAdapter.new(action_name, _update_texture, set_display_device)
		input_helper_adapter.device_indexes = device_indexes
	_update_texture()
	
## Sets the action_index and updates the controls texture
func set_action_index(value: int) -> void:
	action_index = value
	_update_texture()

## Sets the display_device and updates the controls texture
func set_display_device(value: InputIconConstants.InputTypes) -> void:
	display_device = value
	_update_texture()


## Updates the texture of the control to the control's current
## configuration (display_device + action)
func _update_texture() -> void:
	if action_name == _action_property_default:
		texture = null
		return
	
	var result: Texture2D = _icon_resolver.get_icon(display_device, action_name, action_index)
	texture = result
	update_configuration_warnings()

#region Godot Editor Customizations

func set_action_property_value(value: Variant) -> void:
	action_name = value
	if input_helper_adapter != null:
		input_helper_adapter.action_name = value
	_update_texture()


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = [get_action_property_dict()]
	if is_input_helper_adapter_enabled:
		InputHelperAdapter.add_adapter_properties(properties)
	return properties


func _property_can_revert(property: StringName) -> bool:
	return property == _action_property_name or \
		property == InputHelperAdapter.device_indexes_property_name or \
		property == InputHelperAdapter.adapter_enabled_property_name
	

func _property_get_revert(property: StringName) -> Variant:
	if property == _action_property_name:
		return _action_property_default
	elif property == InputHelperAdapter.device_indexes_property_name:
		return InputHelperAdapter.editor_device_indexes_default
	elif property == InputHelperAdapter.adapter_enabled_property_name:
		return true
	return null


func _get_configuration_warnings() -> PackedStringArray:
	var is_unmapped_texture: bool = texture == _icon_resolver.input_icon_map.unmapped_controller_button \
						or texture == _icon_resolver.input_icon_map.unmapped_key
	if (not texture or is_unmapped_texture) and action_name != _action_property_default:
		return ["Input icon not mapped"]
	return []


func get_action_property_dict() -> Dictionary:
	var inputs: PackedStringArray = [_action_property_default]
	inputs.append_array(InputIconResolver.get_all_user_registered_inputs())
	var hint_string: String = ",".join(inputs)
	return {
		"name": _action_property_name,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_string,
		"usage": PROPERTY_USAGE_DEFAULT
	}
	
	
func _set(property: StringName, value: Variant) -> bool:
	if property == _action_property_name:
		set_action_property_value(value)
		return true
	elif is_input_helper_adapter_enabled:
			if property == InputHelperAdapter.device_indexes_property_name:
				device_indexes = value
				if input_helper_adapter != null:
					input_helper_adapter.device_indexes = value
				return true
			elif property == InputHelperAdapter.adapter_enabled_property_name:
				enable_input_helper = value
				return true
	return false


func _get(property: StringName) -> Variant:
	if property == _action_property_name:
		return action_name
	elif is_input_helper_adapter_enabled: 
		if property == InputHelperAdapter.device_indexes_property_name:
			return device_indexes
		elif property == InputHelperAdapter.adapter_enabled_property_name:
			return enable_input_helper
	return null
	
#endregion
