@tool
extends CollisionShape3D
class_name CustomShape3D

const MAX_CORNER_FACES := 16
const DEFAULT_CUT := Vector2(0.1, 0.1)
const X_NEIGHBORS := [1, 0, 3, 2]
const Z_NEIGHBORS := [3, 2, 1, 0]

const CURVE_PROPERTIES := [
	"_fl_extra_1", "_fl_extra_2", "_fr_extra_1", "_fr_extra_2",
	"_br_extra_1", "_br_extra_2", "_bl_extra_1", "_bl_extra_2"
]
const EXTRA_CURVE_PROPERTIES := [
	"_fl_extra_more", "_fr_extra_more", "_br_extra_more", "_bl_extra_more"
]

const RESIZE_PROPERTIES := [
	"left_extent", "right_extent", "front_extent", "back_extent",
	"front_left_cut", "front_right_cut", "back_right_cut", "back_left_cut",
	"_fl_extra_1", "_fl_extra_2", "_fr_extra_1", "_fr_extra_2",
	"_br_extra_1", "_br_extra_2", "_bl_extra_1", "_bl_extra_2",
	"_fl_extra_more", "_fr_extra_more", "_br_extra_more", "_bl_extra_more"
]

var _suspend_rebuild := false
var _rebuild_queued := false
var _invalid_shape_reported := false

@export var show_collision_preview := false:
	set(value):
		show_collision_preview = value
		if Engine.is_editor_hint() and is_inside_tree():
			update_gizmos()

@export_group("Dimensions")
@export_range(0.05, 100.0, 0.01, "or_greater") var left_extent := 1.0:
	set(value):
		left_extent = maxf(value, 0.05)
		_rebuild()

@export_range(0.05, 100.0, 0.01, "or_greater") var right_extent := 1.0:
	set(value):
		right_extent = maxf(value, 0.05)
		_rebuild()

@export_range(0.05, 100.0, 0.01, "or_greater") var front_extent := 1.0:
	set(value):
		front_extent = maxf(value, 0.05)
		_rebuild()

@export_range(0.05, 100.0, 0.01, "or_greater") var back_extent := 1.0:
	set(value):
		back_extent = maxf(value, 0.05)
		_rebuild()

@export_range(0.01, 10.0, 0.01, "or_greater") var height := 0.15:
	set(value):
		height = maxf(value, 0.01)
		_rebuild()

@export var vertical_offset := 0.0:
	set(value):
		vertical_offset = value
		_rebuild()

@export_category("Corner Faces")
## 0 disables the cut, 1 makes a straight edge, 2–16 add curve segments
@export_range(0, 16, 1) var front_left_faces: int = 0:
	set(value):
		var count := clampi(value, 0, MAX_CORNER_FACES)
		_prepare_corner_face_change(0, front_left_faces, count)
		front_left_faces = count
		_rebuild()

@export_range(0, 16, 1) var front_right_faces: int = 0:
	set(value):
		var count := clampi(value, 0, MAX_CORNER_FACES)
		_prepare_corner_face_change(1, front_right_faces, count)
		front_right_faces = count
		_rebuild()

@export_range(0, 16, 1) var back_right_faces: int = 0:
	set(value):
		var count := clampi(value, 0, MAX_CORNER_FACES)
		_prepare_corner_face_change(2, back_right_faces, count)
		back_right_faces = count
		_rebuild()

@export_range(0, 16, 1) var back_left_faces: int = 0:
	set(value):
		var count := clampi(value, 0, MAX_CORNER_FACES)
		_prepare_corner_face_change(3, back_left_faces, count)
		back_left_faces = count
		_rebuild()

@export_group("Corner Cuts")
## X is the distance along X; Y is the distance along Z
@export var front_left_cut := Vector2.ZERO:
	set(value):
		front_left_cut = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		_rebuild()

@export var front_right_cut := Vector2.ZERO:
	set(value):
		front_right_cut = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		_rebuild()

@export var back_right_cut := Vector2.ZERO:
	set(value):
		back_right_cut = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		_rebuild()

