# Write your doc string for this file here
tool
class_name Skeleton2DIKChain
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

enum Preference {
	NONE,
	CLOCKWISE,
	COUNTER_CLOCKWISE,
}

#--- constants ------------------------------------------------------------------------------------

const DEFAULT_MAX_INTERATIONS = 64
const DEFAULT_DISTANCE_THRESHOLD = 0.00001

const ANGLE_DELTA = {
	Preference.CLOCKWISE         : -0.001,
	Preference.COUNTER_CLOCKWISE : +0.001,
}

#--- public variables - order: export > normal var > onready --------------------------------------

# These are meant to be constants, but can be overridden in specific cases (e.g. when baking IK)
var MAX_ITERATIONS = DEFAULT_MAX_INTERATIONS
var DISTANCE_THRESHOLD = DEFAULT_DISTANCE_THRESHOLD

var preference : int = Preference.NONE
var chain_length : float = -1

var ik_node : Node2D
var root_node : Node2D
var tip_node : Node2D

#--- private variables - order: export > normal var > onready -------------------------------------

var _nodes : Array
var _points : Array

var _nodes_tip_to_root : Array
var _points_tip_to_root : Array

var _root : Skeleton2DIKChainPoint
var _tip : Skeleton2DIKChainPoint

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func solve(p_target: Vector2) -> void:
	# Update all point position
	for idx in _points.size():
		var chain_item : Skeleton2DIKChainPoint = _points[idx]
		chain_item.update_position()
	
	var root_position := _root.position
	if (
		_points.empty() or
		not _is_valid(p_target) or
		_is_solved(root_position, p_target)
	):
		_update_all_nodes()
		return
	
	if not _is_solvable(p_target):
		p_target = root_position + root_position.direction_to(p_target) * chain_length
	
	# If user set preference and target is at a safe distance, set initial condition
	# When target's too close to root, altering the initial condition results in unnatural behaviour
	var has_preference = preference != Preference.NONE
	var is_target_at_safe_distance = root_position.distance_to(p_target) > (_root.child_distance / 2)
	if has_preference and is_target_at_safe_distance:
		var chain_angle : float = \
				root_position.direction_to(p_target).angle() + ANGLE_DELTA[preference]
		var parent_pos : Vector2 = root_position
		for idx in _points.size():
			var chain_item : Skeleton2DIKChainPoint = _points[idx]
			var new_item_position = \
					parent_pos + Vector2.RIGHT.rotated(chain_angle) * chain_item.parent_distance
			chain_item.update_position(new_item_position)
			parent_pos = chain_item.position
	
	# Iterate point position until we've reached threshold or max iterations
	for i in MAX_ITERATIONS:
		_iterate_upwards(p_target)
		if _is_solved(root_position, p_target):
			break
		
		_iterate_downwards(root_position)
		if _is_solved(root_position, p_target):
			break
	
	_update_all_nodes()


# Iterates FABRIK algorithm from tip to root
func _iterate_upwards(tip_target: Vector2) -> void:
	for idx in _points_tip_to_root.size():
		var chain_item : Skeleton2DIKChainPoint = _points_tip_to_root[idx]
		
		var chain_item_target : Vector2
		if idx - 1 < 0:
			chain_item_target = tip_target
		else:
			var prev_chain_item : Skeleton2DIKChainPoint = _points_tip_to_root[idx - 1]
			chain_item_target = prev_chain_item.position
		
		chain_item.solve_upwards(chain_item_target)


# Iterates FABRIK algorithm from root to tip
func _iterate_downwards(root_target: Vector2) -> void:
	for idx in _points.size():
		var chain_item : Skeleton2DIKChainPoint = _points[idx]
		
		var chain_item_target : Vector2
		if idx - 1 < 0:
			chain_item_target = root_target
		else:
			var prev_chain_item : Skeleton2DIKChainPoint = _points[idx - 1]
			chain_item_target = prev_chain_item.position
		
		chain_item.solve_downwards(chain_item_target)


func _update_all_nodes() -> void:
	# Update node position and rotation with reference
	for idx in _points_tip_to_root.size():
		var chain_item : Skeleton2DIKChainPoint = _points_tip_to_root[idx]
		var chain_item_child_pos : Vector2
		if idx - 1 >= 0:
			var chain_item_child : Skeleton2DIKChainPoint = _points_tip_to_root[idx - 1]
			chain_item_child_pos = chain_item_child.position
		else:
			chain_item_child_pos = chain_item.position
		chain_item.update_node(chain_item_child_pos)


### Initing/Validation Methods --------------------------------------------------------------------

func is_valid() -> bool:
	return chain_length > 0 and _points.size() >= 2


