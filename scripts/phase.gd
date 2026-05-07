class_name Phase
extends RefCounted

# The four phases of the cycle (SPEC §2). Each is paired with an Element color
# for the bottom-strip phase indicator (§5.4). The pairing is purely visual.

enum Type { EXPLORE, EXPAND, EXPLOIT, EXTERMINATE }

const NAME := {
	Type.EXPLORE: "Explore",
	Type.EXPAND: "Expand",
	Type.EXPLOIT: "Exploit",
	Type.EXTERMINATE: "Exterminate",
}

const COLOR := {
	Type.EXPLORE: Color("#00FFD4"),     # Wood
	Type.EXPAND: Color("#00D4FF"),      # Water
	Type.EXPLOIT: Color("#FF00D4"),     # Poison
	Type.EXTERMINATE: Color("#FF7F00"), # Fire
}
