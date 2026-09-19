# AGENTS.md

Working notes for anyone (human or agent) changing OmaSnap. Users should read
`README.md`; this file is about how the plugin is built, tested and debugged.

## What this is

An Omarchy shell plugin (id `tahayvr.omasnap`, display name **OmaSnap**) that
runs inside the long-lived Quickshell process `omarchy-shell`. It declares two
kinds in `manifest.json`: an `overlay` (`Overlay.qml`, the editor) and a
`bar-widget` (`BarWidget.qml`, the launcher). `keepLoaded: true` keeps the
overlay mounted between summons so the last edit survives.

Capture is delegated to `omarchy capture screenshot <mode> save`; OCR to
`tesseract`; colour sampling and JPEG encoding to ImageMagick; clipboard to
`wl-copy`. The plugin owns only the beautify, annotate and export stage.

## Layout

```
manifest.json          overlay + bar-widget, keepLoaded
Overlay.qml            entry point: shell contract, processes, keyboard, export
BarWidget.qml          bar launcher (summons through bar.shell)
ui/Doc.qml             document state, derived geometry, annotation list model
ui/Stage.qml           the composition that gets grabbed (native pixel size)
ui/Chrome.qml          title bar shared by both cards
ui/CodeBlock.qml       highlighted text sized by its contents
ui/AnnotationLayer.qml annotation delegates, dragging, redaction sampling
ui/Editor.qml          header, viewport, footer, drawing surface
ui/Inspector.qml       settings column
ui/ToolRail.qml        tool strip
ui/controls/           Ui (metrics singleton), IconButton, Chip, Segmented, Dropdown,
                       Swatch, Toggle, LabeledSlider, TextBox, Section; registered in qmldir
lib/Model.js           ratios, gradients, frame geometry, grab size, ids
lib/Redact.js          secret patterns, guards, OCR TSV -> boxes
lib/Code.js            languages, themes, ANSI -> StyledText, language guessing
bin/snap-dir           resolve the screenshot directory the way omarchy does
bin/snap-capture       omarchy capture, print the path it wrote
bin/snap-palette       dominant colours, pushed into a comfortable band
bin/snap-edge          the shot's edge colour, for the inset
bin/snap-ocr           tesseract TSV (redact) or text
bin/snap-deliver       encode + save / copy / clipboard text
bin/snap-pick          system file picker via the portal
bin/snap-portal.py     XDG portal FileChooser client (holds the D-Bus connection)
bin/snap-text          primary selection, else clipboard
bin/snap-highlight     bat -> ANSI
bin/snap-theme         current theme's colors.toml as key=hex lines
tests/                 run.sh runs everything; see Testing
```

## Shell contract (from `$OMARCHY_PATH/shell/README.md` and `shell.qml`)

- The host injects `omarchyPath`, `shell`, `manifest` into the overlay root
  after load. `shell` is a capability-scoped facade (`PluginShellApi.qml`)
  that can only `summon`/`hide`/`toggle`/`isPluginOpen` for this plugin's own
  id.
- `summon <id> <json>` calls `open(payloadJson)`; `hide <id>` calls `close()`.
  `close()` must be idempotent: our own `dismiss()` calls `close()` and then
  `shell.hide()`, which calls `close()` again. Do not close from inside
  without telling the shell, or `toggle` desyncs.
- `call <id> <fn> <arg>` invokes any function on the root item and returns its
  string result (`undefined` becomes `ok`). Public surface: `edit`, `capture`,
  `code`, `pick`, `save`, `copy`, `redact`, `copyText`, `set`, `info`,
  `annotate`.
  Keep those names stable; the README documents them. `info` is not called
  `state` because Item already has a `state` property. An IPC argument that
  starts with `[` is split on commas by the CLI, so `annotate` takes
  `{"items": [...]}` rather than a bare array, and any argument with a
  literal space is split too (use `\u0020` inside JSON strings).
- Bar widgets extend `qs.Ui.BarWidget` and get `bar`, `moduleName`,
  `settings`. `bar.shell` is the same `PluginShellApi` facade the overlay
  gets, wired for every bar entry by `plugins/bar/Bar.qml`, so
  `bar.shell.summon(moduleName, payload)` is the only path the widget needs.
- Payloads: `{"path": "..."}` opens a file, `{"capture": "region|windows|
  fullscreen|smart"}` captures first, `{"code": true}` makes a code card from
  the selection, `{"text": "..."}` from the given text, and `{}` always
  opens the empty starting state (`doc.clearContent()`), never a leftover
  document. Styling settings survive between opens; content does not.

## Document kinds

`doc.kind` is `shot` or `code`. Both report their pixel size through
`shotWidth`/`shotHeight`, so frame geometry, ratio, padding, chrome, shadow,
annotations and export are shared. A code card is measured by `CodeBlock`
(text implicit size plus `codePad`) and pushed into the document; nothing
else may write those two properties in code mode.

