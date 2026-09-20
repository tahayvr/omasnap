# AGENTS.md

Things that cost time to find out and cannot be read off the source. Users
want `README.md`; this is the traps, the outside contracts, and how to run it.

OmaSnap is an Omarchy shell plugin (`tahayvr.omasnap`) living inside the
long-lived Quickshell process `omarchy-shell`: an `overlay` (the editor) and a
`bar-widget`, `keepLoaded` so the last edit survives a hide. Capture, OCR,
image encoding and the clipboard are delegated to `omarchy`, `tesseract`,
ImageMagick and `wl-copy`; the plugin owns the beautify, annotate and export
stage only.

## Shell contract

Imposed by the host, so none of it is negotiable from in here.

- The host injects `omarchyPath`, `shell` and `manifest` into the overlay root
  *after* load. `shell` is a capability-scoped facade that can only act on this
  plugin's own id.
- `summon <id> <json>` calls `open(payloadJson)`, `hide <id>` calls `close()`.
  **`close()` must be idempotent**: `dismiss()` calls it and then
  `shell.hide()`, which calls it again. Never close from the inside without
  telling the shell, or `toggle` desyncs.
- `call <id> <fn> <arg>` invokes any root function and returns its string
  result (`undefined` becomes `ok`). Public surface: `edit`, `capture`, `code`,
  `pick`, `save`, `copy`, `redact`, `copyText`, `set`, `info`, `annotate`.
  Keep those names stable; the README documents them. `info` cannot be called
  `state` because `Item` already has one.
- **The CLI splits an argument starting with `[` on commas, and splits on
  literal spaces.** So `annotate` takes `{"items": [...]}` rather than a bare
  array, and any string value needs a literal \u0020 instead of a space.
- Bar widgets get `bar`, `moduleName`, `settings`. `bar.shell` is the same
  facade the overlay gets, wired per entry by the shell's own `Bar.qml`.
- Payloads: `{"path":…}`, `{"capture":"region|windows|fullscreen|smart"}`,
  `{"code":true}`, `{"text":…}`, and `{}` for the empty starting state.
  Styling survives between opens; content does not.

## Rendering

`Stage` is what `grabToImage()` grabs. It is laid out in shot pixels times
`unit = 1 / dpr` and displayed scaled by `viewport.fit`.

- **`grabToImage(cb, size)` multiplies `size` by the window's *effective*
  DPR** — 1.6 on a fractionally scaled monitor, while `Screen.devicePixelRatio`
  claims 2 — and the stage is then not a whole number of logical pixels
  (1210 shot pixels are 756.25). Grabbing it at 757 renders at 757/756.25 and
  resamples everything, and a padding-0 export came out 1101 wide. So the
  export grabs `grabRoot`, a wrapper padded up to whole device pixels
  (`Model.grabSize`), and `snap-deliver` crops the surplus. `Stage.dpr` reads
  `Window.window.devicePixelRatio`.
- **Never draw the shot through a texture round trip.** `ClippingRectangle`,
  `layer.enabled`, `layer.textureSize` and a `MultiEffect` mask all resample
  it on a fractional scale — measured under Quickshell: 8% of the card's
  pixels changed, some by the full 255, while the plain `qml` runtime and the
  test stub came out exact, which is why the harness never saw it. The shot
  is a `Shape` whose `ShapePath.fillItem` is the hidden `Image`: that samples
  the image's own texture one texel per shot pixel, rounded corners included.
- **The `unit` scaling is load-bearing.** The stage is laid out in shot
  pixels times `unit`, so a stage scale of 1 shows the shot life-size and
  the grab is 1:1. `AnnotationLayer` and `CodeBlock` keep shot-pixel
  coordinates and are placed with `scale: unit`; `Editor.toShot` inverts it.
- **The shadow is a `ShaderEffect` too** (`ui/Shadow.qml`,
  `assets/shaders/shadow.frag`): the closed-form Gaussian blur of a rounded
  box, dithered. `MultiEffect`'s shadow stepped into rings at the radii a
  padded frame asks for and broke down past `blurMax` 64, and it needed the
  cards drawn over a hidden copy of themselves. Nothing goes through
  `MultiEffect` now except the wordmark's colorisation.
- **`doc.exporting`** is raised for the grab frame. Anything that must not
  reach the file — selection outlines, the empty-text placeholder — binds to it.
- **Linear ramps are a `ShaderEffect`** (`ui/Ramp.qml`,
  `assets/shaders/ramp.frag`), not a `Rectangle` gradient: an 8-bit ramp
  steps a level every dozen pixels and a dark auto background showed the
  bands. Only noise added *before* quantisation cures that; grain laid over
  the finished gradient leaves the step in the local mean and only hides it
  once it is visible itself (tried at 1% and 4.5%, both rejected). Rebuild
  the `.qsb` with the command in the shader's header after editing it, and
  commit both. Meshes still go through `QtQuick.Shapes`. `half` is a
  reserved word in the shader language qsb compiles.
