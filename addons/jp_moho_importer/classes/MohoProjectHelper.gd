# Handles a single project import, creating and initializing resources and nodes needed. This is
# instanciated by MohoImporter and it enters Godot's editor tree as a child of the EditorPlugin.
# It serves as a centralizing unit, so that all Moho resources handling stays on this script.
tool
class_name MohoProjectHelper
extends Node

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const ICON_PLACEHOLDER_PATH = "res://addons/jp_moho_importer/components/godot-icon.png"

#--- public variables - order: export > normal var > onready --------------------------------------

# Base Transform2D that transforms from Moho's coordinate system into Godot's.
var viewport_transform : Transform2D
# Reference to the 2D scene this instance is editing
var editing_scene : Node2D

# Array of MohoSkeletons resources
var skeletons : Array
# Array of MohoSprites resources
var sprites : Array
# Array of MohoGroups resources
var groups : Array
# Array of MohoSwitches resources
var switches : Array
# Dictionary of SmartBoneAction resources. Each key maps a action name to its resource.
var actions : Dictionary

#--- private variables - order: export > normal var > onready -------------------------------------

# Raw project data
var _raw_data : Dictionary

var _width : float
var _height : float
var _fps : float

# Dictionary with the user's import options.
var _options : Dictionary
var _loop_animation : bool = false
var _mask_layer : int = 1
var _ik_preference : int
var _source_file : String
var _image_folder : String
var _verbose : bool = false

# Dictionary used when instanciating bones. If a bone's parent isn't created when initialized it,
# we add it to the queue. When the parent is initialized, we also initialize its children. Each key
# is a parent index in bones array and gives a list of the queued children's arguments.
var _queued_bones := {}
#{
#	1: [
#			{
#				skeleton = skeleton,
#				bone = skeleton,
#				parent = bone_parent,
#			}
#	]
#}

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _enter_tree():
	add_to_group("moho_project_helper")

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

static func get_proper_file_name(moho_file_path: String) -> String:
	var proper_name = moho_file_path.get_file().get_basename()
	if proper_name == "Project":
		var folder_name = moho_file_path.get_base_dir().get_file()
		proper_name = folder_name
	return proper_name


static func get_default_file_path(moho_file_path: String, extension: String) -> String:
	return "%s/%s.%s" % [
		moho_file_path.get_base_dir(),
		get_proper_file_name(moho_file_path),
		extension
	]


# Initialize project data and import options.
func initialize(project_data: Dictionary, options: Dictionary):
	_raw_data = project_data
	_options = options
	
	_loop_animation = _options.loop_animation
	_image_folder = _options.image_folder
	_ik_preference = _handle_ik_preference(_options.ik_preference)
	_source_file = _options.source_file
	_mask_layer = _options.mask_layer
	_verbose = _options.verbose
	
	_width = float(_raw_data["project_data"]["width"])
	_height = float(_raw_data["project_data"]["height"])
	_fps = float(_raw_data["project_data"]["fps"])
	
	var transform := Transform2D()
	# Invert the Y axis and scale it down
	transform = transform.scaled(Vector2(_height / 2, -_height / 2))
	# Set global origin to the middle of the screen
	transform.origin = Vector2(_width/2, _height/2)
	viewport_transform = transform
	
	if _verbose:
		print("MohoProjectHelper initialized | %s x %s | %s fps" % [_width, _height, _fps])
		print("| Loop animation : %s" % [_loop_animation])
		print("| Image folder : %s" % [_image_folder])
		print("| Mask layer : %s" % [_get_render_layers_name(_mask_layer)])


# Instantiate skeletons and bones, creates animations, based on project data.
func initialize_scene(scene: Node2D) -> void:
	# Add scene to tree
	editing_scene = scene
	add_child(editing_scene)
	
	# Set root node position
	scene.position = viewport_transform.origin
	
	# Get skeleton layers
	var project_layer : Array = _raw_data["layers"]
	_handle_project_layers(project_layer)
	
	# Create animation
	initialize_animation()


