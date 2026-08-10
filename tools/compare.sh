#!/usr/bin/env bash
#
# G2 (Schema-Aequivalenz) + G3 (Datenaequivalenz) + G4 (dbt-Tests) +
# G5 (Idempotenz) gegen die Referenzparquets in learning/pd/referenz/.
# Read-only fuer den Agenten (tools/ ist in opencode.jsonc schreibgeschuetzt)
# -- das ist der Punkt: der Agent darf diesen Harness nie beeinflussen
# koennen, siehe docs/adr/0001-deterministik-first.md.
#
# Nur Objekte mit passender Referenzdatei sind pruefbar (Konvention seit
# Session 10: <rolle>__<exakter-modellname>.parquet, <rolle> aus derselben
# Vokabular wie dbt/macros/schema_for.sql -- deckt jede Pipeline-Ebene ab,
# nicht nur Kennzahl-Fakten, sobald dafuer eine Referenzdatei vorliegt,
# s. tools/compare_data.py). Objekte ohne Referenz werden uebersprungen,
# nicht als Fehler gewertet -- G3 prueft nur, was tatsaechlich pruefbar ist.
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

# Modellliste: explizit uebergeben, sonst alle mit Referenzdatei
# (<rolle>__<modell>.parquet -- Rolle direkt aus dem Dateinamen, kein
# Praefix-Raten mehr noetig).
if [ "$#" -gt 0 ]; then
    MODELS=("$@")
else
    MODELS=()
    if [ -d "$REF_DIR" ]; then
        while IFS= read -r -d '' f; do
            name="$(basename "$f" .parquet)"
            role="${name%%__*}"
            model="${name#*__}"
            [ -f "dbt/models/${role}/${model}.sql" ] && MODELS+=("$model")
        done < <(find "$REF_DIR" -name "*__*.parquet" -print0)
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
    h1="$("$PY" tools/compare_data.py --month "$MONAT" --model "$m" --hash-only 2>/dev/null)"; rc1=$?
    ( cd dbt && dbt run --profiles-dir . --vars "{verarbeitungsmonat: \"$MONAT\"}" --select "$m" ) >/dev/null 2>&1
    h2="$("$PY" tools/compare_data.py --month "$MONAT" --model "$m" --hash-only 2>/dev/null)"; rc2=$?
    # Laufzeit-verifiziert (diese Session): ein fehlgeschlagener --hash-only-
    # Aufruf (Tabelle existiert nicht, Exasol-Fehler) liefert leeren stdout
    # UND leeren stdout beim zweiten Aufruf -- "" == "" wurde vorher
    # faelschlich als "Hash stabil" gewertet. Exit-Code beider Aufrufe daher
    # explizit pruefen, nicht nur den String-Vergleich.
    if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ] || [ -z "$h1" ] || [ -z "$h2" ]; then
        echo "E G5-IDEMPOTENZ model=$m hash-only fehlgeschlagen (rc1=$rc1 rc2=$rc2) -- kein Vergleich moeglich, nicht als OK werten"
        fail=1
    elif [ "$h1" != "$h2" ]; then
        echo "E G5-IDEMPOTENZ model=$m hash_lauf1=$h1 hash_lauf2=$h2"
        fail=1
    else
        echo "model=$m: G5 OK (Hash stabil ueber 2 Laeufe)"
    fi
done

exit "$fail"
