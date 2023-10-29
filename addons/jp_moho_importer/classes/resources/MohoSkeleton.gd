# Resource for parsing Skeleton (BoneLayer) class data from Moho projects.
# Skeleton raw data structure:
#{
#	type = "BoneLayer",
#	skeleton = {
#		type = "Skeleton"
#		bones = [ { Bone } ]
#	},
#	layers = [ { MeshLayer }, { SwitchLayer } ],
#	name = "name",
#	origin = { x, y },
#	transforms = {
#		translation = {},
#		scale = {},
#		rotation_z = {},
#		flip_h = {},
#		flip_v = {}
#	}
#}
tool
class_name MohoSkeleton
extends MohoRigElement

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

# Array of Bones raw data (Dictionaries)
var bones_data : Array

# Array of MohoBone resources
var bones : Array

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _init(data: Dictionary):
	_raw_data = data
	
	name = _raw_data["name"]
	bones_data = _raw_data["skeleton"]["bones"]


func get_class() -> String:
	return "MohoSkeleton"


func is_class(p_class: String) -> bool:
	return p_class == get_class() or .is_class(p_class)

### -----------------------------------------------------------------------------------------------


### Base Class Methods ----------------------------------------------------------------------------

func _get_raw_property(key: String) -> Dictionary:
	return _raw_data["transforms"][key]


func _get_animated_properties() -> Array:
	return ["translation", "scale", "rotation_z", "flip_h", "flip_v"]


func is_valid_bone_index(index: int) -> bool:
	return (index >= 0 and index < bones.size())

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

# Initializes skeleton's initial position.
func initialize_skeleton(skeleton_node: Skeleton2D, verbose: bool = false) -> void:
	node = skeleton_node
	
	node.name = name
	node.position = _get_property("translation")
	node.scale = _get_property("scale")
	node.rotation = _get_property("rotation_z")
	
	if _get_property("flip_h") != Vector2.ONE:
		node.scale.x *= -1
	if _get_property("flip_v") != Vector2.ONE:
		node.scale.y *= -1
	
	if verbose:
		print("\nInitalized skeleton: %s" % node.name)
		print("| Position: %s" % node.position)
		print("| Scale: %s" % node.scale)
		print("| Rotation: %s" % node.rotation)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
