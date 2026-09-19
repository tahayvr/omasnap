#!/usr/bin/env bash
# Runs every check: JavaScript unit tests, shell script syntax, the Qt 6
# linter, and an offscreen render of the stage. The last two are skipped
# when their tools are missing.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
fail=0

echo "== JavaScript unit tests"
node "$here/run.js" || fail=1

echo "== shell scripts"
for f in "$root"/bin/snap-*; do bash -n "$f" || fail=1; done
[ -n "$(bash "$root/bin/snap-dir")" ] && echo "snap-dir: $(bash "$root/bin/snap-dir")" || { echo "snap-dir printed nothing"; fail=1; }

QMLLINT=/usr/lib/qt6/bin/qmllint
if [ -x "$QMLLINT" ]; then
  echo "== qmllint"
  lintroot="$(mktemp -d)"
  ln -s "${OMARCHY_PATH:-/usr/share/omarchy}/shell" "$lintroot/qs"
  # Only hard problems fail the run. The shell's singletons declare their
  # members on inline QtObjects, which the linter cannot see through.
  out="$("$QMLLINT" -I "$lintroot" -I /usr/lib/qt6/qml "$root"/*.qml "$root"/ui/*.qml "$root"/ui/controls/*.qml 2>&1 \
         | grep -E "\[(duplicated-name|property-override|syntax|inheritance-cycle|unresolved-type|type-error|compiler)\]")"
  rm -rf "$lintroot"
  if [ -n "$out" ]; then echo "$out"; fail=1; else echo "no blocking warnings"; fi
else
  echo "== qmllint skipped (no /usr/lib/qt6/bin/qmllint)"
fi

if [ -x /usr/lib/qt6/bin/qml ] && command -v magick >/dev/null 2>&1; then
  echo "== offscreen render"
  bash "$here/qml/render.sh" || fail=1
else
  echo "== offscreen render skipped (needs /usr/lib/qt6/bin/qml and imagemagick)"
fi

if [ $fail -eq 0 ]; then echo "ALL OK"; else echo "FAILED"; fi
exit $fail
