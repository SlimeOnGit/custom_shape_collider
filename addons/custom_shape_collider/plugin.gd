@tool
extends EditorPlugin

const CustomShapeGizmo = preload("res://addons/custom_shape_collider/custom_shape_gizmo.gd")
const CustomShape = preload("res://addons/custom_shape_collider/custom_shape_3d.gd")
const FACE_PROPERTIES := [
	"front_left_faces", "front_right_faces", "back_right_faces", "back_left_faces"
]

var _gizmo_plugin: EditorNode3DGizmoPlugin

func _enter_tree() -> void:
	_gizmo_plugin = CustomShapeGizmo.new()
	add_node_3d_gizmo_plugin(_gizmo_plugin)
	add_undo_redo_inspector_hook_callback(_on_inspector_property_changed)

func _exit_tree() -> void:
	remove_undo_redo_inspector_hook_callback(_on_inspector_property_changed)
	remove_node_3d_gizmo_plugin(_gizmo_plugin)
	_gizmo_plugin = null

func _on_inspector_property_changed(undo_redo: Object, modified_object: Object, property: String, new_value: Variant) -> void:
	if not modified_object is CustomShape:
		return

	var corner_index := FACE_PROPERTIES.find(property)
	if corner_index == -1:
		return

	var collider := modified_object as CustomShape3D
	if collider.get_corner_faces(corner_index) == int(new_value):
		return

	var previous_state := collider.get_corner_edit_state(corner_index)
	if undo_redo is EditorUndoRedoManager:
		(undo_redo as EditorUndoRedoManager).add_undo_method(
			collider, "restore_corner_edit_state", corner_index, previous_state
		)
	elif undo_redo is UndoRedo:
		(undo_redo as UndoRedo).add_undo_method(
			collider.restore_corner_edit_state.bind(corner_index, previous_state)
		)