Code flow: `code()` -> `bin/snap-text` -> `loadCode()` sets kind, guesses the
language (`Code.guessLanguage`), applies the theme colours, and runs
`bin/snap-highlight` (bat) whose ANSI output `Code.ansiToHtml` turns into
StyledText (`<font color>`, `<b>`, `<i>`, `&nbsp;`, `<br>`). Language, theme
and line-number changes re-run the highlighter; a run that finishes while
another is pending re-runs once more. The `omarchy` theme is bat's `ansi`
theme mapped through `bin/snap-theme`'s palette, refreshed when
`Color.background` changes.

## Rendering model

`Stage` is laid out at the output's native pixel size and displayed scaled by
`viewport.fit`. Export is `grabToImage()` on that same item. Because
`grabToImage` renders the item's own subtree without the item's transform,
the on-screen scale does not matter. Two things do:

- **Device pixel ratio.** `grabToImage(cb, size)` multiplies `size` by the
  window's *effective* DPR (1.6 on a fractionally scaled monitor, while
  `Screen.devicePixelRatio` says 2). `Model.grabSize()` divides it out;
  `scope.dpr` in `Overlay.qml` reads `Window.window.devicePixelRatio`
  (Qt 6.11+). The file can be one pixel off the footer number; that is
  accepted rather than resampling.
- **`doc.exporting`.** Raised for the grab frame; selection outlines and the
  text placeholder bind to it so they never reach the file.

