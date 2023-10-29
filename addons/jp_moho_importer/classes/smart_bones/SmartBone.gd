# Class for SmartBones, a Bone2D that has a minimum and maximum constraint and can trigger one or
# more SmartBoneActions (move some Sprite position, change a layer visibility, etc).
# You have to animate the angle property in order to get these effects. For the SmartBoneAction to
# work, there must be a AnimationPlayer node with the action name as a child of the SmartBone.
# You can also use a SmartBone to animate bone scaling and flipping.
tool
class_name SmartBone, "res://addons/jp_moho_importer/components/icon_smart_bone.svg"
extends Bone2D

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const DEBUG_FONT = preload("res://addons/jp_moho_importer/components/opensans_regular_12pt.tres")

#--- public variables - order: export > normal var > onready --------------------------------------

# Inspector handle, can be used to animate manually and test SmartBoneActions.
export(float, 0.0, 1.0) var handle = 0.5 setget _set_handle
# Array of SmartBoneAction type resources
export(Array, Resource) var actions : Array
# SmartBones angles constraints
export var max_constraint : float = 6.283185
export var min_constraint : float = -6.283185

# Alternative way to animate bone scaling and flipping
export var bone_scale : Vector2 = Vector2.ONE setget _set_bone_scale
export var flip_h : bool = false setget _set_flip_h
export var flip_v : bool = false setget _set_flip_v

export var flip_h_animation : bool = false setget _set_flip_h_animation

# If true, this bone's rotation is independent from its parent transform.
# Angle is saved relative to it's parent rest angle.
export var independent_angle : bool = false setget _set_independent_angle
export var parent_rest_angle : float setget _set_parent_rest_angle

# "rotation" by default, "global_rotation" if independent_angle
var rotation_property : String = "rotation"
# "angle" by default, "parent_angle" if SmartBone is animated by another SmartBone
var angle_property : String = "angle"
# "parent_rest_angle" by default, "_flip_h_parent_rest_angle" if flip_h_animation
var parent_angle_property : String = "parent_rest_angle"

# Bone rotation in radians. Updates SmartBoneActions when changed.
var angle : float = 0.0 setget _set_angle
# Same as angle. Used when a SmartBone controls another SmartBone.
var parent_angle : float = 0.0 setget _set_parent_angle

#--- private variables - order: export > normal var > onready -------------------------------------

var _flip_h_parent_rest_angle : float

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready():
	angle = rotation
	parent_angle = rotation
	_set_independent_angle(independent_angle)
	_set_parent_rest_angle(parent_rest_angle)
	
	_init_actions()
	_handle_process()


func _process(_delta):
	if Engine.editor_hint:
		update()
	update_rotation()


func _exit_tree():
	_terminate_actions()


func get_class() -> String:
	return "SmartBone"


func is_class(p_class: String) -> bool:
	return p_class == get_class() or .is_class(p_class)


func _draw():
	if _should_draw_actions_gizmos():
		draw_set_transform_matrix(get_global_transform().inverse())
		for idx in actions.size():
			var action: SmartBoneAction = actions[idx]
			var text = action.name.capitalize().replace(" ", "").replace("Switch", "")
			var text_position = global_position + Vector2(-20, DEBUG_FONT.size * (idx + 1))
			draw_string(DEBUG_FONT, text_position, text, Color.white, 40)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func update_rotation() -> void:
	set(rotation_property, _get_angle_value())


static func flip_h_angle(p_angle: float) -> float:
	var vector := Vector2.RIGHT.rotated(p_angle)
	vector.x *= -1
	return vector.angle()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _get_angle_value() -> float:
	var value = get(angle_property)
	if independent_angle:
		value += get(parent_angle_property)
	if flip_h_animation:
		value = flip_h_angle(value)
	return value


func _has_actions() -> bool:
	return (not actions.empty()) and (get_child_count() >= actions.size())


func _init_actions() -> void:
	var actions_to_erase := []
	
	for idx in actions.size():
		var action : SmartBoneAction = actions[idx]
		var has_initialized := action.initialize_action(self)
		if not has_initialized:
			actions_to_erase.append(action)
	
	for action in actions_to_erase:
		actions.erase(action)


func _update_actions() -> void:
	for idx in actions.size():
		var action : SmartBoneAction = actions[idx]
		action.update(self)


func _terminate_actions() -> void:
	for idx in actions.size():
		var action : SmartBoneAction = actions[idx]
		action.terminate_action(self)


func _update_bone_scale() -> void:
	var scale_to_set = bone_scale
	if flip_h:
		scale_to_set.x *= -1
	if flip_v:
		scale_to_set.y *= -1
	
	scale = scale_to_set


func _handle_process() -> void:
	var should_process = independent_angle or _should_draw_actions_gizmos()
	set_process(should_process)


func _should_draw_actions_gizmos() -> bool:
	var should_draw := (
		Engine.editor_hint
		and _has_actions()
		and is_inside_tree() and get_tree().edited_scene_root == owner
	)
	return should_draw

### Setters --------------------------------------------------------------------------------------

func _set_angle(value: float) -> void:
	value = clamp(value, min_constraint, max_constraint)
	if value == angle:
		return
	angle = value
	angle_property = "angle"
	update_rotation()
	
	if not is_inside_tree():
		yield(self, "ready")
	
	_update_actions()


func _set_parent_angle(value: float) -> void:
	value = clamp(value, min_constraint, max_constraint)
	if value == parent_angle:
		return
	parent_angle = value
	angle_property = "parent_angle"
	update_rotation()
	
	if not is_inside_tree():
		yield(self, "ready")
	
	_update_actions()


func _set_handle(value: float) -> void:
	handle = value
	var angle_value = lerp(min_constraint, max_constraint, value)
	self.angle = angle_value


func _set_bone_scale(value: Vector2) -> void:
	bone_scale = value
	_update_bone_scale()


func _set_flip_h(value: bool) -> void:
	flip_h = value
	_update_bone_scale()


func _set_flip_v(value: bool) -> void:
	flip_v = value
	_update_bone_scale()


func _set_flip_h_animation(value: bool) -> void:
	if value == flip_h_animation:
		return
	
	flip_h_animation = value
	if flip_h_animation:
		parent_angle_property = "_flip_h_parent_rest_angle"
	else:
		parent_angle_property = "parent_rest_angle"


func _set_independent_angle(value: bool) -> void:
	independent_angle = value
	if independent_angle:
		rotation_property = "global_rotation"
	else:
		rotation_property = "rotation"
	_handle_process()


func _set_parent_rest_angle(value: float) -> void:
	parent_rest_angle = value
	_flip_h_parent_rest_angle = flip_h_angle(parent_rest_angle)


### -----------------------------------------------------------------------------------------------
