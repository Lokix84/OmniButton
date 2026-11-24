@tool
extends RefCounted
class_name OmniDrawItem

## one of the button's visuals (panel, background, icon, selected overlay, cooldown fill, hold
## fill or joystick thumb) drawn straight on a RenderingServer canvas item instead of being a
## Control node. no node, theme, layout, notification or input overhead, and it only redraws when
## one of its draw properties changes.
##
## it draws exactly what the node it replaced used to: ColorRect (RECT), Panel (STYLE) and
## TextureRect (TEXTURE, stretch modes, flips, atlas margins and the expand mode minimum size that
## lets big textures spill past the button). the property names match those nodes so the timing
## and joystick code reads the same.

enum Kind {RECT, STYLE, TEXTURE}

var kind: int
var rid: RID
var name: String

# --- canvas item state (goes to the RenderingServer right away) ---------------------------------
var visible := true:
	set(value):
		if value == visible: return
		visible = value
		RenderingServer.canvas_item_set_visible(rid, value)
var material: Material:
	set(value):
		if value == material: return
		material = value
		RenderingServer.canvas_item_set_material(rid, value.get_rid() if value != null else RID())
var modulate := Color.WHITE:
	set(value):
		if value == modulate: return
		modulate = value
		RenderingServer.canvas_item_set_modulate(rid, value)
var z_index := 0:
	set(value):
		if value == z_index: return
		z_index = value
		RenderingServer.canvas_item_set_z_index(rid, value)
## a CanvasItem.TextureFilter value. PARENT_NODE inherits like a node would.
var texture_filter := CanvasItem.TEXTURE_FILTER_PARENT_NODE:
	set(value):
		if value == texture_filter: return
		texture_filter = value
		# CanvasItem.TextureFilter and RenderingServer.CanvasItemTextureFilter use the same values,
		# except PARENT_NODE (0) lines up with DEFAULT (0), which inherits from the parent canvas item.
		RenderingServer.canvas_item_set_default_texture_filter(rid, int(value))

# --- draw properties (any change queues one redraw at the end of the frame) ---------------------
var position := Vector2.ZERO:
	set(value):
		if value == position: return
		position = value
		_mark()
var size := Vector2.ZERO:
	set(value):
		if value == size: return
		size = value
		_mark()
var color := Color.WHITE:
	set(value):
		if value == color: return
		color = value
		_mark()
## RECT only: corner radii (top left, top right, bottom right, bottom left). anything above zero
## draws a rounded rect, so the fills can follow a rounded panel.
var corner_radius := Vector4i.ZERO:
	set(value):
		if value == corner_radius: return
		corner_radius = value
		_mark()
var _rounded: StyleBoxFlat
var style: StyleBox:
	set(value):
		if value == style: return
		_watch(value)
		style = value
		_mark()
var texture: Texture2D:
	set(value):
		if value == texture: return
		_watch(value)
		texture = value
		_mark()
var flip_h := false:
	set(value):
		if value == flip_h: return
		flip_h = value
		_mark()
var flip_v := false:
	set(value):
		if value == flip_v: return
		flip_v = value
		_mark()
var expand_mode := TextureRect.EXPAND_KEEP_SIZE:
	set(value):
		if value == expand_mode: return
		expand_mode = value
		_mark()
var stretch_mode := TextureRect.STRETCH_SCALE:
	set(value):
		if value == stretch_mode: return
		stretch_mode = value
		_mark()

var _dirty := false

func _init(item_kind: int, parent_canvas_item: RID, item_name: String, z := 0) -> void:
	kind = item_kind
	name = item_name
	rid = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(rid, parent_canvas_item)
	z_index = z
	RenderingServer.canvas_item_set_z_index(rid, z)

## frees the canvas item now. call it when the visual gets removed. dropping the last reference
## does the same thing, but if something else is hanging onto it (a script caching it) it'd stay on screen.
func queue_free() -> void:
	for res in _watched:
		if is_instance_valid(res) and res.changed.is_connected(_mark):
			res.changed.disconnect(_mark)
	_watched.clear()
	if rid.is_valid():
		RenderingServer.free_rid(rid)
		rid = RID()

func is_alive() -> bool:
	return rid.is_valid()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rid.is_valid():
		RenderingServer.free_rid(rid)

## redraw when a StyleBox/Texture we use gets edited, same as Panel/TextureRect do.
## each resource gets hooked up once and stays hooked, so a panel flipping between its normal,
## hover and pressed styles doesn't connect and disconnect signals every time. worst case an edit
## to a style that isn't showing causes one extra redraw.
var _watched: Array[Resource] = []

func _watch(res: Resource) -> void:
	if res == null or _watched.has(res):
		return
	_watched.append(res)
	res.changed.connect(_mark)