# Creates Animation resource for the project animation, set its keyframes and returns it.
func initialize_animation() -> void:
	var animator : AnimationPlayer = editing_scene.get_node("AnimationPlayer")
	var animation := Animation.new()
	var animation_name = get_proper_file_name(_source_file)
	animator.add_animation(animation_name, animation)
	
	var frame_count = _get_animation_frame_count()
	var animation_length = _convert_frame(frame_count)
	animation.length = animation_length
	animation.loop = _loop_animation
	if _verbose:
		print(
			"\nCreating animation: %s | Expected length: %0.2fs"
			% [animation_name, animation_length]
		)
	
	# Add skeleton keyframes
	for s_idx in skeletons.size():
		var skeleton : MohoSkeleton = skeletons[s_idx]
		skeleton.parse_animation(animator, animation, _verbose)
	
		# Add bones keyframes
		for b_idx in skeleton.bones.size():
			var bone : MohoBone = skeleton.bones[b_idx]
			bone.parse_animation(animator, animation, _verbose)
	
	# Add layers keyframes
	for sprite in sprites:
		sprite.parse_animation(animator, animation, _verbose)
	for switch in switches:
		switch.parse_animation(animator, animation, _verbose)
	for group in groups:
		group.parse_animation(animator, animation, _verbose)
	
	var final_length := 0.0
	for track_idx in animation.get_track_count():
		var last_key_idx := animation.track_get_key_count(track_idx) - 1
		var track_duration := animation.track_get_key_time(track_idx, last_key_idx)
		if track_duration > final_length:
			final_length = track_duration
	if final_length != animation_length:
		animation.length = final_length
		if _verbose:
			print("\n| Animation final length: %0.2fs" % [final_length])
	
	# Set actions bindings
	for action_name in actions:
		var action : SmartBoneAction = actions[action_name]
		action.set_bindings(_verbose)


# Sets Sprite textures and masks. Returns an Array of filepaths from the created mask images.
# It will search within the given directory for images that matches any project Sprite.
# If layer is an ImageLayer, it will get the image name from Moho and search for it.
# If it's a MeshLayer, it will search for any image with the layer's name.
# This function also sets Group Masks and generate mask images.
func set_images_from_folder() -> Array:
	var image_list := _get_image_list(_image_folder)
	var group_mask_helper := MohoGroupMaskHelper.new(_options)
	
	var sprites_found = 0
	var sprites_missing := []
	var icon_placeholder : Texture = load(ICON_PLACEHOLDER_PATH)
	if _verbose:
		print("\nSetting images on sprites")
	for idx in sprites.size():
		var sprite : MohoSprite = sprites[idx]
		
		var sprite_node : Sprite = sprite.node
		var sprite_filename = sprite.get_image_filename()
		sprites_found += 1
		
		if sprite_filename.empty():
			sprite_node.texture = null
			sprites_found += 1
		elif sprite_filename in image_list.keys():
			var texture = load(image_list[sprite_filename])
			sprite_node.texture = texture
			sprites_found += 1
		else:
			sprite_node.texture = icon_placeholder
			sprites_missing.append(sprite.name)
	if _verbose:
		print("| Found %s/%s images" % [sprites_found, sprites.size()])
	if not sprites_missing.empty():
		push_warning("Missing images for sprites: %s" % [sprites_missing])
	
	for group_idx in groups.size():
		var group : MohoGroup = groups[group_idx]
		if group.has_mask():
			group_mask_helper.set_group_mask(group)
	
	return group_mask_helper.gen_files

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### Initialization --------------------------------------------------------------------------------

# Creates Skeletons, Sprites, Switches and Groups for the project.
func _handle_project_layers(layers: Array) -> void:
	for layer_data in layers:
		match layer_data["type"]:
			"MeshLayer", "ImageLayer":
				var sprite := _initialize_sprite(layer_data, editing_scene)
			"GroupLayer":
				var group := _initialize_group(layer_data, editing_scene)
			"SwitchLayer":
				var switch := _initialize_switch(layer_data, editing_scene)
			"BoneLayer":
				var new_skeleton := _initialize_skeleton(layer_data, editing_scene)
			_:
				push_error("Unknown layer type: %s" % [layer_data["type"]])


# Creates Skeletons, Sprites, Switches and Groups for the given element.
func _handle_layers_on_element(
		element: MohoRigElement,
		parent_node: Node2D,
		skeleton: MohoSkeleton = null
) -> void:
	var layers := element.get_layers()
	for layer_data in layers:
		match layer_data["type"]:
			"MeshLayer", "ImageLayer":
				var sprite := _initialize_sprite(layer_data, parent_node, skeleton)
				if not sprite in element.layers:
					element.layers.append(sprite)
			"GroupLayer":
				var group := _initialize_group(layer_data, parent_node, skeleton)
				if not group in element.layers:
					element.layers.append(group)
			"SwitchLayer":
				var switch := _initialize_switch(layer_data, parent_node, skeleton)
				if not switch in element.layers:
					element.layers.append(switch)
			"BoneLayer":
				var new_skeleton := _initialize_skeleton(layer_data, parent_node)
				if not new_skeleton in element.layers:
					element.layers.append(new_skeleton)
			_:
				push_error("Unknown layer type: %s" % [layer_data["type"]])