@export var back_left_cut := Vector2.ZERO:
	set(value):
		back_left_cut = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		_rebuild()

# Saved offsets for the first two curve points
@export_storage var _fl_extra_1: Vector2 = Vector2.ZERO:
	set(value):
		_fl_extra_1 = value
		_rebuild()
@export_storage var _fl_extra_2: Vector2 = Vector2.ZERO:
	set(value):
		_fl_extra_2 = value
		_rebuild()
@export_storage var _fr_extra_1: Vector2 = Vector2.ZERO:
	set(value):
		_fr_extra_1 = value
		_rebuild()
@export_storage var _fr_extra_2: Vector2 = Vector2.ZERO:
	set(value):
		_fr_extra_2 = value
		_rebuild()
@export_storage var _br_extra_1: Vector2 = Vector2.ZERO:
	set(value):
		_br_extra_1 = value
		_rebuild()
@export_storage var _br_extra_2: Vector2 = Vector2.ZERO:
	set(value):
		_br_extra_2 = value
		_rebuild()
@export_storage var _bl_extra_1: Vector2 = Vector2.ZERO:
	set(value):
		_bl_extra_1 = value
		_rebuild()
@export_storage var _bl_extra_2: Vector2 = Vector2.ZERO:
	set(value):
		_bl_extra_2 = value
		_rebuild()

# Saved offsets for the remaining curve points
@export_storage var _fl_extra_more: PackedVector2Array = PackedVector2Array():
	set(value):
		_fl_extra_more = value
		_rebuild()
@export_storage var _fr_extra_more: PackedVector2Array = PackedVector2Array():
	set(value):
		_fr_extra_more = value
		_rebuild()
@export_storage var _br_extra_more: PackedVector2Array = PackedVector2Array():
	set(value):
		_br_extra_more = value
		_rebuild()
@export_storage var _bl_extra_more: PackedVector2Array = PackedVector2Array():
	set(value):
		_bl_extra_more = value
		_rebuild()

func _ready() -> void:
	_rebuild()

func _exit_tree() -> void:
	_rebuild_queued = false

func get_top_y() -> float:
	return vertical_offset + height * 0.5

func get_bottom_y() -> float:
	return vertical_offset - height * 0.5

func set_vertical_bounds(top_y: float, bottom_y: float) -> void:
	if top_y - bottom_y < 0.01:
		return
	_suspend_rebuild = true
	height = top_y - bottom_y
	vertical_offset = (top_y + bottom_y) * 0.5
	_suspend_rebuild = false
	_rebuild()

func _stored_corner_cut(index: int) -> Vector2:
	match index:
		0: return front_left_cut
		1: return front_right_cut
		2: return back_right_cut
		3: return back_left_cut
	return Vector2.ZERO

func _clear_corner_edits(index: int) -> void:
	set(CURVE_PROPERTIES[index * 2], Vector2.ZERO)
	set(CURVE_PROPERTIES[index * 2 + 1], Vector2.ZERO)
	set(EXTRA_CURVE_PROPERTIES[index], PackedVector2Array())

func get_corner_edit_state(index: int) -> Dictionary:
	var extra: PackedVector2Array = get(EXTRA_CURVE_PROPERTIES[index])
	return {
		"faces": get_corner_faces(index),
		"cut": _stored_corner_cut(index),
		"first": get(CURVE_PROPERTIES[index * 2]),
		"second": get(CURVE_PROPERTIES[index * 2 + 1]),
		"extra": extra.duplicate()
	}

func restore_corner_edit_state(index: int, state: Dictionary) -> void:
	var was_suspended := _suspend_rebuild
	_suspend_rebuild = true
	match index:
		0: front_left_faces = state["faces"]
		1: front_right_faces = state["faces"]
		2: back_right_faces = state["faces"]
		3: back_left_faces = state["faces"]
	set_corner_cut(index, state["cut"])
	set(CURVE_PROPERTIES[index * 2], state["first"])
	set(CURVE_PROPERTIES[index * 2 + 1], state["second"])
	set(EXTRA_CURVE_PROPERTIES[index], state["extra"])
	_suspend_rebuild = was_suspended
	_rebuild()

