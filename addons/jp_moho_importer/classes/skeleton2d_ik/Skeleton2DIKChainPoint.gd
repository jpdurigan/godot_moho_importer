# Write your doc string for this file here
class_name Skeleton2DIKChainPoint
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

export var position : Vector2
export var parent_distance : float = 0.0
export var child_distance : float = 0.0

#--- private variables - order: export > normal var > onready -------------------------------------

var _node : Node2D

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _init(node2d: Node2D, parent: Node2D, child: Node2D) -> void:
#	printt("Initing IKChainPoint", node2d, parent, child)
	_node = node2d
	position = node2d.global_position
	if parent != null:
		parent_distance = position.distance_to(parent.global_position)
	if child != null:
		child_distance = position.distance_to(child.global_position)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func update_position(p_pos: Vector2 = _node.global_position) -> void:
	position = p_pos

func update_node(child_pos: Vector2) -> void:
	_node.global_position = position
	_node.global_rotation = child_pos.angle_to_point(position)

func get_node_position() -> Vector2:
	return _node.global_position


# Solving from TIP to ROOT
func solve_upwards(child_position: Vector2) -> void:
	_solve(child_position, child_distance)

# Solving from ROOT to TIP
func solve_downwards(parent_position: Vector2) -> void:
	_solve(parent_position, parent_distance)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _solve(p_target: Vector2, p_length: float) -> void:
	var direction = p_target.direction_to(position)
	position = p_target + direction * p_length

### -----------------------------------------------------------------------------------------------
