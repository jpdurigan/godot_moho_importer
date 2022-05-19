# Resource for parsing Sprite (MeshLayer/ImageLayer) data from Moho projects.
# On Sprites, Group and SwitchLayers, we set their global Transform properties (position,
# rotation and scale).
#
# DIFFERENCES BETWEEN MOHO AND GODOT SPRITES
# In Moho, *translation* gives us the position of this layer (in reference to its parent's position)
# and *origin* is the position of the rotation pivot (in reference to translation/image position
# itself). In Godot, Sprite's *position* is actually the pivot and *offset* is the distance between
# where we want the sprite to appear and the pivot.
# Moho import vectors (MeshLayers) aligned with its parent layer (so its translation would be 0,0)
# and all point positions are saved in reference to that. Since we're importing it as a centered
# sprite, we have to estimate this center position (by getting the rect boundaries of the points
# and averaging the upper left and bottom right points) and used it when converting positions for
# MeshLayers.
# So to get the Sprite's position and offset:
#      - sprite.position = origin (pivot's position) + translation
#      - sprite.offset = center position (where the sprite will be displayed) - origin
# We take off the origin because the offset is a relative distance from the position.
#
#Sprite raw data structure:
#{
#	type = "MeshLayer" or "ImageLayer",
#	name = "name",
#	mesh = { Mesh }, // if MeshLayer
#	image_path = "path" // if ImageLayer
#	origin = { x, y },
#	parent_bone = int,
#	masking = int,
#	transforms = {
#		translation = {},
#		scale = {},
#		rotation_z = {},
#		flip_h = {},
#		flip_v = {}
#	}
#}
class_name MohoSprite
extends MohoRigElement

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

# Reference to Sprite Anchor, a Node2D that is its parent and that can be remote transformed
# if the Sprite is connected to a bone
var anchor : Node2D

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _init(data: Dictionary):
	_raw_data = data
	
	name = _raw_data["name"].get_basename()


func get_class() -> String:
	return "MohoSprite"


func is_class(p_class: String) -> bool:
	return p_class == get_class() or .is_class(p_class)

### -----------------------------------------------------------------------------------------------


### Base Class Methods ----------------------------------------------------------------------------

func _get_raw_property(key: String) -> Dictionary:
	return _raw_data["transforms"][key]


func _get_animated_properties() -> Array:
	return ["translation", "scale", "rotation_z", "flip_h", "flip_v"]


func get_parent_index(_val_index: int = POSE_FRAME) -> int:
	return _raw_data["parent_bone"]

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

# Initializes sprite's initial properties.
func initialize_sprite(sprite_node: Sprite, verbose: bool = false) -> void:
	node = sprite_node
	anchor = node.get_parent() as Node2D
	
	node.name = name
	node.position = _get_property("translation")
	
	var sprite_center_position = (
		_get_mesh_layer_center_position(verbose)
		if _is_vector()
		else Vector2.ZERO
	)
	node.offset = sprite_center_position - _get_origin()
	
	node.scale = _get_property("scale")
	node.rotation = _get_property("rotation_z")
	
	node.flip_h = _get_property("flip_h")
	node.flip_v = _get_property("flip_v")
	
	if verbose:
		print("\nInitalized sprite: %s" % node.name)
		print("| Position: %s" % node.position)
		print("| Scale: %s" % node.scale)
		print("| Rotation: %s" % node.rotation)
		print("| Offset: %s" % node.offset)


# Returns the image filename to set as Texture for this Sprite.
# Empty MeshLayers returns an empty string.
func get_image_filename() -> String:
	var image_filename : String = ""
	if _is_vector():
		var points : Array = _get_points()
		var has_image = not points.empty()
		if has_image:
			image_filename = name
	else:
		var image_path : String = _raw_data["image_path"]
		image_filename = image_path.get_file().get_basename()
	
	return image_filename


# Returns an Array of Curve2D, generated from the layer's vectors.
func get_shapes_as_curves() -> Array:
	var resources : Array = []
	var curves : Array = _get_curves()
	if curves.empty():
		return resources
	
	for idx in curves.size():
		var curve := _get_as_curve2d(idx)
		resources.append(curve)
	return resources


# On MohoSprite, we bind the Bone to the Sprite's anchor.
func get_remote_target() -> Node2D:
	return anchor


func get_mask_mode() -> int:
	return int(_raw_data["masking"])

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _format_property(key: String, raw_value):
	var value = ._format_property(key, raw_value)
	
	if key == "translation":
		value += _get_origin()
	
	return value


func _is_vector() -> bool:
	return _raw_data["type"] == "MeshLayer"


