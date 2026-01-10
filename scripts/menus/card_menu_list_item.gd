extends Control

signal card_selected(card: Control)

@onready var _bg: Panel = get_node_or_null("BG") as Panel
@onready var _title: Label = get_node_or_null("BG/Title") as Label
@onready var _card_image: Panel = get_node_or_null("Card_Image") as Panel

var _bg_material: ShaderMaterial = null
var _card_ref: Control = null

func _ready() -> void:
	_cache_material()
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_set_children_mouse_filter(Control.MOUSE_FILTER_IGNORE)

func set_card_from_control(card: Control) -> void:
	if card == null:
		_clear()
		return
	_card_ref = card
	var defn: CardDefinition = null
	if card.has_method("get"):
		defn = card.get("definition") as CardDefinition
	if defn == null:
		_clear()
		return
	if _title != null:
		_title.text = _get_card_title(defn)
	_apply_suit_gradient(defn)
	_apply_card_image(card)

func _cache_material() -> void:
	if _bg == null or not (_bg.material is ShaderMaterial):
		return
	_bg_material = (_bg.material as ShaderMaterial).duplicate()
	_bg.material = _bg_material

func _get_card_title(defn: CardDefinition) -> String:
	var title_text := str(defn.id).strip_edges()
	if title_text.is_empty():
		title_text = CardDefinition.Kind.keys()[defn.kind].capitalize()
	return title_text

func _apply_suit_gradient(defn: CardDefinition) -> void:
	if _bg_material == null:
		return
	var colors := CardDefinition.get_suit_colors(str(defn.suit))
	if colors.is_empty():
		return
	_bg_material.set_shader_parameter("base_color", colors["a"])
	_bg_material.set_shader_parameter("smoke_color", colors["b"])

func _apply_card_image(card: Control) -> void:
	if _card_image == null:
		return
	var sprite := card.get_node_or_null("imageSlot/IMAGE") as Sprite2D
	if sprite == null:
		sprite = card.get_node_or_null("IMAGE") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var style := StyleBoxTexture.new()
	style.texture = sprite.texture
	_card_image.add_theme_stylebox_override("panel", style)

func _clear() -> void:
	if _title != null:
		_title.text = ""
	_card_ref = null

func get_card_ref() -> Control:
	return _card_ref

func _on_gui_input(event: InputEvent) -> void:
	if _card_ref == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_selected.emit(_card_ref)
	if event is InputEventScreenTouch and event.pressed:
		card_selected.emit(_card_ref)

func _set_children_mouse_filter(filter: Control.MouseFilter) -> void:
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = filter
