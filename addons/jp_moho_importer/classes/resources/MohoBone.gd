# Resource for parsing Bone class data from Moho projects
# Bone raw data structure:
#{
#	type = "Bone",
#	name = "name",
#	parent = int,
#	length = float,
#	constrains = bool,
#	min_constraint = float,
#	max_constraint = float,
#	anim_pos = { animation },
#	anim_angle = { animation },
#	anim_scale = { animation },
#	flip_h = { animation },
#	flip_v = { animation },
#	target_bone = { animation },
#	anim_parent = { animation },
#}
tool
class_name MohoBone
extends MohoRigElement

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

var skeleton : MohoSkeleton
var is_smart_bone : bool = false
var is_independent_angle : bool = false

# Dictionary used when animating reparents. Its keys are the parent index and values are
# RemoteTransform2D nodes that need to be turned on/off.
var parent_remotes : Dictionary

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _init(data: Dictionary):
	_raw_data = data
	
	name = _raw_data["name"]


func get_class() -> String:
	return "MohoBone"


func is_class(p_class: String) -> bool:
	return p_class == get_class() or .is_class(p_class)

### -----------------------------------------------------------------------------------------------


### Base Class Methods ----------------------------------------------------------------------------

func _get_raw_property(key: String) -> Dictionary:
	return _raw_data[key]


func _get_animated_properties() -> Array:
	return ["anim_pos", "anim_scale", "anim_angle", "flip_h", "flip_v", "anim_parent"]


func get_parent_index(val_index: int = POSE_FRAME) -> int:
	return _get_property("anim_parent", val_index)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

# Initializes bone's initial properties and rest pose.
func initialize_bone(bone_node: Bone2D, verbose : bool = false) -> void:
	node = bone_node
	
	node.name = name
	node.position = _get_property("anim_pos")
	node.scale = _get_property("anim_scale")
	node.rotation = _get_property("anim_angle")
	
	var flip_h = _get_property("flip_h")
	if flip_h is bool and "flip_h" in node:
		node.flip_h = flip_h
	elif flip_h is Vector2 and flip_h != Vector2.ONE:
		node.scale.x *= -1
	
	var flip_v = _get_property("flip_v")
	if flip_v is bool and "flip_v" in node:
		node.flip_v = flip_v
	elif flip_v is Vector2 and flip_v != Vector2.ONE:
		node.scale.y *= -1
	
	var length = _raw_data["length"]
	node.default_length = _convert_length(length)
	node.rest = node.get_transform()
	
	var has_constraints = _has_constraints()
	if has_constraints:
		node.min_constraint = node.rotation - _raw_data["max_constraint"]
		node.max_constraint = node.rotation - _raw_data["min_constraint"]
	
	is_independent_angle = _has_independent_angle()
	if is_independent_angle:
		node.independent_angle = true
		node.parent_rest_angle = node.get_parent().global_rotation
		node.angle = _get_property("anim_angle")
	
	if verbose:
		print("Initalized bone: %s" % node.name)
		print("| Position: %s" % node.position)
		print("| Scale: %s" % node.scale)
		print("| Rotation: %s" % node.rotation)
		print("| Length: %s" % node.default_length)
		if has_constraints:
			print("| Constrains | min: %s | max: %s"%[node.min_constraint, node.max_constraint])
		if is_independent_angle:
			print("| Independent angle: %s" % node.independent_angle)


func should_be_smart_bone() -> bool:
	is_smart_bone = (
		_has_constraints() or
		_has_actions() or
		_has_scale_and_flip_animation() or
		_has_independent_angle()
	)
	return is_smart_bone


# Returns true if the bone's parent has been animated.
func is_reparented() -> bool:
	return _is_property_animated("anim_parent")


func handle_ik_chain(ik_preference: int, verbose: bool = false) -> void:
	# Handle target bone
	var target_bone = _get_property("target_bone")
	var has_target_bone = skeleton.is_valid_bone_index(target_bone)
	if has_target_bone:
		if verbose:
			print("| Adding Skeleton2DIK to Bone %s" % [name])
		var skeleton2dik = Skeleton2DIK.new()
		node.add_child(skeleton2dik)
		node.move_child(skeleton2dik, 0)
		skeleton2dik.owner = node.owner
		skeleton2dik.name = "%sIK" % [name]
		skeleton2dik.preference = ik_preference
		
		var target = skeleton.bones[target_bone].node
		skeleton2dik.target_node_path = skeleton2dik.get_path_to(target)
	
	if is_ik_chain_root():
		_make_ik_chain(verbose)


# Returns true if this MohoBone is a IK chain root.
# We check that by searching its children and making sure it's a chain of single Bone2D children.
func is_ik_chain_root() -> bool:
	var is_ik_chain := false
	var is_already_in_chain = node.has_meta("_edit_bone_")
	if is_already_in_chain:
		return is_ik_chain
	
	is_ik_chain = (
		not _has_independent_angle() and
		_has_bone_children(node) and 
		_is_single_bone_chain(node)
	)
	
	return is_ik_chain


