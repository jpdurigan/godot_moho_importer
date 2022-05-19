# Write your doc string for this file here
tool
extends PanelContainer

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const ANIMATOR_PATH = "AnimationPlayer"
const HELPER_PATH = "IKBakeHelper"

const TARGET_FPS = 60.0
const DEFAULT_MAX_INTERVAL = 1.0 / TARGET_FPS
const DEFAULT_MIN_INTERVAL = DEFAULT_MAX_INTERVAL / 10

const BAKE_MAX_INTERATIONS = 256
const BAKE_DISTANCE_THRESHOLD = 0.000000001

#--- public variables - order: export > normal var > onready --------------------------------------

var ik: Skeleton2DIK = null setget _set_ik
var ik_bake_helper: IKBakeHelper = null setget _set_ik_bake_helper
var inspector_plugin: EditorInspectorPlugin

#--- private variables - order: export > normal var > onready -------------------------------------

var _force_loop: bool = true
var _bake_interval: float = DEFAULT_MIN_INTERVAL

var _iks: Array
var _bones: Array
var _bones_duplicates: Dictionary

var _root_scene: Node2D
var _animator: AnimationPlayer
var _current_animation: Animation

onready var _launch_helper: Button = $Options/LaunchHelper
onready var _options: OptionButton = $Options/Animation/Options
onready var _bake_section: Control = $Options/Bake

onready var _force_loop_button: CheckBox = $Options/Bake/ForceLoop/CheckBox

onready var _simple_interval_section: Control = $Options/Bake/SimpleInterval
onready var _simple_interval_value: SpinBox = $Options/Bake/SimpleInterval/SpinBox

onready var _bake_progress: ProgressBar = $Options/Bake/ProgressBar
onready var _bake_button: Button = $Options/Bake/Button

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready():
	pass

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func bake() -> void:
	_bake_progress.value = 0.0
	_bake_progress.max_value = _current_animation.length
	_bake_progress.show()
	_bake_button.disabled = true
	_apply_rest_recursive(_root_scene)
	
	for idx in _iks.size():
		var skeleton_ik : Skeleton2DIK = _iks[idx]
		var ik_chain := skeleton_ik.ik_chain
		ik_chain.MAX_ITERATIONS = BAKE_MAX_INTERATIONS
		ik_chain.DISTANCE_THRESHOLD = BAKE_DISTANCE_THRESHOLD
		_clear_ik_tracks(skeleton_ik)
	
	for idx in _bones.size():
		var bone : Bone2D = _bones[idx]
		
		var bone_duplicated := bone.duplicate()
		bone_duplicated.name = "%sDUPLICATE" % [bone.name]
		for child in bone_duplicated.get_children():
			bone_duplicated.remove_child(child)
			child.queue_free()
		_bones_duplicates[bone.get_instance_id()] = bone_duplicated
		
		var duplicated_parent := bone.get_parent()
		if duplicated_parent in _bones:
			duplicated_parent = _bones_duplicates[duplicated_parent.get_instance_id()]
		duplicated_parent.add_child(bone_duplicated)
		bone_duplicated.owner = duplicated_parent.owner
		
		_copy_keyframes(bone, bone_duplicated)
		_clear_track(bone)
		
		if bone is SmartBone:
			if bone._has_actions():
				bone.independent_angle = false
			else:
				bone.set_script(null)
	
	var current_time := 0.0
	_animator.seek(current_time, true)
	while current_time <= _current_animation.length:
		_animator.advance(_bake_interval)
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		
		for idx in _iks.size():
			var skeleton_ik : Skeleton2DIK = _iks[idx]
			_add_current_ik_pose_to_animation(skeleton_ik, current_time)
		for idx in _bones.size():
			var bone : Bone2D = _bones[idx]
			var duplicate : Bone2D = _bones_duplicates[bone.get_instance_id()]
			_add_current_pose_to_animation(bone, current_time, duplicate)
		_bake_progress.value = current_time
		
		if current_time < _current_animation.length:
			current_time = min(current_time + _bake_interval, _current_animation.length)
		else:
			if _force_loop:
				for idx in _iks.size():
					var skeleton_ik : Skeleton2DIK = _iks[idx]
					_add_current_ik_pose_to_animation(skeleton_ik, 0.0)
				for idx in _bones.size():
					var bone : Bone2D = _bones[idx]
					var duplicate : Bone2D = _bones_duplicates[bone.get_instance_id()]
					_add_current_pose_to_animation(bone, 0.0, duplicate)
			break
	
	for idx in _iks.size():
		var skeleton_ik : Skeleton2DIK = _iks[idx]
		_format_ik_keyframes(skeleton_ik)
	for idx in _bones.size():
		var bone : Bone2D = _bones[idx]
		_format_keyframes(bone)
		var bone_duplicate : Bone2D = _bones_duplicates[bone.get_instance_id()]
		_clear_track(bone_duplicate)
	
	_bake_button.disabled = false
	_bake_progress.hide()
	if _is_helper() and _animator.get_animation_list().size() == 1:
		for ik in _iks:
			ik.queue_free()
		for bone_duplicate in _bones_duplicates.values():
			bone_duplicate.queue_free()
		ik_bake_helper.queue_free()
	else:
		for idx in _iks.size():
			var skeleton_ik : Skeleton2DIK = _iks[idx]
			var ik_chain := skeleton_ik.ik_chain
			ik_chain.MAX_ITERATIONS = ik_chain.DEFAULT_MAX_INTERATIONS
			ik_chain.DISTANCE_THRESHOLD = ik_chain.DEFAULT_DISTANCE_THRESHOLD
	
	_current_animation.step = DEFAULT_MIN_INTERVAL
	if not _current_animation.resource_path.empty():
		ResourceSaver.save(_current_animation.resource_path, _current_animation)
		
		if _current_animation.resource_path.ends_with(".tres"):
			var resource_path := _current_animation.resource_path.replace(".tres", ".res")
			ResourceSaver.save(resource_path, _current_animation)
			_current_animation.take_over_path(resource_path)


