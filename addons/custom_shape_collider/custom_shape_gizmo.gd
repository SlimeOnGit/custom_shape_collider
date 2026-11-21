@tool
extends EditorNode3DGizmoPlugin

const CustomShape = preload("res://addons/custom_shape_collider/custom_shape_3d.gd")

# Keep handle IDs consistent when the face count changes
const CURVE_HANDLE_BASE := 12
const CURVE_HANDLES_PER_CORNER := CustomShape.MAX_CORNER_FACES - 1
const HEIGHT_HANDLE_BASE := CURVE_HANDLE_BASE + 4 * CURVE_HANDLES_PER_CORNER
const CORNER_PROPERTIES := [
	"front_left_cut", "front_right_cut", "back_right_cut", "back_left_cut"
]
const CORNER_NAMES := ["Front-left", "Front-right", "Back-right", "Back-left"]

var _preview_material: StandardMaterial3D
var _outline_material: StandardMaterial3D
var _height_guide_material: StandardMaterial3D
var _x_handles_material: StandardMaterial3D
var _z_handles_material: StandardMaterial3D
var _height_handles_material: StandardMaterial3D
var _corner_handles_material: StandardMaterial3D
var _curve_handles_material: StandardMaterial3D

func _init() -> void:
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.albedo_color = Color(0.12, 0.96, 0.20, 0.14)
	_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	_outline_material = _make_line_material(Color(0.25, 0.9, 0.9, 0.9))
	_height_guide_material = _make_line_material(Color(0.28, 0.78, 0.40, 0.95))
	_x_handles_material = _make_handle_material(Color("df5252"))
	_z_handles_material = _make_handle_material(Color("438fe6"))
	_height_handles_material = _make_handle_material(Color("41b86b"))
	_corner_handles_material = _make_handle_material(Color("171717"), true)
	_curve_handles_material = _make_handle_material(Color("a0a0a0"), true)

func _make_line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material

func _make_handle_material(color: Color, square: bool = false) -> StandardMaterial3D:
	var texture := _make_handle_icon(color, square)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.use_point_size = true
	material.point_size = float(texture.get_width())
	material.albedo_texture = texture
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.1
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material

func _make_handle_icon(fill: Color, square: bool = false) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var border := Color(0.94, 0.94, 0.94) if fill == Color("171717") else Color(0.12, 0.12, 0.12)
	for y in range(16):
		for x in range(16):
			var dx := absf(float(x) - 7.5)
			var dy := absf(float(y) - 7.5)
			var outer := maxf(dx, dy) <= 6.0 if square else Vector2(dx, dy).length_squared() <= 36.0
			var inner := maxf(dx, dy) <= 4.0 if square else Vector2(dx, dy).length_squared() <= 16.0
			if outer:
				img.set_pixel(x, y, fill if inner else border)
	return ImageTexture.create_from_image(img)

func _get_gizmo_name() -> String:
	return "Custom Shape Collider"

func _has_gizmo(node: Node3D) -> bool:
	return node is CustomShape

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var collider := gizmo.get_node_3d() as CustomShape3D
	var outline := collider.get_shape_outline()
	var top := collider.get_top_y()
	var bottom := collider.get_bottom_y()
	var middle := collider.vertical_offset
	var lines := PackedVector3Array()
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		lines.append(Vector3(a.x, top, a.y))
		lines.append(Vector3(b.x, top, b.y))
		lines.append(Vector3(a.x, bottom, a.y))
		lines.append(Vector3(b.x, bottom, b.y))
		lines.append(Vector3(a.x, top, a.y))
		lines.append(Vector3(a.x, bottom, a.y))
	gizmo.add_lines(lines, _outline_material)
	gizmo.add_collision_segments(lines)
	if collider.show_collision_preview:
		var preview_mesh := _make_preview_mesh(outline, top, bottom)
		gizmo.add_mesh(preview_mesh, _preview_material)
	var fl := collider.get_corner_cut(0)
	var fr := collider.get_corner_cut(1)
	var br := collider.get_corner_cut(2)
	var bl := collider.get_corner_cut(3)
	var front_mid_x := (-collider.left_extent + fl.x + collider.right_extent - fr.x) * 0.5
	var back_mid_x := (-collider.left_extent + bl.x + collider.right_extent - br.x) * 0.5
	var left_mid_z := (-collider.front_extent + fl.y + collider.back_extent - bl.y) * 0.5
	var right_mid_z := (-collider.front_extent + fr.y + collider.back_extent - br.y) * 0.5
	var edges := PackedVector3Array([
		Vector3(-collider.left_extent, middle, left_mid_z),
		Vector3(collider.right_extent, middle, right_mid_z),
		Vector3(front_mid_x, middle, -collider.front_extent),
		Vector3(back_mid_x, middle, collider.back_extent)
	])

	gizmo.add_handles(
		PackedVector3Array([edges[0], edges[1]]),
		_x_handles_material, PackedInt32Array([0, 1])
	)
	gizmo.add_handles(
		PackedVector3Array([edges[2], edges[3]]),
		_z_handles_material, PackedInt32Array([2, 3])
	)
	var corners := PackedVector3Array()
	var corner_ids := PackedInt32Array()
	var extras := PackedVector3Array()
	var extra_ids := PackedInt32Array()
	for corner_index in range(4):
		var cut := collider.get_corner_cut(corner_index)
		if cut.x < 0.0001 or cut.y < 0.0001:
			continue
		var geometry := collider._corner_geometry(corner_index)
		var first := geometry[1]
		var last := geometry[2]
		var x_endpoint := first
		var z_endpoint := last
		if corner_index == 0 or corner_index == 2:
			x_endpoint = last
			z_endpoint = first
		corners.append(Vector3(x_endpoint.x, middle, x_endpoint.y))
		corners.append(Vector3(z_endpoint.x, middle, z_endpoint.y))
		corner_ids.append(4 + corner_index * 2)
		corner_ids.append(5 + corner_index * 2)
		for inner_index in range(collider.get_corner_faces(corner_index) - 1):
			var point := collider.get_curve_point(corner_index, inner_index)
			extras.append(Vector3(point.x, middle, point.y))
			extra_ids.append(CURVE_HANDLE_BASE + corner_index * CURVE_HANDLES_PER_CORNER + inner_index)
	if corners.size() > 0:
		gizmo.add_handles(corners, _corner_handles_material, corner_ids)
	if extras.size() > 0:
		gizmo.add_handles(extras, _curve_handles_material, extra_ids)
	var center_x := (collider.right_extent - collider.left_extent) * 0.5
	var center_z := (collider.back_extent - collider.front_extent) * 0.5
	var center_top := Vector3(center_x, top, center_z)
	var center_bottom := Vector3(center_x, bottom, center_z)
	gizmo.add_lines(PackedVector3Array([center_bottom, center_top]), _height_guide_material)
	gizmo.add_handles(
		PackedVector3Array([center_top, center_bottom]),
		_height_handles_material,
		PackedInt32Array([HEIGHT_HANDLE_BASE, HEIGHT_HANDLE_BASE + 1])
	)

