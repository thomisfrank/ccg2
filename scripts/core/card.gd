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
@onready var _cardback: Panel = get_node_or_null("CARDBACK") as Panel
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
@export var drag_enabled: bool = true
@export var drag_glow_color: Color = Color(1.0, 0.78, 0.2, 1.0)
@export var drag_glow_strength: float = 1.1
@export var debug_play_delay: float = 0.35

var _base_z_index: int = 0
static var _hover_owner: Node = null
var _hover_enabled: bool = true
var _is_hovered: bool = false
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_restore_z: int = 0
var _is_in_play_area: bool = false

@onready var _drag_glow: ColorRect = get_node_or_null("DragGlow") as ColorRect


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
		_image_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _cardback != null:
		_set_control_mouse_filter_recursive(_cardback, Control.MOUSE_FILTER_IGNORE)
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
		_area.input_event.connect(_on_area_input)
	_configure_drag_glow()


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


func set_face_down(is_face_down: bool) -> void:
	if _cardback != null:
		_cardback.visible = is_face_down
	if _image_slot != null:
		_image_slot.visible = not is_face_down


func set_shadow_visible(shadow_visible: bool) -> void:
	if _shadow != null:
		_shadow.visible = shadow_visible


func _set_control_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		(node as Control).mouse_filter = filter
	for child in node.get_children():
		_set_control_mouse_filter_recursive(child, filter)


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
	if _is_in_play_area:
		return
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
	if not _hover_enabled:
		return
	if _hover_owner != null and _hover_owner != self and is_instance_valid(_hover_owner):
		_hover_owner.call("_apply_thumbnail_mode")
	_hover_owner = self
	_is_hovered = true
	_apply_zoom_mode()


func _on_mouse_exited() -> void:
	if not _hover_enabled:
		return
	if _hover_owner == self:
		_hover_owner = null
	_is_hovered = false
	_apply_thumbnail_mode()


func set_hover_enabled(enabled: bool) -> void:
	_hover_enabled = enabled
	if not enabled:
		_is_hovered = false
	if _area != null:
		_area.input_pickable = enabled
		_area.monitoring = enabled
		_area.monitorable = enabled


func is_hovered() -> bool:
	return _is_hovered


func is_dragging() -> bool:
	return _is_dragging


func _process(_delta: float) -> void:
	if _is_dragging:
		global_position = get_global_mouse_position() + _drag_offset


func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not drag_enabled:
		return
	
	# Handle mouse input
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag()
		else:
			_end_drag()
	
	# Handle touch input
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_drag()
		else:
			_end_drag()


func _start_drag() -> void:
	if _is_dragging:
		return
	_is_dragging = true
	_drag_offset = global_position - get_global_mouse_position()
	_drag_restore_z = z_index
	z_index = hover_z_index + 10
	_set_drag_glow(true)
	_set_play_area_glow(true)
	_apply_zoom_mode()


func _end_drag() -> void:
	if not _is_dragging:
		return
	_is_dragging = false
	_set_drag_glow(false)
	_set_play_area_glow(false)
	var play_area := _get_play_area_under_mouse()
	if play_area:
		_drop_to_play_area(play_area)
	else:
		if _is_hovered:
			_apply_zoom_mode()
		else:
			_apply_thumbnail_mode()
	print("DEBUG drop end: play_area=", play_area, " mouse=", get_global_mouse_position())
	z_index = _drag_restore_z


func _configure_drag_glow() -> void:
	if _drag_glow == null:
		return
	if _drag_glow.material is ShaderMaterial:
		var mat := _drag_glow.material as ShaderMaterial
		mat.set_shader_parameter("glow_color", drag_glow_color)
		mat.set_shader_parameter("glow_strength", drag_glow_strength)
	_drag_glow.visible = false


func _set_drag_glow(enabled: bool) -> void:
	if _drag_glow == null:
		return
	_drag_glow.visible = enabled


func _set_play_area_glow(enabled: bool) -> void:
	get_tree().call_group("play_area", "set_drag_indicator_glow", enabled)


func _get_play_area_under_mouse() -> Control:
	var mouse_pos := get_global_mouse_position()
	for node in get_tree().get_nodes_in_group("play_area"):
		if node is Control:
			var rect := (node as Control).get_global_rect()
			if rect.has_point(mouse_pos):
				print("DEBUG hit play_area:", node.name, "rect=", rect, "mouse=", mouse_pos)
				return node as Control
	return null


func _debug_queue_play() -> void:
	await get_tree().create_timer(debug_play_delay).timeout
	_debug_play_effect()


func _debug_play_effect() -> void:
	if definition == null:
		return
	var mgr = _get_effects_manager()
	if mgr == null:
		print("DEBUG effect: no effects manager found")
		return
	print("DEBUG effect: queue", definition.id, "kind=", definition.kind, "amount=", definition.amount)
	var effect_data: Dictionary = {
		"kind": definition.kind,
		"amount": definition.amount,
		"special_value": definition.special_value,
		"duration_rounds": definition.duration_rounds,
		"source_card": definition.id,
		"target_is_opponent": _get_target_is_opponent(),
	}
	mgr.queue_effect(effect_data)
	mgr.resolve_next()
	_reparent_to_hand_if_needed()


func _get_effects_manager():
	var mgr = get_tree().get_first_node_in_group("effects_manager")
	if mgr != null:
		return mgr
	if get_tree().has_node("/root/EffectsManager"):
		return get_tree().get_node("/root/EffectsManager")
	return null


func _get_target_is_opponent() -> bool:
	if has_meta("target_is_opponent"):
		return bool(get_meta("target_is_opponent"))
	return true


func _drop_to_play_area(area: Control) -> void:
	var parent_hand := get_parent()
	if parent_hand and parent_hand.has_method("remove_card"):
		parent_hand.remove_card(self)
	if get_parent() != area:
		if get_parent():
			get_parent().remove_child(self)
		area.add_child(self)
	global_position = area.get_global_rect().get_center()
	rotation = 0.0
	_is_in_play_area = true
	set_shadow_visible(false)
	_apply_zoom_mode()
	_debug_queue_play()


func _reparent_to_hand_if_needed() -> void:
	# If we later want to snap back after debug play, we could implement here.
	pass