func open() -> void:
	_iks.clear()
	if _is_helper():
		_iks = _get_iks(_root_scene)
		_bones = _get_independent_smart_bones(_root_scene)
	else:
		_iks.append(ik)
	
	_populate_options()
	_bake_section.hide()
	_bake_progress.hide()
	_options.disabled = false
	_bake_button.disabled = false
	
	if _is_helper():
		_launch_helper.hide()
	else:
		_launch_helper.show()
	
	_force_loop_button.pressed = _force_loop
	_simple_interval_value.value = _bake_interval


func close() -> void:
	_clear_and_add_default_option()
	_bake_section.hide()
	_options.disabled = true
	_bake_button.disabled = true

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _clear_track(node: Node2D) -> void:
	var track_idx = _get_track_for(node, false)
	if track_idx >= 0:
		_current_animation.remove_track(track_idx)


func _copy_keyframes(from_node: Node2D, to_node: Node2D) -> void:
	var from_track_id = _get_track_for(from_node, false)
	if from_track_id < 0:
		return
	var to_track_id = _get_track_for(to_node)
	for key_idx in _current_animation.track_get_key_count(from_track_id):
		var key_time = _current_animation.track_get_key_time(from_track_id, key_idx)
		var key_value = _current_animation.track_get_key_value(from_track_id, key_idx)
		var key_transition = _current_animation.track_get_key_transition(from_track_id, key_idx)
		_current_animation.track_insert_key(to_track_id, key_time, key_value, key_transition)


func _add_current_pose_to_animation(node: Node2D, time: float, reference: Node2D = null) -> void:
	if reference == null:
		reference = node
	var track_idx = _get_track_for(node)
	_current_animation.track_insert_key(track_idx, time, _get_current_value(node, reference))


func _format_keyframes(node: Node2D) -> void:
	var track_idx = _get_track_for(node, false)
	for key_idx in _current_animation.track_get_key_count(track_idx):
		if key_idx == 0:
			continue
		
		var value_current  = _current_animation.track_get_key_value(track_idx, key_idx)
		var value_previous = _current_animation.track_get_key_value(track_idx, key_idx - 1)
		
		var value_plus  = value_current + TAU
		var value_minus = value_current - TAU
		
		var dist_value = abs(value_previous - value_current)
		var dist_plus  = abs(value_previous - value_plus)
		var dist_minus = abs(value_previous - value_minus)
		var dist_expected = min(dist_value, min(dist_minus, dist_plus))
		
		match dist_expected:
			dist_value:
				pass # do nothing
			dist_minus:
				_current_animation.track_set_key_value(track_idx, key_idx, value_minus)
			dist_plus:
				_current_animation.track_set_key_value(track_idx, key_idx, value_plus)


func _clear_ik_tracks(skeleton_ik: Skeleton2DIK) -> void:
	var ik_chain := skeleton_ik.ik_chain
	for node in ik_chain.get_nodes():
		if node == skeleton_ik:
			continue
		_clear_track(node)


