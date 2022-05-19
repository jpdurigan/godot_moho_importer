# Base resource for Moho imported rig elements. This class has some commum methods to help parsing
# Moho data as well as some virtual methods that should be especific for each type of element.
# There are four classes that extend this: MohoSkeleton, MohoBone, MohoSprite and MohoSwitch.
tool
class_name MohoRigElement
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

signal action_register(element, property, action_data)

#--- enums ----------------------------------------------------------------------------------------

# List of possible track type and track interpolation combinations.
enum TrackType {
	ERROR,
	UNKNOWN,
	VALUE_LINEAR, # Step, Linear, Ease
	VALUE_CUBIC, # Smooth
	BEZIER, # Bezier
}

# List of Moho interpolation keyframes types. Their index match Moho's Interpolation modes values.
enum MohoInterp {
	LINEAR,
	SMOOTH,
	EASE,
	STEP,
	NOISY,
	CYCLE,
	POSE,
	EASE_IN,
	EASE_OUT,
	BEZIER,
	BOUNCE,
	ELASTIC,
}

#--- constants ------------------------------------------------------------------------------------

# In Moho animation data, frame 0 values must be interpreted as rest pose values.
const POSE_FRAME = 0

# Easing values for Animation value tracks.
const EASE = {
	LINEAR = 1.0,
	STEP = 0.0,
	EASE_IN = -2.25,
	EASE_OUT = -1.75,
	EASE_IN_OUT = -3.15,
	EASE_OUT_IN = -0.5,
}

# An Array of type exceptions in animations. Currently using it to separate dimensions in Vector2
# tracks (this is mandatory for bezier tracks and when position is animated by more than one track).
const TYPE_EXCEPTIONS = ["Vec2", "Vec3"]

const SmartBoneAction = "res://addons/jpd.moho_importer/classes/smart_bones/SmartBoneAction.gd"

#--- public variables - order: export > normal var > onready --------------------------------------

# Name of the element. Will also be the name of the node linked to this resource.
var name : String
# Node2D linked to this resource.
var node : Node2D

# Transform2D used to transform Moho's coordinate system to Godot's.
var viewport_transform : Transform2D
# Frames per second, defined by Moho's project settings.
var fps : float

# Array of MohoRigElement resources, children of this element
var layers : Array

#--- private variables - order: export > normal var > onready -------------------------------------

# Dictionary containing raw data from Moho's class.
var _raw_data : Dictionary

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func get_class() -> String:
	return "MohoRigElement"


func is_class(p_class: String) -> bool:
	return p_class == get_class() or .is_class(p_class)

### -----------------------------------------------------------------------------------------------

### Virtual Methods --------------------------------------------------------------------------------
# These methods are meant to be extended when creating a new class for the MohoImporterPlugin.

# Returns the raw value dictionary of a given property at a given frame index.
func _get_raw_property(key: String) -> Dictionary:
	push_error("Get raw property method should be extended! Class: %s" % [get_class()])
	return {}


# Returns an array of properties keys that could be animated.
func _get_animated_properties() -> Array:
	push_error("Get animated properties method should be extended! Class: %s" % [get_class()])
	return []


# Returns the bone's parent at the given frame index. The index returned refers to the skeleton
# bones array. -1 means bone's parent is the skeleton.
func get_parent_index(val_index: int = POSE_FRAME) -> int:
	push_error("Get parent index method should be extended! Class: %s" % [get_class()])
	return -1


### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

# Parse animation keyframes for this element into the given Animation, if there's any.
func parse_animation(animator: AnimationPlayer, animation: Animation, verbose := false) -> void:
#	printt("Parsing animation at", get_class(), name, _get_animated_properties())
	for property in _get_animated_properties():
		if _is_property_animated(property):
			# Check for interpolation mismatches and get TrackType
			var animation_data = _get_raw_property(property)
			_parse_animation_data(animator, animation, property, animation_data, verbose)
		
		if _has_property_action(property):
			_handle_action(property)


# Adds track and keyframes on the given Animation for the given pose data.
# Used to parse SmartBoneAction bindings.
func parse_action(
		animator: AnimationPlayer,
		animation: Animation,
		property: String,
		pose_data: Dictionary,
		verbose: bool = false
) -> void:
	_parse_animation_data(animator, animation, property, pose_data, verbose)


