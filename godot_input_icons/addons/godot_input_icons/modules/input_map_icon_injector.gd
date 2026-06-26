@tool
extends Node

## Decorates the rows of Godot's built-in Input Map editor (Project Settings >
## Input Map) with resolved input icons. Editor-only and best-effort: if the
## internal ActionMapEditor tree can't be found, it does nothing.
##
## Reconciles the rows each frame, writing only icons that are missing or wrong,
## so it is cheap, seamless, and survives the engine rebuilding the tree for any
## reason. settings_changed drops the cache when bindings may change.

const ICON_HEIGHT := 32
const PREVIEW_CONTROLLER := InputIconConstants.InputTypes.Xbox
## How often to search for the Input Map editor until it's found.
const DISCOVERY_INTERVAL := 0.5

var _resolver: InputIconResolver = InputIconResolver.new()
var _action_map_editor_tree: Tree = null
var _delay := 0.0
var _accum := 0.0
var _discover_accum := 0.0
## Finished icons keyed by "device:action:index".
var _icon_cache: Dictionary = {}

func _ready() -> void:
	_delay = ProjectSettings.get_setting(
		InputIconConstants.INJECT_INPUT_MAP_ICONS_POLL_DELAY_SETTING_NAME, 0.0)
	ProjectSettings.settings_changed.connect(_clear_cache)
	set_process(true)

## Reconcile each frame so a repaint lands the same frame the engine rebuilds the
## tree. A delay > 0 throttles to that interval instead.
func _process(delta: float) -> void:
	if not (is_instance_valid(_action_map_editor_tree) and _action_map_editor_tree.is_inside_tree()):
		# Search for the editor occasionally; the full-tree walk is too expensive
		# to run every frame.
		_discover_accum += delta
		if _discover_accum >= DISCOVERY_INTERVAL:
			_discover_accum = 0.0
			_action_map_editor_tree = _find_action_map_editor_tree()
		return
	if _delay > 0.0:
		_accum += delta
		if _accum < _delay:
			return
		_accum = 0.0
	_reconcile()

func _clear_cache() -> void:
	_icon_cache.clear()

#region Reconcile

func _reconcile() -> void:
	if not _action_map_editor_tree.is_visible_in_tree():
		return
	var root := _action_map_editor_tree.get_root()
	if root == null:
		return
	var action_item := root.get_first_child()
	while action_item != null:
		_reconcile_action(action_item)
		action_item = action_item.get_next()

func _reconcile_action(action_item: TreeItem) -> void:
	var action := action_item.get_text(0)
	if action.is_empty():
		return
	# Unknown actions yield no events, so a wrong tree is left untouched.
	var events := _resolver.get_input_events_for_action(action)
	if events.is_empty():
		return

	var kb_index := 0
	var pad_index := 0
	var i := 0
	var child := action_item.get_first_child()
	while child != null and i < events.size():
		var event: InputEvent = events[i]
		var icon: Texture2D = null
		if event is InputEventKey or event is InputEventMouseButton:
			icon = _row_icon(InputIconConstants.InputTypes.Keyboard, action, kb_index)
			kb_index += 1
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			icon = _row_icon(PREVIEW_CONTROLLER, action, pad_index)
			pad_index += 1
		# Only write when the row isn't already showing our icon.
		if icon != null and child.get_icon(0) != icon:
			child.set_icon(0, icon)
			child.set_icon_max_width(0, _capped_width(icon))
		child = child.get_next()
		i += 1

#endregion

#region Icon building

## Cached resolved + upscaled icon for a row.
func _row_icon(device: InputIconConstants.InputTypes, action: String, index: int) -> Texture2D:
	var key := "%d:%s:%d" % [device, action, index]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var resolved := _resolve(device, action, index)
	var icon: Texture2D = _upscaled(resolved) if resolved != null else null
	_icon_cache[key] = icon
	return icon

## Resolved icon, or null for unmapped placeholders (keep the engine's glyph).
func _resolve(device: InputIconConstants.InputTypes, action: String, index: int) -> Texture2D:
	var icon := _resolver.get_icon(device, StringName(action), index, false)
	if icon == null:
		return null
	var map := _resolver.input_icon_map
	if icon == map.unmapped_key or icon == map.unmapped_controller_button:
		return null
	return icon

## Upscales a small pixel-art icon toward ICON_HEIGHT (integer factor, nearest).
func _upscaled(texture: Texture2D) -> Texture2D:
	var native_height := texture.get_height()
	if native_height <= 0:
		return texture
	var factor := ICON_HEIGHT / native_height
	if factor <= 1:
		# Larger icons are shrunk via set_icon_max_width instead.
		return texture
	var source := texture.get_image()
	if source == null:
		return texture
	# Copy so we don't mutate the texture's shared image.
	var image := Image.new()
	image.copy_from(source)
	if image.is_compressed():
		image.decompress()
	image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

## Max width that renders `texture` at ICON_HEIGHT tall (only shrinks oversized icons).
func _capped_width(texture: Texture2D) -> int:
	var h := texture.get_height()
	if h <= 0:
		return 0
	return roundi(ICON_HEIGHT * float(texture.get_width()) / float(h))

#endregion

#region Tree lookup

func _find_action_map_editor_tree() -> Tree:
	var base := EditorInterface.get_base_control()
	if base == null:
		return null
	var editor := _find_by_class(base, "ActionMapEditor")
	if editor == null:
		return null
	return _find_by_class(editor, "Tree") as Tree

func _find_by_class(node: Node, klass: String) -> Node:
	if node.get_class() == klass:
		return node
	for c in node.get_children():
		var found := _find_by_class(c, klass)
		if found != null:
			return found
	return null

#endregion