- Redaction samples a hidden full-size `Image` through a `ShaderEffectSource`
  with a tiny `textureSize` and `smooth: false`, so each block is one sample
  with nothing to sharpen back out.

## QML traps, all paid for once already

- **Never declare a signal named `<property>Changed`.** `annotationsChanged`
  belongs to the `annotations` property; the duplicate stops the component
  loading at all. Hence `annotationsEdited`.
- **Never use `layer` or `item` as an id.** Every `Item` has a `layer`, and
  `Loader` exposes `item` as the context object of what it loads. Both shadow
  the id inside delegates.
- **A `GradientStop`'s `parent` is not the item being painted.** Reaching a
  property of the `Rectangle` through `parent` from inside its `Gradient`
  silently yields nothing — every gradient swatch came out black. Use an id.
- **A `Repeater` cannot live inside a `Gradient`.** That is why gradient stops
  are padded to a fixed count and bound one by one.
- **A `Text` with a proportional `lineHeight` measures taller than it looks**;
  Qt hangs the extra spacing below every line, the last included.
- **Typing into a `TextInput` breaks its `text` binding for good.** Anything
  that also displays a live value has to restore it with `Qt.binding`.
- **A `Flow` cannot be sized from its own implicit width.** Give it
  `parent.width` or an explicit width.
- Properties on non-root items are not in scope unqualified: write
  `track.norm`, not `norm`. The Qt 6 linter flags these `[unqualified]`.
- Annotations use the role `uid`, not `id`, to stay clear of the keyword.
- `drag.target` overwrites `x`/`y` bindings; restore them after writing a move
  back into the model.
- Integer properties such as `font.pixelSize` warn on doubles; `Math.round`.
- **The Qt engine reports an escaped slash as `\\/` in `RegExp.source`**, so
  a pattern rebuilt from `.source` (`findSensitive` does, to add `g`) never
  matches one. Write slashes as `[/]`. Node shows nothing wrong; the unit
  test scans the patterns for it.
- A tooltip left inside its own button is painted under whatever panel is a
  later sibling. `ui/controls/Tooltip.qml` reparents to the window content item
  for that reason, and computes its position on show, since `mapToItem` is a
  one-off.
- A code card's size must be **bound** to `CodeBlock`, never pushed on a change
  signal: rendering the same snippet twice leaves the natural size unchanged,
  so the signal never fires and the card comes up empty.

## Platform

- **This plugin targets Omarchy only, so shipped tools are assumed present.**
  Everything it shells out to is in
  `/usr/share/omarchy/install/omarchy-base.packages`; the rest comes from the
  Arch `base` meta package. Call them directly — no `command -v` probes, no
  second implementation for a machine that lacks one, no UI copy telling the
  user to install something. Check a new dependency against that list rather
  than writing a fallback. Guards are for real runtime conditions (a cancelled
  picker, a missing file, bat rejecting a language), never a missing package.
- **Scripts that do not read stdin start with `exec </dev/null`.** Quickshell
  gives every child an open stdin pipe that never reaches EOF, and `slurp`
  reads boxes from stdin whenever stdin is not a terminal — the region picker
  sat blocked in `anon_pipe_read` for minutes with no surface on screen, which
  looked like a dead bar widget. Only `snap-highlight` and `snap-deliver text`
  read stdin on purpose.
- **The file picker is whatever the XDG portal is configured to use** — never
  assume a particular chooser. The portal closes a request the moment the
  calling connection disconnects, so `busctl`/`gdbus`/`dbus-send` one-shots
  cannot work; `bin/snap-portal.py` holds the connection until the `Response`
  signal. It runs as `/usr/bin/python3` explicitly, because a linuxbrew or mise
  `python3` on PATH has no `gi`. The overlay hides while `picking` so the
  dialog is not buried under the layer surface.
  `OMASNAP_PICK_TIMEOUT=4 bash bin/snap-pick` flashes it for a test.
- **Qt's image cache is keyed on the URL**, so reopening a file that changed
  under the same path hands back the old picture at the old size. Every load
  bumps `doc.shotRevision`, which rides on the URL as a fragment.
- OCR upscales shots under 2400px to 200% and under 3200px to 150%, then maps
  boxes back; a 4K grab is read as is, because doubling it takes ~60s against
  ~6s. Words under 35% confidence are dropped only when shorter than eight
  characters — tesseract is least confident about exactly the random strings
  worth hiding, and an API key was missed before that rule.
