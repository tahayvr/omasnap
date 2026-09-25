<p align="center">
  <img src="assets/logo/postcard-logo.png" alt="Postcard" width="560">
</p>

<p align="center">
  <a href="https://omarchy.org"><img src="https://raw.githubusercontent.com/tcballard/omarchy-badges/3ee85c9ea63c83845b992f8acb086c4a69cca12a/badges/v1/built-for-omarchy.svg" alt="Built for Omarchy"></a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#install">Install</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#keys">Keys</a> ·
  <a href="#scripting">Scripting</a> ·
  <a href="#dependencies">Dependencies</a> ·
  <a href="#licence">Licence</a>
</p>

Make a screenshot worth posting. Postcard is an [Omarchy](https://omarchy.org)
shell plugin: grab a region and it adds padding, a background,
rounded corners and a shadow, lets you annotate, and hides anything in
the picture that should not be public.

![Postcard editor](assets/showcase/screenshot-full.jpg)

## Features

**Framing**

- Padding, aspect ratio presets, corner radius, crop, shadow and an optional title bar
- Inset, which extends the screenshot's own edge color outwards to give a
  cramped window room to breathe
- Several shots on one card, side by side or stacked, each in a card of its
  own. Larger ones are scaled down to line up, or keep their sizes; each can
  be cropped, reordered or removed, and an arrow can point from one to another

![Framing](assets/showcase/framing.png)

**Backgrounds**

- Auto from the screenshot, gradients, flat colors, your Omarchy theme, your wallpaper,
  or none for a transparent PNG
- Your own colors and gradients: a picker with a screen eyedropper, and saved
  gradients of two to four colors at any angle, kept across restarts

![Backgrounds](assets/showcase/backgrounds.png)

**Annotation**

- Arrows, boxes, ellipses, highlighter, text labels and numbered steps
- Spotlight a rectangle or an ellipse and the rest of the screenshot dims,
  leaving the background as it is
- Magnify: drag over a detail and a zoomed lens (2×, 3× or 4×) appears beside it,
  joined by a line; move the lens and the magnified spot separately
- Drag to move, and they stay pinned to the screenshot when you reframe

![Annotations](assets/showcase/annotations.png)

**Hide sensitive data**

- One click pixelates emails, API keys, JWTs, AWS and GitHub tokens, card
  numbers, IBANs, IP addresses and phone numbers, each category switchable
- Card numbers are Luhn-checked; dates, versions, hashes and loopback
  addresses are left alone
- Pixelation is destructive, not a blur that can be undone
- Or copy the screenshot's text to the clipboard

![Hiding sensitive data](assets/showcase/redaction.png)

**Code cards**

- Any selected text becomes a syntax-highlighted card in the same frame
- Language detected or chosen, font size, line numbers
- Every Omarchy theme you have installed, plus Dracula, Monokai, One Dark,
  GitHub and Solarized

![Postcard code card preview](assets/showcase/screenshot-full-code.jpg)

**Presets**

- Save the whole look (background, framing, corners, shadow, export settings and
  code card style) as a named preset and switch between them from the top of the
  panel; annotations are never part of one
- The preset you pick stays in use after a restart, so it is where every capture
  starts
- Kept in `~/.config/postcard/presets.json`

**Output**

- Clipboard or disk, PNG or JPEG, at 1x, 2x or 3x
- The preview is the file

## Install

```sh
omarchy plugin add https://github.com/tahayvr/postcard.git --enable
```

Update it with `omarchy plugin update tahayvr.postcard`

Remove it with `omarchy plugin remove tahayvr.postcard`,

or `omarchy plugin disable tahayvr.postcard` to keep it installed but off.

Plugins run as unsandboxed code inside your shell process. Read the source
before you enable it.

## Usage

Enabling the plugin puts a Postcard button 󰆟 in the bar. Left-click it to grab a
region or window, middle-click to make a code card from the selected text, right-click
for a menu: region, window, screen with an optional delay, code card, or the editor. Move it with:

```sh
omarchy bar move tahayvr.postcard --section center
```

Or bind keys in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + PRINT", "Postcard", "omarchy-shell shell summon tahayvr.postcard '{\"capture\":\"region\"}'")
o.bind("SUPER + SHIFT + C", "Postcard code card", "omarchy-shell shell summon tahayvr.postcard '{\"code\":true}'")
o.bind("SUPER + SHIFT + S", "Postcard editor", "omarchy-shell shell toggle tahayvr.postcard '{}'")
```

The buttons at the top of the editor grab a region, window or screen, make a
code card, or open a file. A code card takes the primary selection, or the
clipboard if nothing is highlighted.

### Keys

| Key                                              | Action                                                                  |
| ------------------------------------------------ | ----------------------------------------------------------------------- |
| `V`, `A`, `R`, `O`, `T`, `S`, `H`, `B`, `L`, `M`, `C` | move, arrow, box, ellipse, text, step, highlight, hide, spotlight, magnify, crop |
| `Ctrl+C` / `Ctrl+S`                              | copy / save                                                             |
| `Ctrl+C`, `Ctrl+X`, `Ctrl+V`, `Ctrl+D`           | With annotations selected: copy, cut, paste, duplicate them             |
| `Ctrl+Shift+S`                                   | Save as, through the system file dialog                                 |
| `Ctrl+Z`                                         | undo                                                                    |
| `Ctrl+Shift+Z` / `Ctrl+Y`                        | redo                                                                    |
| `Ctrl+N`                                         | Grab another region                                                     |
| `Ctrl+K`                                         | Code card from the selected text                                        |
| `Delete`                                         | Remove the selected annotations                                         |
| `Shift`+click, or drag a box with the move tool  | Select several annotations; `Ctrl+A` selects them all                    |
| Arrow keys, `Shift`+arrows                       | Move the selected annotations 1px, or 10px                              |
| `Enter`                                          | Finish typing a text label                                              |
| `Esc`                                            | Deselect, then close                                                    |

### Scripting

Everything the editor does can be driven from the command line. `help` prints
the full reference, generated from the same lists the plugin uses, so it is
always current:

```sh
omarchy-shell shell call tahayvr.postcard help ''         # every call
omarchy-shell shell call tahayvr.postcard help set        # every setting and what it takes
omarchy-shell shell call tahayvr.postcard help annotate   # every kind of mark and its fields
omarchy-shell shell call tahayvr.postcard help capture
```

Three rules of the command line:

- Every call takes exactly one argument. One that needs nothing takes `''`.
- The argument is split on spaces, so a string inside JSON writes a space as
  `\u0020`: `'{"watermarkText":"by\u0020me"}'`. A path with a space in it
  cannot be passed at all.
- An argument that starts with `[` is split on commas, so a list goes inside an
  object: `annotate '{"items":[...]}'`.

A call answers `ok`, or a short reason such as `busy`, `no shot` or `bad json`.

#### Reference

```sh
# Getting a picture in
omarchy-shell shell call tahayvr.postcard capture region        # region | windows | fullscreen | smart
omarchy-shell shell call tahayvr.postcard capture '{"mode":"fullscreen","delay":5}'   # after 0–60 seconds
omarchy-shell shell call tahayvr.postcard edit ~/Pictures/Screenshots/shot.png
omarchy-shell shell call tahayvr.postcard add region            # another shot beside it: a mode, a path, or file
omarchy-shell shell call tahayvr.postcard code ''               # code card from the selection (or pass the text)
omarchy-shell shell call tahayvr.postcard pick ''               # system file picker
omarchy-shell shell hide tahayvr.postcard                       # close, or cancel a pending capture

# Styling
omarchy-shell shell call tahayvr.postcard set '{"codeTheme":"nord","padding":8,"frame":"titlebar"}'
omarchy-shell shell call tahayvr.postcard preset social-post    # "Social Post": a dash for each space; or default

# Marking up
omarchy-shell shell call tahayvr.postcard annotate '{"kind":"box","x":40,"y":40,"w":300,"h":120}'
omarchy-shell shell call tahayvr.postcard crop '{"x":80,"y":40,"w":900,"h":600}'   # the shot under it; or '' for the selection
omarchy-shell shell call tahayvr.postcard uncrop ''             # back to the whole picture
omarchy-shell shell call tahayvr.postcard redact ''             # find and hide secrets

# Getting it out
omarchy-shell shell call tahayvr.postcard save ''               # to the screenshot folder (and the clipboard)
omarchy-shell shell call tahayvr.postcard saveAs ''             # choose the file
omarchy-shell shell call tahayvr.postcard copy ''               # to the clipboard
omarchy-shell shell call tahayvr.postcard copyText ''           # the text in the shot, by OCR

omarchy-shell shell call tahayvr.postcard info ''               # the document as JSON
```

A save never writes over an earlier one: two in the same second get `-2`,
`-3` and so on.

#### Waiting for the editor

Captures, OCR and exports run in the background and answer `ok` straight away,
so a script that chains calls has to wait between them. `info` says when the
editor is done: `hasContent` once a picture is in, and `capturing`, `busy`
(rendering, cropping, reading text) and `delivering` (writing the file)
while work is under way. After a save, `lastSaved` is the path it wrote.

These two functions, which need `jq` (it ships with Omarchy), are all the
recipes below rely on:

```sh
pc() { omarchy-shell shell call tahayvr.postcard "$@"; }

# Wait until Postcard holds a picture and has nothing left running.
pc_ready() {
  for _ in $(seq 150); do
    pc info '' | jq -e '.hasContent and ((.capturing or .busy or .delivering) | not)' >/dev/null && return 0
    sleep 0.2
  done
  return 1
}
```

The editor has to be open for anything to render, which every call that brings
a picture in does by itself. Close it at the end with
`omarchy-shell shell hide tahayvr.postcard`.

#### Recipes

**One key: grab a region, style it, save it, print the path.** Save as
`~/.local/bin/postcard-shot`, make it executable, and bind it like any command.
The check on `shotPath` tells a cancelled pick apart from the picture that was
already open:

```sh
#!/usr/bin/env bash
pc() { omarchy-shell shell call tahayvr.postcard "$@"; }
pc_ready() { for _ in $(seq 150); do pc info '' | jq -e '.hasContent and ((.capturing or .busy or .delivering) | not)' >/dev/null && return 0; sleep 0.2; done; return 1; }

before=$(pc info '' | jq -r .shotPath)
pc capture region >/dev/null && pc_ready || exit 1
[ "$(pc info '' | jq -r .shotPath)" = "$before" ] && exit 1   # cancelled
pc preset social >/dev/null
pc save '' >/dev/null && pc_ready && pc info '' | jq -r .lastSaved
omarchy-shell shell hide tahayvr.postcard
```

```lua
o.bind("PRINT", "Postcard shot", "postcard-shot")
```

**A folder of screenshots in one look.** Every picture gets the same preset
and is saved beside the others:

```sh
pc preset docs
for f in ~/Pictures/raw/*.png; do
  pc edit "$f" >/dev/null && pc_ready && pc save '' >/dev/null && pc_ready &&
    pc info '' | jq -r .lastSaved
done
omarchy-shell shell hide tahayvr.postcard
```

**A marked-up screenshot for documentation.** The whole screen without a
picker, cropped to the part that matters, with an arrow and a label.
Coordinates are in the picture's own pixels:

```sh
pc capture fullscreen >/dev/null && pc_ready
pc crop '{"x":0,"y":0,"w":1600,"h":1000}' >/dev/null && pc_ready
pc annotate '{"items":[{"kind":"arrow","x":200,"y":200,"w":300,"h":150},{"kind":"text","x":520,"y":360,"text":"Click\u0020here","size":40}]}'
pc save '' >/dev/null && pc_ready
```

**Before and after, side by side.** Two regions, one card each, lined up
and saved. `layoutDir` `column` stacks them instead:

```sh
pc capture region >/dev/null && pc_ready
pc add region >/dev/null && pc_ready
pc set '{"layoutDir":"row","slotGap":6}' >/dev/null && pc_ready
pc save '' >/dev/null && pc_ready && pc info '' | jq -r .lastSaved
```

With several shots, marks and crops are in the combined picture's pixels,
left to right (or top to bottom) with the gaps; `info` lists the shots.

**A code card from a file.** The text can not go on the command line, since
it would be split at every space, so it goes through the selection:

```sh
wl-copy --primary < src/main.rs
pc code '' >/dev/null && pc_ready
pc set '{"codeTheme":"nord","codeNumbers":true,"frame":"titlebar","frameTitle":"main.rs"}'
pc copy '' >/dev/null && pc_ready
```

**Hide anything secret, then copy it for a chat.**

```sh
pc edit ~/Pictures/Screenshots/terminal.png >/dev/null && pc_ready
pc redact '' >/dev/null && pc_ready
pc copy '' >/dev/null && pc_ready
omarchy-shell shell hide tahayvr.postcard
```

**Sign everything.** A watermark is part of the style, so it can be set once
and saved into a preset from the editor, or set for one picture:

```sh
pc set '{"watermarkText":"@you","watermarkSize":120}'
```

## Dependencies

All of these ship with Omarchy:

- `omarchy`
- `bat`
- `imagemagick`
- `tesseract`
- `wl-clipboard`
- `python-gobject`
- `xdg-desktop-portal`

Postcards are read from and saved to the directory Omarchy uses
(`$OMARCHY_SCREENSHOT_DIR`, else `$XDG_PICTURES_DIR`, else `~/Pictures`) as
`postcard-<date>_<time>.png`. OCR follows `$OMARCHY_OCR_LANGS`.

## Licence

MIT
