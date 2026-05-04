# Combo Spell

A turn-based hex-strategy game on an infinite hex map. Defend a central Heart by harvesting twelve Elements from resource nodes and enemies, combining them into units that fight back. Every unit, enemy, and resource node is built from the same Element parts — defeated enemies and harvested nodes return their full composition to the player.

Inspired by *Master Dungeon*, the TTRPG *Combo Spell*, the *Diablo IV: Lord of Hatred* skill tree redesign, and ~9-year-old personal 4X notes.

## Status

Design phase. The full design is in [`SPEC.md`](SPEC.md). Code, scenes, and assets to follow.

## Engine and target

- **Engine**: Godot 4 (GDScript)
- **Primary target**: iPhone, portrait orientation
- **Secondary target**: macOS

## Repository layout

```
assets/
  elements/   12 Element symbol SVGs
  biomes/     biome marker art
  ui/         interface art
scenes/       Godot scenes (.tscn)
scripts/      GDScript source
docs/         design notes, references
SPEC.md       canonical design doc
```

## License

TBD.