# Returns an Array of layer data (as Dictionaries).
func get_layers() -> Array:
	if not _raw_data.has("layers"):
		return []
	
	return _raw_data["layers"]


# Returns the node target for binding this element to a Bone.
func get_remote_target() -> Node2D:
	return node

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

# Property Parsing --------------------------------------------------------------------------------

# Returns the value of a given property at a given frame index,
# properly converted to Godot variable types.
# Frame index is the index of a keyframe/value in Moho's raw data.
func _get_property(key: String, val_index: int = POSE_FRAME):
	var subkey := _get_subproperty(key)
	if not subkey.empty():
		key = _get_main_property(key)
#		print("||| Found subkey | key = %s | subkey = %s" % [key, subkey])
	
	var raw_property = _get_raw_property(key)
	var raw_value = raw_property["val"][val_index]
	var value = _format_property(key, raw_value)
	
	if not subkey.empty():
		value = value[subkey]
#		print("||| Got subproperty %s : %s" % [subkey, value])
	
	return value


# Formats Moho's raw value into proper Godot's variable type.
func _format_property(key: String, raw_value):
	var value = null
	match key:
		"anim_pos", "translation":
			if raw_value is Dictionary:
				value = _convert_position(_dict_to_vec2(raw_value))
		"anim_scale", "scale":
			if raw_value is Dictionary:
				value = _dict_to_vec2(raw_value)
			elif raw_value is float:
				# Scaling a bone in Moho should only affect the X axis
				value = Vector2(raw_value, 1.0)
		"anim_angle", "rotation_z", "rotation":
			if raw_value is float:
				value = _convert_rotation(raw_value)
		"anim_parent", "target_bone":
			if raw_value is float:
				value = int(raw_value)
			elif raw_value is int:
				value = raw_value
		"flip_h":
			if raw_value is bool:
				if key in node:
					value = raw_value
				else:
					value = Vector2(-1, 1) if raw_value else Vector2(1, 1)
		"flip_v":
			if raw_value is bool:
				if key in node:
					value = raw_value
				else:
					value = Vector2(1, -1) if raw_value else Vector2(1, 1)
		"switch_keys":
			if raw_value is String:
				value = raw_value
		_:
			push_error(
				"Format error: unknown key %s | at %s %s"
				% [key, get_class(), name]
			)
			return value
	
	if value == null:
		push_error(
			"Format error: unknown type for property %s | raw value: %s | type: %s | at %s %s" 
			% [key, raw_value, typeof(raw_value), get_class(), name]
		)
	
	return value


# Returns a property path translated from Moho's naming conventions to Godot's.
func _translate_property(property_path: String) -> String:
	var subpath := _get_subproperty(property_path)
	if not subpath.empty():
		property_path = _get_main_property(property_path)
#		print("||| Found subkey | key = %s | subkey = %s" % [property_path, subpath])
	
	var property := ""
	match property_path:
		"anim_pos", "translation":
			property = "position"
		"anim_scale", "scale":
			property = "scale"
		"anim_angle":
			if _has_property_action(property_path):
				property = "angle"
			else:
				property = "rotation"
		"rotation_z":
			property = "rotation"
		"flip_h", "flip_v":
			if property_path in node:
				property = property_path
			else:
				property = "scale"
		"switch_keys":
			property = "key"
		_:
			push_error("Unknown property: %s | Couldn't translate"% [property_path])
	
	if not subpath.empty():
		property += ":" + subpath
	
	return property


# Returns the given position (in Moho's coordinate system) transformed into a local position
# for this element's node.
func _convert_position(value: Vector2) -> Vector2:
	return viewport_transform.basis_xform(value)


func _convert_length(value: float) -> float:
	var lenght_vec = Vector2(value, 0)
	return _convert_position(lenght_vec).x


func _convert_rotation(value: float) -> float:
	return value * -1


# Converts a frame number into its time in seconds.
# This is used while parsing keyframes: Moho saves keyframe placement based on frame number,
# but we need it as a time measurement in Godot.
func _convert_frame(frame: float) -> float:
	var time = frame / fps
	# The first frame is an exception, we need it to be in the very beggining of the animation
	if frame <= 1:
		time = 0.0
