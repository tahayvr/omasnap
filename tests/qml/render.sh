#!/usr/bin/env bash
# Renders tests/qml/Harness.qml offscreen with the Qt 6 runtime and checks
# the exported pixels. Needs /usr/lib/qt6/bin/qml and imagemagick.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
# Scratch goes to the runtime dir, not the plugin directory: writing a file
# under the plugin reloads it in the running shell, and a full run wrote
# seven, which knocked the live overlay out from under whoever was using it.
out="${XDG_RUNTIME_DIR:-/tmp}/omasnap-tests"
mkdir -p "$out"
rm -f "$out/export.png" "$out/export-inset.png" "$out/export-gradient.png" "$out/export-mesh.png" \
      "$out/export-odd.png" "$out/export-spot.png" "$out/export-spot-oval.png"

# Synthetic screenshot: white left half, black right half, and a band of
# 1px red/blue stripes through the middle that redaction has to destroy.
magick -size 2x1 xc:red xc:blue +append -write mpr:tile +delete \
       -size 200x100 tile:mpr:tile "$out/stripes.png"
magick -size 400x200 xc:white -fill black -draw "rectangle 200,0 399,199" \
       "$out/stripes.png" -geometry +100+50 -composite "$out/shot.png"

# The offscreen platform can only use the software scene graph, which does
# not run shader effects, so the card (drawn through MultiEffect) is missing
# there. On a live Wayland session the harness opens a real window for about
# a second and renders on the GPU, which covers everything.
platform=offscreen
[ -n "${WAYLAND_DISPLAY:-}" ] && [ "${OMASNAP_TEST_OFFSCREEN:-0}" != "1" ] && platform=wayland

# Qt routes messages to journald when stderr is not a terminal; force them here.
log="$(cd "$here" && QSG_INFO=1 QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=$platform timeout 40 /usr/lib/qt6/bin/qml -I "$here/stubs" Harness.qml -- "$out" 2>&1)"
backend=gpu; echo "$log" | grep -q "Loading backend software" && backend=software
echo "platform=$platform backend=$backend $(echo "$log" | grep -oE 'HARNESS.*')"
echo "$log" | grep -E "file://|Error|error|Unable to assign|Warning" | head -20
echo "$log" | grep -q "HARNESS export ok" || { echo "FAIL harness did not report a successful grab"; echo "$log" | tail -5; exit 1; }
if echo "$log" | grep -qE "Error|error|Unable to assign"; then echo "FAIL runtime errors above"; fail_log=1; else fail_log=0; fi
[ -f "$out/export.png" ] || { echo "no export written"; exit 1; }

# The harness grabs a wrapper padded up to whole device pixels, as the overlay
# does; crop each file to the size the document reported, as snap-deliver does.
crop_to() { # crop_to <file> <WxH>
  [ -f "$1" ] && magick "$1" -crop "$2+0+0" +repage "$1"
}
while read -r name size; do crop_to "$out/$name.png" "$size"; done \
  < <(echo "$log" | sed -nE 's/.*HARNESS ([a-z-]+) ok expected ([0-9]+x[0-9]+).*/\1 \2/p')

fail=$fail_log
# px X Y -> "r g b" (0-255) of the exported image
px() { magick "$out/export.png" -format "%[fx:int(255*p{$1,$2}.r+0.5)] %[fx:int(255*p{$1,$2}.g+0.5)] %[fx:int(255*p{$1,$2}.b+0.5)]" info:; }
expect() { # expect "name" X Y R G B [tolerance]
  local got; got="$(px "$2" "$3")"; local tol="${7:-24}"
  read -r r g b <<<"$got"
  if (( r-$4 > tol || $4-r > tol || g-$5 > tol || $5-g > tol || b-$6 > tol || $6-b > tol )); then
    echo "FAIL $1 at $2,$3: expected $4 $5 $6, got $got"; fail=1
  else
    echo "ok   $1"
  fi
}

# Whether the card rendered at all, asked of the picture rather than guessed
# from the backend name. The software scene graph used not to run MultiEffect,
# which the card sits over, but whether it does depends on the Qt and Mesa
# build: it does here now, and the old guess left the run red.
cardpx="$(px 100 100)"
gpu=1; [ "$cardpx" = "0 255 0" ] && gpu=0
[ $gpu = 1 ] || echo "note the card did not render; its checks are skipped"

size="$(magick "$out/export.png" -format "%wx%h" info:)"
[ "$size" = "480x280" ] && echo "ok   export size 480x280" || { echo "FAIL export size $size, expected 480x280"; fail=1; }

# Shot pixel (sx, sy) lands at (sx+40, sy+40) in the export.
expect "background is the solid color"     5   5     0 255   0
if [ $gpu = 1 ]; then
  expect "white half of the shot"            60  60   255 255 255
  expect "black half of the shot"           390  60     0   0   0
