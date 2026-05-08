# TODO

## Now

- [x] Camera-bump UI mockup (paper or Figma). Left notch: top-3 / expanded 12-grid / crafting button. Right notch: play / multiplier / robot-head.

## Then we start coding

- [x] Set up Godot 4 project structure inside the repo.
- [ ] Implement the MVP vertical slice: 4 Elements (Wood / Metal / Wind / Earth), all four phases minimally functional. Game starts at the standard initial state (Heart + 3 candidate big-hexes) — the player reveals their first big-hex via the first Explore phase, rather than the slice booting into a pre-revealed map.
  - [x] Explore: candidates, reveals, biome markers, resource & enemy seeding.
  - [x] Expand: place / augment units, crafting (recycle), starting wallet endowment. Earth's "fills only the new HP point" rule deferred until combat exists.
  - [x] Exploit: tap to harvest, per-phase budget.
  - [ ] Exterminate: unit half + enemy half, combat resolution, enemy pathing.
- [x] Raid the *Diablo IV: Lord of Hatred* skill trees for enemy (later AI-assisted player unit) behavior ideas, to inform post-slice enemy variety. Notes in `docs/behaviors.md`.
