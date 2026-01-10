extends Control

@onready var _bleed_counter: Panel = get_node_or_null("Bleed_counter") as Panel
@onready var _bleed_label: Label = get_node_or_null("Bleed_counter/bleed_counter_label") as Label
@onready var _replen_counter: Panel = get_node_or_null("Replen_counter") as Panel
@onready var _replen_label: Label = get_node_or_null("Replen_counter/replen_counter_label") as Label
@onready var _regen_counter: Panel = get_node_or_null("Regen_counter") as Panel
@onready var _regen_label: Label = get_node_or_null("Regen_counter/regen_counter_label") as Label

var _effects_manager: Node = null
var _active_effect_id: String = ""
var _active_kind: String = ""
var _is_opponent_tracker: bool = false

func _ready() -> void:
	_resolve_tracker_side()
	_resolve_effects_manager()
	_wire_signals()
	_reset_effect()

func _resolve_tracker_side() -> void:
	var node: Node = self
	while node != null:
		if node.name.begins_with("Op_"):
			_is_opponent_tracker = true
			return
		node = node.get_parent()


func _resolve_effects_manager() -> void:
	_effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if _effects_manager != null:
		return
	if get_tree().has_node("/root/EffectsManager"):
		_effects_manager = get_tree().get_node("/root/EffectsManager")


func _wire_signals() -> void:
	if _effects_manager == null:
		return
	if _effects_manager.has_signal("effect_resolved"):
		if not _effects_manager.effect_resolved.is_connected(_on_effect_resolved):
			_effects_manager.effect_resolved.connect(_on_effect_resolved)
	if _effects_manager.has_signal("effect_ticked"):
		if not _effects_manager.effect_ticked.is_connected(_on_effect_ticked):
			_effects_manager.effect_ticked.connect(_on_effect_ticked)
	if _effects_manager.has_signal("effect_expired"):
		if not _effects_manager.effect_expired.is_connected(_on_effect_expired):
			_effects_manager.effect_expired.connect(_on_effect_expired)


func _on_effect_resolved(effect_id: String) -> void:
	if _active_effect_id != "":
		return
	if _effects_manager == null or not _effects_manager.has_method("get_effect_data"):
		return
	var effect_data: Dictionary = _effects_manager.get_effect_data(effect_id)
	if effect_data.is_empty():
		return
	var kind_name := _get_kind_name(effect_data)
	if kind_name == "":
		return
	if not _is_target_match(effect_data):
		return
	var duration := int(effect_data.get("duration_rounds", 0))
	if duration <= 0:
		return
	if _effects_manager.has_method("claim_effect"):
		if not _effects_manager.claim_effect(effect_id, str(get_instance_id())):
			return
	_active_effect_id = effect_id
	_active_kind = kind_name
	_show_effect(kind_name, duration)


func _on_effect_ticked(effect_id: String, remaining_rounds: int) -> void:
	if effect_id != _active_effect_id:
		return
	_update_effect(max(remaining_rounds, 0))


func _on_effect_expired(effect_id: String) -> void:
	if effect_id != _active_effect_id:
		return
	_reset_effect()

func _get_kind_name(effect_data: Dictionary) -> String:
	var kind: Variant = effect_data.get("kind", null)
	if typeof(kind) == TYPE_INT:
		if kind == CardDefinition.Kind.BLEED:
			return "bleed"
		if kind == CardDefinition.Kind.REGENERATE:
			return "regen"
		if kind == CardDefinition.Kind.REPLENISH:
			return "replen"
		return ""
	var kind_name := str(kind).to_lower()
	if kind_name == "bleed":
		return "bleed"
	if kind_name == "regenerate":
		return "regen"
	if kind_name == "replenish":
		return "replen"
	return ""


func _is_target_match(effect_data: Dictionary) -> bool:
	var source_is_opponent: bool = bool(effect_data.get("source_is_opponent", false))
	var target_is_opponent: bool = bool(effect_data.get("target_is_opponent", not source_is_opponent))
	return target_is_opponent == _is_opponent_tracker

func _show_effect(kind_name: String, duration: int) -> void:
	_hide_all_panels()
	if kind_name == "bleed":
		if _bleed_counter == null or _bleed_label == null:
			return
		_bleed_counter.visible = true
		_bleed_label.text = str(duration)
	elif kind_name == "regen":
		if _regen_counter == null or _regen_label == null:
			return
		_regen_counter.visible = true
		_regen_label.text = str(duration)
	elif kind_name == "replen":
		if _replen_counter == null or _replen_label == null:
			return
		_replen_counter.visible = true
		_replen_label.text = str(duration)


func _update_effect(remaining_rounds: int) -> void:
	var label: Label = null
	var panel: Panel = null
	if _active_kind == "bleed":
		label = _bleed_label
		panel = _bleed_counter
	elif _active_kind == "regen":
		label = _regen_label
		panel = _regen_counter
	elif _active_kind == "replen":
		label = _replen_label
		panel = _replen_counter
	if label == null:
		return
	label.text = str(remaining_rounds)
	if remaining_rounds <= 0:
		if panel != null:
			panel.visible = false
		_active_effect_id = ""
		_active_kind = ""


func _reset_effect() -> void:
	_active_effect_id = ""
	_active_kind = ""
	_hide_all_panels()

func _hide_all_panels() -> void:
	if _bleed_counter != null:
		_bleed_counter.visible = false
	if _regen_counter != null:
		_regen_counter.visible = false
	if _replen_counter != null:
		_replen_counter.visible = false