func _initialize_skeleton(skeleton_data: Dictionary, parent_node: Node2D) -> MohoSkeleton:
	var skeleton := MohoSkeleton.new(skeleton_data)
	skeleton.viewport_transform = viewport_transform
	skeleton.fps = _fps
	skeletons.append(skeleton)
	
	var skeleton_node := Skeleton2D.new()
	parent_node.add_child(skeleton_node)
	if parent_node.owner != null:
		skeleton_node.owner = parent_node.owner
	else:
		skeleton_node.owner = parent_node
	skeleton.initialize_skeleton(skeleton_node, _verbose)
	
	_initialize_bones(skeleton)
	
	var layers_node := Node2D.new()
	parent_node.add_child(layers_node, true)
	layers_node.owner = skeleton_node.owner
	parent_node.move_child(layers_node, skeleton_node.get_index() + 1)
	layers_node.name = "%s_Layers" % [skeleton.name]
	_handle_layers_on_element(skeleton, layers_node, skeleton)
	
	return skeleton


# Creates MohoBone resources for each bone of the skeleton and initialize their initial properties.
func _initialize_bones(skeleton: MohoSkeleton) -> void:
	for bone_data in skeleton.bones_data:
		var new_bone := MohoBone.new(bone_data)
		new_bone.viewport_transform = viewport_transform
		new_bone.fps = _fps
		new_bone.skeleton = skeleton
		skeleton.bones.append(new_bone)
	
	for idx in skeleton.bones.size():
		var bone : MohoBone = skeleton.bones[idx]
		var bone_parent_idx : int = bone.get_parent_index()
		var bone_parent : MohoRigElement
		if bone.is_reparented():
			bone_parent = _get_reparented_bone_parent(skeleton, bone)
		elif skeleton.is_valid_bone_index(bone_parent_idx):
			bone_parent = skeleton.bones[bone_parent_idx]
		else:
			bone_parent = skeleton
		
		if bone_parent.node == null:
			# If bone's parent is not initialized, we queue its initialization
			var args := {
				skeleton = skeleton,
				bone = bone,
				parent = bone_parent,
			}
			if not _queued_bones.has(bone_parent_idx):
				_queued_bones[bone_parent_idx] = []
			_queued_bones[bone_parent_idx].append(args)
			if _verbose:
				print("Bone %s is queued for initialization" % bone.name)
		else:
			_initialize_bone(skeleton, bone, bone_parent)
	
	if _verbose:
		print("\nLooking for reparented bones")
	for idx in skeleton.bones.size():
		var bone : MohoBone = skeleton.bones[idx]
		if bone.is_reparented():
			_handle_reparented_bone_remotes(bone)
	
	if _verbose:
		print("\nMaking IK chains")
	for idx in skeleton.bones.size():
		var bone : MohoBone = skeleton.bones[idx]
		bone.handle_ik_chain(_ik_preference, _verbose)
	
	if not _queued_bones.empty():
		push_error("Some queued bones weren't initialized! | Remaining: %s" % _queued_bones)
	
	if _verbose:
		print("\nSkeleton final tree:")
		skeleton.node.print_tree_pretty()


func _initialize_bone(
		skeleton: MohoSkeleton,
		bone: MohoBone,
		bone_parent: MohoRigElement
) -> void:
	var bone_node : Bone2D
	if bone.should_be_smart_bone():
		bone_node = SmartBone.new()
	else:
		bone_node = Bone2D.new()
	bone_parent.node.add_child(bone_node)
	bone_node.owner = skeleton.node.owner
	
	if _verbose:
		print("\nCreating bone: %s" % bone.name)
		print("| Got parent: %s %s" % [bone_parent.name, bone_parent])
	
	bone.initialize_bone(bone_node, _verbose)
	if not bone.is_connected("action_register", self, "_on_rig_element_action_register"):
		bone.connect("action_register", self, "_on_rig_element_action_register")
	
	var bone_index = skeleton.bones.find(bone)
	if _queued_bones.has(bone_index):
		for args in _queued_bones[bone_index]:
			_initialize_bone(args.skeleton, args.bone, args.parent)
		_queued_bones.erase(bone_index)


