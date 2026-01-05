extends Node2D

const CARD_SCENE: PackedScene = preload("res://scenes/core/card.tscn")

@export var deck_recipe: DeckRecipe

@export var columns: int = 7
@export var card_scale: float = 0.5
@export var x_spacing: float = 190.0
@export var y_spacing: float = 260.0
@export var start_pos: Vector2 = Vector2(120, 120)

@onready var spawn_root: Node2D = $SpawnRoot

func _ready() -> void:
	if deck_recipe == null:
		push_error("CardSpawnTest: deck_recipe is not assigned in the Inspector.")
		return

	var deck := DeckBuilder.build_shuffled_deck(deck_recipe)

	for i in range(deck.size()):
		var defn: CardDefinition = deck[i]
		var card: Control = CARD_SCENE.instantiate()
		spawn_root.add_child(card)

		if card.has_method("apply_definition"):
			card.apply_definition(defn)

		var col := i % columns
		var row := i / float(columns)
		card.position = start_pos + Vector2(col * x_spacing, row * y_spacing)
		card.scale = Vector2.ONE * card_scale