else
  echo "skip the screenshot card: software scene graph cannot run MultiEffect"
fi
expect "box border is blue"                52  75     0   0 255
expect "step badge is red"                352 140   255   0   0
expect "arrow shaft is magenta"           390  90   255   0 255

# The curved arrow runs flat from shot (250,175) to (330,175), so a straight
# one would be at export y 215 all the way. Bowed, it passes through 206 and
# leaves the chord bare.
expect "curved arrow bows off the chord"  330 206     0 255 255
expect "and the chord is left bare"       330 215     0   0   0

# The unredacted part of the stripe band must come out pixel for pixel: the
# export path is expected to be exact, not merely close.
if [ $gpu = 1 ]; then
  magick "$out/export.png" -crop 50x100+140+90 +repage "$out/band-export.png"
  magick "$out/shot.png"   -crop 50x100+100+50 +repage "$out/band-source.png"
  rmse="$(magick compare -metric RMSE "$out/band-source.png" "$out/band-export.png" null: 2>&1 | awk '{print $1}')"
  [ "${rmse%%.*}" = "0" ] && echo "ok   export is pixel-exact (band RMSE $rmse)" || { echo "FAIL export resamples the shot (band RMSE $rmse)"; fail=1; }
fi

# Inside the redaction a whole block is one color: five neighbours agree.
ref="$(px 195 135)"; same=1
for x in 196 197 198 199; do [ "$(px $x 135)" = "$ref" ] || same=0; done
[ $same = 1 ] && echo "ok   redaction is blocky ($ref)" || { echo "FAIL redaction still shows stripes"; fail=1; }

# "Hello" at shot (20,150) puts dark pixels on the white half.
minv="$(magick "$out/export.png" -crop 100x30+60+188 -colorspace gray -format "%[fx:int(255*minima)]" info:)"
[ "$minv" -lt 90 ] && echo "ok   text label rendered (min $minv)" || { echo "FAIL text label missing (min $minv)"; fail=1; }

# The empty label at shot (20,100) must not export its placeholder, and the
# selection outline around the box (selected) must not export either. Both
# sit on the white half, so anything darker than white is a leak.
if [ $gpu = 1 ]; then
  minv="$(magick "$out/export.png" -crop 70x28+60+138 -colorspace gray -format "%[fx:int(255*minima)]" info:)"
  [ "$minv" -gt 240 ] && echo "ok   empty label exported nothing" || { echo "FAIL placeholder or outline leaked (min $minv)"; fail=1; }
  expect "no selection outline beside the box" 45 45   255 255 255
else
  # On the software path the shot is absent, so the same spots must be the bare background.
  expect "empty label exported nothing"      70 150     0 255   0
  expect "no selection outline beside the box" 45 45     0 255   0
fi

# ---- editor controls -------------------------------------------------------
# Pure control logic, so it runs offscreen whatever the scene graph is doing.
slog="$(cd "$here" && QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 30 /usr/lib/qt6/bin/qml -I "$here/stubs" HarnessControls.qml 2>&1)"
echo "$slog" | grep -E "^qml: (ok|FAIL)" | sed 's/^qml: //'
if echo "$slog" | grep -q "FAIL"; then fail=1; fi
echo "$slog" | grep -q "^qml: ok   a move that size is still a crop" \
  || { echo "FAIL controls harness did not run to the end"; fail=1; }

# ---- inset -----------------------------------------------------------------
# Second export from the same harness: inset 10% of 400 = 40px of the shot's
# edge color (forced to magenta) on every side, so the card grows to 480x280
# and the frame, padded by 10% of 480, to 576x376.
if [ $gpu = 1 ]; then
  if [ -f "$out/export-inset.png" ]; then
    isize="$(magick "$out/export-inset.png" -format "%wx%h" info:)"
    [ "$isize" = "576x376" ] && echo "ok   inset export size $isize" \
      || { echo "FAIL inset export size: $isize (want 576x376)"; fail=1; }
    ipx() { magick "$out/export-inset.png" -format "%[fx:int(255*p{$1,$2}.r+0.5)] %[fx:int(255*p{$1,$2}.g+0.5)] %[fx:int(255*p{$1,$2}.b+0.5)]" info:; }
    iexpect() { local got; got="$(ipx "$2" "$3")"
      if [ "$got" = "$4 $5 $6" ]; then echo "ok   $1"; else echo "FAIL $1: got $got want $4 $5 $6"; fail=1; fi; }
    iexpect "inset band is the edge color (left)" 60 180   255 0 255
    iexpect "inset band is the edge color (top)" 288 60    255 0 255
    iexpect "background still outside the card"    20 180     0 255 0
    iexpect "shot moved in by the inset (white half)" 150 150  255 255 255
    iexpect "shot moved in by the inset (black half)" 400 150    0   0 0
    # The box sits at shot (10,10); its left border must move in with the shot,
    # which is what proves AnnotationLayer picked up the inset origin.
    iexpect "annotations follow the shot"          100 123   0   0 255
  else
    echo "FAIL inset export missing"; fail=1
  fi
