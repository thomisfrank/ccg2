extends Control

@export var definition: CardDefinition

@onready var _suit_panel: Panel = $"SuitColor"
@onready var _title_label: Label = $"Title_ValueFrame/CardData/Title"
@onready var _balance_title_label: Label = $"Title_ValueFrame/BalanceCardData/Title"
@onready var _value_label: Label = $"Title_ValueFrame/CardData/Value"
@onready var _balance_row: HBoxContainer = $"Title_ValueFrame/BalanceCardData"
@onready var _standard_row: HBoxContainer = $"Title_ValueFrame/CardData"
@onready var _description_label: Label = $"DescriptionFrame/Description"
@onready var _image_slot: ColorRect = get_node_or_null("imageSlot") as ColorRect
@onready var _image_sprite: Sprite2D = get_node_or_null("imageSlot/IMAGE") as Sprite2D
@onready var _balance_icon: Sprite2D = $"Title_ValueFrame/BalanceCardData/BalanceIcon"
@onready var _effect_tag: Panel = $"DescriptionFrame/EffectTag"
@onready var _effect_label: Label = $"DescriptionFrame/EffectTag/EffectLabel"
@onready var _thumb_value_label: Label = $"THUMBvalue"
@onready var _area: Area2D = $"Area2D"
@onready var _title_frame: Panel = $"Title_ValueFrame"
@onready var _description_frame: Panel = $"DescriptionFrame"
@onready var _shadow: Panel = $"Shadow"

var _image_target_size: Vector2
@export var image_target_size: Vector2 = Vector2.ZERO
const BALANCE_ICON: Texture2D = preload("res://assets/Card/Icons/BalanceIcon.png")

@export var thumbnail_scale: float = 0.5
@export var zoom_scale: float = 1.0
@export var hover_z_index: int = 100

var _base_z_index: int = 0
static var _hover_owner: Node = null


func _ready() -> void:
	if _image_sprite == null:
		_image_sprite = get_node_or_null("IMAGE") as Sprite2D
	_ensure_unique_shader()
	_cache_image_target_size()
	_base_z_index = z_index
	_shadow.z_as_relative = false
	_shadow.z_index = _base_z_index
	if _image_slot != null:
		_image_slot.clip_contents = true
	if definition == null:
		_apply_thumbnail_mode()
	else:
		apply_definition(definition)
		_apply_thumbnail_mode()
	if _area != null:
		_area.input_pickable = true
		_area.monitoring = true
		_area.monitorable = true
		_area.mouse_entered.connect(_on_mouse_entered)
		_area.mouse_exited.connect(_on_mouse_exited)


func apply_definition(defn: CardDefinition) -> void:
	definition = defn
	var title_text := defn.id.strip_edges()
	if title_text.is_empty():
		title_text = CardDefinition.Kind.keys()[defn.kind].capitalize()
	_title_label.text = title_text
	_balance_title_label.text = title_text
	_value_label.text = _get_value_text(defn)
	_thumb_value_label.text = _get_thumb_value_text(defn)
	_description_label.text = defn.get_description()
	if defn.kind == CardDefinition.Kind.REGENERATE:
		_title_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		_value_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		_description_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	else:
		_title_label.remove_theme_color_override("font_color")
		_value_label.remove_theme_color_override("font_color")
		_description_label.remove_theme_color_override("font_color")

	var icon_texture := defn.get_icon()
	if icon_texture != null:
		_set_image_texture(icon_texture)
	_balance_icon.texture = BALANCE_ICON

	var is_balance := defn.kind == CardDefinition.Kind.BALANCE
	_balance_row.visible = is_balance
	_standard_row.visible = not is_balance

	_apply_suit_colors(defn.suit)
	_apply_effect_tag(defn.special_value)


func _apply_suit_colors(suit_value: String) -> void:
	var colors := CardDefinition.get_suit_colors(suit_value)
	if colors.is_empty():
		return
	var panel_material := _suit_panel.material
	if panel_material is ShaderMaterial:
		panel_material.set_shader_parameter("base_color", colors["a"])
		panel_material.set_shader_parameter("smoke_color", colors["b"])
	var thumb_color: Color = colors["b"]
	thumb_color.a = 62.0 / 255.0
	_thumb_value_label.add_theme_color_override("font_color", thumb_color)


