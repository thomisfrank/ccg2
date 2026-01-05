# res://scripts/cards/DeckBuilder.gd
extends Node
class_name DeckBuilder

static func build_shuffled_deck(recipe: DeckRecipe) -> Array[CardDefinition]:
	var deck: Array[CardDefinition] = []
	for entry in recipe.entries:
		if entry.card == null or entry.copies <= 0:
			continue
		for i in range(entry.copies):
			deck.append(entry.card)
	deck.shuffle()
	return deck
