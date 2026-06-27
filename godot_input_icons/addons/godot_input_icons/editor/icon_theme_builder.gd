@tool
extends Control

## TileSet-style editor for assigning regions of a source sheet to the slots of
## an InputIconMap. Pick a group, load a sheet, set the grid, select a slot, then
## click or drag across cells to assign it as an AtlasTexture.

const IconSheetView = preload("res://addons/godot_input_icons/editor/icon_sheet_view.gd")
const THUMB_SIZE := 24
const HEADER_COLOR := Color(0.7, 0.8, 1.0)

var _map: InputIconMap = null
var _target: Resource = null
var _entries: Array = []  # ordered [{header = String} | {slot = String}]
var _selected_slot_name := ""
var _undo_redo: EditorUndoRedoManager = null
var _watched: Resource = null

var _group: OptionButton
var _source: EditorResourcePicker
var _cell_w: SpinBox
var _cell_h: SpinBox
var _sep: SpinBox
var _margin: SpinBox
var _zoom: SpinBox
var _filter: LineEdit
var _auto_advance: CheckBox
var _tree: Tree
var _sheet: Control = null

func _init() -> void:
	custom_minimum_size = Vector2(0, 320)
	_build()

func edit_map(map: InputIconMap) -> void:
	_map = map
	_rebuild_slots()

func set_undo_redo(undo_redo: EditorUndoRedoManager) -> void:
	_undo_redo = undo_redo

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_refresh_icons()

#region UI

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Controls on the left, the sheet picker on its own at the right.
	var top := HBoxContainer.new()
	var controls := _toolbar()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(controls)
	top.add_child(_label("Sheet"))
	_source = EditorResourcePicker.new()
	_source.base_type = "Texture2D"
	_source.custom_minimum_size = Vector2(180, 0)
	_source.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_source.resource_changed.connect(func(_r): _apply_grid())
	top.add_child(_source)
	root.add_child(top)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 240
	root.add_child(split)

	_tree = Tree.new()
	_tree.custom_minimum_size = Vector2(220, 0)
	_tree.hide_root = true
	_tree.item_selected.connect(_on_slot_selected)
	split.add_child(_tree)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet = IconSheetView.new()
	_sheet.region_picked.connect(_on_region_picked)
	scroll.add_child(_sheet)
	split.add_child(scroll)

func _toolbar() -> Control:
	var bar := HFlowContainer.new()

	_group = OptionButton.new()
	for value in InputIconConstants.InputTypes.values():
		_group.add_item(InputIconResolver.get_device_type_display(value), value)
	_group.item_selected.connect(func(_i): _rebuild_slots())
	bar.add_child(_pair("Group", _group))

	_cell_w = _spin("W", 1, 1024, 16, bar)
	_cell_h = _spin("H", 1, 1024, 16, bar)
	_sep = _spin("Sep", 0, 256, 0, bar)
	_margin = _spin("Margin", 0, 256, 0, bar)
	_zoom = _spin("Zoom", 1, 16, 3, bar)

	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter"
	_filter.custom_minimum_size = Vector2(120, 0)
	_filter.text_changed.connect(func(t): _populate(t))
	bar.add_child(_filter)

	_auto_advance = CheckBox.new()
	_auto_advance.text = "Auto-advance"
	bar.add_child(_auto_advance)

	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(_save)
	bar.add_child(save)
	return bar

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

## Keeps a label and its input together so they wrap as one unit in the flow row.
func _pair(label: String, control: Control) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_child(_label(label))
	box.add_child(control)
	return box

func _spin(label: String, min_v: float, max_v: float, value: float, parent: Control) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.value = value
	s.custom_minimum_size = Vector2(64, 0)
	s.value_changed.connect(func(_v): _apply_grid())
	parent.add_child(_pair(label, s))
	return s

#endregion

func _apply_grid() -> void:
	if _sheet == null:
		return
	_sheet.set_sheet(_source.edited_resource)
	_sheet.set_grid(
		Vector2i(int(_cell_w.value), int(_cell_h.value)),
		Vector2i(int(_sep.value), int(_sep.value)),
		Vector2i(int(_margin.value), int(_margin.value)))
	_sheet.set_zoom(int(_zoom.value))
	_show_current_region()

#region Slot tree

func _rebuild_slots() -> void:
	if _map == null or _tree == null:
		return
	_target = _target_for_group(_group.get_selected_id())
	_watch_target(_target)
	_entries = _build_entries(_target)
	_selected_slot_name = ""
	_populate(_filter.text if _filter else "")

## Builds the tree. With no filter, headers are collapsible parents holding their
## slots; while filtering, matching slots are listed flat.
func _populate(filter: String) -> void:
	if _tree == null:
		return
	_tree.clear()
	var root := _tree.create_item()
	var f := filter.to_lower()
	var header: TreeItem = null
	for e in _entries:
		if e.has("header"):
			if f == "":
				header = _tree.create_item(root)
				header.set_text(0, e.header)
				header.set_selectable(0, false)
				header.set_custom_color(0, HEADER_COLOR)
			else:
				header = null
		elif e.has("slot"):
			if f != "" and e.slot.to_lower().find(f) == -1:
				continue
			var item := _tree.create_item(header if header else root)
			item.set_text(0, e.slot)
			item.set_metadata(0, e.slot)
			_set_item_icon(item, _target.get(e.slot) as Texture2D)

