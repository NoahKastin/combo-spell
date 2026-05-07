class_name Element
extends RefCounted

# The 12 Elements. Order and colors match SPEC.md §3.1.
# Enum values double as Dictionary keys for player wallets and tile compositions.

enum Type {
	EARTH,
	METAL,
	WIND,
	WOOD,
	WATER,
	FIRE,
	ICE,
	LIGHTNING,
	ACID,
	POISON,
	DREAD,
	SHADOW,
}

const NAME := {
	Type.EARTH: "Earth",
	Type.METAL: "Metal",
	Type.WIND: "Wind",
	Type.WOOD: "Wood",
	Type.WATER: "Water",
	Type.FIRE: "Fire",
	Type.ICE: "Ice",
	Type.LIGHTNING: "Lightning",
	Type.ACID: "Acid",
	Type.POISON: "Poison",
	Type.DREAD: "Dread",
	Type.SHADOW: "Shadow",
}

const COLOR := {
	Type.EARTH: Color("#000000"),
	Type.METAL: Color("#3F3F3F"),
	Type.WIND: Color("#7F7F7F"),
	Type.WOOD: Color("#00FFD4"),
	Type.WATER: Color("#00D4FF"),
	Type.FIRE: Color("#FF7F00"),
	Type.ICE: Color("#0015FF"),
	Type.LIGHTNING: Color("#FFD400"),
	Type.ACID: Color("#AAFF00"),
	Type.POISON: Color("#FF00D4"),
	Type.DREAD: Color("#FF0055"),
	Type.SHADOW: Color("#AA00FF"),
}

const ICON := {
	Type.EARTH: preload("res://assets/elements/earth.png"),
	Type.METAL: preload("res://assets/elements/metal.png"),
	Type.WIND: preload("res://assets/elements/wind.png"),
	Type.WOOD: preload("res://assets/elements/wood.png"),
	Type.WATER: preload("res://assets/elements/water.png"),
	Type.FIRE: preload("res://assets/elements/fire.png"),
	Type.ICE: preload("res://assets/elements/ice.png"),
	Type.LIGHTNING: preload("res://assets/elements/lightning.png"),
	Type.ACID: preload("res://assets/elements/acid.png"),
	Type.POISON: preload("res://assets/elements/poison.png"),
	Type.DREAD: preload("res://assets/elements/dread.png"),
	Type.SHADOW: preload("res://assets/elements/shadow.png"),
}
