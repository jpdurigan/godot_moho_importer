# Write your doc string for this file here
tool
extends Control

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

var smart_bone: SmartBone setget _set_smart_bone
var scene_root: Node

#--- private variables - order: export > normal var > onready -------------------------------------

var _selected_action: SmartBoneAction = null

onready var _action_name: LineEdit = $Options/ActionName
onready var _action_create_button: Button = $Options/CreateNewAction
onready var _bone_toggle_process: CheckButton = $Options/ToggleProcess
onready var _action_options: OptionButton = $Options/EditAction/Options
onready var _action_bind_button: Button = $Options/BindCurrentState

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready():
	pass

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func open() -> void:
	_action_create_button.hide()
	_action_bind_button.hide()
	_populate_action_options()
	_bone_toggle_process.set_pressed_no_signal(smart_bone.is_processing())


func save_actions() -> void:
	for idx in smart_bone.actions.size():
		var action : SmartBoneAction = smart_bone.actions[idx]
		_save_action(action)
	smart_bone.property_list_changed_notify()


func create_new_action() -> void:
	var action_name = _action_name.text
	
	# Create SmartBoneAction resource
	var action := SmartBoneAction.new()
	action.name = action_name
	smart_bone.actions.append(action)
	
	# Create AnimationPlayer
	var animation_player = AnimationPlayer.new()
	smart_bone.add_child(animation_player)
	animation_player.owner = smart_bone.owner
	animation_player.name = action_name
	
	# Create Animation
	var animation = Animation.new()
	var animation_name = action.get_animation_name()
	animation_player.add_animation(animation_name, animation)
	animation_player.assigned_animation = animation_name
	action.animation = animation
	
	_save_action(action)
	smart_bone._handle_process()
	_populate_action_options()


func bind_current_state() -> void:
	var current_bone_angle = smart_bone.angle
	var current_animation_time = _selected_action._animator.current_animation_position
	_selected_action.bindings[current_bone_angle] = current_animation_time

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _save_action(action: SmartBoneAction) -> void:
	var animation := action.animation
	_save_resource(animation, _get_action_animation_path(action))
	_save_resource(action, _get_action_resource_path(action))
	action.init(smart_bone, true)


func _get_action_animation_path(action: SmartBoneAction) -> String:
	var proper_name = action.name.replace(" ", "_")
	var path := "%s%s_anim.tres" % [_get_action_base_dir(), proper_name]
	return path


func _get_action_resource_path(action: SmartBoneAction) -> String:
	var proper_name = action.name.replace(" ", "_")
	var path := "%s%s_action.tres" % [_get_action_base_dir(), proper_name]
	return path


func _get_action_base_dir() -> String:
	var base_dir = scene_root.filename.get_base_dir() + "/actions/"
	return base_dir


func _save_resource(resource: Resource, resource_path: String) -> void:
	var base_dir := resource_path.get_base_dir()
	var dir := Directory.new()
	if not dir.dir_exists(base_dir):
		dir.make_dir_recursive(base_dir)
	
	ResourceSaver.save(resource_path, resource)
	resource.take_over_path(resource_path)


func _populate_action_options() -> void:
	_action_options.clear()
	for idx in smart_bone.actions.size():
		var action : SmartBoneAction = smart_bone.actions[idx]
		_action_options.add_item(action.name)
	_on_Options_item_selected(0)


func _set_smart_bone(p_bone: SmartBone) -> void:
	smart_bone = p_bone
	scene_root = smart_bone.owner
	
	if not is_inside_tree():
		yield(self, "ready")
	
	open()


func _on_SaveActions_pressed():
	save_actions()


func _on_ActionName_text_changed(new_text: String):
	_action_create_button.visible = not new_text.empty()


func _on_CreateNewAction_pressed():
	create_new_action()


func _on_ToggleProcess_toggled(button_pressed: bool):
	smart_bone.set_process(button_pressed)


func _on_Options_item_selected(index: int):
	if index >= smart_bone.actions.size():
		_selected_action = null
	else:
		_selected_action = smart_bone.actions[index]
	_action_bind_button.visible = is_instance_valid(_selected_action)


func _on_BindCurrentState_pressed():
	bind_current_state()

### -----------------------------------------------------------------------------------------------
