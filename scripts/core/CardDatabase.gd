extends Resource
class_name CardDatabase

@export var cards: Array[CardDefinition] = []

func get_by_id(card_id: String) -> CardDefinition:
	for c in cards:
		if c.id == card_id:
			return c
	return null