#	print("Converting frame %s to time: %s s" % [frame, time])
	return time


# Converts a dictionary with x and y keys into a Vector2.
func _dict_to_vec2(dict: Dictionary) -> Vector2:
	return Vector2(dict.x, dict.y)


# Returns the main property of a concatened property path.
func _get_main_property(property: String) -> String:
	var main_property := property
	if property.split(":").size() > 1:
		main_property = property.split(":")[0]
	return main_property


# Returns the subproperty of a concatened property path.
func _get_subproperty(property: String) -> String:
	var subproperty := ""
	if property.split(":").size() > 1:
		subproperty = property.split(":")[1]
	return subproperty


### -----------------------------------------------------------------------------------------------

# Animation Parsing -------------------------------------------------------------------------------
# Animation data structure:
#{
#	"type": "Val",
#	"ref": false,
#	"mute": false,
#	"when": [ ],
#	"val": [ ],
#	"interp": [ { interp } ]
#}

# Returns a TrackType value for the given interpolation type from Moho.
# Compatibles types are grouped together.
# Raises an error if the type is unknown or unsupported.
func _get_track_type_for_frame(interpolation_type: int) -> int:
	var track_type : int = TrackType.UNKNOWN
	
	match interpolation_type:
		MohoInterp.LINEAR, MohoInterp.EASE, MohoInterp.EASE_IN, MohoInterp.EASE_OUT, \
		MohoInterp.STEP:
			track_type = TrackType.VALUE_LINEAR
		MohoInterp.SMOOTH:
			track_type = TrackType.VALUE_CUBIC
		MohoInterp.BEZIER:
			track_type = TrackType.BEZIER
		MohoInterp.BOUNCE, MohoInterp.CYCLE, MohoInterp.ELASTIC, MohoInterp.NOISY, \
		MohoInterp.POSE:
			track_type = TrackType.ERROR
			var interpolation_name: String = MohoInterp.keys()[interpolation_type]
			push_error("Moho Interpolation mode %s isn't supported" % [interpolation_name])
		_:
			track_type = TrackType.ERROR
			push_error("Unknown Moho Interpolation mode: %s" % [interpolation_type])
	
	return track_type


# Returns a TrackType value for the given animation data.
# Raises an error if keyframes interpolation types are incompatible.
func _get_track_type(animation_data: Dictionary) -> int:
	var track_type = TrackType.UNKNOWN
	var frame_count := _get_frame_count(animation_data)
	
	# Deals with exceptions, such as bone with independent angle 
	if frame_count == 1:
		var interp_type : int = _get_interpolation_type(animation_data, POSE_FRAME)
		track_type = _get_track_type_for_frame(interp_type)
		return track_type
	
	for idx in range(frame_count):
		if idx == POSE_FRAME:
			continue
		
		var interp_type : int = _get_interpolation_type(animation_data, idx)
		var new_track_type = _get_track_type_for_frame(interp_type)
		if new_track_type <= TrackType.UNKNOWN:
			return new_track_type
		
		if track_type == TrackType.UNKNOWN:
			track_type = new_track_type
		if track_type != new_track_type:
			push_error("Incompatible interpolation types on track: %s x %s" % [
				TrackType.keys()[track_type], TrackType.keys()[new_track_type]
			])
			push_warning(
				"This track will be imported as VALUE_LINEAR type and " +
				"result may differ from the original."
			)
			return TrackType.VALUE_LINEAR
	
	return track_type


# Creates and initialize a track in the given Animation, with the given TrackType setting.
# Returns the created track index. See TrackType enum for settings.
func _initialize_track(
		animation: Animation,
		track_type: int,
		verbose: bool = false
) -> int:
	var track_idx : int
	
	match track_type:
		TrackType.VALUE_LINEAR:
			track_idx = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_LINEAR)
		TrackType.VALUE_CUBIC:
			track_idx = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_CUBIC)
		TrackType.BEZIER:
			track_idx = animation.add_track(Animation.TYPE_BEZIER)
	
	if verbose:
		print("| Created track type %s" % [TrackType.keys()[track_type]])
	
	return track_idx