func _mark() -> void:
	if _dirty or not rid.is_valid():
		return
	_dirty = true
	redraw.call_deferred()

func redraw() -> void:
	_dirty = false
	if not rid.is_valid():
		return
	RenderingServer.canvas_item_clear(rid)
	match kind:
		Kind.RECT:
			if corner_radius == Vector4i.ZERO:
				RenderingServer.canvas_item_add_rect(rid, Rect2(position, size), color)
			elif size.x > 0.0 and size.y > 0.0:
				if _rounded == null:
					_rounded = StyleBoxFlat.new()
				_rounded.bg_color = color
				_rounded.corner_radius_top_left = corner_radius.x
				_rounded.corner_radius_top_right = corner_radius.y
				_rounded.corner_radius_bottom_right = corner_radius.z
				_rounded.corner_radius_bottom_left = corner_radius.w
				# StyleBoxFlat shrinks radii that don't fit, so a thin fill stays a thin bar.
				_rounded.draw(rid, Rect2(position, size))
		Kind.STYLE:
			if style != null:
				var min_size := style.get_minimum_size()
				style.draw(rid, Rect2(position, Vector2(maxf(size.x, min_size.x), maxf(size.y, min_size.y))))
		Kind.TEXTURE:
			_draw_texture_rect()

## the size a TextureRect would've been: the anchored size grown to its expand mode minimum.
func _texture_rect_size() -> Vector2:
	var s := size
	if texture == null:
		return s
	var tw := float(texture.get_width())
	var th := float(texture.get_height())
	var min_size := Vector2.ZERO
	match expand_mode:
		TextureRect.EXPAND_KEEP_SIZE:
			min_size = texture.get_size()
		TextureRect.EXPAND_FIT_WIDTH:
			min_size = Vector2(s.y, 0)
		TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL:
			min_size = Vector2(s.y * (tw / th) if th > 0.0 else 0.0, 0)
		TextureRect.EXPAND_FIT_HEIGHT:
			min_size = Vector2(0, s.x)
		TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL:
			min_size = Vector2(0, s.x * (th / tw) if tw > 0.0 else 0.0)
	return Vector2(maxf(s.x, min_size.x), maxf(s.y, min_size.y))

## copy of what TextureRect does in NOTIFICATION_DRAW.
func _draw_texture_rect() -> void:
	if texture == null:
		return
	var node_size := _texture_rect_size()
	var draw_size := Vector2.ZERO
	var offset := Vector2.ZERO
	var region := Rect2()
	var tile := false
	var tex_size := texture.get_size()
	match stretch_mode:
		TextureRect.STRETCH_SCALE:
			draw_size = node_size
		TextureRect.STRETCH_TILE:
			draw_size = node_size
			tile = true
		TextureRect.STRETCH_KEEP:
			draw_size = tex_size
		TextureRect.STRETCH_KEEP_CENTERED:
			offset = (node_size - tex_size) / 2.0
			draw_size = tex_size
		TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			draw_size = node_size
			# integer division on purpose, the engine does it the same way (int tex_width / tex_height).
			var tex_width := int(texture.get_width() * draw_size.y / texture.get_height())
			var tex_height := int(draw_size.y)
			if tex_width > draw_size.x:
				tex_width = int(draw_size.x)
				tex_height = texture.get_height() * tex_width / texture.get_width()
			if stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
				offset.x += (draw_size.x - tex_width) / 2.0
				offset.y += (draw_size.y - tex_height) / 2.0
			draw_size = Vector2(tex_width, tex_height)
		TextureRect.STRETCH_KEEP_ASPECT_COVERED:
			draw_size = node_size
			var scale_size := Vector2(draw_size.x / tex_size.x, draw_size.y / tex_size.y)
			var s := scale_size.x if scale_size.x > scale_size.y else scale_size.y
			var scaled_tex_size := tex_size * s
			region.position = ((scaled_tex_size - draw_size) / scaled_tex_size) * tex_size / 2.0
			region.size = draw_size / s
	var atlas := texture as AtlasTexture
	if atlas != null and not region.has_area():
		var atlas_scale := Vector2(draw_size.x / texture.get_width(), draw_size.y / texture.get_height())
		offset.x += atlas.margin.position.x * atlas_scale.x * 2.0 if flip_h else 0.0
		offset.y += atlas.margin.position.y * atlas_scale.y * 2.0 if flip_v else 0.0
	if flip_h:
		draw_size.x = -draw_size.x
	if flip_v:
		draw_size.y = -draw_size.y
	if region.has_area():
		texture.draw_rect_region(rid, Rect2(position + offset, draw_size), region)
	else:
		texture.draw_rect(rid, Rect2(position + offset, draw_size), tile)
