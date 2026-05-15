# Deployment

Two paths to get the slice in front of someone: itch.io (cheap, immediate, browser) and TestFlight on Mac (heavier, deferred until the slice has more depth). Both use accounts the developer already has, so no new subscriptions to set up.

## itch.io (HTML5 — first deploy target)

The fastest way to "playable in any browser, no install."

1. **Export from Godot.** Project → Export → Add… → Web. If the Web export template isn't installed yet, Editor → Manage Export Templates and download for the running 4.3 version. Set the export path to `build/web/index.html` (`build/` is gitignored — create the directory first if it doesn't exist). Click *Export Project* and uncheck *Export with Debug* for the public upload.
2. **Bundle.** Zip the *contents* of `build/web/` so the archive's root holds `index.html`, `index.js`, `index.wasm`, `index.pck`, etc. itch.io extracts the zip and looks for `index.html` at the root — a wrapping folder will hide the entry point.
3. **Upload.** On the project's itch.io page → *Edit game* → *Uploads* → upload the zip → tick *This file will be played in the browser*. Set viewport to `540 × 1170` (a 2:1 downscale of the project's 1170×2532 portrait viewport — fits comfortably in a desktop browser without forcing horizontal scroll). Set the project kind to HTML.
4. **Enable SharedArrayBuffer.** Under the upload's *Embed options*, tick *SharedArrayBuffer support*. Godot 4 web builds need the COOP/COEP headers this option installs; without it the runtime fails to start with a console error.
5. **Save & smoke-test.** Open the page in a private/incognito window before sending the link — that catches missing-asset surprises that don't show up locally.

### Caveats
- The project uses `window/handheld/orientation="portrait"` and a 1170×2532 viewport with `keep_height` aspect (see `project.godot`). At 540×1170 the canvas downscales 2:1 cleanly. On a desktop browser this renders as a tall narrow strip, which is acceptable for a quick share but may feel cramped — revisit the iframe size or stretch settings if anyone complains.
- No save persistence in the browser yet. Until the §8 Saves item lands and gets a localStorage backend, a tab refresh is a new game.
- Dad on iPad / iPhone Safari should get a touch-input experience close to the eventual mobile build, since the engine routes screen-touch events the same way in web exports.

### Re-deploys
Each backlog item that changes gameplay or visuals can ship the same way: re-export, re-zip, replace the upload on the same itch page, save. Players using the embedded link get the new build on next load — no version bump needed.

## TestFlight (Mac — deferred until slice grows)

Use once the slice has saves, more Elements, and at least one AI macro — that's enough depth to justify the heavier deploy lift and give a tester something to chew on across multiple sessions. Outline:

1. **Export macOS bundle.** Project → Export → Add… → macOS. In the preset, fill Bundle Identifier (matching the App Store Connect record), Apple Developer Team ID, signing identity, and tick *App Sandbox* (Mac App Store requires it). Export to `build/mac/ComboSpell.app`.
2. **Codesign + notarize.** Godot's exporter can shell out to `codesign` and `xcrun notarytool` if the credentials in the preset are right. If automation flakes, fall back to `codesign --deep --sign "Developer ID Application: …" build/mac/ComboSpell.app` then `xcrun notarytool submit … --wait`.
3. **Wrap in `.pkg`.** App Store Connect won't accept a bare `.app`; build an installer with `productbuild --component build/mac/ComboSpell.app /Applications build/mac/ComboSpell.pkg --sign "3rd Party Mac Developer Installer: …"`.
4. **Upload.** Transporter (App Store Connect's Mac app) handles the pkg upload. Then App Store Connect → My Apps → Combo Spell → TestFlight tab → invite an internal tester by Apple ID.
5. **Wait + invite.** Build processing usually takes 5–30 min. Dad's invite email arrives once the build flips to *Ready to Test*.

### Caveats
- Sandbox entitlements should stay minimal. The MVP slice needs nothing beyond the default sandbox; once §8 Saves lands, add `com.apple.security.files.user-selected.read-write` (or use `Application Support` via `NSApplicationSupportDirectory`, which the sandbox grants by default).
- Pre-flight the signed `.app` outside TestFlight first: `xattr -cr build/mac/ComboSpell.app` then double-click. If Gatekeeper still blocks, signing or notarization isn't right and TestFlight will reject for the same reason.
- Apple's exact CLI invocations and App Store Connect UI shift between Xcode/macOS releases — verify against current Apple docs before the first upload, especially `notarytool` and Transporter steps.
