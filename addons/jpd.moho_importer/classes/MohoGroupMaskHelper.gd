# Sets Group Mask on a given MohoGroup and creates images for the masks.
class_name MohoGroupMaskHelper
extends Reference

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

# List of Moho mask modes. Their index match Moho's masking mode constants.
enum MaskMode {
	MASKED,
	NOT_MASKED,
	ADD_MASK,
	SUB_MASK,
	ADD_MASK_INVIS,
	SUB_MASK_INVIS,
	CLEAR_ADD_MASK,
	CLEAR_ADD_MASK_INVIS,
}

#--- constants ------------------------------------------------------------------------------------

const LIGHT_MASK_DEFAULT_LAYER = 1

const MASKED_MATERIAL = \
	preload("res://addons/jpd.moho_importer/components/canvas_item_light_only_material.tres")

#--- public variables - order: export > normal var > onready --------------------------------------

# List of filepaths from generated images.
var gen_files : Array

#--- private variables - order: export > normal var > onready -------------------------------------

var _verbose : bool = false
var _mask_layer : int = LIGHT_MASK_DEFAULT_LAYER

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _init(options: Dictionary):
	_verbose = options.verbose
	_mask_layer = options.mask_layer

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

# Sets masks on a given MohoGroup.
func set_group_mask(group: MohoGroup) -> void:
	if _verbose:
		print("Setting Group Mask on group %s" % [group.name])
	
	for idx in group.layers.size():
		var sprite : MohoSprite = group.layers[idx] as MohoSprite
		if sprite == null:
			continue
		
		var mask_mode := sprite.get_mask_mode()
		match mask_mode:
			MaskMode.NOT_MASKED:
				if _verbose:
					print("| Set sprite %s as not masked" % [sprite.name])
			MaskMode.MASKED:
				_mask_sprite(sprite, _mask_layer)
				if _verbose:
					print("| Set sprite %s as masked" % [sprite.name])
			MaskMode.ADD_MASK:
				_add_mask(sprite, _mask_layer)
				if _verbose:
					print("| Set sprite %s as mask" % [sprite.name])
			MaskMode.ADD_MASK_INVIS:
				_add_mask(sprite, _mask_layer, true)
				if _verbose:
					print("| Set sprite %s as mask and invisible" % [sprite.name])
			MaskMode.SUB_MASK, MaskMode.SUB_MASK_INVIS, \
			MaskMode.CLEAR_ADD_MASK, MaskMode.CLEAR_ADD_MASK_INVIS:
				var mask_mode_name: String = MaskMode.keys()[mask_mode]
				push_error(
					"Moho Mask Mode mode %s isn't supported | Sprite: %s"
					% [mask_mode_name, sprite.name]
				)
			_:
				push_error("Unknown Mask Mode: %s | Sprite: %s" % [mask_mode, sprite.name])

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _mask_sprite(sprite: MohoSprite, light_mask_layer: int) -> void:
	var sprite_node : Sprite = sprite.node
	sprite_node.material = MASKED_MATERIAL
	sprite_node.light_mask = light_mask_layer


func _add_mask(sprite: MohoSprite, light_mask_layer: int, invisible: bool = false) -> void:
	var sprite_node : Sprite = sprite.node
	
	var light2d_mask := Light2D.new()
	sprite_node.add_child(light2d_mask)
	light2d_mask.owner = sprite_node.owner
	light2d_mask.name = "%sMask" % [sprite_node.name]
	
	var mask_texture := _create_mask_texture(sprite_node.texture)
	light2d_mask.texture = mask_texture
	light2d_mask.offset = sprite_node.offset
	light2d_mask.mode = Light2D.MODE_MIX
	light2d_mask.range_item_cull_mask = light_mask_layer
	
	if invisible:
		sprite_node.modulate = Color.transparent


# Returns a ImageTexture to be used as a Mask on Light2Ds, based on a given texture transparency.
func _create_mask_texture(og_texture: Texture) -> Texture:
	var og_image : Image = og_texture.get_data()
	var mask_image := Image.new()
	mask_image.create(og_image.get_width(), og_image.get_height(), false, Image.FORMAT_RGBA8)
	mask_image.fill(Color.transparent)
	
	og_image.lock()
	mask_image.lock()
	for x in og_image.get_width():
		for y in og_image.get_height():
			var og_color : Color = og_image.get_pixel(x, y)
			var mask_color = Color(1.0, 1.0, 1.0, og_color.a)
			mask_image.set_pixel(x, y, mask_color)
	og_image.unlock()
	mask_image.unlock()
	
	var mask_texture := ImageTexture.new()
	mask_texture.create_from_image(mask_image)
	
	var og_path = og_texture.resource_path
	var mask_path = og_path.replace("." + og_path.get_extension(), "_mask.png")
	_save_resource(mask_path, mask_texture)
	
	return mask_texture


func _save_resource(resource_path: String, resource: Resource) -> void:
	ResourceSaver.save(resource_path, resource)
	resource.take_over_path(resource_path)
	gen_files.append(resource_path)


### -----------------------------------------------------------------------------------------------
