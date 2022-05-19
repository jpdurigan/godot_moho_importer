# Resource for parsing SwitchLayer data from Moho projects.
# On Sprites, Group and SwitchLayers, we set their global Transform properties (position,
# rotation and scale).
# SwitchLayer raw data structure:
#{
#	type = "SwitchLayer",
#	name = "name",
#	switch_keys = {},
#	layers = [ { MeshLayer }, { ImageLayer } ],
#	origin = { x, y },
#	parent_bone = int,
#	transforms = {
#		translation = {},
#		scale = {},
#		rotation_z = {},
#		flip_h = {},
#		flip_v = {}
#	}
#}
class_name MohoSwitch
extends MohoRigElement

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _init(data: Dictionary):
	_raw_data = data
	
	name = _raw_data["name"]


func get_class() -> String:
	return "MohoSwitch"


func is_class(p_class: String) -> bool:
	return p_class == get_class() or .is_class(p_class)

### -----------------------------------------------------------------------------------------------


### Base Class Methods ----------------------------------------------------------------------------

func _get_raw_property(key: String) -> Dictionary:
	if key == "switch_keys":
		return _raw_data[key]
	else:
		return _raw_data["transforms"][key]


func _get_animated_properties() -> Array:
	return ["translation", "scale", "rotation_z", "flip_h", "flip_v", "switch_keys"]


func get_parent_index(_val_index: int = POSE_FRAME) -> int:
	return _raw_data["parent_bone"]

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

# Initializes SwitchLayer's initial properties.
func initialize_switch_layer(switch_layer: SwitchLayer, verbose: bool = false) -> void:
	node = switch_layer
	
	node.name = name
	node.position = _get_property("translation")
	node.scale = _get_property("scale")
	node.rotation = _get_property("rotation_z")
	
	if _get_property("flip_h") != Vector2.ONE:
		node.scale.x *= -1
	if _get_property("flip_v") != Vector2.ONE:
		node.scale.y *= -1
	
	# Since we're initializing this node without its children,
	# we queue the initialization of "switch_key" property.
	var initial_key = _get_property("switch_keys")
	
	if verbose:
		print("\nInitalized switch layer: %s" % node.name)
		print("| Position: %s" % node.position)
		print("| Scale: %s" % node.scale)
		print("| Rotation: %s" % node.rotation)
		print("| Key: %s" % node.key)


### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

# Override format property so that we can handle Sprite anchors.
func _format_property(key: String, raw_value):
	var value = ._format_property(key, raw_value)
	
	if key == "switch_keys" and value is String:
		value = _get_proper_initial_key(value)
	
	return value


func _connect_to_signal(initial_key: String) -> void:
	var editor_tree := node.get_tree()
	if not editor_tree.is_connected("tree_changed", self, "_on_switch_node_tree_changed"):
		editor_tree.connect("tree_changed", self, "_on_switch_node_tree_changed", [initial_key])


func _get_proper_initial_key(value: String, skip_error: bool = false) -> String:
	var candidate := ""
	if not is_instance_valid(node):
		return candidate
	
	candidate = value
	if node.has_node(candidate):
		return candidate
	
	candidate = value.get_basename()
	if node.has_node(candidate):
		return candidate
	
	candidate = "%sAnchor" % [value.get_basename()]
	if not node.has_node(candidate) and not skip_error:
		push_error(
			"Unknown switch key %s for Switch %s | Possible keys are: %s"
			% [value, name, _get_valid_keys()]
		)
		_connect_to_signal(value)
	return candidate


func _get_valid_keys() -> Array:
	var valid_keys := []
	if is_instance_valid(node):
		for child in node.get_children():
			if child is CanvasItem:
				valid_keys.append(child.name)
	return valid_keys


func _disconnect_all_signals() -> void:
	for connection in get_incoming_connections():
		var source : Object = connection.source
		source.disconnect(connection.signal_name, self, connection.method_name)


func _on_switch_node_tree_changed(initial_key: String) -> void:
	if not is_instance_valid(node):
		push_error(
			"MohoSwitch %s hasn't set initial switch key and scene has been packed." % [name]
			+ " | Initial key was: %s" % [initial_key]
		)
		_disconnect_all_signals()
		return
	
	var proper_key := _get_proper_initial_key(initial_key, true)
	if not proper_key.empty():
		node.key = initial_key
		node.get_tree().disconnect("tree_changed", self, "_on_switch_node_tree_changed")

### -----------------------------------------------------------------------------------------------
