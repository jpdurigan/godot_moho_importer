# Write your doc string for this file here
tool
extends EditorInspectorPlugin

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const UI_PLUGIN_SCENE = preload("res://addons/jpd.moho_importer/fix_interpolation/FixInterpolation.tscn")

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func can_handle(object: Object) -> bool:
	var can_handle : bool = object is AnimationTree and not object.anim_player.is_empty()
	return can_handle


func parse_begin(object: Object) -> void:
	var inspector_control = UI_PLUGIN_SCENE.instance()
	add_custom_control(inspector_control)
	inspector_control.animation_tree = object

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
