@tool
class_name InputHelperAdapter

var action_name: String
var _update_texture_callback: Callable
var _update_display_device_callback: Callable
# The device indexes to listen for. Defaults to -1 & 0 (keyboard and mouse + first controller)
var device_indexes: PackedInt32Array = [-1, 0]
static var editor_device_indexes_default: PackedInt32Array = [-1, 0]

func _init(action_name_val: String, update_texture_callback: Callable,
	update_display_device_callback: Callable) -> void:
	if Engine.is_editor_hint():
		return
		
	var loop = Engine.get_main_loop()
	var scene_tree = loop as SceneTree
	var input_helper = scene_tree.root.get_node("InputHelper") as InputHelper
	if input_helper:
		action_name = action_name_val
		_update_texture_callback = update_texture_callback
		_update_display_device_callback = update_display_device_callback
		input_helper.device_changed.connect(on_device_changed)
		input_helper.joypad_changed.connect(on_joypad_changed)
		input_helper.keyboard_input_changed.connect(on_keyboard_input_changed)
		input_helper.joypad_input_changed.connect(on_joypad_input_changed)
	else:
		push_warning("Unable to locate InputHelper. Did you add the plugin and enable it?")


func on_device_changed(device: String, device_index: int):
	if device_index not in device_indexes and \
		not device_indexes.is_empty():
			return
	var device_id = input_helper_device_to_icon_helper_device(device)
	_update_display_device_callback.callv([device_id])
	
# An empty action_name matches any action, for multi-action consumers.
func on_keyboard_input_changed(action: String, input: InputEvent):
	if action_name == "" or action == action_name:
		_update_texture_callback.call()

func on_joypad_input_changed(action: String, input: InputEvent):
	if action_name == "" or action == action_name:
		_update_texture_callback.call()

func on_joypad_changed(device_index: int, is_connected: bool):
	pass
	
static func input_helper_device_to_icon_helper_device(device: String) -> InputIconConstants.InputTypes:
	match device:
		InputHelper.DEVICE_KEYBOARD:
			return InputIconConstants.InputTypes.Keyboard
		InputHelper.DEVICE_XBOX_CONTROLLER, InputHelper.SUB_DEVICE_XBOX_ONE_CONTROLLER, \
			InputHelper.SUB_DEVICE_XBOX_SERIES_CONTROLLER:
			return InputIconConstants.InputTypes.Xbox
		InputHelper.DEVICE_SWITCH_CONTROLLER, InputHelper.SUB_DEVICE_SWITCH_JOYCON_LEFT_CONTROLLER, \
			InputHelper.SUB_DEVICE_SWITCH_JOYCON_RIGHT_CONTROLLER:
			return InputIconConstants.InputTypes.Switch
		InputHelper.DEVICE_PLAYSTATION_CONTROLLER, InputHelper.SUB_DEVICE_PLAYSTATION3_CONTROLLER, \
			InputHelper.SUB_DEVICE_PLAYSTATION4_CONTROLLER, InputHelper.SUB_DEVICE_PLAYSTATION5_CONTROLLER:
			return InputIconConstants.InputTypes.Playstation
		_:
			return InputIconConstants.InputTypes.Generic
	pass


const device_indexes_property_name: String = "device_indexes"
static func get_device_index_property_dict() -> Dictionary:
	return {
		"name": device_indexes_property_name,
		"type": TYPE_PACKED_INT32_ARRAY,
		"usage": PROPERTY_USAGE_DEFAULT
	}
	
const adapter_enabled_property_name: String = "adapter_enabled"
static func get_adapter_enabled_property_dict() -> Dictionary:
	return {
		"name": adapter_enabled_property_name,
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	}

## Adds all property dictionaries to the for all
## neccessary properties relating to the
## input helper adapter to the array passed in
static func add_adapter_properties(properties: Array) -> void:
	properties.append({
			name = "Input Helper Options",
			type = TYPE_NIL,
			hint_string = "Input Helper Options",
			usage = PROPERTY_USAGE_CATEGORY
		})
	properties.append(InputHelperAdapter.get_adapter_enabled_property_dict())
	properties.append(InputHelperAdapter.get_device_index_property_dict())
	
