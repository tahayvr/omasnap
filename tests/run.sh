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
magick -size 200x100 xc:white "$XDG_RUNTIME_DIR/postcard-crop-src.png" 2>/dev/null
bash "$root/bin/postcard-crop" "$XDG_RUNTIME_DIR/postcard-crop-src.png" 20 10 100 50 \
     "$XDG_RUNTIME_DIR/postcard-crop-out.png" >/dev/null
csize="$(magick "$XDG_RUNTIME_DIR/postcard-crop-out.png" -format "%wx%h" info: 2>/dev/null)"
[ "$csize" = "100x50" ] && echo "postcard-crop cuts to the size asked for" \
  || { echo "postcard-crop produced $csize, wanted 100x50"; fail=1; }
rm -f "$XDG_RUNTIME_DIR/postcard-crop-src.png" "$XDG_RUNTIME_DIR/postcard-crop-out.png"

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
