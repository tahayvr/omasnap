#!/usr/bin/env bash
# Runs every check: JavaScript unit tests, shell script syntax, the Qt 6
# linter, and an offscreen render of the stage.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
fail=0

echo "== JavaScript unit tests"
node "$here/run.js" || fail=1

echo "== shell scripts"
for f in "$root"/bin/postcard-*; do
  case "$(head -c 40 "$f")" in *bash*) bash -n "$f" || fail=1 ;; *python3*) /usr/bin/python3 -B -m py_compile "$f" && rm -rf "$root/bin/__pycache__" || fail=1 ;; esac
done
[ -n "$(bash "$root/bin/postcard-dir")" ] && echo "postcard-dir: $(bash "$root/bin/postcard-dir")" || { echo "postcard-dir printed nothing"; fail=1; }
# A long line folds at the column limit, and a folded line keeps its gutter.
folded="$(printf 'let u = "%s";\n' "$(printf 'x%.0s' $(seq 1 120))" | bash "$root/bin/postcard-highlight" rs ansi 1 60 | sed 's/\x1b\[[0-9;]*m//g')"
[ "$(printf '%s\n' "$folded" | wc -l)" -ge 3 ] && printf '%s\n' "$folded" | sed -n 2p | grep -qE '^ {5}x' \
  && echo "postcard-highlight folds long lines under the gutter" || { echo "postcard-highlight did not fold a long line"; fail=1; }

# A crop is taken from the file, so the cut has to come out the size asked for.
# Two shots on one sheet: the first cropped 1:1, the second scaled into
# place, and nothing but transparency between them.
t="$XDG_RUNTIME_DIR/postcard-test-sheet"
magick -size 200x100 gradient:red-blue -depth 8 "$t-a.png" 2>/dev/null
magick -size 100x200 xc:'#00ff00' "$t-b.png" 2>/dev/null
bash "$root/bin/postcard-sheet" "$t.png" 120 50 "$t-a.png" 20 10 50 50 50 50 0 0 \
     "$t-b.png" 0 0 100 200 25 50 95 0 >/dev/null
sheet="$(magick "$t.png" -format "%wx%h %[pixel:p{97,25}] %[fx:p{60,25}.a] %z %[channels]" info: 2>/dev/null)"
cut="$(magick compare -metric AE "$t.png[50x50+0+0]" "$t-a.png[50x50+20+10]" null: 2>&1 | cut -d' ' -f1)"
[ "$sheet" = "120x50 srgba(0,255,0,1) 0 8 srgba 4.0" ] && [ "$cut" = "0" ] \
  && echo "postcard-sheet places, crops 1:1 and leaves the gap clear" \
  || { echo "postcard-sheet produced '$sheet', crop differed by $cut"; fail=1; }
rm -f "$t.png" "$t-a.png" "$t-b.png"

echo "== qmllint"
lintroot="$(mktemp -d)"
ln -s "${OMARCHY_PATH:-/usr/share/omarchy}/shell" "$lintroot/qs"
# Only hard problems fail the run. The shell's singletons declare their
# members on inline QtObjects, which the linter cannot see through.
out="$(/usr/lib/qt6/bin/qmllint -I "$lintroot" -I /usr/lib/qt6/qml \
         "$root"/*.qml "$root"/ui/*.qml "$root"/ui/controls/*.qml 2>&1 \
       | grep -E "\[(duplicated-name|property-override|syntax|inheritance-cycle|unresolved-type|type-error|compiler)\]")"
rm -rf "$lintroot"
if [ -n "$out" ]; then echo "$out"; fail=1; else echo "no blocking warnings"; fi

echo "== offscreen render"
bash "$here/qml/render.sh" || fail=1

if [ $fail -eq 0 ]; then echo "ALL OK"; else echo "FAILED"; fi
exit $fail