func _get_origin() -> Vector2:
	return _convert_position(_dict_to_vec2(_raw_data["origin"]))


### Mesh Layer Helpers ----------------------------------------------------------------------------

# Returns an estimated position of where the mesh layer is being displayed. We get that by
# converting curve data into Curve2D resources, calculate the total rect from all curves and
# returning the center of said rect.
func _get_mesh_layer_center_position(verbose: bool = false) -> Vector2:
	var curves : Array = _get_curves()
	if curves.empty():
		return Vector2.ZERO
	
	var total_rect := Rect2()
	for idx in curves.size():
		var curve := _get_as_curve2d(idx, verbose)
		var curve_rect := _get_curve2d_rect(curve)
		
		if total_rect.has_no_area():
			total_rect = curve_rect
		else:
			total_rect = total_rect.merge(curve_rect)
	
	var center = total_rect.position + total_rect.size / 2
	if verbose:
		print("| Got mesh layer center position: %s" % [center])
	return center


# Returns a shape's curve as Curve2D, given its index.
func _get_as_curve2d(curve_idx: int, verbose: bool = false) -> Curve2D:
	var curve := Curve2D.new()
	if verbose:
		print("| Creating curve #%02d" % [curve_idx])
	
	var is_closed := _is_curve_closed(curve_idx)
	var points := _get_points_from_curve(curve_idx)
	# We loop twice on the first point if curve is closed.
	var points_to_loop = points.size() + 1 if is_closed else points.size()
	for p_idx in range(points_to_loop):
		var point_index = p_idx % points.size()
		var point_position := _get_point_position(points, point_index)
		var point_handle_in := _get_point_handle_in(points, point_index, is_closed)
		var point_handle_out := _get_point_handle_out(points, point_index, is_closed)
		curve.add_point(point_position, point_handle_in, point_handle_out)
		if verbose:
			print(
				"  | Added point #%02d | Position: %s | In: %s | Out: %s"
				% [p_idx, point_position, point_handle_in, point_handle_out]
			)
	
	return curve


# Returns a Rect2 that encloses all tessellated points of a Curve2D.
func _get_curve2d_rect(curve: Curve2D) -> Rect2:
	var baked_points := curve.tessellate()
	var upper_left := baked_points[0]
	var lower_right := baked_points[0]
	
	for point_position in baked_points:
		if point_position.x < upper_left.x:
			upper_left.x = point_position.x
		if point_position.y < upper_left.y:
			upper_left.y = point_position.y
		if point_position.x > lower_right.x:
			lower_right.x = point_position.x
		if point_position.y > lower_right.y:
			lower_right.y = point_position.y
	
	var curve_rect := Rect2()
	curve_rect.position = upper_left
	curve_rect.end = lower_right
	return curve_rect


# Returns an Array of point data (Dictionary). This includes point's position, width and color.
func _get_points() -> Array:
	return _raw_data["mesh"]["points"]


# Returns an Array of curve data (Dictionary).
func _get_curves() -> Array:
	return _raw_data["mesh"]["curves"]


# Returns an Array of point data (Dictionary) in a given curve.
# This includes all information contained in _get_points(), plus the shape's bezier data.
func _get_points_from_curve(curve_idx: int) -> Array:
	var curve_data : Dictionary = _get_curves()[curve_idx]
	var curve_point_size : int = curve_data["num_points"]
	
	var points : Array = []
	points.resize(curve_point_size)
	
	for curve_point_data in curve_data["points"]:
		var point_idx : int = curve_point_data["point"]
		var point_data : Dictionary = _get_points()[point_idx]
		var curve_point_position : int = _get_curve_point_index(point_data, curve_idx)
		
		# We "merge" both dictionaries, because we need point position from one
		# and its bezier data from another.
		for key in curve_point_data:
			if not key in point_data:
				point_data[key] = curve_point_data[key]
		
		points[curve_point_position] = point_data
	
	return points


func _is_curve_closed(curve_idx: int) -> bool:
	var curve_data : Dictionary = _get_curves()[curve_idx]
	return curve_data["closed"]


# Returns a point's index on the given curve. Gives -1 if point is not on the curve.
func _get_curve_point_index(point_data: Dictionary, curve_idx: int) -> int:
	var curve_point_index := -1
	
	for curve_data in point_data["curves"]:
		if curve_data["curve"] == curve_idx:
			curve_point_index = curve_data["curve_points"]
			break
	
	return curve_point_index