# Adds animation data as a animated track into the given Animation.
# Handles bezier subproperties path and exceptions.
func _parse_animation_data(
		animator: AnimationPlayer,
		animation: Animation,
		property_path: String,
		animation_data: Dictionary,
		verbose: bool = false
) -> void:
	# Check for interpolation mismatches and get TrackType
	var track_type : int = _get_track_type(animation_data)
	if track_type <= TrackType.UNKNOWN:
		return
	
	if animation_data["type"] in TYPE_EXCEPTIONS:
		match animation_data["type"]:
			"Vec2", "Vec3":
				var subproperties = [ property_path + ":x", property_path + ":y" ]
				for subproperty in subproperties:
					_parse_animated_property(
						animator,
						animation,
						subproperty,
						animation_data,
						track_type,
						verbose
					)
			_:
				push_error("Unknown bezier exception: %s" % [animation_data["type"]])
	else:
		_parse_animated_property(
			animator,
			animation,
			property_path,
			animation_data,
			track_type,
			verbose
		)


# Adds track and keyframes on the given Animation for the given property.
func _parse_animated_property(
		animator: AnimationPlayer,
		animation: Animation,
		property_path: String,
		animation_data: Dictionary,
		track_type: int,
		verbose: bool = false
) -> void:
	# Add property track to animation
	if verbose:
		print(
			"\nAdding track for %s %s property : %s"
			% [get_class(), name, property_path]
		)
	
	var track_path = "%s:%s" % [
		animator.get_parent().get_path_to(node),
		_translate_property(property_path)
	]
	var track_idx : int = animation.find_track(track_path)
	var has_track : bool = track_idx > -1
	if has_track:
		push_error(
			"Animation already has track %s. Skipping property: %s"
			% [track_path, property_path]
		)
		return
	else:
		track_idx = _initialize_track(animation, track_type, verbose)
		animation.track_set_path(track_idx, track_path)
		animation.track_set_interpolation_loop_wrap(track_idx, false)
	
	var last_value = null
	var value_has_changed = false
	
	# Parse keyframes
	for idx in _get_frame_count(animation_data):
		var time = _get_frame_time(animation_data, idx)
		var value = _get_frame_value(animation_data, property_path, idx)
		
		if last_value == null:
			last_value = value
		elif not value_has_changed:
			value_has_changed = last_value != value
			last_value = value
		
		match animation.track_get_type(track_idx):
			Animation.TYPE_VALUE:
				animation.track_insert_key(track_idx, time, value)
			Animation.TYPE_BEZIER:
				animation.bezier_track_insert_key(track_idx, time, value)
		
		if verbose:
			print("| Added keyframe at %0.2fs : %s" % [time, value])
	
	# If there is no change in the track, we remove it
	if _should_remove_track(property_path, value_has_changed):
		animation.remove_track(track_idx)
		return
	
	# Parse keyframe interpolation/easing
	match track_type:
		TrackType.VALUE_LINEAR:
			_handle_value_interpolation(animation, animation_data, track_idx, verbose)
		TrackType.BEZIER:
			_handle_bezier_interpolation(animation, animation_data, track_idx, verbose)


# By default, we delete tracks whose values don't change. "anim_angle" is an exception:
# even if bone is not animated, we want it's rest pose set in the animation.
func _should_remove_track(property: String, value_has_changed: bool) -> bool:
	var is_rotation_property = property == "anim_angle"
	var should_remove = not is_rotation_property and not value_has_changed 
	return should_remove


# Returns the time of a given keyframe.
# Frame index is the index of a keyframe/value in Moho's raw data.
func _get_frame_time(animation_data: Dictionary, val_index: int = POSE_FRAME) -> float:
	var raw_value = animation_data["when"][val_index]
	var value = _convert_frame(raw_value)
#	print("Got frame %s : %s" % [key, value])
	
	return value


# Returns the value of a property in a given keyframe.
# Frame index is the index of a keyframe/value in Moho's raw data.
func _get_frame_value(animation_data: Dictionary, key: String, val_index: int):
	var subkey := _get_subproperty(key)
	if not subkey.empty():
		key = _get_main_property(key)
