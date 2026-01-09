extends Control

signal card_draw_finished(card: Control)

@export var slot_paths: Array[NodePath] = []
@export var deck_path: NodePath

var _slots: Array[ReferenceRect] = []
var _cards_in_slots: Array[Control] = []
var _deck: Node = null
var _slot_centers: Array[Vector2] = []

@export var wave_enabled: bool = true
@export var wave_amplitude: float = 8.0
@export var wave_frequency: float = 1.5
@export var wave_phase_shift: float = 1.0
@export var draw_animation_duration: float = 0.25
@export var draw_animation_trans: Tween.TransitionType = Tween.TRANS_CUBIC
@export var draw_animation_ease: Tween.EaseType = Tween.EASE_OUT

var _wave_time: float = 0.0


func _ready() -> void:
	_collect_slots()
	_cards_in_slots.resize(_slots.size())
	_slot_centers.resize(_slots.size())
	_resolve_deck()
	_refresh_slot_centers()


func has_space() -> bool:
	for card in _cards_in_slots:
		if card == null:
			return true
	return false


func add_card(card: Control) -> bool:
	return _add_card_internal(card, Vector2.ZERO, false)


func add_card_from_pos(card: Control, from_global_pos: Vector2) -> bool:
	return _add_card_internal(card, from_global_pos, true)


func _process(delta: float) -> void:
	if not wave_enabled:
		_apply_base_positions()
		return
	_wave_time += delta
	for i in range(_cards_in_slots.size()):
		var card := _cards_in_slots[i]
		if card == null:
			continue
		if card.has_method("is_dragging") and card.is_dragging():
			continue
		if card.has_meta("hand_animating") and card.get_meta("hand_animating"):
			continue
		var base := _slot_centers[i]
		if base == Vector2.ZERO and i < _slots.size():
			base = _slots[i].get_global_rect().get_center()
			_slot_centers[i] = base
		if card.has_method("is_hovered") and card.is_hovered():
			card.global_position = base
			continue
		var phase := float(i) * wave_phase_shift
		var wave_offset := sin((_wave_time * wave_frequency) + phase) * wave_amplitude
		card.global_position = Vector2(base.x, base.y + wave_offset)


func _collect_slots() -> void:
	_slots.clear()
	if not slot_paths.is_empty():
		for path in slot_paths:
			var slot := get_node_or_null(path) as ReferenceRect
			if slot != null:
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_slots.append(slot)
	else:
		for child in get_children():
			if child is ReferenceRect:
				(child as ReferenceRect).mouse_filter = Control.MOUSE_FILTER_IGNORE
				_slots.append(child)


func _resolve_deck() -> void:
	if deck_path == NodePath(""):
		_deck = null
		return
	_deck = get_node_or_null(deck_path)


func _find_first_empty_slot() -> int:
	for i in range(_cards_in_slots.size()):
		if _cards_in_slots[i] == null:
			return i
	return -1


func _prepare_card_for_hand(card: Control) -> void:
	if card.has_method("set_face_down"):
		card.set_face_down(false)
	if card.has_method("set_hover_enabled"):
		card.set_hover_enabled(true)
	if card.has_method("set_shadow_visible"):
		card.set_shadow_visible(true)


func _place_card_in_slot(card: Control, slot: ReferenceRect) -> void:
	var rect := slot.get_global_rect()
	card.global_position = rect.get_center()
	card.rotation = slot.rotation


func _add_card_internal(card: Control, from_global_pos: Vector2, animate: bool) -> bool:
	var slot_index := _find_first_empty_slot()
	if slot_index == -1:
		return false
	var slot := _slots[slot_index]
	if card.get_parent() != null:
		card.get_parent().remove_child(card)
	add_child(card)
	_prepare_card_for_hand(card)
	var target := _get_slot_center(slot, slot_index)
	card.rotation = slot.rotation
	if animate and from_global_pos != Vector2.ZERO:
		card.global_position = from_global_pos
		card.set_meta("hand_animating", true)
		var tween := create_tween()
		tween.set_trans(draw_animation_trans)
		tween.set_ease(draw_animation_ease)
		tween.tween_property(card, "global_position", target, draw_animation_duration)
		tween.finished.connect(func() -> void:
			card.set_meta("hand_animating", false)
			_emit_draw_finished(card)
		)
	else:
		card.global_position = target
		call_deferred("_emit_draw_finished", card)
	_cards_in_slots[slot_index] = card
	_slot_centers[slot_index] = target
	_update_z_order()
	return true


func _get_slot_center(slot: ReferenceRect, slot_index: int) -> Vector2:
	var rect := slot.get_global_rect()
	var center := rect.get_center()
	if center == Vector2.ZERO and slot_index < _slot_centers.size():
		center = _slot_centers[slot_index]
	if center == Vector2.ZERO:
		center = rect.position + (rect.size * 0.5)
	return center


func _emit_draw_finished(card: Control) -> void:
	emit_signal("card_draw_finished", card)


func _update_z_order() -> void:
	for i in range(_cards_in_slots.size()):
		var card := _cards_in_slots[i]
		if card != null:
			card.z_index = i


func _refresh_slot_centers() -> void:
	for i in range(_slots.size()):
		_slot_centers[i] = _slots[i].get_global_rect().get_center()


func _apply_base_positions() -> void:
	for i in range(_cards_in_slots.size()):
		var card := _cards_in_slots[i]
		if card == null:
			continue
		var base := _slot_centers[i]
		if base == Vector2.ZERO and i < _slots.size():
			base = _slots[i].get_global_rect().get_center()
			_slot_centers[i] = base
		card.global_position = base
