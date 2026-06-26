@tool
class_name InputIconResolver

const InputTypes = preload("res://addons/godot_input_icons/input_icon_constants.gd").InputTypes
var input_icon_map: InputIconMap = null

static var _combine_cache: Dictionary = {}


## Initalizes the resolver by loading the map specified by the plugin
func _init() -> void:
	input_icon_map = load(ProjectSettings.get_setting(InputIconConstants.MAP_PATH_SETTING_NAME, InputIconConstants.DEFAULT_MAP_PATH))
	pass


## Gets an icon from the plugin's registed icon map based off of the device_type
## and the input_action passed in
func get_icon(device_type: InputTypes, input_action: String, index: int = 0, push_warnings: bool = true) -> Texture2D:
	var result: Texture2D = null
	if device_type == InputTypes.Keyboard:
		result = get_keyboard_icon(input_action, index, push_warnings)
		if not result and input_icon_map.unmapped_key:
			result = input_icon_map.unmapped_key
	else:
		result = get_joypad_icon(device_type, input_action, index, push_warnings)
		if not result and input_icon_map.unmapped_controller_button:
			result = input_icon_map.unmapped_controller_button
	return result


## Gets the keyboard icon for the first keyboard input associated with
## an action
func get_keyboard_icon(input_action: String, index: int = 0, push_warnings: bool = true) -> Texture2D:
	var input_event: InputEvent = get_keyboard_input_event_for_action(input_action, index, push_warnings)
	var textures: Array[Texture2D] = []
	# Add modifiers first
	if input_event is InputEventWithModifiers:
		textures.append_array(get_keyboard_modifier_icons(input_event))
	
	# Add key after
	if input_event is InputEventKey:
		# Get the OS keycode string (this ignores the modifiers and lets us get just the key)
		var key_name: String = OS.get_keycode_string(input_event.physical_keycode).to_lower()
		# arrow keys are named specially for user to setup easier
		if key_name == "up" or key_name == "down" or key_name == "left" or key_name == "right":
			key_name = key_name.insert(0, "arrow_")
		
		var texture: Texture2D = input_icon_map.keyboard_icons.get("key_%s" % [key_name])
		if texture:
			textures.append(texture)
	elif input_event is InputEventMouseButton:
		var texture: Texture2D = get_mouse_button_icon(input_event)
		if texture:
			textures.append(texture)
			
	if textures.size() == 0:
		return null
	elif textures.size() == 1:
		return textures[0]
	return combine_textures_with_gap(textures)


func get_keyboard_modifier_icons(input_event: InputEventWithModifiers) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	if input_event.alt_pressed and input_icon_map.keyboard_icons.key_alt:
		textures.append(input_icon_map.keyboard_icons.key_alt)
	if input_event.ctrl_pressed and input_icon_map.keyboard_icons.key_ctrl:
		textures.append(input_icon_map.keyboard_icons.key_ctrl)
	if input_event.meta_pressed and input_icon_map.keyboard_icons.key_meta:
		textures.append(input_icon_map.keyboard_icons.key_meta)
	if input_event.shift_pressed and input_icon_map.keyboard_icons.key_shift:
		textures.append(input_icon_map.keyboard_icons.key_shift)
	return textures


func get_mouse_button_icon(input_event: InputEventMouseButton) -> Texture2D:
	match input_event.button_index:
		MOUSE_BUTTON_LEFT:
			return input_icon_map.keyboard_icons.mouse_left_click
		MOUSE_BUTTON_RIGHT:
			return input_icon_map.keyboard_icons.mouse_right_click
		MOUSE_BUTTON_MIDDLE:
			return input_icon_map.keyboard_icons.mouse_middle_click
		MOUSE_BUTTON_XBUTTON1:			
			return input_icon_map.keyboard_icons.mouse_extra_button1
		MOUSE_BUTTON_XBUTTON2:
			return input_icon_map.keyboard_icons.mouse_extra_button2
	return null


## Gets the controller icon for the first controller input associated with
## an action
func get_joypad_icon(device_type: InputTypes, input_action: String, index: int = 0, push_warnings: bool = true) -> Texture2D:
	if not input_icon_map.controller_icons.has(device_type):
		if push_warnings:
			push_warning("InputIcons: Missing icon map for device %s" % \
				[get_device_type_display(device_type)])
		return null

	var joypad_icon_map: ControllerIcons = input_icon_map.controller_icons.get(device_type)
	var input_event: InputEvent = get_joypad_input_event_for_action(input_action, index, push_warnings)
	if input_event is InputEventJoypadButton:
		return _get_joypad_button_icon(joypad_icon_map, input_event)
	elif input_event is InputEventJoypadMotion:
		return _get_joypad_axis_icon(joypad_icon_map, input_event)
		
	return null