- Code card theme keys are Omarchy theme *directory* names, resolved at
  runtime from `omarchy theme list`. Never add a bat theme whose key could
  collide with one — bat's Nord was dropped for exactly that.
- Redaction guards: Luhn for cards, entropy for bare tokens, and the phone and
  IP guards reject dates, dotted quads, loopback and version strings. Extend
  `PATTERNS`/`CLASSES` in `lib/Redact.js` *and* add a case to `tests/run.js`.
- Scratch files go to `$XDG_RUNTIME_DIR`, never the plugin directory.

## House style

- Every size, gap and tint in the editor chrome comes from
  `ui/controls/Ui.qml`. Do not hardcode `Style.space(n)` unless it is a
  genuine one-off width.
- All editor chrome is square. Only the exported card has a radius, and that
  is a user setting.
- Section titles and the wordmark are uppercase with letter spacing 1.
- Fonts and colors come from `qs.Commons.Style` and `qs.Commons.Color`.
- Text inside cards is `Text.StyledText`, not `RichText`.
- Comments explain a non-obvious why, never a what. No banner separators.

## Testing

```sh
tests/run.sh
```

JavaScript unit tests in a `vm` context; `bash -n` over `bin/*`;
`/usr/lib/qt6/bin/qmllint` (the `qmllint` on PATH is the Qt 5 syntax-only tool
and proves nothing); then `tests/qml/render.sh`, which drives the real
components and checks exported pixels with ImageMagick.

- On a Wayland session the harnesses open a real window for about a second to
  get the GPU. `OMASNAP_TEST_OFFSCREEN=1` forces the offscreen platform.
- Whether the card rendered is decided by **sampling the exported picture**,
  not by the backend name — what the software scene graph can draw varies by
  Qt and Mesa build.
- The harnesses take their output directory as the last argument, and
  `render.sh` points it at `$XDG_RUNTIME_DIR`. See the reload note below.

Live checks in the running shell, no mouse needed:

```sh
omarchy-shell shell summon tahayvr.omasnap '{"path":"/path/to/shot.png"}'
omarchy-shell shell call tahayvr.omasnap capture fullscreen   # non-interactive
printf 'fn main() {}\n' | wl-copy --primary                   # fake a selection
omarchy-shell shell call tahayvr.omasnap code ''
omarchy-shell shell call tahayvr.omasnap set '{"frame":"titlebar"}'
omarchy-shell shell call tahayvr.omasnap info ''
omarchy-shell shell call tahayvr.omasnap save ''
qs log -p "$OMARCHY_PATH/shell" --tail 300 | grep -iE "omasnap|TypeError"
```

- The overlay is `keepLoaded`, so **QML changes need `omarchy restart shell`**.
  A new root function answering `unknown` over `call` is why.
- **Any file written under the plugin directory triggers a plugin reload**, and
  the reload resets the overlay's document — `hasContent` goes false and the
  next `save` answers `no shot`. Generate images into a scratch directory and
  copy them in afterwards.
- **Wait a few seconds between saving plugin files and restarting the shell.**
  Each save starts an asynchronous reload, and exiting mid-incubation
  segfaulted Quickshell 0.3.1 (`__dynamic_cast` under
  `QQmlObjectCreator::finalize`). The crash reporter then sits on screen.
- After a restart, give the first `summon` a moment: the overlay loads
  asynchronously and a screenshot taken immediately can miss it.
- **A locked screen wedges every screen capture.** `grim` blocks in `poll`,
  `grabToImage` never calls back, and the plugin's export sits at `busy`
  forever. Nothing in the symptoms points at the lock. Check it first.
- A capture blocks other calls with `busy` until `slurp` finishes or
  `pkill -x slurp`. `/proc/<slurp>/wchan` says `anon_pipe_read` if it is
  stuck on stdin.
- Qt logs to journald when stderr is not a terminal; set
  `QT_FORCE_STDERR_LOGGING=1` when running QML by hand or you see nothing.
  `/usr/bin/qml` is Qt 5 — use `/usr/lib/qt6/bin/qml`.
- When killing helpers from a script, use a pattern that cannot match the
  script's own command line (`pkill -f 'snap-portal[.]py'`); a plain
  `pkill -f name` kills the calling shell too.
- Hyprland's close-window bind closes the window *behind* a layer-shell
  overlay and leaves the overlay up. Verified against the stock Emojis overlay,
  so it is not fixable here; Escape, the close button and the scrim are the
  ways out.
- Shell linter false positives to ignore: `Style.font.*` / `Color.menu.*` "not
  found on QObject", `PanelWindow` "not creatable", `bar.shell` on `QObject`.