func _initialize_sprite(
		sprite_data: Dictionary,
		parent_node: Node2D,
		skeleton: MohoSkeleton = null
) -> MohoSprite:
	var sprite := MohoSprite.new(sprite_data)
	sprite.viewport_transform = viewport_transform
	sprite.fps = _fps
	sprites.append(sprite)
	if not sprite.is_connected("action_register", self, "_on_rig_element_action_register"):
		sprite.connect("action_register", self, "_on_rig_element_action_register")
	
	var sprite_anchor := Node2D.new()
	parent_node.add_child(sprite_anchor)
	sprite_anchor.owner = parent_node.owner
	sprite_anchor.name = "%sAnchor" % [sprite.name]
	
	var sprite_node := Sprite.new()
	sprite_anchor.add_child(sprite_node)
	sprite_node.owner = parent_node.owner
	
	if _verbose:
		print("\nCreating sprite: %s" % sprite.name)
	
	sprite.initialize_sprite(sprite_node, _verbose)
	if skeleton != null:
		_set_remote_transform(skeleton, sprite)
	
	return sprite


func _initialize_group(
		layer_data: Dictionary,
		parent_node: Node2D,
		skeleton: MohoSkeleton = null
) -> MohoGroup:
	var group := MohoGroup.new(layer_data)
	group.viewport_transform = viewport_transform
	group.fps = _fps
	groups.append(group)
	if not group.is_connected("action_register", self, "_on_rig_element_action_register"):
		group.connect("action_register", self, "_on_rig_element_action_register")
	
	var group_node := Node2D.new()
	parent_node.add_child(group_node)
	group_node.owner = parent_node.owner
	
	if _verbose:
		print("\nCreating group layer: %s" % group.name)
	
	group.initialize_group_layer(group_node, _verbose)
	_handle_layers_on_element(group, group_node, skeleton)
	if skeleton != null:
		_set_remote_transform(skeleton, group)
	
	return group


func _initialize_switch(
		layer_data: Dictionary,
		parent_node: Node2D,
		skeleton: MohoSkeleton = null
) -> MohoSwitch:
	var switch := MohoSwitch.new(layer_data)
	switch.viewport_transform = viewport_transform
	switch.fps = _fps
	switches.append(switch)
	if not switch.is_connected("action_register", self, "_on_rig_element_action_register"):
		switch.connect("action_register", self, "_on_rig_element_action_register")
	
	var switch_node := SwitchLayer.new()
	parent_node.add_child(switch_node)
	switch_node.owner = parent_node.owner
	
	if _verbose:
		print("\nCreating switch layer: %s" % switch.name)
	
	switch.initialize_switch_layer(switch_node, _verbose)
	_handle_layers_on_element(switch, switch_node, skeleton)
	if skeleton != null:
		_set_remote_transform(skeleton, switch)
	
	return switch


func _get_image_list(image_folder_path: String) -> Dictionary:
	var image_list := {}
	var valid_image_extensions = ["png", "jpg"]
	
	if not image_folder_path.ends_with("/"):
		image_folder_path += "/"
	
	var directory = Directory.new()
	if not directory.dir_exists(image_folder_path):
		return image_list
	
	var err = directory.open(image_folder_path)
	if err != OK:
		push_error("Error %s trying to read folder: %s" % [err, image_folder_path])
		return image_list
	
	directory.list_dir_begin(true, true)
	var file_name = directory.get_next()
	while (file_name):
		if not directory.current_is_dir():
			var extension = file_name.get_extension()
			if valid_image_extensions.has(extension):
				var full_path = image_folder_path + file_name
				image_list[file_name.get_basename()] = full_path
		
		file_name = directory.get_next()
	directory.list_dir_end()
	
	return image_list

### -----------------------------------------------------------------------------------------------

### Bone binding ----------------------------------------------------------------------------------

func _set_remote_transform(skeleton: MohoSkeleton, element: MohoRigElement) -> void:
	var parent : MohoBone = _get_parent(skeleton, element.get_parent_index()) as MohoBone
	if parent == null:
		return
	
	var target := element.get_remote_target()
	_create_remote_transform(parent.node, target)


# Returns a MohoBone resource used to initialize a reparented bone.
# It creates a Bone2D, child of the Skeleton2D, that can be remote transformed in the animation.
func _get_reparented_bone_parent(skeleton: MohoSkeleton, reparented_bone: MohoBone) -> MohoBone:
	var parent_name = "%sParent" % [reparented_bone.name]
	var parent_data = {
		"name" : parent_name
	}
	var parent_bone := MohoBone.new(parent_data)
	
	var parent_bone_node := Bone2D.new()
	skeleton.node.add_child(parent_bone_node)
	parent_bone_node.owner = skeleton.node.owner
	parent_bone_node.name = parent_name
	parent_bone.node = parent_bone_node
	
	return parent_bone