#		print("||| Found subkey | key = %s | subkey = %s" % [key, subkey])
	
	var raw_value = animation_data["val"][val_index]
	var value = _format_property(key, raw_value)
#	print("Got property %s : %s" % [key, value])
	
	if not subkey.empty():
		value = value[subkey]
#		print("||| Got subproperty %s : %s" % [subkey, value])
	
	return value


# Returns the number of keyframes in the animation data.
func _get_frame_count(animation_data: Dictionary) -> int:
	return animation_data["when"].size()


# Returns if the property is animated (has more than one keyframe). "anim_angle" is an exception:
# even if bone is not animated, we want it's rest pose set in the animation.
func _is_property_animated(key: String) -> bool:
	if key == "anim_angle":
		return true
	key = _get_main_property(key)
	var animation_data = _get_raw_property(key)
	return _get_frame_count(animation_data) > 1


### -----------------------------------------------------------------------------------------------

# Interpolation Parsing ---------------------------------------------------------------------------

# Returns the interpolation data (as Dictionary) of a given keyframe.
func _get_interpolation_data(animation_data: Dictionary, val_index: int) -> Dictionary:
	var interp_data : Dictionary = animation_data["interp"][val_index]
	return interp_data


# Returns the interpolation type of a given keyframe. See MohoInterp enum for known values.
func _get_interpolation_type(animation_data: Dictionary, val_index: int) -> int:
	var interp_data = _get_interpolation_data(animation_data, val_index)
	var interp_type = int(interp_data["im"])
	if animation_data["type"] == "String" or animation_data["type"] == "Bool":
		interp_type = MohoInterp.STEP
	
	return interp_type


# Adds easing to a Animation value track.
func _handle_value_interpolation(
		animation: Animation,
		animation_data: Dictionary,
		track_idx: int,
		verbose: bool = false
) -> void:
	for idx in _get_frame_count(animation_data):
		var easing = EASE.LINEAR
		var interp_type : int = _get_interpolation_type(animation_data, idx)
		match interp_type:
			MohoInterp.LINEAR:
				pass
			MohoInterp.EASE:
				easing = EASE.EASE_IN_OUT
			MohoInterp.EASE_IN:
				easing = EASE.EASE_IN
			MohoInterp.EASE_OUT:
				easing = EASE.EASE_OUT
			MohoInterp.STEP:
				easing = EASE.STEP
			_:
				push_error(
					"Invalid interpolation type: %s"%[MohoInterp.keys()[interp_type]] +
					" on %s %s" % [get_class(), name] +
					" | The result animation will differ from the original."
				)
		
		var key_index = _get_proper_key_idx(animation, animation_data, track_idx, idx)
		animation.track_set_key_transition(track_idx, key_index, easing)
		if verbose:
			var easing_type = EASE.keys()[EASE.values().find(easing)]
			print("| Set keyframe #%s interpolation : %s" % [key_index, easing_type])


# Sets handle values to a Animation bezier track.
func _handle_bezier_interpolation(
		animation: Animation,
		animation_data: Dictionary,
		track_idx: int,
		verbose: bool = false
) -> void:
	var max_key_idx = animation.track_get_key_count(track_idx)
	
	for idx in _get_frame_count(animation_data):
		if idx >= max_key_idx:
			continue
		
		var interp_type : int = _get_interpolation_type(animation_data, idx)
		if interp_type != MohoInterp.BEZIER:
			push_error(
				"Invalid interpolation type %s in bezier track"%[MohoInterp.keys()[interp_type]] +
				" on %s %s" % [get_class(), name] +
				" | Skipping keyframe."
			)
			continue
		
		var bezier_data := _get_bezier_data(animation_data, idx)
#		print("Frame %s | Bezier data: %s" % [idx, bezier_data])
		
		var key_out_idx = _get_proper_key_idx(animation, animation_data, track_idx, idx)
		var key_in_idx = key_out_idx + 1

		if key_in_idx >= max_key_idx:
			continue
		
		var key_out_time = animation.track_get_key_time(track_idx, key_out_idx)
		var key_in_time = animation.track_get_key_time(track_idx, key_in_idx)