func _add_current_ik_pose_to_animation(skeleton_ik: Skeleton2DIK, time: float) -> void:
	var ik_chain := skeleton_ik.ik_chain
	for node in ik_chain.get_nodes():
		if node == skeleton_ik:
			continue
		_add_current_pose_to_animation(node, time)


func _format_ik_keyframes(skeleton_ik: Skeleton2DIK) -> void:
	var ik_chain := skeleton_ik.ik_chain
	for node in ik_chain.get_nodes():
		if node == skeleton_ik:
			continue
		_format_keyframes(node)


func _get_current_value(node: Node2D, reference: Node2D = null) -> float:
	if reference == null:
		reference = node
	var value = reference.rotation
	
	if _is_independent_angle(node) and _is_independent_angle(reference):
		value = reference.global_rotation - reference.parent_rest_angle
	return value


func _get_track_for(chain_node: Node2D, should_create_new: bool = true) -> int:
	var property = _get_track_property(chain_node)
	var animator_root := _animator.get_node(_animator.root_node)
	var base_path := animator_root.get_path_to(chain_node)
	var track_node_path := NodePath("%s:%s" % [base_path, property])
	var track_idx := _current_animation.find_track(track_node_path)
	if track_idx == -1 and should_create_new:
		track_idx = _current_animation.add_track(Animation.TYPE_VALUE)
		_current_animation.track_set_path(track_idx, track_node_path)
	return track_idx


func _get_track_property(chain_node: Node2D) -> String:
	var property = "rotation"
	if chain_node is SmartBone:
		property = "angle"
	return property


func _is_independent_angle(node: Node2D) -> bool:
	return node is SmartBone and node.independent_angle


func _populate_options() -> void:
	_clear_and_add_default_option()
	var animation_list := _animator.get_animation_list()
	for anim_name in animation_list:
		_options.add_item(anim_name)


func _clear_and_add_default_option() -> void:
	_options.clear()
	_options.add_item("---", 0)


func _is_helper() -> bool:
	return ik_bake_helper != null


func _launch_helper() -> void:
	var helper : IKBakeHelper = _root_scene.find_node(HELPER_PATH)
	if helper == null:
		helper = IKBakeHelper.new()
		_root_scene.add_child(helper, true)
		helper.name = HELPER_PATH.get_basename()
		helper.owner = _root_scene
	inspector_plugin.call_deferred("edit_node", helper)


func _apply_rest_recursive(node: Node) -> void:
	if node is Bone2D:
		node.apply_rest()
	for child in node.get_children():
		_apply_rest_recursive(child)


func _get_iks(node: Node, p_iks: Array = []) -> Array:
	if node is Skeleton2DIK:
		p_iks.append(node)
	for child in node.get_children():
		_get_iks(child, p_iks)
	return p_iks


func _get_independent_smart_bones(node: Node, p_bones: Array = []) -> Array:
	if _is_independent_angle(node):
		p_bones.append(node)
	for child in node.get_children():
		_get_independent_smart_bones(child, p_bones)
	return p_bones


func _set_ik(p_ik: Skeleton2DIK) -> void:
	ik = p_ik
	
	if not is_inside_tree():
		yield(self, "ready")
	
	_root_scene = ik.owner
	_animator = _root_scene.get_node_or_null(ANIMATOR_PATH)
	if _animator != null:
		open()


func _set_ik_bake_helper(p_helper: IKBakeHelper) -> void:
	ik_bake_helper = p_helper
	
	if not is_inside_tree():
		yield(self, "ready")
	
	_root_scene = ik_bake_helper.owner
	_animator = _root_scene.get_node_or_null(ANIMATOR_PATH)
	if _animator != null:
		open()


func _on_LaunchHelper_pressed():
	_launch_helper()


func _on_Options_item_selected(index: int):
	var selected_animation : String = _options.get_item_text(index)
	if _animator.has_animation(selected_animation):
		_current_animation = _animator.get_animation(selected_animation)
		_animator.assigned_animation = selected_animation
		_bake_section.show()
	else:
		_current_animation = null
		_bake_section.hide()


func _on_Bake_toggled(button_pressed: bool):
	if button_pressed:
		bake()


func _on_simple_interval_SpinBox_value_changed(value: float):
	_bake_interval = value


func _on_ForceLoop_CheckBox_toggled(button_pressed: float):
	_force_loop = button_pressed

### -----------------------------------------------------------------------------------------------