# Creates RemoteTransform2D nodes linked to the given reparented bone.
func _handle_reparented_bone_remotes(reparented_bone: MohoBone) -> void:
	var target : Bone2D = reparented_bone.node.get_parent()
	var initial_parent_idx := reparented_bone.get_parent_index()
	
	var remotes_created = 0
	for parent_idx in reparented_bone.get_parents_index():
		var bone_parent : MohoRigElement = \
			_get_parent(reparented_bone.skeleton, parent_idx)
		var is_active : bool = parent_idx == initial_parent_idx
		
		var remote_transform = _create_remote_transform(bone_parent.node, target, false, is_active)
		
		reparented_bone.register_remote(parent_idx, remote_transform)
		remotes_created += 1
	
	target.rest = target.get_transform()


func _create_remote_transform(
		parent_node: Node2D,
		target: Node2D,
		keep_children_transform: bool = true,
		is_active: bool = true
) -> RemoteTransform2D:
	var child_transforms := []
	if keep_children_transform:
		for idx in target.get_child_count():
			var child : Node2D = target.get_child(idx)
			child_transforms.append(child.get_global_transform())
	
	var remote_transform = _get_remote_transform(parent_node, is_active)
	var target_name = target.name.replace("Anchor", "")
	var remote_name = "%sRemote" % [target_name]
	var remote_path = remote_transform.get_path_to(target)
	remote_transform.name = remote_name
	remote_transform.remote_path = remote_path
	
	if keep_children_transform:
		for idx in target.get_child_count():
			var child : Node2D = target.get_child(idx)
			var child_transform : Transform2D = child_transforms[idx]
			child.global_transform = child_transform
	
	if _verbose:
		print("| Created RemoteTransform for target %s" % [target.name])
	
	return remote_transform


# Returns a RemoteTransform2D with basic settings.
# We use it to set its update properties before we set the remote path.
func _get_remote_transform(parent_node: Node2D, is_active: bool) -> RemoteTransform2D:
	var remote_transform = RemoteTransform2D.new()
	parent_node.add_child(remote_transform)
	remote_transform.owner = parent_node.owner
	
	remote_transform.update_position = is_active
	remote_transform.update_rotation = is_active
	remote_transform.update_scale = is_active
	
	return remote_transform


func _get_parent(skeleton: MohoSkeleton, parent_idx: int) -> MohoRigElement:
	var parent : MohoRigElement
	if skeleton.is_valid_bone_index(parent_idx):
		parent = skeleton.bones[parent_idx]
	else:
		parent = skeleton
	return parent


### -----------------------------------------------------------------------------------------------

### Animation -------------------------------------------------------------------------------------

func _get_animation_frame_count() -> float:
	return float(_raw_data["project_data"]["end_frame"])


# Converts a frame number into its time in seconds. This is used while parsing keyframes: Moho saves
# keyframe placement based on frame number, but we need it as a time measurement in Godot.
func _convert_frame(frame: float) -> float:
	var time = frame / _fps
	# The first frame is an exception, we need it to be in the very beggining of the animation
	if frame <= 1:
		time = 0.0
#	print("Converting frame %s to time: %s s" % [frame, time])
	return time

### -----------------------------------------------------------------------------------------------

### Actions ---------------------------------------------------------------------------------------

func _on_rig_element_action_register(
		rig_element: MohoRigElement,
		property: String,
		action_data: Dictionary
) -> void:
	var action : SmartBoneAction
	var action_name = action_data.name
	if not actions.has(action_name):
		action = SmartBoneAction.new()
		action.name = action_name
		actions[action_name] = action
	else:
		action = actions[action_name]
	
	action.register_rig_element(rig_element, property, action_data)

### -----------------------------------------------------------------------------------------------

### Misc ------------------------------------------------------------------------------------------

func _get_render_layers_name(mask_value: int) -> String:
	var render_layers := ""
	var max_layer = 20
	
	for i in range(max_layer, 0, -1):
		var value = int(pow(2, i - 1))
		if mask_value >= value:
			var layer_name = _get_single_render_layer_name(i)
			if not render_layers.empty():
				render_layers += " + "
			render_layers += layer_name
		
		mask_value = mask_value % value
	
	return render_layers


func _get_single_render_layer_name(layer: int) -> String:
	var mask_layer_setting = "layer_names/2d_render/layer_%s" % [layer]
	var mask_layer_name : String = ProjectSettings.get_setting(mask_layer_setting)
	if mask_layer_name.empty():
		mask_layer_name = "Layer %02d" % [layer]
	return mask_layer_name


func _handle_ik_preference(value: String) -> int:
	var preference : int = Skeleton2DIKChain.Preference.NONE
	value = value.to_upper()
	if value in Skeleton2DIKChain.Preference.keys():
		preference = Skeleton2DIKChain.Preference[value]
	return preference

### -----------------------------------------------------------------------------------------------