func _prepare_corner_face_change(index: int, old_faces: int, new_faces: int) -> void:
	if old_faces == new_faces or not is_inside_tree():
		return

	var was_suspended := _suspend_rebuild
	_suspend_rebuild = true
	if new_faces == 0:
		set_corner_cut(index, Vector2.ZERO)
		_clear_corner_edits(index)
	elif old_faces == 0:
		_clear_corner_edits(index)
		var cut := _stored_corner_cut(index)
		if cut.x <= 0.0001 or cut.y <= 0.0001:
			set_corner_cut(index, DEFAULT_CUT)
	else:
		_resample_corner_edits(index, old_faces, new_faces)
	_suspend_rebuild = was_suspended

func get_corner_cut(index: int) -> Vector2:
	if get_corner_faces(index) == 0:
		return Vector2.ZERO
	var cut := _stored_corner_cut(index)
	var opposite_x := int(X_NEIGHBORS[index])
	var opposite_z := int(Z_NEIGHBORS[index])
	var other_x := _stored_corner_cut(opposite_x) if get_corner_faces(opposite_x) > 0 else Vector2.ZERO
	var other_z := _stored_corner_cut(opposite_z) if get_corner_faces(opposite_z) > 0 else Vector2.ZERO
	return Vector2(
		clampf(cut.x, 0.0, maxf(left_extent + right_extent - other_x.x - 0.005, 0.0)),
		clampf(cut.y, 0.0, maxf(front_extent + back_extent - other_z.y - 0.005, 0.0))
	)

func set_corner_cut(index: int, cut: Vector2) -> void:
	match index:
		0: front_left_cut = cut
		1: front_right_cut = cut
		2: back_right_cut = cut
		3: back_left_cut = cut

func get_corner_faces(index: int) -> int:
	match index:
		0: return front_left_faces
		1: return front_right_faces
		2: return back_right_faces
		3: return back_left_faces
	return 1

func get_curve_property_name(corner_index: int, inner_index: int) -> String:
	if inner_index < 2:
		return CURVE_PROPERTIES[corner_index * 2 + inner_index]
	return EXTRA_CURVE_PROPERTIES[corner_index]

func get_curve_adjustment(corner_index: int, inner_index: int) -> Vector2:
	var property_name := get_curve_property_name(corner_index, inner_index)
	if inner_index < 2:
		return get(property_name)
	var edits: PackedVector2Array = get(property_name)
	var array_index := inner_index - 2
	return edits[array_index] if array_index < edits.size() else Vector2.ZERO

func set_curve_adjustment(corner_index: int, inner_index: int, adjustment: Vector2) -> void:
	var property_name := get_curve_property_name(corner_index, inner_index)
	if inner_index < 2:
		set(property_name, adjustment)
		return
	var edits: PackedVector2Array = get(property_name)
	edits = edits.duplicate()
	var array_index := inner_index - 2
	if edits.size() <= array_index:
		edits.resize(array_index + 1)
	edits[array_index] = adjustment
	set(property_name, edits)

# Keep curve edits when changing the segment count
func _resample_corner_edits(corner_index: int, old_faces: int, new_faces: int) -> void:
	var original: Array[Vector2] = [Vector2.ZERO]
	for i in range(old_faces - 1):
		original.append(get_curve_adjustment(corner_index, i))
	original.append(Vector2.ZERO)
	var resampled: Array[Vector2] = []
	for i in range(new_faces - 1):
		var scaled_t := float(i + 1) * float(old_faces) / float(new_faces)
		var left_index := mini(int(floorf(scaled_t)), old_faces - 1)
		var fraction := scaled_t - float(left_index)
		resampled.append(original[left_index].lerp(original[left_index + 1], fraction))

	var was_suspended := _suspend_rebuild
	_suspend_rebuild = true
	for i in range(resampled.size()):
		set_curve_adjustment(corner_index, i, resampled[i])
	_suspend_rebuild = was_suspended

