# Write your doc string for this file here
tool
extends Node

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const DEFAULT_FILE_NAME = "merged_scenes"

#--- public variables - order: export > normal var > onready --------------------------------------

export(Array, String, FILE, "*.tscn") var scene_paths : Array
export var file_name: String = DEFAULT_FILE_NAME

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready():
	if Engine.editor_hint:
		return
	merge()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func merge() -> void:
	var final_scene := Node2D.new()
	final_scene.name = file_name.capitalize().replace(" ", "")
	add_child(final_scene, true)
	
	for scene_path in scene_paths:
		var packed_scene : PackedScene = load(scene_path)
		var scene_merge_from : Node2D = packed_scene.instance()
		add_child(scene_merge_from, true)
		merge_scenes_recursive(final_scene, scene_merge_from)
	
	var final_scene_path = "%s/%s.tscn" % [scene_paths.front().get_base_dir(), file_name]
	var final_scene_packed := PackedScene.new()
	var error = final_scene_packed.pack(final_scene)
	if error != OK:
		push_error("Error while merging scenes: %s" % [error])
	
	ResourceSaver.save(final_scene_path, final_scene_packed)


static func merge_scenes_recursive(
		root_merge_to: Node,
		node_merge_from: Node,
		root_merge_from: Node = null
) -> void:
	if root_merge_from == null:
		root_merge_from = node_merge_from
	
	var node_path = root_merge_from.get_path_to(node_merge_from)
	var node_already_exists = root_merge_to.has_node(node_path)
	if node_already_exists:
		if node_merge_from is AnimationPlayer:
			var animator_merge_to : AnimationPlayer = root_merge_to.get_node(node_path)
			_handle_animation_player(animator_merge_to, node_merge_from)
		
		for child in node_merge_from.get_children():
			merge_scenes_recursive(root_merge_to, child, root_merge_from)
	else:
		var node_parent = node_merge_from.get_parent()
		var parent_path = root_merge_from.get_path_to(node_parent)
		var parent_merge_to = root_merge_to.get_node(parent_path)
		
		var node_merge_to = node_merge_from.duplicate()
		parent_merge_to.add_child(node_merge_to, true)
		set_owner_recursive(node_merge_to, root_merge_to)
		
		# Duplicating an AnimationPlayer node also duplicate its animation resources.
		# We set its animation list again so we get them as external resources (if they are).
		if node_merge_from is AnimationPlayer:
			_handle_animation_player(node_merge_to, node_merge_from, false)


static func set_owner_recursive(node: Node, p_owner: Node = null) -> void:
	if p_owner == null:
		p_owner = node
	if node.owner == null or node.owner != p_owner:
		node.owner = p_owner
	var is_not_packed_scene = node.filename.empty()
	if is_not_packed_scene:
		for child in node.get_children():
			set_owner_recursive(child, p_owner)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

static func _handle_animation_player(
		animator_merge_to: AnimationPlayer,
		animator_merge_from: AnimationPlayer,
		should_show_warning: bool = true
) -> void:
	if not is_instance_valid(animator_merge_from) or not is_instance_valid(animator_merge_to):
		return
	for anim_name in animator_merge_from.get_animation_list():
		if animator_merge_to.has_animation(anim_name) and should_show_warning:
			push_warning(
				"Animation %s already exists in %s. It will be replaced by one found in %s."
				% [anim_name, animator_merge_to, animator_merge_from]
			)
		var animation := animator_merge_from.get_animation(anim_name)
		animator_merge_to.add_animation(anim_name, animation)

### -----------------------------------------------------------------------------------------------
