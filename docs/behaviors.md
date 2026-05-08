# Behavior Catalog

Candidate behaviors for AI-assisted player units and enemy AI, raided from *Diablo IV: Lord of Hatred* skill trees plus the project's own design slate. Most behaviors are side-agnostic — see SPEC §9 (AI / Automation) for the macro framework. Material here is what *wasn't* already implied elsewhere; obvious behaviors (move toward the Heart, harvest a node) live in SPEC and are not duplicated.

Tickboxes track implementation, not commitment: unchecked = candidate, checked = wired. Items may still be culled or merged before any are implemented.

## Attack an unfogged point

- [ ] Rush / place units near the point. Try to touch it (Exterminate) or place units onto it (Expand) if possible. Only attack once movement is no longer an option.
- [ ] **Exterminate only** — keep to Wind distance, shooting once the target is within range. Move to Wind distance of any defending target as well, if it threatens the unit.

## Defend an unfogged point

- [ ] Rush the point — move (Exterminate) or place units (Expand) close to or onto it. Shoot at or heal targets near it.
- [ ] Encircle the point — build the thickest possible ring of units around it, attacking or healing only after the wall is in place.
- [ ] Defensive curve — same as encircle but for a player-specified arc (120°, 180°, 240°, or 300°) around the point.

## Expand-only

- [ ] Convert all of a specified Element into another specified Element (via crafting).
- [ ] Convert every Element *except* ones specifically excluded into a chosen Element.

## Exploit-only

- [ ] Harvest everything within a specified boundary.
- [ ] Harvest all of a certain Element first.
- [ ] Harvest everything discovered earliest first.
- [ ] Harvest a specified half of everything discovered in the latest Explore phase.

## Exterminate-only

- [ ] Corridor break — attack opposing targets along a straight line from a player-specified start to end point until no opposing targets remain in the line, then fill the corridor and attack anything encroaching on it.

## Player- / enemy-exclusive

- [ ] **Player-exclusive**: defend the Heart (cannot include moving onto it).
- [ ] **Enemy-exclusive**: attack the Heart (cannot shoot it — must touch).
