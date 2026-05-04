# TODO

## Now

- [ ] Finish drawing: **Heart first**, then the 3 most common (**Earth → Metal → Wind**), then the remaining 9 (incl. **Ice at `#0015FF`**).
- [ ] Save SVGs: Element symbols into `assets/elements/`, the Heart into `assets/` (we can rehome it once the world layer takes shape).
- [ ] `! gh auth login` whenever you're back at the prompt — once authed, I'll create the GitHub remote and push.

## Next

- [ ] Camera-bump UI mockup (paper or Figma). Left notch: top-3 / expanded 12-grid / crafting button. Right notch: play / multiplier / robot-head.
- [ ] Raid the *Diablo IV: Lord of Hatred* skill tree for enemy behavior ideas. Rough notes go in `docs/`.

## Soon after

- [ ] Decide camera-bump UI behavior during Exterminate phase (open question in `SPEC.md` §5.3).
- [ ] Pick a license (memory shows CC-BY 4.0 on web projects; choose deliberately for code).
- [ ] Pick a minimum-legible-size target for Element symbols (e.g. "must read at 16×16 px") — sanity-check against the actual SVGs once drawn.

## Then we start coding

- [ ] Set up Godot 4 project structure inside the repo.
- [ ] Implement the MVP vertical slice: 4 Elements (Wood / Metal / Wind / Earth), one revealed big-hex, all four phases minimally functional.