fi

# ---- odd size --------------------------------------------------------------
# 444x244 is not a whole number of logical pixels at 1.25, 1.5 or 1.6, unlike
# every size above. The file still has to come out that size, and the shot
# inside it (at 22,22) still pixel for pixel.
if [ $gpu = 1 ]; then
  if [ -f "$out/export-odd.png" ]; then
    osize="$(magick "$out/export-odd.png" -format "%wx%h" info:)"
    [ "$osize" = "444x244" ] && echo "ok   odd export size $osize" \
      || { echo "FAIL odd export size: $osize (want 444x244)"; fail=1; }
    magick "$out/export-odd.png" -crop 50x100+122+72 +repage "$out/band-odd.png"
    rmse="$(magick compare -metric RMSE "$out/band-source.png" "$out/band-odd.png" null: 2>&1 | awk '{print $1}')"
    [ "${rmse%%.*}" = "0" ] && echo "ok   odd export is pixel-exact (band RMSE $rmse)" \
      || { echo "FAIL odd export resamples the shot (band RMSE $rmse)"; fail=1; }
  else
    echo "FAIL odd export missing"; fail=1
  fi
fi

# ---- spotlight -------------------------------------------------------------
# One spotlight over shot (10,10)-(90,190) at 60%, on the same 480x280 frame as
# the first export: inside stays the shot, outside is the shot at 40% of its
# brightness, and the background around the card must not move at all.
if [ $gpu = 1 ]; then
  for f in spot spot-oval; do
    [ -f "$out/export-$f.png" ] || { echo "FAIL $f export missing"; fail=1; continue; }
    spx() { magick "$out/export-$f.png" -format "%[fx:int(255*p{$1,$2}.r+0.5)] %[fx:int(255*p{$1,$2}.g+0.5)] %[fx:int(255*p{$1,$2}.b+0.5)]" info:; }
    sexpect() { local got; got="$(spx "$2" "$3")"; local tol=6
      read -r r g b <<<"$got"
      if (( r-$4 > tol || $4-r > tol || g-$5 > tol || $5-g > tol || b-$6 > tol || $6-b > tol )); then
        echo "FAIL $1 at $2,$3: expected $4 $5 $6, got $got"; fail=1
      else
        echo "ok   $1"
      fi
    }
    # Shot pixel (sx,sy) is at (sx+40, sy+40).
    sexpect "$f leaves the background alone"      5   5     0 255   0
    sexpect "$f dims the white half outside"    170  70   102 102 102
    sexpect "$f dims the black half outside"    390  60     0   0   0
    if [ "$f" = "spot" ]; then
      sexpect "$f keeps the corner of the hole"  54  54   255 255 255
    else
      # An ellipse inscribed in the same box: bright in the middle, and that
      # same corner now falls outside it.
      sexpect "$f dims the corner of the box"    54  54   102 102 102
    fi
    sexpect "$f keeps the middle of the hole"    90 140   255 255 255
  done
fi

# ---- multipoint gradient ---------------------------------------------------
# aurora runs #08203e -> #15756b -> #9fe0a8 at 150 degrees, so the background
# runs light mint at the top left to dark navy at the bottom right, turning
# through a saturated teal on the way. That teal is the whole point: a plain
# ramp between the two ends passes through about #53806f instead, which these
# tolerances tell apart.
if [ -f "$out/export-gradient.png" ]; then
  gpx() { magick "$out/export-gradient.png" -format "%[fx:int(255*p{$1,$2}.r+0.5)] %[fx:int(255*p{$1,$2}.g+0.5)] %[fx:int(255*p{$1,$2}.b+0.5)]" info:; }
  gexpect() { # gexpect "name" X Y R G B
    local got; got="$(gpx "$2" "$3")"
    read -r r g b <<<"$got"
    if (( r-$4 > 20 || $4-r > 20 || g-$5 > 20 || $5-g > 20 || b-$6 > 20 || $6-b > 20 )); then
      echo "FAIL $1 at $2,$3: expected $4 $5 $6, got $got"; fail=1
    else
      echo "ok   $1"
    fi
  }
  # The far corner is not quite t=1: the ramp is drawn on a square rotated
  # over the frame, so the corner sits a little short of the final color.
  gexpect "gradient starts at its last stop"  20  20   138 208 159
  gexpect "gradient ends at its first stop"  700 500     8  32  62
  gexpect "and turns through the middle one" 700 120    21 117 107