# Returns curve point data (Dictionary) for a given curve and point.
func _get_curve_point_data(curve_data: Dictionary, point_idx: int) -> Dictionary:
	for point_data in curve_data["points"]:
		if point_data["point"] == point_idx:
			return point_data
	return {}


# Returns the initial position (as Vector2) of a given point in a curve.
func _get_point_position(points: Array, point_idx: int) -> Vector2:
	var point_data : Dictionary = points[point_idx]
	var position_dict : Dictionary = _get_point_raw_property(point_data, "position")
	var point_position := _convert_position(_dict_to_vec2(position_dict))
	return point_position


# Returns the handle in vector of a given point in a curve.
func _get_point_handle_in(points: Array, point_idx: int, is_closed: bool) -> Vector2:
	var point_data : Dictionary = points[point_idx]
	
	# We rotate it by 180º degrees, because the function returns the out handle by default.
	var base_angle : float = _get_point_base_angle(points, point_idx, is_closed) - PI
	var offset_in : float = _get_point_raw_property(point_data, "offset_in")
	
	var length : float = _get_point_distance(points, point_idx, point_idx - 1)
	var smoothness : float = _get_point_raw_property(point_data, "smoothness")
	var weight_in : float = _get_point_raw_property(point_data, "weight_in")
	
	return _get_point_handle_vec(base_angle, offset_in, length, smoothness, weight_in)


# Returns the handle out vector of a given point in a curve.
func _get_point_handle_out(points: Array, point_idx: int, is_closed: bool) -> Vector2:
	var point_data : Dictionary = points[point_idx]
	
	var base_angle : float = _get_point_base_angle(points, point_idx, is_closed)
	var offset_out : float = _get_point_raw_property(point_data, "offset_out")
	
	var length : float = _get_point_distance(points, point_idx, point_idx + 1)
	var smoothness : float = _get_point_raw_property(point_data, "smoothness")
	var weight_out : float = _get_point_raw_property(point_data, "weight_out")
	
	return _get_point_handle_vec(base_angle, offset_out, length, smoothness, weight_out)


# Returns the bezier's out handle base angle in radians. To get the base angle for the in handle,
# rotate it by 180 degrees (add or subtract PI).
# Moho saves bezier in and out data using some kind of base angle and adding an offset to it.
# I'm not sure that's how Moho does it, so we're using a rough estimate that is enough to get the
# shape's rect: we use the direction between previous and next points of the curve. If the curve's
# closed, we loop from the first to the last; if not, we cap it at the first or last point.
func _get_point_base_angle(points: Array, point_idx: int, is_closed: bool) -> float:
	var prev_index : int
	if is_closed:
		prev_index = (point_idx - 1) % points.size()
	else:
		prev_index = max(point_idx - 1, 0)
	var prev_position := _get_point_position(points, prev_index)
	
	var next_index : int
	if is_closed:
		next_index = (point_idx + 1) % points.size()
	else:
		next_index = min(point_idx + 1, points.size() - 1)
	var next_position := _get_point_position(points, next_index)
	
	var direction := prev_position.direction_to(next_position)
	var angle := direction.angle()
	return angle


# Returns the distance between two curve's points, using Godot's coordinates.
func _get_point_distance(points: Array, point1_idx: int, point2_idx: int) -> float:
	var point1_pos := _get_point_position(points, point1_idx % points.size())
	var point2_pos := _get_point_position(points, point2_idx % points.size())
	return point1_pos.distance_to(point2_pos)


# Returns the handle (Vector2) for a given point data. Similiar to the way we calculate bezier
# handles in the animation (we have an angle, a size and a percentage), but different calculations.
# To understand the arguments:
#	- base_angle: calculated using the points position, already in Godot's rotation orientation
#	- offset: offset from that base_angle, in Moho's orientation (needs conversion)
#	- length: distance between points in the interpolation, using Godot's coordinates
#	- smoothness: a percentage/multiplier for the size
#	- weight: a percentage/multiplier for the size
#
# We get an unit vector in the handle direction by rotating a Vector2.RIGHT to the sum of both
# angles (the opposite of what Vector2.angle() does) and multiply that to the calculated size
# to get the final handle vector.
func _get_point_handle_vec(
		base_angle: float,
		offset: float,
		length: float,
		smoothness: float,
		weight: float
) -> Vector2:
	var handle_angle := base_angle + _convert_rotation(offset)
	var handle_size := length * smoothness * weight
	var handle_vector := Vector2.RIGHT.rotated(handle_angle) * handle_size
	return handle_vector


func _get_point_raw_property(point_data: Dictionary, property: String, val_index: int = 0):
	return point_data[property]["val"][val_index]

### -----------------------------------------------------------------------------------------------
