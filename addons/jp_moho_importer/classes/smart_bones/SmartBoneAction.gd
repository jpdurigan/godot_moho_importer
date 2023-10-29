# Resource for handling actions of a SmartBone. It binds a SmartBone rotation to any kind of
# transformation that can be animated.
# Action data structure
#{
#	"name": "Bone_Angle",
#	"pose": {
#		"type": "Val",
#		"ref": false,
#		"mute": false,
#		"when": [ ],
#		"val": [ ],
#		"interp": [ { interp } ]
#	}
#}
tool
class_name SmartBoneAction
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const SMART_BONE_TRACK_PATH = ".:angle"

#--- public variables - order: export > normal var > onready --------------------------------------

# Name of the action
export var name : String
# Maps a SmartBone angle to a specfic time on the Animation.
export var bindings : Dictionary
export var animation : Animation

#--- private variables - order: export > normal var > onready -------------------------------------

var _animators : Dictionary
var _registered_elements := []

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

# Updates action based on SmartBone rotation.
func update(smart_bone: Bone2D) -> void:
	if not is_instance_valid(smart_bone) or not _animators.has(smart_bone.get_instance_id()):
		return
	
	var time : float
	var angle_value = smart_bone.rotation
	angle_value = clamp(angle_value, bindings.keys().min(), bindings.keys().max())
	var lower_angle = _get_lower_boundary(angle_value)
	var upper_angle = _get_upper_boundary(angle_value)
	
	if lower_angle == upper_angle:
		time = bindings[lower_angle]
	else:
		var lower_time = bindings[lower_angle]
		var upper_time = bindings[upper_angle]
		
		var weight = inverse_lerp(lower_angle, upper_angle, angle_value)
		time = lerp(lower_time, upper_time, weight)
	
	var animator : AnimationPlayer = _animators[smart_bone.get_instance_id()]
	animator.seek(time, true)


# Sets SmartBone and AnimationPlayer references for updating. Must be called before updating.
func initialize_action(smart_bone: Bone2D, force_animation_update: bool = false) -> bool:
	var has_initialized : bool = false
	var animator : AnimationPlayer = smart_bone.get_node_or_null(name) as AnimationPlayer
	if animator == null:
		push_error(
			"Couldn't find AnimationPlayer for action %s on SmartBone %s"
			% [name, smart_bone.name]
		)
		return has_initialized
	
	var animation_name : String = get_animation_name()
	if not animator.has_animation(animation_name) or force_animation_update:
		animator.add_animation(animation_name, animation)
	animator.assigned_animation = animation_name
	_animators[smart_bone.get_instance_id()] = animator
	
	has_initialized = true
	return has_initialized


func terminate_action(smart_bone: Bone2D) -> void:
	if _animators.has(smart_bone.get_instance_id()):
		_animators.erase(smart_bone.get_instance_id())


# Queues a MohoRigElement to bind in the action.
func register_rig_element(
		element: MohoRigElement,
		property: String,
		action_data: Dictionary
) -> void:
	var new_rig = {
		element = element,
		property = property,
		action_data = action_data
	}
	_registered_elements.append(new_rig)


# Creates Animation resource for binding.
func set_bindings(verbose: bool = false) -> void:
	var action_owner : Dictionary = _get_action_owner()
	if action_owner.empty():
		push_error(
			"Couldn't find action owner for SmartBoneAction %s | Registered elements: %s"
			% [name, _registered_elements]
		)
		return
	
	if verbose:
		print("\nInitializing action %s" % [name])
	
	# Clear data dictionary
	bindings = {}
	
	# Set SmartBone node reference
	var smart_bone : MohoBone = action_owner["element"] as MohoBone
	var bone : Bone2D = smart_bone.node as Bone2D
	
	# Add AnimationPlayer and Animation to help binding
	var animation_player = AnimationPlayer.new()
	bone.add_child(animation_player)
	animation_player.owner = bone.owner
	animation_player.name = name
	
	animation = Animation.new()
	var animation_name = get_animation_name()
	animation_player.add_animation(animation_name, animation)
	animation_player.assigned_animation = animation_name
	
	# Parse pose data into Animation tracks
	for element_dict in _registered_elements:
		var element := element_dict["element"] as MohoRigElement
		var property = element_dict["property"]
		var action_data = element_dict["action_data"]
		element.parse_action(
			animation_player,
			animation,
			property,
			action_data["pose"],
			verbose
		)
	
	# Get list of keyframes time
	var bone_track_idx = animation.find_track(SMART_BONE_TRACK_PATH)
	if bone_track_idx < 0:
		push_error("Couldn't find bone track on animation")
		return
	
	var key_count = animation.track_get_key_count(bone_track_idx)
	for key_idx in key_count:
		var key_time = animation.track_get_key_time(bone_track_idx, key_idx)
		var key_value = animation.track_get_key_value(bone_track_idx, key_idx)
		bindings[key_value] = key_time
	
	var animation_length = bindings.values().max()
	animation.remove_track(bone_track_idx)
	animation.length = animation_length
	
	bone.actions.append(self)
	_registered_elements.clear()


# Returns the default animation name.
func get_animation_name() -> String:
	return "SmartBoneAction_%s" % [name]

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _get_lower_boundary(value: float) -> float:
	var lower_value = -INF
	
	for angle in bindings.keys():
		if angle <= value and angle > lower_value:
			lower_value = angle
	
	return lower_value


func _get_upper_boundary(value: float) -> float:
	var upper_value = INF
	
	for angle in bindings.keys():
		if angle >= value and angle < upper_value:
			upper_value = angle
	
	return upper_value


func _get_action_owner() -> Dictionary:
	var action_owner := {}
	for rig_element in _registered_elements:
		if rig_element.element is MohoBone and rig_element.element.name == name:
			action_owner = rig_element
			break

	return action_owner


### -----------------------------------------------------------------------------------------------
