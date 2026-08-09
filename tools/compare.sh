#!/usr/bin/env bash
#
# G2 (Schema-Aequivalenz) + G3 (Datenaequivalenz) + G4 (dbt-Tests) +
# G5 (Idempotenz) gegen die Referenzparquets in learning/pd/referenz/.
# Read-only fuer den Agenten (tools/ ist in opencode.jsonc schreibgeschuetzt)
# -- das ist der Punkt: der Agent darf diesen Harness nie beeinflussen
# koennen, siehe docs/adr/0001-deterministik-first.md.
#
# Nur Objekte mit passender Referenzdatei sind pruefbar (Konvention:
# tf_pd_knz_<N> <-> fct_pd_knz_<N>.parquet, tools/compare_data.py).
# Objekte ohne Referenz werden uebersprungen, nicht als Fehler gewertet --
# G3 prueft nur, was tatsaechlich pruefbar ist.
#
# Aufruf: bash tools/compare.sh <YYYYMM> [MODEL ...]
# Ohne MODEL-Liste: alle dbt-Modelle mit vorhandener Referenzdatei.
set -uo pipefail

MONAT="${1:?Aufruf: tools/compare.sh <YYYYMM> [MODEL ...]}"
shift || true
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PY="${PY:-.venv/bin/python3}"
REF_DIR="learning/pd/referenz/$MONAT"
fail=0

# Modellliste: explizit uebergeben, sonst alle mit Referenzdatei (Konvention
# tf_pd_knz_<N> -> fct_pd_knz_<N>.parquet).
if [ "$#" -gt 0 ]; then
    MODELS=("$@")
else
    MODELS=()
    if [ -d "$REF_DIR" ]; then
        while IFS= read -r -d '' f; do
            name="$(basename "$f" .parquet)"
            model="${name/fct_/tf_}"
            [ -f "dbt/models"/*/"${model}.sql" ] 2>/dev/null && MODELS+=("$model")
        done < <(find "$REF_DIR" -name "*.parquet" -print0)
    fi
fi

if [ "${#MODELS[@]}" -eq 0 ]; then
    echo "Keine Modelle mit Referenzdatei fuer $MONAT gefunden -- G2-G5 uebersprungen."
    exit 0
fi

echo "=== G2+G3: Schema-/Datenaequivalenz gegen $REF_DIR ==="
for m in "${MODELS[@]}"; do
    out="$("$PY" tools/compare_data.py --month "$MONAT" --model "$m" 2>&1)"
    rc=$?
    echo "$out"
    [ "$rc" -ne 0 ] && fail=1
done

echo
echo "=== G4: dbt-Tests (schema.yml) ==="
if find dbt/models -name "schema.yml" 2>/dev/null | grep -q .; then
    ( cd dbt && dbt test --profiles-dir . --vars "{verarbeitungsmonat: \"$MONAT\"}" ) 2>&1 | tail -20
else
    echo "keine schema.yml mit Tests gefunden -- G4 noch nicht befuellt, kein Fehler."
fi

echo
echo "=== G5: Idempotenz (zweimal laufen lassen, Hash vergleichen) ==="
for m in "${MODELS[@]}"; do
    h1="$("$PY" tools/compare_data.py --month "$MONAT" --model "$m" --hash-only 2>/dev/null)"
    ( cd dbt && dbt run --profiles-dir . --vars "{verarbeitungsmonat: \"$MONAT\"}" --select "$m" ) >/dev/null 2>&1
    h2="$("$PY" tools/compare_data.py --month "$MONAT" --model "$m" --hash-only 2>/dev/null)"
    if [ "$h1" != "$h2" ]; then
        echo "E G5-IDEMPOTENZ model=$m hash_lauf1=$h1 hash_lauf2=$h2"
        fail=1
    else
        echo "model=$m: G5 OK (Hash stabil ueber 2 Laeufe)"
    fi
done

exit "$fail"
