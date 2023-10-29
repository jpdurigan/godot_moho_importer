# Write your doc string for this file here
extends EditorInspectorPlugin

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const SMART_BONE_HELPER = preload("res://addons/jp_moho_importer/smart_bone_helper/SmartBoneHelper.tscn")

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func can_handle(object: Object) -> bool:
	var can_handle := object is SmartBone
	return can_handle


func parse_begin(object: Object) -> void:
	var inspector_control = SMART_BONE_HELPER.instance()
	add_custom_control(inspector_control)
	inspector_control.smart_bone = object

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
