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

# Nested: a mixed folder is distributed by default; `--mode keep` moves it as one unit, undo restores the tree.
ROOT2="$TMP/root2"; mkdir -p "$ROOT2/Rastgele" "$ROOT2/Tatil"
print x > "$ROOT2/Rastgele/a.pdf"; print x > "$ROOT2/Rastgele/b.jpg"
print x > "$ROOT2/Tatil/1.jpg"; print x > "$ROOT2/Tatil/2.jpg"
OUT=$($BIN plan "$ROOT2" --no-llm --data-dir "$DATA")
print -r -- "$OUT" | grep -q "Rastgele/b.jpg"
print -r -- "$OUT" | grep -q "\[dağıt\]"
print -r -- "$OUT" | grep -q "\[bütün tut · 2 öğe\]"
PLAN2=$(print -r -- "$OUT" | tail -1 | sed 's/^Plan kaydedildi: //')
FOLDER=$(print -r -- "$OUT" | grep "\[dağıt\]" | awk '{print $3}')
$BIN set "$PLAN2" "$FOLDER" --mode keep --approve --data-dir "$DATA"
$BIN apply "$PLAN2" --yes --data-dir "$DATA"
test -f "$ROOT2/Diger/Rastgele/a.pdf" && test -d "$ROOT2/Tatil"
$BIN undo --data-dir "$DATA"
test -f "$ROOT2/Rastgele/a.pdf" && test -f "$ROOT2/Rastgele/b.jpg" && test ! -d "$ROOT2/Diger"

# Tag-only: nothing moves; the category tag is written in place and cleared on undo.
ROOT3="$TMP/root3"; DATA3="$TMP/data3"; mkdir -p "$ROOT3" "$DATA3"
print '{"recentMinutes":0,"targetMode":"tagOnly"}' > "$DATA3/settings.json"
print x > "$ROOT3/fatura-ocak.pdf"
OUT3=$($BIN plan "$ROOT3" --no-llm --data-dir "$DATA3")
print -r -- "$OUT3" | grep -q "＋ Fatura etiketi"
PLAN3=$(print -r -- "$OUT3" | tail -1 | sed 's/^Plan kaydedildi: //')
$BIN apply "$PLAN3" --yes --data-dir "$DATA3"
test -f "$ROOT3/fatura-ocak.pdf"
xattr -px com.apple.metadata:_kMDItemUserTags "$ROOT3/fatura-ocak.pdf" | xxd -r -p | plutil -p - | grep -q Fatura
$BIN undo --data-dir "$DATA3"
if xattr -px com.apple.metadata:_kMDItemUserTags "$ROOT3/fatura-ocak.pdf" 2>/dev/null | xxd -r -p | plutil -p - 2>/dev/null | grep -q Fatura; then
  echo "tag still present after undo" >&2
  exit 1
fi
echo "SMOKE OK"
