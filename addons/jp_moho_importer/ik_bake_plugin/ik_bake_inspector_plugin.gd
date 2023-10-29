# Write your doc string for this file here
extends EditorInspectorPlugin

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const IK_BAKE_PLUGIN_SCENE = preload("res://addons/jp_moho_importer/ik_bake_plugin/IkBakePlugin.tscn")

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func can_handle(object: Object) -> bool:
	var can_handle := object is Skeleton2DIK or object is IKBakeHelper
	return can_handle


func parse_begin(object: Object) -> void:
	var inspector_control = IK_BAKE_PLUGIN_SCENE.instance()
	add_custom_control(inspector_control)
	if object is Skeleton2DIK:
		inspector_control.ik = object
	elif object is IKBakeHelper:
		inspector_control.ik_bake_helper = object
	inspector_control.inspector_plugin = self

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func edit_node(node: Node) -> void:
	if not Engine.editor_hint:
		return
	
	if not node.is_inside_tree():
		yield(node, "ready")
	
	var editor_script := EditorScript.new()
	var editor_interface := editor_script.get_editor_interface()
	editor_interface.edit_node(node)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
