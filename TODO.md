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

## After MVP slice

Order is rough-priority: ship to itch.io first so dad gets hands on it, then incremental work. itch.io re-deploys are cheap (re-export, re-upload zip), so each item below can ship to dad as it lands.

- [ ] Ship MVP to itch.io for early family playtest. Recipe in `docs/deployment.md`.
- [ ] Font (§5.6): apply PajamaPants-XBold (already in `assets/fonts/`) via project-default theme so all UI labels (phase strip, multiplier, game-over panel, buttons, grid counts) pick it up. Confirm license terms allow ship-with-app distribution before any public itch.io listing — currently flagged open in §5.6.
- [ ] Saves (§8): JSON, infinite, deletable. Snapshot the autoload (`wallet`, `phase`, `cycles_completed`) plus the scene-level world state (`revealed_big_hexes`, `tiles`, `candidates`, `harvested_this_phase`, `units_acted`). Restore is a scene reload that hydrates from the snapshot instead of `_seed_starting_candidates`. Add a Saves screen reachable from the game-over panel and (eventually) a main menu.
- [ ] Zoom (§5.2): pinch on iOS, scroll-wheel + click-drag pan on macOS. Tile rendering currently always uses the mid-zoom tier; switch to max-in (every Element shown with count, ring layout `6 × 2^n`) and max-out (outline + primary symbol + count) tiers based on the camera's zoom level. Pan bounds stay clamped to revealed territory per §4.1.
- [ ] More Elements: the eight non-MVP Elements — Water (heal, with Wind ≥ 1 to heal others), Fire (next-phase Metal echo on hit), Ice (target skips first action), Lightning (chain on hit), Acid (radius splash on hit), Poison (Metal-damage debuff stacking), Dread (random damage `[Metal, Metal + 2 × Dread]`), Shadow (stealth + reveal timing per §3.4). Wallet and grid already display all 12; just behavior wiring.
- [ ] Status visuals (§3.3): burning (flame), frozen (ice block), poisoned (teardrop) hex backgrounds, composable. Lands alongside Fire / Ice / Poison from the Elements item.
- [ ] Camera-bump completion (§5.3): long-press any Element symbol for its definition tooltip; robot-head button shell in the right notch (opens an AI/automation dialog whose content arrives with the §9 macros item).
- [ ] §9 AI/Automation macros: deterministic local heuristics — harvest patterns ("all of one Element first," "earliest-spawned first," "everything in this region"), attack patterns ("closest to Heart," "lowest-HP enemy," "everything in this direction"), crafting automation while crafting mode is on, replay fast-forward toggle, optional boundary-painted region scoping for any of the above.
- [ ] Replay fast-forward toggle (§4.4): currently fixed at `ENEMY_TURN_DELAY = 0.45s`. Add a per-phase toggle plus an AI-panel default. Could ride on the §9 macros item or land standalone.
- [ ] Ship to TestFlight (Mac) once the slice has grown enough to justify the heavier deploy lift — saves + a few more Elements + at least one AI macro is a sensible bar. Recipe in `docs/deployment.md`.