#		printt("time | out:", key_out_time, "| in:", key_in_time)
		
		var interp_length = key_in_time - key_out_time
		
		var bezier_out = _get_bezier_out_handle(bezier_data, interp_length)
		var bezier_in = _get_bezier_in_handle(bezier_data, interp_length)
		
		animation.bezier_track_set_key_out_handle(track_idx, key_out_idx, bezier_out)
		animation.bezier_track_set_key_in_handle(track_idx, key_in_idx, bezier_in)
		
		if verbose:
			print("| Set keyframe #%s bezier out : %s" % [key_out_idx, bezier_out])
			print("| Set keyframe #%s bezier in : %s" % [key_in_idx, bezier_in])


# Returns the proper key index for a given value index in animation data.
# This is needed when the first keyframe (usually rest post) is overrided by a keyframe in index 1:
# their index in animation data do not match the keyframe index in the Animation resource.
func _get_proper_key_idx(
		animation: Animation,
		animation_data: Dictionary,
		track_idx: int,
		val_idx: int
) -> int:
	var time = _get_frame_time(animation_data, val_idx)
	var key_idx = animation.track_find_key(track_idx, time, true)
	return key_idx


# Returns bezier data (as Dictionary) for a given keyframe.
func _get_bezier_data(
		animation_data: Dictionary,
		val_index: int,
		subproperty: String = ""
) -> Dictionary:
	var bezier_data : Dictionary = {}
	
	var interp_data = _get_interpolation_data(animation_data, val_index)
	
	match subproperty:
		"", "x":
			bezier_data = interp_data["b"][0]
		"y":
			bezier_data = interp_data["b"][1]
		_:
			push_error("Unknown subproperty: %s | Can't get interpolation data" % subproperty)
	
	return bezier_data


# Returns the bezier in handle (as Vector2) for a given bezier data and its interpolation length
# (distance in seconds between the keyframes).
func _get_bezier_in_handle(bezier_data: Dictionary, interp_length: float) -> Vector2:
	# Get angle and percentage values
	var angle = float(bezier_data["ai"]) * -1
	var percentage = float(bezier_data["pi"])
#	printt("BEZIER IN", angle, String(rad2deg(angle)) + "º", percentage)
	
	var vector_in = _get_bezier_vec(angle, percentage, interp_length)
	# We flip the in handle vector, since it should point the other way
	vector_in *= -1
	
	return vector_in


# Returns the bezier out handle (as Vector2) for a given bezier data and its interpolation length
# (distance in seconds between the keyframes).
func _get_bezier_out_handle(bezier_data: Dictionary, interp_length: float) -> Vector2:
	# Get angle and percentage values
	var angle = float(bezier_data["ao"]) * -1
	var percentage = float(bezier_data["po"])
#	printt("BEZIER OUT", angle, String(rad2deg(angle)) + "º", percentage)
	
	var vector_out = _get_bezier_vec(angle, percentage, interp_length)
	
	return vector_out


# Returns a Vector2 based on an angle, a length and a percentage of that length. This is the way
# Moho saves its handle values: we get the angle of the handle and its projection to the x axis
# of the timeline. This function reverses it.
func _get_bezier_vec(angle: float, percentage: float, interp_length: float) -> Vector2:
	var x = percentage * interp_length
	var y = x * tan(angle)
	return Vector2(x, y)


### -----------------------------------------------------------------------------------------------

# Actions Parsing ---------------------------------------------------------------------------------

# Returns if this element has at least one action in its animated properties.
func _has_actions() -> bool:
	var has_actions := false
	for property in _get_animated_properties():
		if _has_property_action(property):
			has_actions = true
			break
	
	return has_actions


# Returns if this element has actions, given a property.
func _has_property_action(property: String) -> bool:
	property = _get_main_property(property)
	var raw_property = _get_raw_property(property)
	var has_action = raw_property.has("actions")
	return has_action


# Returns a Array of action data Dictionaries for the given the property.
func _get_actions(property: String) -> Array:
	property = _get_main_property(property)
	var raw_property = _get_raw_property(property)
	return raw_property["actions"]


# Binds this element to all SmartBoneActions of the given property.
func _handle_action(property: String) -> void:
	var actions = _get_actions(property)
	for action_data in actions:
		emit_signal("action_register", self, property, action_data)


### -----------------------------------------------------------------------------------------------