func _make_preview_mesh(outline: PackedVector2Array, top: float, bottom: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var triangles := Geometry2D.triangulate_polygon(outline)
	for i in range(0, triangles.size(), 3):
		var a := outline[triangles[i]]
		var b := outline[triangles[i + 1]]
		var c := outline[triangles[i + 2]]

		vertices.append(Vector3(a.x, top, a.y))
		vertices.append(Vector3(b.x, top, b.y))
		vertices.append(Vector3(c.x, top, c.y))
		vertices.append(Vector3(a.x, bottom, a.y))
		vertices.append(Vector3(b.x, bottom, b.y))
		vertices.append(Vector3(c.x, bottom, c.y))
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		vertices.append(Vector3(a.x, bottom, a.y))
		vertices.append(Vector3(a.x, top, a.y))
		vertices.append(Vector3(b.x, top, b.y))
		vertices.append(Vector3(a.x, bottom, a.y))
		vertices.append(Vector3(b.x, top, b.y))
		vertices.append(Vector3(b.x, bottom, b.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	if handle_id < 4:
		return ["Left edge", "Right edge", "Front edge (-Z)", "Back edge (+Z)"][handle_id]
	if handle_id < 12:
		var corner_index := int((handle_id - 4) / 2)
		return CORNER_NAMES[corner_index] + (" X cut endpoint" if handle_id % 2 == 0 else " Z cut endpoint")
	if handle_id < HEIGHT_HANDLE_BASE:
		var relative := handle_id - CURVE_HANDLE_BASE
		var corner_index := int(relative / CURVE_HANDLES_PER_CORNER)
		return CORNER_NAMES[corner_index] + " curve vertex " + str(relative % CURVE_HANDLES_PER_CORNER + 1)
	return "Top height" if handle_id == HEIGHT_HANDLE_BASE else "Bottom height"

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> Variant:
	var collider := gizmo.get_node_3d() as CustomShape3D
	if handle_id < 4:
		return collider.get_resize_state()
	if handle_id < 12:
		return collider.get(CORNER_PROPERTIES[int((handle_id - 4) / 2)])
	if handle_id < HEIGHT_HANDLE_BASE:
		var relative := handle_id - CURVE_HANDLE_BASE
		var corner_index := int(relative / CURVE_HANDLES_PER_CORNER)
		var inner_index := relative % CURVE_HANDLES_PER_CORNER
		var property_name := collider.get_curve_property_name(corner_index, inner_index)
		var stored_value: Variant = collider.get(property_name)
		if stored_value is PackedVector2Array:
			return stored_value.duplicate()
		return stored_value
	return Vector2(collider.height, collider.vertical_offset)

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var collider := gizmo.get_node_3d() as CustomShape3D
	if handle_id >= HEIGHT_HANDLE_BASE:
		var hit_height = _mouse_on_vertical_axis(collider, camera, screen_pos)
		if hit_height == null:
			return
		var y: float = hit_height
		# Clamp the Y drag when the camera ray is nearly parallel
		const MAX_HANDLE_HEIGHT := 100.0
		const MIN_HANDLE_HEIGHT := 0.05
		if handle_id == HEIGHT_HANDLE_BASE:
			collider.set_vertical_bounds(clampf(y, collider.get_bottom_y() + MIN_HANDLE_HEIGHT, collider.get_bottom_y() + MAX_HANDLE_HEIGHT), collider.get_bottom_y())
		else:
			collider.set_vertical_bounds(collider.get_top_y(), clampf(y, collider.get_top_y() - MAX_HANDLE_HEIGHT, collider.get_top_y() - MIN_HANDLE_HEIGHT))
		return
	var hit = _mouse_on_edit_plane(collider, camera, screen_pos)
	if hit == null:
		return
	var point: Vector3 = hit

	match handle_id:
		0: collider.resize_edge_preserving_corners(0, -point.x)
		1: collider.resize_edge_preserving_corners(1, point.x)
		2: collider.resize_edge_preserving_corners(2, -point.z)
		3: collider.resize_edge_preserving_corners(3, point.z)
		_:
			if handle_id < 12:
				var corner_index := int((handle_id - 4) / 2)
				var cut := collider.get_corner_cut(corner_index)
				if handle_id % 2 == 0:
					cut.x = point.x + collider.left_extent if corner_index == 0 or corner_index == 3 else collider.right_extent - point.x
					cut.x = maxf(cut.x, 0.01)
				else:
					cut.y = point.z + collider.front_extent if corner_index == 0 or corner_index == 1 else collider.back_extent - point.z
					cut.y = maxf(cut.y, 0.01)
				collider.set_corner_cut(corner_index, cut)
			else:
				var relative := handle_id - CURVE_HANDLE_BASE
				collider.move_curve_point(int(relative / CURVE_HANDLES_PER_CORNER), relative % CURVE_HANDLES_PER_CORNER, Vector2(point.x, point.z))

func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var collider := gizmo.get_node_3d() as CustomShape3D
	var undo_redo := EditorInterface.get_editor_undo_redo()
	if handle_id >= HEIGHT_HANDLE_BASE:
		var original: Vector2 = restore
		var updated := Vector2(collider.height, collider.vertical_offset)
		if cancel:
			collider.height = original.x
			collider.vertical_offset = original.y
			return
		if updated.is_equal_approx(original):
			return
		undo_redo.create_action("Change Custom Collider Height")
		undo_redo.add_do_property(collider, "height", updated.x)
		undo_redo.add_do_property(collider, "vertical_offset", updated.y)
		undo_redo.add_undo_property(collider, "height", original.x)
		undo_redo.add_undo_property(collider, "vertical_offset", original.y)
		undo_redo.commit_action(false)
		return
	if handle_id < 4:
		var updated_state := collider.get_resize_state()
		if cancel:
			collider.restore_resize_state(restore)
			return
		if updated_state == restore:
			return
		undo_redo.create_action("Resize Custom Shape Side")
		undo_redo.add_do_method(collider, "restore_resize_state", updated_state)
		undo_redo.add_undo_method(collider, "restore_resize_state", restore)
		undo_redo.commit_action(false)
		return
	var property_name: String = ""
	if handle_id < 12:
		property_name = CORNER_PROPERTIES[int((handle_id - 4) / 2)]
	else:
		var relative := handle_id - CURVE_HANDLE_BASE
		property_name = collider.get_curve_property_name(int(relative / CURVE_HANDLES_PER_CORNER), relative % CURVE_HANDLES_PER_CORNER)
	var edited_value: Variant = collider.get(property_name)
	if cancel:
		collider.set(property_name, restore)
		return
	if edited_value == restore:
		return
	undo_redo.create_action("Resize Custom Shape Collider")
	undo_redo.add_do_property(collider, property_name, edited_value)
	undo_redo.add_undo_property(collider, property_name, restore)

	undo_redo.commit_action(false)

func _mouse_on_edit_plane(node: CustomShape3D, camera: Camera3D, screen_pos: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var local_origin := node.to_local(origin)
	var local_direction := node.to_local(origin + direction) - local_origin
	if absf(local_direction.y) < 0.00001:
		return null
	var t := (node.vertical_offset - local_origin.y) / local_direction.y
	if t < 0.0:
		return null
	return local_origin + local_direction * t

func _mouse_on_vertical_axis(node: CustomShape3D, camera: Camera3D, screen_pos: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var local_origin := node.to_local(origin)
	var local_direction := node.to_local(origin + direction) - local_origin
	var handle_x := (node.right_extent - node.left_extent) * 0.5
	var handle_z := (node.back_extent - node.front_extent) * 0.5
	var planar_length := local_direction.x * local_direction.x + local_direction.z * local_direction.z
	if planar_length < 0.0000001:
		return null
	var ray_t := ((handle_x - local_origin.x) * local_direction.x + (handle_z - local_origin.z) * local_direction.z) / planar_length
	if ray_t < 0.0:
		return null
	return local_origin.y + local_direction.y * ray_t
