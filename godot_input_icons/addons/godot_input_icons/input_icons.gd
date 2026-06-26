@tool
extends EditorPlugin

const InputMapIconInjector = preload("res://addons/godot_input_icons/modules/input_map_icon_injector.gd")
var _icon_injector: Node = null

const SETTINGS_CONFIGURATION: Dictionary = {
	InputIconConstants.MAP_PATH_SETTING_NAME: {
		value = InputIconConstants.DEFAULT_MAP_PATH,
		type = TYPE_STRING,
		is_basic = true,
		hint = PROPERTY_HINT_FILE,
		require_restart = true
	},
	InputIconConstants.INPUT_HELPER_ADAPTER_SETTING_NAME: {
		value = false,
		type = TYPE_BOOL,
		is_basic = true,
		require_restart = true
	},
	InputIconConstants.INJECT_INPUT_MAP_ICONS_SETTING_NAME: {
		value = true,
		type = TYPE_BOOL,
		is_basic = true,
		require_restart = true
	},
	InputIconConstants.INJECT_INPUT_MAP_ICONS_POLL_DELAY_SETTING_NAME: {
		value = 0.0,
		type = TYPE_FLOAT,
		is_basic = true,
		require_restart = true
	}
}


func _enter_tree() -> void:
	initialize()
	if ProjectSettings.get_setting(InputIconConstants.INJECT_INPUT_MAP_ICONS_SETTING_NAME, true):
		_icon_injector = InputMapIconInjector.new()
		add_child(_icon_injector)


static func initialize() -> void:
	for key: String in SETTINGS_CONFIGURATION:
		var setting_config: Dictionary = SETTINGS_CONFIGURATION[key]
		var setting_name: String = key
		if not ProjectSettings.has_setting(setting_name):
			ProjectSettings.set_setting(setting_name, setting_config.value)
		
		ProjectSettings.set_initial_value(setting_name, setting_config.value)
		ProjectSettings.add_property_info({
			"name" = setting_name,
			"type" = setting_config.type,
			"hint" = setting_config.get("hint", PROPERTY_HINT_NONE),
			"hint_string" = setting_config.get("hint_string", "")
		})
		
		ProjectSettings.set_as_basic(setting_name, setting_config.get("is_basic", true))
		ProjectSettings.set_as_internal(setting_name, setting_config.get("is_hidden", false))
		ProjectSettings.set_restart_if_changed(setting_name, setting_config.get("require_restart", false))


func _exit_tree() -> void:
	if is_instance_valid(_icon_injector):
		_icon_injector.queue_free()
		_icon_injector = null
