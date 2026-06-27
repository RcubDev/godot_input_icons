@tool
extends Control

## Shows a source sheet with a grid overlay. Click a cell or drag across cells to
## pick a region; middle-drag pans the parent scroll.

signal region_picked(region: Rect2i)

var _texture: Texture2D = null
var _cell := Vector2i(16, 16)
var _separation := Vector2i.ZERO
var _margin := Vector2i.ZERO
var _zoom := 3
var _hover := Vector2i(-1, -1)
var _drag_start := Vector2i(-1, -1)
var _drag_end := Vector2i(-1, -1)
var _selecting := false
var _panning := false
var _current := Rect2i()

func set_sheet(texture: Texture2D) -> void:
	_texture = texture
	_refresh()

func set_grid(cell: Vector2i, separation: Vector2i, margin: Vector2i) -> void:
	_cell = cell
	_separation = separation
	_margin = margin
	_refresh()

func set_zoom(zoom: int) -> void:
	_zoom = maxi(1, zoom)
	_refresh()

## Highlights the region a slot currently maps to and scrolls it into view.
func set_current_region(region: Rect2i) -> void:
	_current = region
	queue_redraw()
	var scroll := get_parent() as ScrollContainer
	if scroll:
		var screen := Rect2(Vector2(region.position) * _zoom, Vector2(region.size) * _zoom)
		var center := screen.position + screen.size * 0.5
		scroll.scroll_horizontal = int(center.x - scroll.size.x * 0.5)
		scroll.scroll_vertical = int(center.y - scroll.size.y * 0.5)

func clear_current_region() -> void:
	_current = Rect2i()
	queue_redraw()

func _refresh() -> void:
	custom_minimum_size = Vector2(_texture.get_size()) * _zoom if _texture else Vector2.ZERO
	queue_redraw()

func _columns() -> int:
	if _texture == null or _cell.x <= 0:
		return 0
	return (_texture.get_width() - _margin.x + _separation.x) / (_cell.x + _separation.x)

func _rows() -> int:
	if _texture == null or _cell.y <= 0:
		return 0
	return (_texture.get_height() - _margin.y + _separation.y) / (_cell.y + _separation.y)

func _cell_screen_rect(c: Vector2i) -> Rect2:
	var pos := (_margin + c * (_cell + _separation)) * _zoom
	return Rect2(Vector2(pos), Vector2(_cell * _zoom))

func _span_screen_rect(a: Vector2i, b: Vector2i) -> Rect2:
	return _cell_screen_rect(a).merge(_cell_screen_rect(b))

func _cell_at(pos: Vector2) -> Vector2i:
	if _texture == null or _cell.x <= 0 or _cell.y <= 0:
		return Vector2i(-1, -1)
	var p := pos / _zoom - Vector2(_margin)
	var step := Vector2(_cell + _separation)
	if p.x < 0 or p.y < 0:
		return Vector2i(-1, -1)
	var c := Vector2i(int(p.x / step.x), int(p.y / step.y))
	if c.x >= _columns() or c.y >= _rows():
		return Vector2i(-1, -1)
	# Reject clicks that land in the separation gap.
	if fmod(p.x, step.x) > _cell.x or fmod(p.y, step.y) > _cell.y:
		return Vector2i(-1, -1)
	return c

## Pixel region spanning cells a..b inclusive, gaps included.
func _region_for(a: Vector2i, b: Vector2i) -> Rect2i:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	var span := hi - lo + Vector2i.ONE
	var pos := _margin + lo * (_cell + _separation)
	var size := _cell * span + _separation * (span - Vector2i.ONE)
	return Rect2i(pos, size)

func _draw() -> void:
	if _texture == null:
		return
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(_texture.get_size()) * _zoom), false)
	var line := Color(1, 1, 1, 0.2)
	for c in _columns():
		for r in _rows():
			draw_rect(_cell_screen_rect(Vector2i(c, r)), line, false, 1.0)
	if _current.size != Vector2i.ZERO:
		var cur := Rect2(Vector2(_current.position) * _zoom, Vector2(_current.size) * _zoom)
		draw_rect(cur, Color(0.3, 1.0, 0.4, 0.2), true)
		draw_rect(cur, Color(0.3, 1.0, 0.4), false, 2.0)
	var marked := _span_screen_rect(_drag_start, _drag_end) if _selecting and _drag_start.x >= 0 \
		else (_cell_screen_rect(_hover) if _hover.x >= 0 else Rect2())
	if marked.size != Vector2.ZERO:
		draw_rect(marked, Color(0.3, 0.7, 1.0, 0.25), true)
		draw_rect(marked, Color(0.3, 0.7, 1.0), false, 2.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var c := _cell_at(event.position)
				if c.x >= 0:
					_selecting = true
					_drag_start = c
					_drag_end = c
					queue_redraw()
			elif _selecting:
				_selecting = false
				if _drag_start.x >= 0:
					region_picked.emit(_region_for(_drag_start, _drag_end))
				queue_redraw()
	elif event is InputEventMouseMotion:
		if _panning:
			var scroll := get_parent() as ScrollContainer
			if scroll:
				scroll.scroll_horizontal -= int(event.relative.x)
				scroll.scroll_vertical -= int(event.relative.y)
		elif _selecting:
			var c := _cell_at(event.position)
			if c.x >= 0 and c != _drag_end:
				_drag_end = c
				queue_redraw()
		else:
			var c := _cell_at(event.position)
			if c != _hover:
				_hover = c
				queue_redraw()
