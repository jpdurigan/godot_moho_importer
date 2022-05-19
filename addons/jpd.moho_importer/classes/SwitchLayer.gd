# A Node2D that sets as visible only one of its children (they must inherit from CanvasItem).
tool
class_name SwitchLayer, "res://addons/jpd.moho_importer/components/icon_switch_layer.svg"
extends Node2D

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

var key : String = "" setget _set_key

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready():
	if key.empty():
		key = _get_default_key()
		_set_key(key)


func _get_property_list() -> Array:
	var property_list := []
	property_list.append({
		"hint": PROPERTY_HINT_ENUM,
		"usage": PROPERTY_USAGE_DEFAULT,
		"name": "key",
		"type": TYPE_STRING,
		"hint_string": _get_hint_string(),
	})
	return property_list

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _get_default_key() -> String:
	var default_key := ""
	for idx in range(get_children().size()-1, -1, -1):
		var child := get_child(idx) as CanvasItem
		if is_instance_valid(child):
			default_key = child.name
			break
	
	return default_key


func _hide_all_children() -> void:
	for child in get_children():
		if child is CanvasItem:
			child.visible = false


func _set_key(value: String) -> void:
	_hide_all_children()
	if not has_node(value):
		return
	
	key = value
	var key_node = get_node(key) as CanvasItem
	key_node.visible = true


func _get_hint_string() -> String:
	var children = get_children()
	var children_name := PoolStringArray([""])
	for child in children:
		if child is CanvasItem:
			children_name.append(child.name)
		else:
			children_name.append("---")
	
	return children_name.join(",")

### -----------------------------------------------------------------------------------------------
