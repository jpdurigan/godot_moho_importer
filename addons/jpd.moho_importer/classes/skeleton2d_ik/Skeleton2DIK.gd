# Custom class to use 2D IK at runtime in 2D Bones and Skeleton, using FABRIK algorithm.
# Default usage: add this node as the last member of the chain and tip path should point to self.
# Node's tree should be Skeleton-like (every member of the chain is child/parent of another).
# It can detect automatically IK chains, if you make IK chain from skeleton options in the editor.
# You can also set custom root and tip bones in the inspector.
# You may set a preference, forcing nodes to be oriented clockwise or counter-clockwise.
tool
class_name Skeleton2DIK
extends Node2D

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const META_IK_CHAIN_ROOT = "_edit_ik_"

#--- public variables - order: export > normal var > onready --------------------------------------

export(Skeleton2DIKChain.Preference) var preference : int = Skeleton2DIKChain.Preference.NONE \
		setget _set_preference
export var target_node_path : NodePath setget _set_target_node_path
# Global position target
export var target : Vector2 = Vector2.INF setget _set_target
export var root_path : NodePath setget _set_root_path
export var tip_path := NodePath(".") setget _set_tip_path

var is_active : bool = true

var root : Node2D
var tip : Node2D
var target_node : Node2D

var ik_chain : Skeleton2DIKChain

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready():
	if tip_path == NodePath("."):
		_set_tip_path(tip_path)
	if root_path.is_empty():
		_get_root_from_parent()
	if target_node == null:
		_set_target_node_path(target_node_path)


func _process(_delta):
	update()
	if not is_active or not is_instance_valid(ik_chain) or not ik_chain.is_valid():
		return
	
	var p_target = _get_target()
	ik_chain.solve(p_target)


func _draw():
	if Engine.editor_hint and is_instance_valid(ik_chain):
		ik_chain.draw(self)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _get_target() -> Vector2:
	return target if target_node == null else target_node.global_position


func _update_chain() -> void:
	ik_chain = Skeleton2DIKChain.new()
	ik_chain.create_chain(self, root, self)
	ik_chain.preference = preference
	update()

### -----------------------------------------------------------------------------------------------


### Auto detect chain -----------------------------------------------------------------------------

func _get_root_from_parent() -> void:
	var parent : Node2D = get_parent() as Node2D
	if parent == null:
		return
	
	var root_candidate := _find_ik_root(parent)
	if root_candidate != null:
		self.root_path = get_path_to(root_candidate)


func _find_ik_root(node2d: Node2D) -> Node2D:
	var is_node_ik_root = _node_has_meta(node2d, META_IK_CHAIN_ROOT)
	var node_parent : Node2D = node2d.get_parent() as Node2D
	
	if is_node_ik_root:
		return node2d
	elif node_parent != null:
		return _find_ik_root(node_parent)
	else:
		return null


func _node_has_meta(node2d: Node2D, meta_property: String) -> bool:
	return node2d != null and node2d.has_meta(meta_property) and node2d.get_meta(meta_property)


### -----------------------------------------------------------------------------------------------


### Setters and Getters ---------------------------------------------------------------------------

func _set_preference(value: int) -> void:
	preference = value
	
	if is_instance_valid(ik_chain):
		ik_chain.preference = preference


func _set_target_node_path(value: NodePath) -> void:
	target_node_path = value
	target_node = get_node_or_null(target_node_path) as Node2D


func _set_target(value: Vector2) -> void:
	target = value


func _set_root_path(value: NodePath) -> void:
	root_path = value
	
	if not is_inside_tree():
		yield(self, "ready")
	
	root = get_node_or_null(root_path)
	if root != null and tip != null:
		_update_chain()


func _set_tip_path(value: NodePath) -> void:
	tip_path = value
	
	if not is_inside_tree():
		yield(self, "ready")
	
	tip = get_node_or_null(tip_path)
	
	# If self is tip (default case), we correct this node's position based on it's parent
	if tip == self:
		var parent := get_parent()
		if parent is Bone2D:
			position = Vector2(parent.default_length, 0)
		else:
			position = Vector2.ZERO
	
	if root != null and tip != null:
		_update_chain()


### -----------------------------------------------------------------------------------------------
