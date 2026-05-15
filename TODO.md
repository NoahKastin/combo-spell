# TODO

## Now

- [x] Camera-bump UI mockup (paper or Figma). Left notch: top-3 / expanded 12-grid / crafting button. Right notch: play / multiplier / robot-head.

## Then we start coding

- [x] Set up Godot 4 project structure inside the repo.
- [x] Implement the MVP vertical slice: 4 Elements (Wood / Metal / Wind / Earth), all four phases minimally functional. Game starts at the standard initial state (Heart + 3 candidate big-hexes) — the player reveals their first big-hex via the first Explore phase, rather than the slice booting into a pre-revealed map. Remaining sub-items below are in execution order: small refinements to already-shipped phases first (low risk, keeps the slice tight), then the long-pole Exterminate work.
  - [x] Explore: candidates, reveals, biome markers, resource & enemy seeding.
  - [x] Expand: place / augment units, crafting (recycle), starting wallet endowment. Earth's "fills only the new HP point" rule deferred until combat exists.
  - [x] Exploit: tap to harvest, per-phase budget.
  - [x] Explore refinement: subsumed-candidate biome bonus — when a chosen big-hex prunes a previously-offered candidate by fully nesting it inside revealed territory, add the pruned candidate's biome as a guaranteed extra resource node in the chosen big-hex, drawn from its `2 × multiplier` budget (§4.1).
  - [x] Exploit refinement: harvest-budget counter UI — show `remaining/multiplier` in the right-notch slot during Exploit, decrementing on each harvest (§4.3, §5.3).
  - [x] Exterminate: unit half + enemy half, combat resolution, enemy pathing.
  - [x] Game-over polish (surfaced in playtest). The current full-screen red "HEART BREACHED" with no recovery feels jarring. Swap for a standard "Game Over" panel — "Heart Touched" subtitle, echoing §1's loss-condition phrasing — plus a "Play Again" button. Restart should reset the Game autoload state (`wallet` back to `STARTING_WALLET`, `phase` to `EXPLORE`, `cycles_completed` to 0) and call `get_tree().reload_current_scene()` so `_ready` re-seeds the starting candidates and re-creates the Heart sprite. After it works and the slice playtests cleanly end-to-end, commit and push the MVP slice.
- [x] Raid the *Diablo IV: Lord of Hatred* skill trees for enemy (later AI-assisted player unit) behavior ideas, to inform post-slice enemy variety. Notes in `docs/behaviors.md`.