func _get_value_text(defn: CardDefinition) -> String:
	match defn.kind:
		CardDefinition.Kind.DISCARD, CardDefinition.Kind.REPLENISH:
			return str(defn.count)
		CardDefinition.Kind.BALANCE:
			return ""
		_:
			return str(defn.amount)


func _get_thumb_value_text(defn: CardDefinition) -> String:
	match defn.kind:
		CardDefinition.Kind.BALANCE:
			return ""
		CardDefinition.Kind.DISCARD, CardDefinition.Kind.REPLENISH:
			return "%02d" % defn.count
		_:
			return "%02d" % defn.amount


func _apply_effect_tag(special_value: String) -> void:
	var normalized := special_value.to_lower()
	if normalized == "persistent":
		_effect_label.text = "Persistent Effect"
		_effect_tag.visible = true
	elif normalized == "dynamic":
		_effect_label.text = "Dynamic Effect"
		_effect_tag.visible = true
	else:
		_effect_tag.visible = false


func _ensure_unique_shader() -> void:
	var panel_material := _suit_panel.material
	if panel_material is ShaderMaterial:
		var unique_material: ShaderMaterial = panel_material.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(get_instance_id())
		unique_material.set_shader_parameter("time_offset", rng.randf_range(0.0, 10.0))
		_suit_panel.material = unique_material


func _cache_image_target_size() -> void:
	if image_target_size != Vector2.ZERO:
		_image_target_size = image_target_size
		return
	if _image_slot != null:
		var slot_size := _image_slot.size
		if slot_size == Vector2.ZERO:
			slot_size = _image_slot.custom_minimum_size
		_image_target_size = slot_size
		return
	if _image_sprite.texture == null:
		_image_target_size = Vector2.ZERO
		return
	var texture_size := _image_sprite.texture.get_size()
	_image_target_size = Vector2(
		texture_size.x * _image_sprite.scale.x,
		texture_size.y * _image_sprite.scale.y
	)


func _set_image_texture(texture: Texture2D) -> void:
	_image_sprite.texture = texture
	_fit_image_to_target()


func _fit_image_to_target() -> void:
	if _image_target_size == Vector2.ZERO:
		_cache_image_target_size()
		if _image_target_size == Vector2.ZERO:
			return
	var texture := _image_sprite.texture
	if texture == null:
		return
	var texture_size := texture.get_size()
	if texture_size.x == 0 or texture_size.y == 0:
		return
	var scale_factor: float = max(
		_image_target_size.x / texture_size.x,
		_image_target_size.y / texture_size.y
	)
	_image_sprite.scale = Vector2.ONE * scale_factor
	if _image_slot != null:
		_image_sprite.position = _image_target_size * 0.5


func _apply_text_scale_from_parent() -> void:
	if scale.x == 0 or scale.y == 0:
		return
	var inverse := Vector2(1.0 / scale.x, 1.0 / scale.y)
	_title_label.scale = inverse
	_balance_title_label.scale = inverse
	_value_label.scale = inverse
	_description_label.scale = inverse
	_effect_label.scale = inverse


func _apply_thumbnail_mode() -> void:
	scale = Vector2(thumbnail_scale, thumbnail_scale)
	_thumb_value_label.visible = true
	_title_frame.visible = false
	_description_frame.visible = false
	z_index = _base_z_index


func _apply_zoom_mode() -> void:
	scale = Vector2(zoom_scale, zoom_scale)
	_thumb_value_label.visible = false
	_title_frame.visible = true
	_description_frame.visible = true
	z_index = hover_z_index
	_apply_text_scale_from_parent()


func _on_mouse_entered() -> void:
	if _hover_owner != null and _hover_owner != self and is_instance_valid(_hover_owner):
		_hover_owner.call("_apply_thumbnail_mode")
	_hover_owner = self
	_apply_zoom_mode()


func _on_mouse_exited() -> void:
	if _hover_owner == self:
		_hover_owner = null
	_apply_thumbnail_mode()
