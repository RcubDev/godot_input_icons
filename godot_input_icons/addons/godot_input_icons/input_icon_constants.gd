@tool
class_name InputIconConstants

const DEFAULT_MAP_PATH: String = "res://addons/godot_input_icons/default_icon_maps/default_map.tres"
const INPUT_HELPER_ADAPTER_SETTING_NAME: String = "input_icons/settings/use_input_helper"
const MAP_PATH_SETTING_NAME: String = "input_icons/settings/input_icons_map"
const INJECT_INPUT_MAP_ICONS_SETTING_NAME: String = "input_icons/settings/inject_input_map_icons"
const INJECT_INPUT_MAP_ICONS_POLL_DELAY_SETTING_NAME: String = "input_icons/settings/inject_input_map_icons_poll_delay"

enum InputTypes {
	Keyboard,
	Xbox,
	Switch,
	Playstation,
	Generic
}