- **Screen units.** `Model.frameGeometry` works in shot pixels, but `Stage`
  lays everything out multiplied by `unit = 1 / dpr`. Effect textures
  (`ClippingRectangle`'s clip, `MultiEffect`) are allocated at item size
  times the window ratio, so this makes them exactly one texel per shot
  pixel, a 1x export is pixel-exact (`tests/qml/render.sh` asserts RMSE 0 on
  the stripe band; live, a native grim region exported at 1x matched with
  RMSE 0), and a viewport fit of 1 is life-size. `AnnotationLayer` and
  `CodeBlock` keep shot-pixel coordinates and are placed with
  `scale: unit`; `Editor.toShot` divides by `fit * unit`.

Both cards stay **visible** and sit *over* their `MultiEffect`, which then
only contributes the shadow. Two reasons, both verified: inside the shell,
descendants of a hidden effect source did not render (they did under the
plain `qml` runtime), and `MultiEffect`'s auto padding shifts its copy of
the source by a fraction of a device pixel, which resamples the screenshot.
The screenshot card is a Quickshell `ClippingRectangle` (rounded clip); the
code card is a plain rounded `Rectangle`. Do not move either back into a
hidden source. Redaction
samples a hidden full-size `Image` through a `ShaderEffectSource` with a tiny
`textureSize` and `smooth: false`: each block is one sample, nothing to
sharpen back. Annotations are stored in screenshot pixel coordinates and the
layer sits at `cardX, cardY + chromeH`.

## QML pitfalls that bit this code (all verified, do not reintroduce)

- **Do not declare a signal named `<property>Changed`.** `Doc.qml` uses
  `annotationsEdited` because `annotationsChanged` belongs to the
  `annotations` property. The duplicate stops the component loading at all.
- **Never use `layer` or `item` as an id.** Every `Item` has a `layer`
  property, and `Loader` makes itself the context object of what it loads and
  exposes `item`. Both shadow the id inside delegates and inline components.
  The layer is `anno`, the delegate is `entry`.
- **Properties on non-root items are not in scope unqualified.** Inside a
  child of `track`, write `track.norm`, not `norm`. The Qt 6 linter reports
  these as `[unqualified]`; the ones left are `doc` (a root property) and
  component ids, which resolve through the scope chain.
- Annotations use the role `uid`, not `id`, to stay clear of the keyword.
- `drag.target` overwrites `x`/`y` bindings; `entry.rebind()` restores them
  after writing the move back into the model.
- Integer properties (`font.pixelSize`) warn on doubles; wrap in `Math.round`.

## Conventions

- Every size, gap and tint in the chrome comes from `ui/controls/Ui.qml`:
  `control` (28) for inspector controls, `button` (32) for header, footer and
  tool buttons, `swatch` (24), `gap` (6) between siblings, `row` (10) between
  rows, `section` (22) between sections, `pad` (16) panel padding, `padX` (12)
  text inset; `fill`/`fillHover`/`fillActive`, `borderActive`, `hairline`,
  `text`/`textMuted`/`textFaint`. Do not hardcode `Style.space(n)` for chrome
  unless it is a one-off width.
- All editor chrome is square: no `radius` on any control, the editor window,
  or the selection outline. Only the exported card has a radius, and that is a
  user setting.
- **Padding and inset are different spacings.** `doc.padding` grows the frame
  around the whole card; `doc.inset` grows the card around the shot and fills
  the new band with the shot's own edge colour, so a screenshot reads as
  having more room inside its window. Both are a percentage of the shot's
  longest edge, and `Model.frameGeometry` returns the resolved `inset` in
  shot pixels. Everything that positions itself against the shot has to add
  it: the `Image`/`CodeBlock` inside the card, `AnnotationLayer`'s origin and
  `Editor.toShot`. The colour comes from `bin/snap-edge`, which samples the
  border ring rather than the whole image, because the most common colour
  overall often belongs to a content area that never touches the edge and
  would leave a visible seam; `doc.shotPalette[0]` is the fallback and a code
  card carries on its own `codeBg`.
- **`doc.frame` is `none` or `titlebar`, nothing else.** There is no
  macOS-style button row: Omarchy windows carry no titlebar buttons, so the
  bar is the title alone. It tints itself from the card underneath rather
  than from the theme, so the frame stays in harmony with what it frames:
  `bin/snap-palette` prints one `#backdrop #source` pair per line, where the
  first is pushed into a background-friendly lightness band (`autoPalette`)
  and the second is the colour as it appears in the image (`shotPalette`);
  `Model.chromeTint` steps that one away from the card and `Model.textOn`
  picks readable title text. A code card tints from `doc.codeBg` instead.
- Headings are uppercase: `Section` titles, the header wordmark and the empty
  state title use `font.capitalization: Font.AllUppercase` with letter
  spacing 1, at caption or bodySmall size.
- Fonts and colours come from the shell singletons `qs.Commons.Style` and
  `qs.Commons.Color` (`Color.menu.*` for the surface).
- Text inside cards is `Text.StyledText`, not `RichText`: it is lighter and
  supports everything the highlighter emits.
- A `Flow` (Segmented, Chip rows) cannot be sized from its own implicit width;
  give it `parent.width` or an explicit width, never `width: implicitWidth`.
- Comments explain a non-obvious why, not what; no banner separators.
- Helper scripts are run as `bash <path>`. Scratch files go to
  `$XDG_RUNTIME_DIR`.
- **This plugin targets Omarchy only, so shipped tools are assumed present.**
  Everything it shells out to is in Omarchy's default package list
  (`/usr/share/omarchy/install/omarchy-base.packages`): `bat`, `imagemagick`,
  `tesseract` + `tesseract-data-eng`, `wl-clipboard`, `python-gobject`,
  `xdg-desktop-portal-gtk` and `xdg-desktop-portal-hyprland`, plus `omarchy`
  itself, which owns capture and the save notification. The rest (`bash`,
  `coreutils`, `findutils`, `gawk`, `grep`, `sed`) come from the Arch `base`
  meta package. Call these directly: no `command -v` probes, no second
  implementation for a machine that lacks one, and no UI copy telling the
  user to install something. Check any new dependency against that package
  list before adding it, rather than writing a fallback for its absence.
  Guards are for genuine runtime conditions (a cancelled picker, a missing
  file, bat rejecting a language), never for a missing package.
- **The file picker is the XDG portal FileChooser**, so it is whatever
  chooser the system's portal configuration names (never assume a specific
  one), driven by `bin/snap-portal.py` with the system Python's GObject
  bindings. `bin/snap-pick` is only the wrapper that runs it. The portal
  closes a request the moment the calling connection disconnects, so
  `busctl`/`gdbus`/`dbus-send` one-shots cannot work; the
  helper keeps the connection open until the `Response` signal. It is run as
  `/usr/bin/python3` explicitly because a linuxbrew or mise `python3` on
  PATH has no `gi`. The overlay hides while `picking` so the dialog (a
  normal window) is not buried under the layer surface.
  `OMASNAP_PICK_TIMEOUT=4 bash bin/snap-pick` flashes the dialog for tests.
- **Scripts that do not read stdin start with `exec </dev/null`.** Quickshell
  gives every child an open stdin pipe that never reaches EOF. `slurp` reads
  boxes from stdin whenever stdin is not a terminal, so without the redirect
  the region picker sat blocked in `anon_pipe_read` for minutes with no
  surface on screen, which looked like a dead bar widget. Only
  `snap-highlight` and `snap-deliver text` read stdin on purpose.
- OCR upscales shots under 2400px (200%) and under 3200px (150%) before
  tesseract, then maps boxes back; 4K is read as is (~6 s, vs ~60 s doubled).
- OCR words under 35% confidence are dropped only when shorter than eight
  characters: tesseract is least confident about exactly the random strings
  worth hiding, and an API key was missed before this rule.