func create_chain(ik: Node2D, root: Node2D, tip: Node2D) -> void:
	ik_node = ik
	root_node = root
	tip_node = tip
	
	# Populates _nodes Array
	_nodes_tip_to_root.clear()
	var current_bone : Node2D = tip
	while root.is_a_parent_of(current_bone) or current_bone == root:
		_nodes_tip_to_root.append(current_bone)
		current_bone = current_bone.get_parent()
	
	_nodes = _nodes_tip_to_root.duplicate()
	_nodes.invert()
	
	# Creates IKChainPoint references and populates _points Array
	_points.clear()
	chain_length = 0.0
	for idx in _nodes.size():
		var bone : Node2D = _nodes[idx]
		var parent : Node2D = null
		var child : Node2D = null
		
		if idx + 1 < _nodes.size():
			child = _nodes[idx + 1]
		if idx - 1 >= 0:
			parent = _nodes[idx - 1]
		
		var points_chain_item := Skeleton2DIKChainPoint.new(bone, parent, child)
		_points.append(points_chain_item)
		chain_length += points_chain_item.parent_distance
	
	_points_tip_to_root = _points.duplicate()
	_points_tip_to_root.invert()
	
	_root = _points.front()
	_tip = _points.back()


func get_nodes() -> Array:
	return _nodes


### Debugging -------------------------------------------------------------------------------------

func draw(canvas: CanvasItem) -> void:
	canvas.draw_set_transform_matrix(canvas.get_global_transform().inverse())
	var last_point : Skeleton2DIKChainPoint = null
	for point in _points:
		if last_point != null:
			canvas.draw_line(last_point.position, point.position, Color.tomato, 6.0)
		last_point = point
	for point in _points:
		canvas.draw_circle(point.position, 10.0, Color.yellowgreen)
		canvas.draw_circle(point.position, 8.0, Color.yellow)


# Method meant for debugging. Every step will yield until node emits said signal.
# Progress func is called right before the yield, with some text to be displayed.
func solve_interactive(
		p_target: Vector2,
		node: Node,
		signal_name: String,
		progress_func: FuncRef = null
) -> void:
	# Update all point position
	for idx in _points.size():
		var chain_item : Skeleton2DIKChainPoint = _points[idx]
		chain_item.update_position()
	
	var text : String
	var root_position := _root.position
	if (
		_points.empty() or
		not _is_valid(p_target) or
		_is_solved(root_position, p_target)
	):
		text = "Skipping IK"
		_update_progress(progress_func, text)
		yield(node, signal_name)
		_update_all_nodes()
		return
	
	if not _is_solvable(p_target):
		p_target = root_position + root_position.direction_to(p_target) * chain_length
	text = "IK Begin"
	_update_progress(progress_func, text)
	yield(node, signal_name)
	
	# If there's preference, set initial condition
	if preference != Preference.NONE:
		var chain_angle : float = \
				root_position.direction_to(p_target).angle() + ANGLE_DELTA[preference]
		var parent_pos : Vector2 = root_position
		for idx in _points.size():
			var chain_item : Skeleton2DIKChainPoint = _points[idx]
			var new_item_position = \
					parent_pos + Vector2.RIGHT.rotated(chain_angle) * chain_item.parent_distance
			chain_item.update_position(new_item_position)
			parent_pos = chain_item.position
		
		text = "Set preference"
		_update_progress(progress_func, text)
		yield(node, signal_name)
	
	# Iterate point position until we've reached threshold or max iterations
	for i in MAX_ITERATIONS:
		for idx in _points_tip_to_root.size():
			var chain_item : Skeleton2DIKChainPoint = _points_tip_to_root[idx]
			
			var chain_item_target : Vector2
			if idx - 1 < 0:
				chain_item_target = p_target
			else:
				var prev_chain_item : Skeleton2DIKChainPoint = _points_tip_to_root[idx - 1]
				chain_item_target = prev_chain_item.position
			
			chain_item.solve_upwards(chain_item_target)
			
			text = "Iterate upwards #%02d | point %02d" % [i, idx]
			_update_progress(progress_func, text)
			yield(node, signal_name)
		
		if _is_solved(root_position, p_target):
			break
		
		for idx in _points.size():
			var chain_item : Skeleton2DIKChainPoint = _points[idx]
			
			var chain_item_target : Vector2
			if idx - 1 < 0:
				chain_item_target = root_position
			else:
				var prev_chain_item : Skeleton2DIKChainPoint = _points[idx - 1]
				chain_item_target = prev_chain_item.position
			
			chain_item.solve_downwards(chain_item_target)
			
			text = "Iterate downwards #%02d | point %02d" % [i, idx]
			_update_progress(progress_func, text)
			yield(node, signal_name)
		
		if _is_solved(root_position, p_target):
			break
	
	text = "IK Solved!"
	_update_progress(progress_func, text)
	yield(node, signal_name)
	
	_update_all_nodes()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

# Returns true if target is within chain's length reach.
func _is_solvable(p_target: Vector2) -> bool:
	return _root.get_node_position().distance_to(p_target) <= chain_length


# Returns true if target is valid (is not default target, Vector2.INF)
func _is_valid(p_target: Vector2) -> bool:
	return not p_target.is_equal_approx(Vector2.INF)


# Return true if root and tip is in place
func _is_solved(root_target: Vector2, tip_target: Vector2) -> bool:
	return (
		_root.position.distance_squared_to(root_target) < DISTANCE_THRESHOLD and
		_tip.position.distance_squared_to(tip_target) < DISTANCE_THRESHOLD
	)


# Used to update progress with solve_interactive
func _update_progress(progress: FuncRef, text: String) -> void:
	if progress != null and progress.is_valid():
		progress.call_funcv([text])


### -----------------------------------------------------------------------------------------------

