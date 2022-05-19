# Resource for parsing GroupLayer data from Moho projects.
# On Sprites, Group and SwitchLayers, we set their global Transform properties (position,
# rotation and scale).
# GroupLayer raw data structure:
#{
#	type = "GroupLayer",
#	name = "name",
#	group_mask = int,
#	layers = [ { MeshLayer }, { ImageLayer } ],
#	origin = { x, y },
#	parent_bone = int,
#	transforms = {
#		translation = {},
#		scale = {},
#		rotation_z = {},
#		flip_h = {},
#		flip_v = {}
#	}
#}
class_name MohoGroup
extends MohoRigElement

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

# List of Moho Group mask types. Their index match Moho's group mask constants.
enum GroupMask {
	NONE,
	SHOW_ALL,
	HIDE_ALL,
}

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _init(data: Dictionary):
	_raw_data = data
	
	name = _raw_data["name"]


func get_class() -> String:
	return "MohoGroup"


func is_class(p_class: String) -> bool:
	return p_class == get_class() or .is_class(p_class)

### -----------------------------------------------------------------------------------------------


### Base Class Methods ----------------------------------------------------------------------------

func _get_raw_property(key: String) -> Dictionary:
	return _raw_data["transforms"][key]


func _get_animated_properties() -> Array:
	return ["translation", "scale", "rotation_z", "flip_h", "flip_v"]


func get_parent_index(_val_index: int = POSE_FRAME) -> int:
	return _raw_data["parent_bone"]

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

# Initializes SwitchLayer's initial properties.
func initialize_group_layer(group_node: Node2D, verbose: bool = false) -> void:
	node = group_node
	layers.clear()
	
	node.name = name
	node.position = _get_property("translation")
	node.scale = _get_property("scale")
	node.rotation = _get_property("rotation_z")
	
	if _get_property("flip_h") != Vector2.ONE:
		node.scale.x *= -1
	if _get_property("flip_v") != Vector2.ONE:
		node.scale.y *= -1
	
	if verbose:
		print("\nInitalized group layer: %s" % node.name)
		print("| Position: %s" % node.position)
		print("| Scale: %s" % node.scale)
		print("| Rotation: %s" % node.rotation)


func has_mask() -> bool:
	var group_mask = int(_raw_data["group_mask"])
	return group_mask != GroupMask.NONE

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
