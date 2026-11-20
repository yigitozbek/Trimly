#!/bin/zsh
# End-to-end CLI smoke test in a throwaway folder: plan → apply → undo. Never touches real user folders.
set -euo pipefail
TMP=$(mktemp -d); ROOT="$TMP/root"; DATA="$TMP/data"; mkdir -p "$ROOT" "$DATA"
print '{"recentMinutes":0}' > "$DATA/settings.json"
print x > "$ROOT/Screenshot 2025-03-14 at 10.22.31.png"
print x > "$ROOT/cert.der"
BIN=.build/debug/trimly
PLAN=$($BIN plan "$ROOT" --no-llm --data-dir "$DATA" | tail -1 | sed 's/^Plan kaydedildi: //')
$BIN apply "$PLAN" --yes --data-dir "$DATA"
test -f "$ROOT/Ekran-Goruntuleri/2025-03-14_Ekran-Goruntusu_10-22-31.png"
test -f "$ROOT/cert.der"                       # kritik: onaysız, yerinde
$BIN runs --data-dir "$DATA"
$BIN undo --data-dir "$DATA"
test -f "$ROOT/Screenshot 2025-03-14 at 10.22.31.png" && test ! -d "$ROOT/Ekran-Goruntuleri"
echo "SMOKE OK"