# Returns an Array of all possible parent indexs (int) on the current animation.
func get_parents_index() -> Array:
	var parents := []
	var property = "anim_parent"
	var animation_data = _get_raw_property(property)
	
	for idx in _get_frame_count(animation_data):
		var parent_idx : int = _get_frame_value(animation_data, property, idx)
		if not parent_idx in parents:
			parents.append(parent_idx)
	
	return parents


func register_remote(parent_idx: int, remote_transform: RemoteTransform2D) -> void:
	parent_remotes[parent_idx] = remote_transform

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _has_bone_children(bone2d: Bone2D) -> bool:
	var has_bone_children := false
	
	for child in bone2d.get_children():
		if child is Bone2D:
			has_bone_children = true
			break
	
	return has_bone_children


func _is_single_bone_chain(bone2d: Bone2D) -> bool:
	var is_single_bone_chain := true
	var bone_child : Bone2D = null
	
	for child in bone2d.get_children():
		if not child is Bone2D:
			continue
		
		if bone_child != null:
			is_single_bone_chain = false
			break
		
		bone_child = child
	
	if is_single_bone_chain and bone_child != null:
		is_single_bone_chain = _is_single_bone_chain(bone_child)
	
	return is_single_bone_chain


func _make_ik_chain(verbose: bool = false) -> void:
	if verbose:
		print("| Initing IK chain on Bone %s" % name)
	node.set_meta("_edit_ik_", true)
	_make_custom_bones_on_chain(node, verbose)


# Sets custom bone property on Bone2D and all of its Bone2D children.
func _make_custom_bones_on_chain(bone2d: Bone2D, verbose: bool = false) -> void:
	if verbose:
		print("| Making custom bones on Bone %s" % bone2d.name)
	bone2d.set_meta("_edit_bone_", true)
	for child in bone2d.get_children():
		if child.is_class("SmartBone") and child.independent_angle:
			continue
		if child is Bone2D:
			_make_custom_bones_on_chain(child)


func _has_constraints() -> bool:
	return _raw_data["constraints"]


func _has_independent_angle() -> bool:
	return _raw_data["fixed_angle"]


# Since Bone2D doesn't have a flip property, we need to flip it using scale.
# If only a single property of these three is animated, it controls scale property and works fine.
# Otherwise, we need the node to be a SmartBone and use its scaling/flipping properties.
func _has_scale_and_flip_animation() -> bool:
	return (
		int(_is_property_animated("anim_scale"))
		+ int(_is_property_animated("flip_h"))
		+ int(_is_property_animated("flip_v")) > 1
	)


func _is_property_animated(key: String) -> bool:
	if is_independent_angle and key == "anim_angle":
		return true
	return ._is_property_animated(key)


# Override translate property so that we set bone_scale instead of scale on SmartBones
func _translate_property(property_path: String) -> String:
	var property := ._translate_property(property_path)
	
	if node.is_class("SmartBone"):
		if "rotation" in property:
			property = property.replace("rotation", "angle")
		if "scale" in property:
			property = property.replace("scale", "bone_scale")
	
	return property


# Override so that we can handle reparenting animation in a different method.
func _parse_animation_data(
		animator: AnimationPlayer,
		animation: Animation,
		property_path: String,
		animation_data: Dictionary,
		verbose: bool = false
) -> void:
	if "anim_parent" in property_path:
		_parse_reparenting_animation(animator, animation, property_path, animation_data, verbose)
	else:
		._parse_animation_data(animator, animation, property_path, animation_data, verbose)


# Adds reparenting animation. Its main difference from other property animations is that we're
# parsing keyframes into multiple tracks (as many possible parents as the bone have). Also, for each
# RemoteTransform2D that controls this bone, we need three tracks, because we need to turn on/off
# all three update properties.
func _parse_reparenting_animation(
		animator: AnimationPlayer,
		animation: Animation,
		property_path: String,
		animation_data: Dictionary,
		verbose: bool = false
) -> void:
	# Add property track to animation
	if verbose:
		print(
			"\nAdding track for %s %s property : %s"
			% [get_class(), name, property_path]
		)
	
	var properties_to_set = ["update_position", "update_rotation", "update_scale"]
	
	# Loop in every RemoteTransform that controls this bone
	for parent_idx in parent_remotes.keys():
		var parent_remote : RemoteTransform2D = parent_remotes[parent_idx]
		for property in properties_to_set:
			# Create track with Nearest interpolation
			var track_idx = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)
			var track_path = "%s:%s" % [
				animator.get_parent().get_path_to(parent_remote),
				property
			]
			animation.track_set_path(track_idx, track_path)
			if verbose:
				print("| Added track for RemoteTransform %s" % [track_path])
			
			# Parse keyframes
			for idx in _get_frame_count(animation_data):
				# "anim_parent" property gives us the parent_idx of the current active remote.
				# We check if it's the same index as the remote we're dealing with and that is
				# the value we pass on to the property.
				var time = _get_frame_time(animation_data, idx)
				var key_parent_idx = _get_frame_value(animation_data, property_path, idx)
				var is_active = parent_idx == key_parent_idx
				
				animation.track_insert_key(track_idx, time, is_active)
				if verbose:
					print("| | Added keyframe at %0.2fs : %s" % [time, is_active])

### -----------------------------------------------------------------------------------------------
