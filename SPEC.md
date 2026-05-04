# Combo Spell — Design Specification

## 1. Concept

Defend a central Heart on an infinite hex map by harvesting twelve Elements from resource nodes and enemies, combining them into units that fight back. Units, enemies, and resource nodes are all composed of the same Elements; defeated enemies and harvested nodes return their full Element composition to the player.

Touching the Heart with any enemy is the loss condition.

## 2. Core Loop — The Phase Cycle

Each cycle is four phases in fixed order:

1. **Explore** — uncover one of N candidate big-hexes, seeded with resources and enemies.
2. **Expand** — place new units or augment existing ones; optional crafting.
3. **Exploit** — harvest Elements from resource nodes.
4. **Exterminate** — units act, then enemies act; combat resolves; enemies advance toward the Heart.

**Design discipline**: decisions made in any phase pay off two phases later.
- Explore choices land in Exploit (what you'll have to harvest).
- Expand choices land in Exterminate (what your units can do).
- Exploit choices land in next-cycle Explore (which big-hex is worth uncovering).
- Exterminate choices land in next-cycle Expand (which units survived, what Elements you collected).

This through-line is the spine of the game.

## 3. Elements

Every unit, enemy, and resource node is composed of zero or more Elements. The same Element behaves identically regardless of who possesses it.

**Stacking** is linear by default: 3 Earth on a unit = +3 max HP, 3 Wood on a unit = 3 movement per Exterminate phase. Specific exceptions noted below.

**Active vs passive.** Using an active Element (Metal attack, Water heal) consumes the unit's single action for the Exterminate phase. Earth and Wind never consume actions. Passive triggers (Fire ticks, Lightning chains, Acid splashes, Dread rolls) fire automatically as part of whatever active action causes them.

### 3.1 Element list

The first three are the most common, and form the three starting biomes.

| Element | Hex | Effect |
|---|---|---|
| **Earth** | `#000000` | +1 max HP per stack, beyond the default 1. Healing on a damaged unit fills only the new HP point; it does not also restore previously-lost HP. |
| **Metal** | `#7F7F7F` | Damage on intentional attack (requires Wind ≥ 1) or counter-attack within Wind range − 1. |
| **Wind** | `#FFFFFF` | Range. Required ≥ 1 to attack intentionally; gates many other Elements. |
| **Wood** | `#00FFD4` | Movement (tiles per Exterminate phase). |
| **Water** | `#00D4FF` | Healing up to (Earth + 1). With Wind = 0, only self-heal at amount equal to Water per phase. With Wind ≥ 1, can heal others. |
| **Fire** | `#FF7F00` | When the unit lands a Metal hit, the target also takes that same Metal damage on its next Exterminate phase, regardless of whether the burner is alive or chooses differently then. |
| **Ice** | `#D4FF00` | Hit target skips its first chance to act, then resumes normally. |
| **Lightning** | `#FFD400` | On hit (Metal, Water, Ice, or successful Dread), the same effect chains to one new target within Wind range of the previous target. Each Lightning on the user adds one chain. |
| **Acid** | `#AAFF00` | On hit (Metal, Water, Ice, or successful Dread), the effect splashes to **all** same-side targets within radius equal to the user's Acid score. |
| **Poison** | `#FF00D4` | Poisoned target takes +1 damage from each subsequent Metal hit for the rest of the current Exterminate phase. |
| **Dread** | `#FF0055` | On a Metal attack, damage rolls uniformly from `[Metal, Metal + 2 × Dread]`. Mean = `Metal + Dread`; variance grows with Dread. |
| **Shadow** | `#AA00FF` | Stealth, except in Phase Cycles where the unit reveals itself by using a traceable Element (Metal, Water, Ice, or successful Dread). |

### 3.2 Design tradeoffs

- **Acid vs Lightning** — precision-vs-reach. Acid hits everything close in a fixed radius; Lightning hits a chain of arbitrary length that can travel far across the map.
- **Metal vs Dread** — precision-vs-potency. Metal is exact; Dread trades certainty for higher peaks.

### 3.3 Status visuals

Burning, frozen, and poisoned targets render distinct hex backgrounds, all composable with each other:
- **Burning**: flame pattern.
- **Frozen**: hexagonal ice block.
- **Poisoned**: teardrop pattern.

### 3.4 Shadow reveal timing

Exterminate has two halves: unit half, then enemy half.
- A **unit** that reveals itself in the unit half is targetable by enemies in that same cycle's enemy half.
- An **enemy** that reveals itself in the enemy half is visible to the player until the next enemy half — giving the player one Phase Cycle of opportunity to act before it slips back into Shadow.

### 3.5 Scrapped statistics

Kept here for posterity in case they return: Armor, Chill (frozen-but-not-skipped — judged too weak in theory), Dodge, Knockback / forced-movement.

## 4. Phases (Detail)

### 4.1 Explore

Players see a set of fog-shrouded big-hex candidates adjacent to (often partially overlapping) already-revealed big-hexes. Tap one to remove fog from those 7 tiles.

- **Game start**: 3 candidates, each containing the Heart at one of its corners (bottom, top-right, top-left). The biome marker for these three is randomly assigned from {Earth, Metal, Wind}, one each, distinct.
- **Subsequent Explore rounds**: 6 candidates per round, adjacent to the most-recently-revealed big-hex.
- **Biome markers** are small visible features protruding above the fog, signaling the most-likely Element for that big-hex. Markers stay visible after the fog is lifted, as a reminder of local Element bias.
- **Resource seeding**: total Elements in resource nodes within a newly-revealed big-hex equals `2 × difficulty multiplier` at time of reveal. The biome's Element is guaranteed to appear at least once.
- **Enemy seeding**: total Elements across enemies within a newly-revealed big-hex is up to `2 × difficulty multiplier`. The biome's Element is highly likely (but not guaranteed) on enemies. Enemies do not spawn adjacent to the Heart.
- Resource nodes and enemies cannot share tiles.
- During non-Explore phases, only non-fogged tiles are interactable. Camera panning is bounded so players cannot wander far past revealed territory.

### 4.2 Expand

Place or augment units. No combat occurs.

- **Place a unit**: drag-and-drop an Element from the camera-bump grid onto an empty non-fogged tile. The new unit has 1 max HP plus whatever the dropped Element confers (so Earth → 2 max HP, Wood → 1 HP / 1 movement).
- **Augment a unit**: drag an Element onto an existing unit to add that property; stacks linearly.
- **Health rule**: dropping Earth on a damaged unit raises max HP and fills only the new point. Previously-lost HP is not restored.
- **Crafting**: tap the recycle button to enter crafting mode. While active, drag-and-drop one Element onto another to spend 2 of the dragged Element for 1 of the dropped Element. Tap recycle again to exit. AI automation can drive this from text/voice while in crafting mode.

### 4.3 Exploit

Harvest Elements from resource nodes. The player can harvest up to `difficulty multiplier` Elements per phase.

- **Tap** an Element symbol on a tile to harvest 1.
- **Tap-and-hold** to harvest as many as possible from that symbol in one action, capped by the per-phase budget.
- **AI automation**: pattern-driven harvesting — "all of one Element first," "everything in this region," "earliest-spawned first," etc.

### 4.4 Exterminate

Two halves: **unit half**, then **enemy half**. Sequential resolution within each half.

- The player picks one unit at a time, chooses its single action; that action fully resolves (including all passive triggers — Fire applies, Lightning chains, Acid splashes, Dread rolls) before the next unit is selected. Same for enemies in their half.
- **One action per unit per phase**: each unit either moves up to its Wood, OR uses one active Element. Passive Elements fire automatically as part of whatever active action triggers them.
- **Targeting UX**: tap unit → valid targets/destinations highlight → tap target. Tap unit again to deselect.
- **Enemies head for the Heart by any path**, using their Elements as they go. They instinctively know the Heart's position regardless of distance. They cannot share tiles with each other or with units, and they cannot move onto resource nodes.
- **Replay**: enemy half plays out visually. The player can fast-forward, or pre-set fast-forward as default via the AI panel. A recap is saved and queryable via AI later.

## 5. UI

### 5.1 Drag-and-drop convention

Anywhere "drag-and-drop" is used: tap-to-pick-up (the picked Element enlarges), then tap-to-drop is equivalent. Tapping the source again deselects and aborts.

### 5.2 Zoom

iOS: pinch / pull. macOS: scroll wheel. Pan with one-finger drag (iOS) or click-drag (macOS).

- **Max zoom in**: every Element used in the tile is shown with a count near each symbol. The most-heavily-used Element (or earliest-added in a tie) sits at center; other Elements arrange in concentric rings of `6 × 2^n`, sorted by usage count, then by earliest player addition within each tier.
- **Max zoom out**: each tile shows only its outline color (green/red/blue), the primary Element symbol, and possibly its count.

### 5.3 Camera-bump notches

**Left notch — Element UI**:
- **Default state**: top three player-owned Elements with single-digit count (`?` if > 9).
- **During Explore**: tappable to expand into the full 12-Element grid; tap collapse glyph (e.g. minus) to return.
- **During Expand**: grid forced open; crafting button (recycle glyph) appears.
- **During Exploit**: grid forced open; no extra button.
- **During Exterminate**: TBD (defer until UI prototype).
- **Long-press** any Element symbol for its definition.

The expanded grid is 3 rows × 4 columns:
- Top: Earth, Wood, Water, Shadow
- Middle: Metal, Fire, Poison, Dread
- Bottom: Wind, Ice, Lightning, Acid

**Right notch** (right-to-left):
- **Play button**: end the current phase.
- **Difficulty multiplier**: see §6.
- **Robot-head button**: open AI / automation dialog for the current phase.

## 6. Difficulty Scaling

```
difficulty_multiplier = floor(cycles_completed / 3) + 1
```

| Cycles completed | Multiplier |
|---|---|
| 0–2 | 1 |
| 3–5 | 2 |
| 6–8 | 3 |
| 30 | 11 |
| 100 | 34 |

The multiplier scales:
- resource Elements per newly-revealed big-hex (`= 2 × multiplier`)
- max enemy Elements per newly-revealed big-hex (`= 2 × multiplier`)
- max Elements harvested per Exploit phase (`= multiplier`)

## 7. Map / Hex System

- **Flat-top hexes**, matching Master Dungeon's pipeline.
- **Storage**: axial coordinates `(q, r)` per small hex, with the third coordinate `s = -q - r` derived. Tiles live in a `Dictionary` keyed by `Vector2i(q, r)` so the map is genuinely infinite — only revealed tiles take memory.
- **Algorithms**: cube coordinates for distance, line-drawing, ring/spiral iteration, rotation. Conversion is one line each way.
- **Big-hex (7-tile cluster)**: 1 center + 6 immediate neighbors. Big-hex centers themselves form a hex lattice rotated relative to the small hexes; neighbor offsets in axial: `(3, -1), (2, -3), (-1, -2), (-3, 1), (-2, 3), (1, 2)`. Each big-hex has its own ID, and `(q, r) → big_hex_id` membership is computed on reveal and cached.
- **Heart** sits at axial `(0, 0)`. Game starts in Explore with three candidate big-hexes, each touching `(0, 0)` at a corner.

Reference: Red Blob Games' hex grids guide.

## 8. Saves

- Infinite saves, deletable.
- JSON for now (portable, debuggable). Re-evaluate format only if save size becomes a problem.
- Leaderboard publishing on completion is **not** in MVP — flagged for possible future work.

## 9. AI / Automation

Local heuristic macros, deterministic, ships in the binary:
- "harvest all of one Element first"
- "harvest everything earliest-spawned"
- "attack everything in this direction"
- "attack everything closest to the Heart"
- "target lowest-HP enemies"
- crafting automation while crafting mode is active
- replay fast-forward toggle

LLM upgrade is **deferred**. Only consider if natural-language commands feel necessary in playtesting. On-device (Apple Intelligence, MLX) preferred over cloud.

## 10. MVP Scope

A vertical slice that exercises all four phases minimally:

- **Element set**: Wood (movement), Metal (damage), Wind (range), Earth (max HP). Enough to prove combat.
- **Map**: starting state with Heart and three candidate big-hexes.
- **Single cycle playable**: reveal one big-hex with one resource node and one enemy, harvest, place a unit, attack/move, watch enemy advance.
- **Goal**: ship to TestFlight (or Godot web export) so it can be played on a phone.

## 11. Open Decisions

- License (memory shows CC-BY 4.0 on web projects; pick deliberately for code).
- Heart visual identity (placeholder until first art pass; will be drawn alongside the Element symbols).
- Element symbol minimum legible size target.
- Camera-bump UI behavior during Exterminate phase.
- Music & SFX direction (deferred until core loop is fun).
- Tutorial / first-run UX (the random Earth/Metal/Wind starting biomes give a natural drip; full tutorial design TBD).

## 12. Attribution

Inspired by, in chronological order:
1. ~9-year-old personal 4X notes.
2. *Master Dungeon* — `/Users/noahkastin/Documents/Programming/master-dungeon`.
3. *Combo Spell* (TTRPG) — `/Users/noahkastin/Documents/Game/*-Current Releases/Combo Spell.pdf`.
4. *Diablo IV: Lord of Hatred* skill tree redesign.