## Gets all input events for a specified action
func get_input_events_for_action(input_action: String) -> Array[InputEvent]:
	var input_events: Array[InputEvent] = []
	if Engine.is_editor_hint():
		var project_setting_input: Variant = ProjectSettings.get_setting("input/%s" % [input_action])
		if not project_setting_input:
			return input_events
			
		var input_dict: Dictionary = project_setting_input as Dictionary
		for item in input_dict.get_or_add("events", []):
			input_events.append(item as InputEvent)
	else:
		# At runtime we need to use godot's InputMap singleton
		# because remapping inputs is not saved in the project settings
		var events: Array[InputEvent] = InputMap.action_get_events(input_action)
		if events:
			input_events.append_array(events)
	return input_events


## Gets a keyboard or mouse button action at a specific index.
## - if no index specified defaults to index 0
## - returns null if no actions are found
## NOTE: The index applies to only input events for keyboard and will be
## in the same order that they are registered in the ProjectSettings input	
func get_keyboard_input_event_for_action(input_action: String, index: int = 0, push_warnings: bool = true) -> InputEvent:
	var events: Array[InputEvent] = get_input_events_for_action(input_action)
	var filtered_events: Array[InputEvent] = events.filter(func(event): return event is InputEventKey or event is InputEventMouseButton)
	if not filtered_events or index >= filtered_events.size():
		if push_warnings:
			push_warning("InputIcons: keyboard action '%s' at index %s not found." % \
				 [input_action, index])
		return null
	return filtered_events[index]
	

## Gets a joypad action at a specific index.
## - if no index specified defaults to index 0
## - returns null if no actions are found
## NOTE: The index applies to only input events for joypad and will be
## in the same order that they are registered in the ProjectSettings input 
func get_joypad_input_event_for_action(input_action: String, index: int = 0, push_warnings: bool = true) -> InputEvent:
	var events: Array[InputEvent] = get_input_events_for_action(input_action)
	var filtered_events = events.filter(func(event): return event is InputEventJoypadButton \
		 or event is InputEventJoypadMotion)
	if not filtered_events or index >= filtered_events.size():
		if push_warnings:
			push_warning("InputIcons: joypad action '%s' at index %s not found." % \
				 [input_action, index])
		return null
	return filtered_events[index]
	

## Gets the controller icon from the input map using a InputEventJoypadButton
func _get_joypad_axis_icon(icon_map: ControllerIcons, joypad_motion_event: InputEventJoypadMotion) -> Texture2D:
	match joypad_motion_event.axis:
		JoyAxis.JOY_AXIS_TRIGGER_LEFT:
			return icon_map.left_trigger
		JoyAxis.JOY_AXIS_TRIGGER_RIGHT:
			return icon_map.right_trigger
		_:
			return null
	

## Gets the controller icon from the input map using a InputEventJoypadButton
func _get_joypad_button_icon(icon_map: ControllerIcons, button_event: InputEventJoypadButton) -> Texture2D:
	match button_event.button_index:
		JOY_BUTTON_A:
			if icon_map.face_button_down_extra:
				return combine_textures_with_overlap([icon_map.face_button_down, icon_map.face_button_down_extra])
			return icon_map.face_button_down
		JOY_BUTTON_B:
			if icon_map.face_button_right_extra:
				return combine_textures_with_overlap([icon_map.face_button_right, icon_map.face_button_right_extra])
			return icon_map.face_button_right
		JOY_BUTTON_X:
			if icon_map.face_button_left_extra:
				return combine_textures_with_overlap([icon_map.face_button_left, icon_map.face_button_left_extra])
			return icon_map.face_button_left
		JOY_BUTTON_Y:
			if icon_map.face_button_up_extra:
				return combine_textures_with_overlap([icon_map.face_button_up, icon_map.face_button_up_extra])
			return icon_map.face_button_up
		JOY_BUTTON_DPAD_UP:
			return icon_map.dpad_up
		JOY_BUTTON_DPAD_LEFT:
			return icon_map.dpad_left
		JOY_BUTTON_DPAD_RIGHT:
			return icon_map.dpad_right
		JOY_BUTTON_DPAD_DOWN:
			return icon_map.dpad_down
		JOY_BUTTON_START:
			return icon_map.start_button
		JOY_BUTTON_LEFT_SHOULDER:
			return icon_map.left_bumper
		JOY_BUTTON_RIGHT_SHOULDER:
			return icon_map.right_bumper
		JOY_BUTTON_BACK:
			return icon_map.back_button
		JOY_BUTTON_INVALID:
			return icon_map.invalid_button
		JOY_BUTTON_GUIDE:
			return icon_map.guide_button 
		JOY_BUTTON_LEFT_STICK:
			return icon_map.left_stick_in
		JOY_BUTTON_RIGHT_STICK:
			return icon_map.right_stick_in
		JOY_BUTTON_MISC1:
			return icon_map.misc1
		JOY_BUTTON_PADDLE1:
			return icon_map.paddle1
		JOY_BUTTON_PADDLE2:
			return icon_map.paddle2
		JOY_BUTTON_PADDLE3:
			return icon_map.paddle3
		JOY_BUTTON_PADDLE4:
			return icon_map.paddle4
		JOY_BUTTON_TOUCHPAD:
			return icon_map.touchpad
		_:
			return null


