# Godot plugin in GDScript for importing Moho animations.
#
# It imports .mohoproj files and converts it into a single scene. This plugin also adds two classes
# from Moho that may be useful besides importation: SwitchLayer and SmartBone.
#
# See https://github.com/jpdurigan/godot_moho_importer for usage.

tool
extends EditorPlugin

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const MOHO_IMPORTER = preload("res://addons/jp_moho_importer/MohoImporter.gd")

const IK_BAKE_PLUGIN = \
		preload("res://addons/jp_moho_importer/ik_bake_plugin/ik_bake_inspector_plugin.gd")
const SMART_BONE_PLUGIN = \
		preload("res://addons/jp_moho_importer/smart_bone_helper/smart_bone_inspector_plugin.gd")
const FIX_INTERPOLATION_PLUGIN = \
		preload("res://addons/jp_moho_importer/fix_interpolation/fix_interpolation_plugin.gd")
const INSPECTOR_PLUGINS = {
	_ik_bake_plugin = IK_BAKE_PLUGIN,
	_smart_bone_plugin = SMART_BONE_PLUGIN,
	_fix_interpolation_plugin = FIX_INTERPOLATION_PLUGIN,
}

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _moho_importer : EditorImportPlugin
var _ik_bake_plugin : EditorInspectorPlugin
var _smart_bone_plugin : EditorInspectorPlugin
var _fix_interpolation_plugin : EditorInspectorPlugin
var _helpers_in_use := []

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _enter_tree():
	print_debug("MohoImporter entering tree")
	_moho_importer = MOHO_IMPORTER.new()
	_moho_importer.editor_plugin = self
	add_import_plugin(_moho_importer)
	
	for plugin_name in INSPECTOR_PLUGINS.keys():
		var plugin : EditorInspectorPlugin = INSPECTOR_PLUGINS[plugin_name].new()
		set(plugin_name, plugin)
		add_inspector_plugin(plugin)
	
	for helper in _helpers_in_use:
		remove_helper(helper)


func _exit_tree():
	print_debug("MohoImporter exiting tree")
	if _moho_importer:
		remove_import_plugin(_moho_importer)
		_moho_importer = null
		
		for helper in _helpers_in_use:
			remove_helper(helper)
	
	for plugin_name in INSPECTOR_PLUGINS.keys():
		var plugin : EditorInspectorPlugin = get(plugin_name)
		remove_inspector_plugin(plugin)
		set(plugin_name, null)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func add_helper(node: Node, verbose: bool = false) -> void:
	add_child(node)
	_helpers_in_use.append(node)
	
	if verbose:
		print("Adding created scene to Plugin Tree")
		print("Current child count: %s" % [get_child_count()])


func remove_helper(node: Node, verbose: bool = false) -> void:
	if node in _helpers_in_use:
		_helpers_in_use.erase(node)
		remove_child(node)
		node.queue_free()
		if verbose:
			print("Removing created scene to Plugin Tree")
			print("Current child count: %s" % [get_child_count()])

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
