#!/usr/bin/env bash
# Cheap sanity checks, run by check.yml on every push and pull request and by
# sync-upstream.yml before an upstream update is merged on its own.
# Prints what it checks and exits non-zero if anything is wrong.
set -u
cd "$(dirname "$0")/../.."
fail=0
bad() { echo "  FAIL: $*"; fail=1; }

echo "== CSS braces and comments are balanced"
for f in userChrome.css userContent.css macfox/*.css crisp/*.css; do
  o=$(tr -cd '{' < "$f" | wc -c); c=$(tr -cd '}' < "$f" | wc -c)
  co=$(grep -o '/\*' "$f" | wc -l); cc=$(grep -o '\*/' "$f" | wc -l)
  echo "  $f  braces $o/$c  comments $co/$cc"
  if [ "$o" != "$c" ] || [ "$co" != "$cc" ]; then bad "$f is unbalanced"; fi
done

echo "== The loaders point at files that exist"
for p in $(grep -ohE '@import "[^"]+"' userChrome.css userContent.css | sed -E 's/@import "([^"]+)"/\1/'); do
  [ -f "$p" ] || bad "missing $p"
done
for f in crisp/*.css; do
  n=$(basename "$f"); [ "$n" = "crisp.css" ] && continue
  grep -q "@import \"$n\"" crisp/crisp.css || bad "crisp/crisp.css does not import $n"
done
for f in $(grep -ohE '@import "[^"]+"' macfox/userChrome.css | sed -E 's/@import "([^"]+)"/\1/'); do
  [ -f "macfox/$f" ] || bad "macfox/userChrome.css imports missing macfox/$f"
done

echo "== Installer syntax and the files it copies"
bash -n install.sh || bad "install.sh does not parse"
for f in $(sed -n '/^UPSTREAM_FILES=(/,/^)/p' install.sh | grep -E '\.css$'); do
  [ -f "macfox/$f" ] || bad "missing macfox/$f"
done
for f in $(sed -n '/^CRISP_FILES=(/,/^)/p' install.sh | grep -E '\.css$'); do
  [ -f "crisp/$f" ] || bad "missing crisp/$f"
done
for f in $(sed -n '/^ICON_FILES=(/,/^)/p' install.sh | grep -E '\.svg$'); do
  [ -f "crisp/icons/$f" ] || bad "missing crisp/icons/$f"
done

echo "== Every icon the overlay refers to exists"
for p in $(grep -ohE 'url\("icons/[^"]+"\)' crisp/*.css | sed -E 's/url\("([^"]+)"\)/\1/' | sort -u); do
  [ -f "crisp/$p" ] || bad "missing crisp/$p"
done

echo "== No personal paths in our files"
if grep -rnE '/Users/|[a-z0-9]{8}\.default' --include='*.css' --include='*.sh' --include='*.svg' crisp userChrome.css userContent.css install.sh; then
  bad "found personal paths"
fi

[ "$fail" = 0 ] && echo "All checks passed." || echo "Checks failed."
exit "$fail"