static func get_device_type_display(device_type: InputTypes) -> String:
	match device_type:
		InputTypes.Keyboard:
			return "Keyboard"
		InputTypes.Xbox:
			return "Xbox"
		InputTypes.Playstation:
			return "Playstation"
		InputTypes.Switch:
			return "Switch"
		InputTypes.Generic:
			return "Generic"
	return "Unknown device type"


static func combine_textures_with_overlap(textures: Array[Texture2D]) -> Texture2D:
	var cache_key := _combine_cache_key("overlap", textures, 0)
	if _combine_cache.has(cache_key):
		return _combine_cache[cache_key]

	var max_width: int = 0
	var max_height: int = 0

	for texture in textures:
		if not texture:
			continue
		max_width = max(max_width, texture.get_width())
		max_height = max(max_height, texture.get_height())

	var combined_image = Image.create_empty(max_width, max_height, false, Image.FORMAT_RGBA8)

	# Blend each texture onto the combined image
	for texture in textures:
		if not texture:
			continue
		var image: Image = texture.get_image()
		combined_image.blend_rect(image, Rect2(Vector2.ZERO, image.get_size()), Vector2(0, 0))

	var combined := ImageTexture.create_from_image(combined_image)
	_combine_cache[cache_key] = combined
	return combined


## Combines an array of Texture2Ds and converts them into a single Texture2D with a gap
static func combine_textures_with_gap(textures: Array[Texture2D], gap: int = 2) -> Texture2D:
	var cache_key := _combine_cache_key("gap", textures, gap)
	if _combine_cache.has(cache_key):
		return _combine_cache[cache_key]

	var total_width: int = 0
	var max_height: int = 0

	for texture in textures:
		total_width += texture.get_width() + gap
		max_height = max(max_height, texture.get_height())

	total_width -= gap  # Remove the last gap

	var combined_image: Image = Image.create_empty(total_width, max_height, false, Image.FORMAT_RGBA8)

	# Blit each texture onto the combined image with a gap
	var current_x: int = 0
	for texture in textures:
		var image = texture.get_image()
		combined_image.blit_rect(image, Rect2(Vector2.ZERO, image.get_size()), Vector2(current_x, 0))
		current_x += texture.get_width() + gap

	var combined := ImageTexture.create_from_image(combined_image)
	_combine_cache[cache_key] = combined
	return combined


static func _combine_cache_key(kind: String, textures: Array[Texture2D], gap: int) -> String:
	var parts: PackedStringArray = [kind, str(gap)]
	for texture in textures:
		parts.append(str(texture.get_instance_id()) if texture else "null")
	return "|".join(parts)


## Gets all registered user inputs (filters out inputs that start with ui_)
static func get_all_user_registered_inputs() -> PackedStringArray:
	var input_actions: PackedStringArray = []
	var project_settings: Object = Engine.get_singleton("ProjectSettings")
	for setting_dict in project_settings.get_property_list():
		if setting_dict and "name" in setting_dict:
			var setting_name: String = str(setting_dict["name"])
			if setting_name.begins_with("input/"):
				setting_name = setting_name.substr("input/".length())
				if not setting_name.begins_with("ui_"):
					input_actions.append(setting_name)
	return input_actions
