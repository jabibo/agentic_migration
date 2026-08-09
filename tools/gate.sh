#!/usr/bin/env bash
#
# G0: sqlfluff parse --dialect exasol auf das von dbt kompilierte SQL
#     (kein Jinja-Templater-Aufwand -- dbt hat Jinja schon expandiert,
#     sqlfluff sieht reines Exasol-SQL). Reiner Grammatik-Check, keine
#     Style-Regeln (die waeren hier Rauschen, siehe docs/... Session 3).
# G1: dbt run gegen das Monatsschema (kein Ephemeral-Schema-Wrapper in
#     dieser Session -- Schema-je-Monat ist unsere Ephemeral-Grenze,
#     siehe docs/systemkontext.md B.4).
#
# Fehlerkanal: eine Zeile pro Fehler, normalisiert (kein Rohlog in den
# Agenten-Kontext -- Fehlercode -> Regeldatei ist deterministisches
# Lookup, kein LLM-Job, siehe docs/adr/0001-deterministik-first.md).
#
# Aufruf: bash tools/gate.sh <YYYYMM>
set -uo pipefail

MONAT="${1:?Aufruf: tools/gate.sh <YYYYMM>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# dbt schreibt target/ relativ zum Aufrufverzeichnis, nicht zu --project-dir
# -- deshalb explizit ins dbt/-Verzeichnis wechseln, keine Flags dafuer.
cd "$ROOT/dbt"

SQLFLUFF="${SQLFLUFF:-$ROOT/.venv/bin/sqlfluff}"
VARS="{verarbeitungsmonat: \"$MONAT\"}"
COMPILED_DIR="target/compiled/agentic_migration/models"

fail=0

echo "=== G0: Syntax (sqlfluff --dialect exasol, kompiliertes SQL) ==="
# dbt compile (nicht dbt parse -- das schreibt nur das Manifest, kein
# target/compiled/**/*.sql je Modell) validiert Jinja/ref()/source() UND
# erzeugt reines SQL fuer G0, ohne DB-Roundtrip.
if ! dbt compile --profiles-dir . --vars "$VARS" >/tmp/gate_g0_parse.log 2>&1; then
    echo "E G0-COMPILE dbt-Jinja-Kompilierung fehlgeschlagen -- siehe tools/gate.sh, dann 'dbt compile' direkt"
    fail=1
fi
if [ "$fail" -eq 0 ]; then
    n=0
    while IFS= read -r -d '' f; do
        n=$((n + 1))
        out="$("$SQLFLUFF" parse --dialect exasol "$f" 2>&1)"
        if echo "$out" | grep -q "unparsable"; then
            rel="${f#"$COMPILED_DIR"/}"
            line="$(echo "$out" | grep -oE '^L:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')"
            echo "E G0-SYNTAX model=${rel%.sql} line=${line:-?}"
            fail=1
        fi
    done < <(find "$COMPILED_DIR" -name "*.sql" -print0 2>/dev/null)
    [ "$n" -eq 0 ] && { echo "E G0-EMPTY keine kompilierten Modelle unter $COMPILED_DIR -- Scaffold/Render pruefen"; fail=1; }
fi
[ "$fail" -eq 0 ] && echo "G0 OK ($n Modelle)"

echo
echo "=== G1: dbt run (Schema-je-Monat $MONAT) ==="
dbt --log-format json run --profiles-dir . --vars "$VARS" >/tmp/gate_g1_run.jsonl 2>/dev/null

jq -sr '
  [.[] | select(.info.name=="LogModelResult")] as $results
  | [.[] | select(.info.name=="SkippingDetails")] as $skips
  | (($results[0].data.total) // ($results | length) + ($skips | length)) as $total
  | ($results | map(select(.data.node_info.node_status=="success")) | length) as $ok
  | ($results | map(select(.data.node_info.node_status=="error")) | length) as $err
  | ($skips | length) as $skip
  | "\($ok)/\($total) Modelle erfolgreich (\($err) Fehler, \($skip) uebersprungen)"
' /tmp/gate_g1_run.jsonl

jq -r '
  select(.info.name=="RunResultError")
  | .data.node_info.node_name as $model
  | (.data.msg | split("\n") | map(select(test("message\\s*=>|code\\s*=>"))) | join(" | ")
     | gsub("^\\s+message\\s*=>\\s*"; "") | gsub("\\s*\\|\\s*code\\s*=>\\s*"; " sqlcode=")) as $short
  | "E G1-RUN model=\($model) \($short)"
' /tmp/gate_g1_run.jsonl

err_count="$(jq -r 'select(.info.name=="LogModelResult" and .data.node_info.node_status=="error")' /tmp/gate_g1_run.jsonl | wc -l | tr -d ' ')"
[ "$err_count" -gt 0 ] && fail=1

echo
echo "Rohlogs (nicht in Agenten-Kontext geben): /tmp/gate_g0_parse.log, /tmp/gate_g1_run.jsonl"
exit "$fail"