func _corner_geometry(index: int) -> PackedVector2Array:
	var cut := get_corner_cut(index)
	match index:
		0:
			return PackedVector2Array([
				Vector2(-left_extent, -front_extent),
				Vector2(-left_extent, -front_extent + cut.y),
				Vector2(-left_extent + cut.x, -front_extent)
			])
		1:
			return PackedVector2Array([
				Vector2(right_extent, -front_extent),
				Vector2(right_extent - cut.x, -front_extent),
				Vector2(right_extent, -front_extent + cut.y)
			])
		2:
			return PackedVector2Array([
				Vector2(right_extent, back_extent),
				Vector2(right_extent, back_extent - cut.y),
				Vector2(right_extent - cut.x, back_extent)
			])
		3:
			return PackedVector2Array([
				Vector2(-left_extent, back_extent),
				Vector2(-left_extent + cut.x, back_extent),
				Vector2(-left_extent, back_extent - cut.y)
			])
	return PackedVector2Array()

func get_curve_point(corner_index: int, inner_index: int) -> Vector2:
	var geometry := _corner_geometry(corner_index)
	var cut := get_corner_cut(corner_index)
	var faces := get_corner_faces(corner_index)
	var corner := geometry[0]
	var first := geometry[1]
	var last := geometry[2]
	var center := first + last - corner
	var angle := PI * 0.5 * float(inner_index + 1) / float(faces)
	var base := center + (first - center) * cos(angle) + (last - center) * sin(angle)
	var adjustment := get_curve_adjustment(corner_index, inner_index)
	return base + adjustment * cut

