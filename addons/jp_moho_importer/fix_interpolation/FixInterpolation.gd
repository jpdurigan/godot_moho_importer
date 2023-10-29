# Write your doc string for this file here
tool
extends Control

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

var animation_tree: AnimationTree = null setget _set_animation_tree

#--- private variables - order: export > normal var > onready -------------------------------------

var _animation_player: AnimationPlayer

var _selected_animations: Array

onready var _animation_list: VBoxContainer = $Content/Animations/List

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func reset() -> void:
	_selected_animations.clear()


func populate_anim_player(anim_player: AnimationPlayer = _animation_player) -> void:
	for child in _animation_list.get_children():
		child.queue_free()
	
	for anim_name in anim_player.get_animation_list():
		_add_checkbox(anim_name)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _fix_animations() -> void:
	var anim_resources := []
	var anim_datas := []
	for anim_name in _selected_animations:
		var animation := _animation_player.get_animation(anim_name)
		var anim_data := AnimationData.new(animation)
		anim_resources.append(animation)
		anim_datas.append(anim_data)
	
	for track_path in _get_unique_track_paths(anim_resources):
		var should_be_bezier : bool = false
		for idx in anim_datas.size():
			var anim_data : AnimationData = anim_datas[idx]
			should_be_bezier = anim_data.is_track_bezier(track_path)
			if should_be_bezier:
				break
		
		if should_be_bezier:
			for idx in anim_datas.size():
				var anim_data : AnimationData = anim_datas[idx]
				anim_data.track_convert_to_bezier(track_path)
				anim_data.save_animation()


func _get_unique_track_paths(animations: Array) -> Array:
	var track_list := []
	for anim in animations:
		for track_idx in anim.get_track_count():
			var track_path = anim.track_get_path(track_idx)
			if not track_list.has(track_path):
				track_list.append(track_path)
	return track_list


func _has_track(animation: Animation, track_path: NodePath) -> bool:
	return animation.find_track(track_path) >= 0


func _add_checkbox(anim_name: String) -> void:
	var check_box := CheckBox.new()
	check_box.text = anim_name
	check_box.connect("toggled", self, "_on_checkbox_toggled", [anim_name])
	_animation_list.add_child(check_box)
	check_box.pressed = true


func _on_checkbox_toggled(pressed: bool, anim_name: String) -> void:
	if pressed and not _selected_animations.has(anim_name):
		_selected_animations.append(anim_name)
	elif not pressed and _selected_animations.has(anim_name):
		_selected_animations.erase(anim_name)


func _set_animation_tree(value: AnimationTree) -> void:
	animation_tree = value
	
	if not is_inside_tree():
		yield(self, "ready")
	
	_animation_player = animation_tree.get_node(animation_tree.anim_player)
	
	reset()
	populate_anim_player()


func _on_Fix_pressed():
	_fix_animations()

### -----------------------------------------------------------------------------------------------


class AnimationData:
	var animation: Animation
	var tracks: Dictionary
	
	
	func _init(p_animation: Animation):
		animation = p_animation
		tracks.clear()
		for track_idx in animation.get_track_count():
			var track_data := TrackData.new(animation, track_idx)
			tracks[track_data.track_path] = track_data
	
	
	func save_animation() -> void:
		if not animation.resource_path.empty():
			ResourceSaver.save(animation.resource_path, animation)
	
	
	func has_track(track_path: NodePath) -> bool:
		return tracks.has(track_path)
	
	
	func is_track_bezier(track_path: NodePath) -> bool:
		if not has_track(track_path):
			return false
		
		var track_data : TrackData = tracks[track_path]
		return track_data.track_type == Animation.TYPE_BEZIER
	
	
	func track_convert_to_bezier(track_path: NodePath) -> void:
		if not has_track(track_path):
			return
		
		var track_data : TrackData = tracks[track_path]
		track_data.convert_to_bezier()


class TrackData:
	var animation: Animation
	var track_idx: int
	var track_type: int
	var track_path: NodePath
	
	
	func _init(p_animation: Animation, p_track_idx: int):
		animation = p_animation
		track_idx = p_track_idx
		track_type = animation.track_get_type(track_idx)
		track_path = animation.track_get_path(track_idx)
	
	
	func convert_to_bezier() -> void:
		_update_from_path()
		if track_type != Animation.TYPE_VALUE:
			return
		
		# keys = key time, values = key value
		var animation_data := {}
		for key_idx in animation.track_get_key_count(track_idx):
			var key_time = animation.track_get_key_time(track_idx, key_idx)
			var key_value = animation.track_get_key_value(track_idx, key_time)
			animation_data[key_time] = key_value
		
		animation.remove_track(track_idx)
		track_type = Animation.TYPE_BEZIER
		track_idx = animation.add_track(track_type)
		animation.track_set_path(track_idx, track_path)
		
		for key_time in animation_data.keys():
			var key_value = animation_data[key_time]
			animation.bezier_track_insert_key(track_idx, key_time, key_value)
	
	
	func _update_from_path() -> void:
		track_idx = animation.find_track(track_path)
		track_type = animation.track_get_type(track_idx)