- Redaction guards: Luhn for cards, entropy for bare tokens, and the phone /
  IP guards reject dates, dotted quads, loopback and version strings. Extend
  `PATTERNS`/`CLASSES` in `lib/Redact.js` and add a case to `tests/run.js`.

## Testing

```sh
tests/run.sh
```

1. `node tests/run.js`: unit tests for `lib/*.js`, evaluated in a `vm`
   context with the `.pragma library` line stripped.
2. `bash -n` over `bin/*` and a `snap-dir` sanity check.
3. `/usr/lib/qt6/bin/qmllint` over every QML file with `-I <dir>` where
   `<dir>/qs` is a symlink to `$OMARCHY_PATH/shell`, so `qs.Commons` and
   `qs.Ui` resolve. Only hard categories fail the run. The `qmllint` on PATH
   is the old syntax-only Qt 5 tool and proves nothing.
4. `tests/qml/render.sh`: `tests/qml/Harness.qml` loads `Doc` + `Stage` with
   stub singletons (`tests/qml/stubs/qs/Commons`) and a stub
   `Quickshell.Widgets.ClippingRectangle` (the real one needs the Quickshell
   host), places one of every annotation, exports through `grabToImage`, and
   ImageMagick checks pixels; `HarnessCode.qml` does the same for a code
   card. On a Wayland session each opens a real window for about a second to
   get the GPU; `OMASNAP_TEST_OFFSCREEN=1` uses the
   offscreen platform, which forces the software scene graph, where
   `MultiEffect` renders nothing, so the card checks are skipped there.

Live checks in the running shell, all over IPC (no mouse needed):

```sh
omarchy plugin enable tahayvr.omasnap
omarchy-shell shell summon tahayvr.omasnap '{"path":"/path/to/shot.png"}'
omarchy-shell shell call tahayvr.omasnap capture fullscreen   # non-interactive
printf 'fn main() {}\n' | wl-copy --primary                 # fake a selection
omarchy-shell shell call tahayvr.omasnap code ''
omarchy-shell shell call tahayvr.omasnap set '{"frame":"titlebar","codeNumbers":true}'
omarchy-shell shell call tahayvr.omasnap info ''
omarchy-shell shell call tahayvr.omasnap redact ''
omarchy-shell shell call tahayvr.omasnap save ''
omarchy-shell shell hide tahayvr.omasnap
grim /tmp/x.png                                                # see the overlay
qs log -p "$OMARCHY_PATH/shell" --tail 300 | grep -iE "omasnap|TypeError|ReferenceError"
```

Notes:

- The overlay is `keepLoaded`, so **QML changes need `omarchy restart shell`**;
  saving a file hot-reloads the widget but keeps the old overlay instance.
  If a new root function returns `unknown` over `call`, that is why.
- **Any file written under the plugin directory triggers a plugin reload**,
  including images in `docs/`, and the reload resets the overlay's document
  (`hasContent` goes false, the next `save` answers `no shot`). Generate
  README images into a scratch directory and copy them in afterwards.
- Wait a few seconds between saving plugin files and `omarchy restart shell`.
  Each save triggers an asynchronous reload of the plugin, and exiting while
  that incubation is still finalizing segfaulted Quickshell 0.3.1 in the host
  (`__dynamic_cast` under `QQmlObjectCreator::finalize` during "Exiting due
  to IPC request"). The crash reporter then sits on screen until dismissed.
- After a restart, give the first `summon` a moment: the overlay is loaded
  asynchronously at startup and a screenshot taken right after can miss it.
- `qs log` needs `-p "$OMARCHY_PATH/shell"` to find the instance.
- When killing helpers from a test script, use a pattern that cannot match
  the script's own command line (`pkill -f 'snap-portal[.]py'`); a plain
  `pkill -f name` kills the calling shell too.
- Qt sends messages to journald when stderr is not a terminal. Set
  `QT_FORCE_STDERR_LOGGING=1` when running QML by hand or you will see nothing.
- `/usr/bin/qml` is Qt 5; use `/usr/lib/qt6/bin/qml`.
- Summoning with `{}` and nothing loaded starts a `slurp` region picker and
  blocks other calls with `busy` until it is finished or `pkill -x slurp`.
  `info` reports `capturing` and `busy`; `hyprctl layers -j` lists a
  `selection` namespace while the picker is up, and `/proc/<slurp>/wchan`
  says `anon_pipe_read` if it is stuck on stdin.
- Hyprland's close-window bind (`hl.dsp.window.close()`) closes the window
  *behind* any layer-shell overlay and leaves the overlay up. Verified against
  the stock Emojis overlay too, so it is not fixable in the plugin; Escape,
  the close button and a click on the scrim are the ways out.
- The shell's own linter false positives: `Style.font.*` / `Color.menu.*`
  "not found on QObject" (inline QtObject members), `PanelWindow` "not
  creatable", `bar.shell` on `QObject`. Ignore those.