func get_shape_outline(override_corner: int = -1, override_inner: int = -1, override_adjustment: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for corner_index in range(4):
		var geometry := _corner_geometry(corner_index)
		var corner := geometry[0]
		var cut := get_corner_cut(corner_index)
		if cut.x <= 0.0001 or cut.y <= 0.0001:
			outline.append(corner)
			continue
		outline.append(geometry[1])
		for inner_index in range(get_corner_faces(corner_index) - 1):
			var point := get_curve_point(corner_index, inner_index)
			if corner_index == override_corner and inner_index == override_inner:
				point += (override_adjustment - get_curve_adjustment(corner_index, inner_index)) * cut
			outline.append(point)
		outline.append(geometry[2])
	return outline

func move_curve_point(corner_index: int, inner_index: int, target: Vector2) -> void:
	if inner_index >= get_corner_faces(corner_index) - 1:
		return
	var cut := get_corner_cut(corner_index)
	if cut.x <= 0.0001 or cut.y <= 0.0001:
		return
	target.x = clampf(target.x, -left_extent + 0.001, right_extent - 0.001)
	target.y = clampf(target.y, -front_extent + 0.001, back_extent - 0.001)
	var before := get_curve_adjustment(corner_index, inner_index)
	var point := get_curve_point(corner_index, inner_index)
	var desired := before + Vector2((target.x - point.x) / cut.x, (target.y - point.y) / cut.y)
	if _is_shape_outline_valid(get_shape_outline(corner_index, inner_index, desired)):
		set_curve_adjustment(corner_index, inner_index, desired)
		return

	# Stop before the outline crosses itself
	var lower := 0.0
	var upper := 1.0
	for iteration in range(16):
		var middle := (lower + upper) * 0.5
		var candidate := before.lerp(desired, middle)
		if _is_shape_outline_valid(get_shape_outline(corner_index, inner_index, candidate), false):
			lower = middle
		else:
			upper = middle
	if lower > 0.0001:
		var accepted := before.lerp(desired, lower)
		if _is_shape_outline_valid(get_shape_outline(corner_index, inner_index, accepted)):
			set_curve_adjustment(corner_index, inner_index, accepted)

func _is_shape_outline_valid(outline: PackedVector2Array, check_triangulation: bool = true) -> bool:
	var count := outline.size()
	if count < 3:
		return false
	var signed_twice_area := 0.0
	for i in range(count):
		var a := outline[i]
		var b := outline[(i + 1) % count]
		if a.distance_squared_to(b) < 0.000001:
			return false
		signed_twice_area += a.cross(b)
	if signed_twice_area <= 0.00001:
		return false
	for i in range(count):
		var a := outline[i]
		var b := outline[(i + 1) % count]
		for j in range(i + 1, count):
			if j == i + 1 or (i == 0 and j == count - 1):
				continue
			var c := outline[j]
			var d := outline[(j + 1) % count]
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return false
	if check_triangulation:
		return not Geometry2D.triangulate_polygon(outline).is_empty()
	return true

func _is_shape_outline_convex(outline: PackedVector2Array) -> bool:
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var c := outline[(i + 2) % outline.size()]
		if (b - a).cross(c - b) < -0.000000001:
			return false
	return true

func _rebuild() -> void:
	if not is_inside_tree() or _suspend_rebuild or is_queued_for_deletion():
		return
	if not _rebuild_queued:
		_rebuild_queued = true
		_apply_rebuild.call_deferred()
	if Engine.is_editor_hint():
		update_gizmos()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _invalid_shape_reported:
		warnings.append("The shape outline is invalid. Collision is disabled until the shape is fixed.")
	return warnings

func _clear_invalid_shape(message: String) -> void:
	# Setting shape to null also clears the remaining shapes in its owner.
	if shape != null:
		shape = null
	if not _invalid_shape_reported:
		push_warning("CustomShape3D: " + message + " Collision was cleared.")
		_invalid_shape_reported = true
		if Engine.is_editor_hint():
			update_configuration_warnings()

func _apply_rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree() or _suspend_rebuild or is_queued_for_deletion():
		return
	var outline := get_shape_outline()
	if not _is_shape_outline_valid(outline):
		_clear_invalid_shape("Invalid shape outline.")
		return
	var polygons: Array[PackedVector2Array] = []
	if _is_shape_outline_convex(outline):
		polygons.append(outline)
	else:
		polygons = Geometry2D.decompose_polygon_in_convex(outline)
		if polygons.is_empty():
			var indices := Geometry2D.triangulate_polygon(outline)
			for i in range(0, indices.size(), 3):
				polygons.append(PackedVector2Array([
					outline[indices[i]], outline[indices[i + 1]], outline[indices[i + 2]]
				]))
	if polygons.is_empty():
		_clear_invalid_shape("Failed to decompose shape outline.")
		return
	var solids: Array[ConvexPolygonShape3D] = []
	for polygon in polygons:
		if polygon.size() < 3:
			continue
		var twice_area := 0.0
		for i in range(polygon.size()):
			twice_area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
		if absf(twice_area) < 0.000001:
			continue
		solids.append(_make_prism(polygon))
	if solids.is_empty():
		_clear_invalid_shape("No usable convex pieces were generated.")
		return

	if _invalid_shape_reported:
		_invalid_shape_reported = false
		if Engine.is_editor_hint():
			update_configuration_warnings()
	# Replacing the main shape also clears the other shapes in its owner
	shape = solids[0]
	_add_remaining_shapes(solids)
	if Engine.is_editor_hint():
		update_gizmos()

func _make_prism(outline: PackedVector2Array) -> ConvexPolygonShape3D:
	var vertices := PackedVector3Array()
	for p in outline:
		vertices.append(Vector3(p.x, get_bottom_y(), p.y))
		vertices.append(Vector3(p.x, get_top_y(), p.y))
	var prism := ConvexPolygonShape3D.new()
	prism.resource_local_to_scene = true
	prism.points = vertices
	return prism

func _add_remaining_shapes(solids: Array[ConvexPolygonShape3D]) -> void:
	var body := get_parent() as CollisionObject3D
	if body == null:
		return

	# Share the main shape owner so transforms and disabling work normally
	for owner_id in body.get_shape_owners():
		if body.shape_owner_get_owner(owner_id) == self:
			for i in range(1, solids.size()):
				body.shape_owner_add_shape(owner_id, solids[i])
			return

	push_warning("Could not find the shape owner for CustomShape3D.")

func get_resize_state() -> Dictionary:
	var state := {}
	for name in RESIZE_PROPERTIES:
		var v: Variant = get(name)
		state[name] = v.duplicate() if v is PackedVector2Array else v
	return state

func restore_resize_state(state: Dictionary) -> void:
	_suspend_rebuild = true
	for name in RESIZE_PROPERTIES:
		if state.has(name):
			set(name, state[name])
	_suspend_rebuild = false
	_rebuild()

func resize_edge_preserving_corners(edge_index: int, requested_extent: float) -> void:
	var original_state := get_resize_state()
	var extents := [left_extent, right_extent, front_extent, back_extent]
	var old_extent: float = extents[edge_index]
	var new_extent := maxf(requested_extent, 0.05)
	if absf(old_extent - new_extent) < 0.000001:
		return
	var saved_points: Array = []
	for corner_index in range(4):
		var positions: Array[Vector2] = []
		for inner_index in range(get_corner_faces(corner_index) - 1):
			positions.append(get_curve_point(corner_index, inner_index))
		saved_points.append(positions)
	var delta := new_extent - old_extent
	_suspend_rebuild = true
	match edge_index:
		0:
			left_extent = new_extent
			if front_left_faces > 0:
				front_left_cut.x = maxf(0.01, front_left_cut.x + delta)
			if back_left_faces > 0:
				back_left_cut.x = maxf(0.01, back_left_cut.x + delta)
		1:
			right_extent = new_extent
			if front_right_faces > 0:
				front_right_cut.x = maxf(0.01, front_right_cut.x + delta)
			if back_right_faces > 0:
				back_right_cut.x = maxf(0.01, back_right_cut.x + delta)
		2:
			front_extent = new_extent
			if front_left_faces > 0:
				front_left_cut.y = maxf(0.01, front_left_cut.y + delta)
			if front_right_faces > 0:
				front_right_cut.y = maxf(0.01, front_right_cut.y + delta)
		3:
			back_extent = new_extent
			if back_left_faces > 0:
				back_left_cut.y = maxf(0.01, back_left_cut.y + delta)
			if back_right_faces > 0:
				back_right_cut.y = maxf(0.01, back_right_cut.y + delta)

	# Leave curve points in place until the edge catches up
	for corner_index in range(4):
		var cut := get_corner_cut(corner_index)
		if cut.x < 0.0001 or cut.y < 0.0001:
			continue
		for inner_index in range(get_corner_faces(corner_index) - 1):
			var target: Vector2 = saved_points[corner_index][inner_index]
			target.x = clampf(target.x, -left_extent + 0.002, right_extent - 0.002)
			target.y = clampf(target.y, -front_extent + 0.002, back_extent - 0.002)
			var current := get_curve_point(corner_index, inner_index)
			var edit := get_curve_adjustment(corner_index, inner_index)
			set_curve_adjustment(corner_index, inner_index, edit + Vector2(
				(target.x - current.x) / cut.x, (target.y - current.y) / cut.y
			))

	# Pull overlapping points back toward the default arc
	if not _is_shape_outline_valid(get_shape_outline()):
		var requested_edits: Array = []
		for corner_index in range(4):
			var edits: Array[Vector2] = []
			for i in range(get_corner_faces(corner_index) - 1):
				edits.append(get_curve_adjustment(corner_index, i))
				set_curve_adjustment(corner_index, i, Vector2.ZERO)
			requested_edits.append(edits)
		if _is_shape_outline_valid(get_shape_outline()):
			var lo := 0.0
			var hi := 1.0
			for _trial in range(12):
				var mid := (lo + hi) * 0.5
				for corner_index in range(4):
					for i in range(get_corner_faces(corner_index) - 1):
						set_curve_adjustment(corner_index, i, requested_edits[corner_index][i] * mid)
				if _is_shape_outline_valid(get_shape_outline(), false):
					lo = mid
				else:
					hi = mid
			for corner_index in range(4):
				for i in range(get_corner_faces(corner_index) - 1):
					set_curve_adjustment(corner_index, i, requested_edits[corner_index][i] * lo)

	_suspend_rebuild = false
	if not _is_shape_outline_valid(get_shape_outline()):
		restore_resize_state(original_state)
		return
	_rebuild()