else
  echo "FAIL gradient export missing"; fail=1
fi

# ---- multipoint (mesh) gradient --------------------------------------------
# bloom puts violet top left, rose top right, amber bottom right and teal
# bottom left. A ramp cannot do that: whatever its angle, the two ends of one
# diagonal must bracket the two ends of the other. Reading all four corners is
# what separates a mesh from a ramp.
if [ -f "$out/export-mesh.png" ]; then
  mpx() { magick "$out/export-mesh.png" -format "%[fx:int(255*p{$1,$2}.r+0.5)] %[fx:int(255*p{$1,$2}.g+0.5)] %[fx:int(255*p{$1,$2}.b+0.5)]" info:; }
  mexpect() { # mexpect "name" X Y R G B
    local got; got="$(mpx "$2" "$3")"
    read -r r g b <<<"$got"
    if (( r-$4 > 26 || $4-r > 26 || g-$5 > 26 || $5-g > 26 || b-$6 > 26 || $6-b > 26 )); then
      echo "FAIL $1 at $2,$3: expected $4 $5 $6, got $got"; fail=1
    else
      echo "ok   $1"
    fi
  }
  # The corners sit where the fills have already faded part way into the
  # base, so these are the colors the frame really carries there.
  mexpect "mesh is violet at the top left"    30  30    86  81 178
  mexpect "rose at the top right"            690  30   224  86 122
  mexpect "amber at the bottom right"        690 490   191 126  83
  mexpect "and teal at the bottom left"       30 490    46 197 182
else
  echo "FAIL mesh export missing"; fail=1
fi

# ---- code card -------------------------------------------------------------
if [ $gpu = 1 ]; then
  rm -f "$out/export-code.png"
  clog="$(cd "$here" && QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=$platform timeout 40 /usr/lib/qt6/bin/qml -I "$here/stubs" HarnessCode.qml -- "$out" 2>&1)"
  echo "$clog" | grep -E "file://|Error|error|Unable to assign|Warning" | head -10
  crop_to "$out/export-code.png" "$(echo "$clog" | sed -nE 's/.*HARNESS ok expected ([0-9]+x[0-9]+).*/\1/p')"
  if echo "$clog" | grep -q "HARNESS resize ok"; then
    echo "ok   code card keeps its size on a re-render ($(echo "$clog" | grep -o 'measures [0-9]*' | head -1))"
  else
    echo "FAIL code card lost its size when the same snippet rendered again"; fail=1
  fi
  if [ -f "$out/export-code.png" ]; then
    read -r cw ch <<<"$(magick "$out/export-code.png" -format "%w %h" info:)"
    # Card at (pad, pad); its top-left pixel is the code background.
    cbg="$(magick "$out/export-code.png" -format "%[fx:int(255*p{40,40}.r+0.5)] %[fx:int(255*p{40,40}.g+0.5)] %[fx:int(255*p{40,40}.b+0.5)]" info:)"
    [ "$cbg" = "32 32 48" ] && echo "ok   code card background" || { echo "FAIL code card background: $cbg"; fail=1; }
    n="$(magick "$out/export-code.png" -crop $((cw-80))x$((ch-80))+40+40 +repage -format "%k" info:)"
    [ "$n" -gt 40 ] && echo "ok   code text rendered ($n colors)" || { echo "FAIL code text missing ($n colors)"; fail=1; }

    # The card must not be bottom-heavy: Qt hangs the proportional line
    # spacing under the last line too, which used to leave half a line of
    # dead space below the code. Trim the frame to the card, then the card
    # to the ink, and compare the margins.
    magick "$out/export-code.png" -fuzz 5% -trim +repage "$out/code-card.png"
    read -r ccw cch <<<"$(magick "$out/code-card.png" -format "%w %h" info:)"
    read -r iw ih ix iy <<<"$(magick "$out/code-card.png" -fuzz 12% -trim -format "%w %h %X %Y" info: | tr -d '+')"
    top=$iy; bottom=$((cch - iy - ih)); left=$ix; right=$((ccw - ix - iw))
    gap=$((top > bottom ? top - bottom : bottom - top))
    [ "$gap" -le 8 ] && echo "ok   code padding is even (top $top, bottom $bottom)" \
      || { echo "FAIL code card is lopsided: top $top, bottom $bottom"; fail=1; }
    hgap=$((left > right ? left - right : right - left))
    [ "$hgap" -le 8 ] && echo "ok   code padding is even sideways (left $left, right $right)" \
      || { echo "FAIL code card off-centre: left $left, right $right"; fail=1; }
  else
    echo "FAIL code harness wrote nothing"; fail=1
  fi
fi

exit $fail