func _on_slot_selected() -> void:
	var item := _tree.get_selected()
	if item == null or item.get_metadata(0) == null:
		return
	_selected_slot_name = str(item.get_metadata(0))
	_maybe_autoload_sheet()
	_show_current_region()

func _set_item_icon(item: TreeItem, texture: Texture2D) -> void:
	item.set_icon(0, texture)
	if texture:
		item.set_icon_max_width(0, THUMB_SIZE)

func _item_for_slot(slot: String) -> TreeItem:
	return _find_item(_tree.get_root(), slot)

func _find_item(parent: TreeItem, slot: String) -> TreeItem:
	if parent == null:
		return null
	var child := parent.get_first_child()
	while child:
		if child.get_metadata(0) == slot:
			return child
		var found := _find_item(child, slot)
		if found:
			return found
		child = child.get_next()
	return null

func _advance() -> void:
	var item := _item_for_slot(_selected_slot_name)
	if item == null:
		return
	var next := item.get_next_visible(false)
	while next and next.get_metadata(0) == null:
		next = next.get_next_visible(false)
	if next:
		next.select(0)
		_tree.scroll_to_item(next)

#endregion

#region Assigning

func _on_region_picked(region: Rect2i) -> void:
	if _selected_slot_name == "" or _target == null or _source.edited_resource == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = _source.edited_resource
	atlas.region = region
	if _undo_redo:
		_undo_redo.create_action("Assign input icon: %s" % _selected_slot_name, UndoRedo.MERGE_DISABLE, _map)
		_undo_redo.add_do_method(self, "_set_slot", _selected_slot_name, atlas)
		_undo_redo.add_undo_method(self, "_set_slot", _selected_slot_name, _target.get(_selected_slot_name))
		_undo_redo.commit_action()
	else:
		_set_slot(_selected_slot_name, atlas)
	if _auto_advance.button_pressed:
		_advance()
	_show_current_region()

func _set_slot(slot: String, texture: Texture2D) -> void:
	if _target == null:
		return
	_target.set(slot, texture)
	var item := _item_for_slot(slot)
	if item:
		_set_item_icon(item, texture)
	if slot == _selected_slot_name:
		_show_current_region()

func _refresh_icons() -> void:
	if _target == null or _tree == null:
		return
	_refresh_under(_tree.get_root())

func _refresh_under(parent: TreeItem) -> void:
	if parent == null:
		return
	var child := parent.get_first_child()
	while child:
		var slot = child.get_metadata(0)
		if slot != null:
			_set_item_icon(child, _target.get(slot) as Texture2D)
		_refresh_under(child)
		child = child.get_next()

## Highlights the selected slot's region if its icon points at the loaded sheet.
func _show_current_region() -> void:
	if _sheet == null:
		return
	if _target == null or _selected_slot_name == "":
		_sheet.clear_current_region()
		return
	var tex := _target.get(_selected_slot_name)
	if tex is AtlasTexture and tex.atlas == _source.edited_resource:
		_sheet.set_current_region(tex.region)
	else:
		_sheet.clear_current_region()

## When no sheet is loaded, adopt the selected slot's source atlas (and its
## region size as the grid) so you can edit it right away.
func _maybe_autoload_sheet() -> void:
	if _source.edited_resource != null or _target == null or _selected_slot_name == "":
		return
	var tex := _target.get(_selected_slot_name)
	if tex is AtlasTexture and tex.atlas != null:
		_source.edited_resource = tex.atlas
		if tex.region.size.x > 0 and tex.region.size.y > 0:
			_cell_w.value = tex.region.size.x
			_cell_h.value = tex.region.size.y
		_apply_grid()

func _save() -> void:
	if _target and not _target.resource_path.is_empty():
		ResourceSaver.save(_target)
	if _map and not _map.resource_path.is_empty():
		ResourceSaver.save(_map)

#endregion

#region Resource helpers

func _target_for_group(device: int) -> Resource:
	if _map == null:
		return null
	if device == InputIconConstants.InputTypes.Keyboard:
		if _map.keyboard_icons == null:
			_map.keyboard_icons = KeyboardIcons.new()
		return _map.keyboard_icons
	if not _map.controller_icons.has(device) or _map.controller_icons[device] == null:
		_map.controller_icons[device] = ControllerIcons.new()
	return _map.controller_icons[device]

## Ordered entries of group headers and their texture slots.
func _build_entries(res: Resource) -> Array:
	var entries: Array = []
	if res == null:
		return entries
	var pending := ""
	for prop in res.get_property_list():
		var usage := int(prop.usage)
		if usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_CATEGORY):
			pending = str(prop.name)
		elif str(prop.get("hint_string", "")) == "Texture2D" and (usage & PROPERTY_USAGE_EDITOR):
			if pending != "":
				entries.append({header = pending})
				pending = ""
			entries.append({slot = str(prop.name)})
	return entries

## Re-read slot icons when the edited resource changes elsewhere (e.g. inspector).
func _watch_target(res: Resource) -> void:
	if _watched and _watched.changed.is_connected(_refresh_icons):
		_watched.changed.disconnect(_refresh_icons)
	_watched = res
	if res and not res.changed.is_connected(_refresh_icons):
		res.changed.connect(_refresh_icons)

#endregion
