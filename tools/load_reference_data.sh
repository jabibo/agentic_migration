#!/usr/bin/env bash
#
# Laedt Test-/Referenzdaten (Dimensionen + Delta-Importe) EINES Verarbeitungs-
# monats nach Exasol, per exapump, in monats-suffigierte Schemata (siehe
# docs/systemkontext.md B.4, tools/lib/monatsschema.sh). Vereinfachte Fassung
# gegenueber without_macros/agentic/scripts/load_*_monatsschema.sh: dort ein
# Winner-Detection/Archiv-Mechanismus fuer eine LAUFENDE Lieferkette --
# hier ein statischer, dreimonatiger Testdatensatz (docs/datenlage.md), also
# simples Drop+Reload statt Idempotenz-Buchhaltung.
#
# Voraussetzung: Exasol erreichbar (`exapump sql -p napc "SELECT 1"`).
#
# Aufruf:
#   bash tools/load_reference_data.sh <YYYYMM> [--dims-only|--delta-only]
set -euo pipefail

MONAT="${1:?Aufruf: tools/load_reference_data.sh <YYYYMM> [--dims-only|--delta-only]}"
MODE="${2:-all}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/monatsschema.sh
source tools/lib/monatsschema.sh

PROFILE="${EXAPUMP_PROFILE:-napc}"
DIM_DIR="learning/pd/dimensions"
DELTA_DIR="data/pd"

echo "==> Exasol-Verbindung pruefen (Profil: $PROFILE)"
exapump sql -p "$PROFILE" "SELECT 1" >/dev/null || {
    echo "FEHLER: Exasol nicht erreichbar ueber Profil '$PROFILE'." >&2
    exit 1
}

load_dimensions() {
    local schema
    schema="$(schema_for dim "$MONAT")"
    echo "==> Dimensionen -> $schema"
    test -d "$DIM_DIR" || { echo "FEHLER: $DIM_DIR fehlt (siehe docs/datenlage.md)." >&2; exit 1; }
    exapump sql -p "$PROFILE" "CREATE SCHEMA IF NOT EXISTS $schema" >/dev/null
    local n=0
    for f in "$DIM_DIR"/*.parquet; do
        [ -e "$f" ] || continue
        local base tbl
        base="$(basename "$f" .parquet)"
        tbl="${base#dbo__}"
        exapump sql -p "$PROFILE" "DROP TABLE IF EXISTS ${schema}.${tbl}" >/dev/null
        exapump upload "$f" --table "${schema}.${tbl}" -p "$PROFILE" < /dev/null >/dev/null
        n=$((n + 1))
    done
    echo "    $n Dimensionstabellen geladen."
}

load_delta() {
    local schema
    schema="$(schema_for data "$MONAT")"
    echo "==> Delta-Import ($MONAT) -> $schema"
    test -d "$DELTA_DIR" || { echo "FEHLER: $DELTA_DIR fehlt (siehe docs/datenlage.md)." >&2; exit 1; }
    exapump sql -p "$PROFILE" "CREATE SCHEMA IF NOT EXISTS $schema" >/dev/null
    local n=0
    for f in "$DELTA_DIR"/dbo__bi_delta_*_"${MONAT}"_*.csv; do
        [ -e "$f" ] || continue
        local base tbl
        base="$(basename "$f" .csv)"
        tbl="${base#dbo__}"       # bi_delta_<kuerzel>_<YYYYMM>_<ts>
        tbl="${tbl%_*}"           # Bereitstellungs-Timestamp entfernen
        tbl="${tbl%_*}"           # Verarbeitungsmonat entfernen -> bi_delta_<kuerzel>
        exapump sql -p "$PROFILE" "DROP TABLE IF EXISTS ${schema}.${tbl}" >/dev/null
        exapump upload "$f" --table "${schema}.${tbl}" -p "$PROFILE" < /dev/null >/dev/null
        n=$((n + 1))
    done
    if [ "$n" -eq 0 ]; then
        echo "    WARNUNG: kein Delta-Import fuer $MONAT gefunden (siehe docs/datenlage.md, Luecke 202403)." >&2
    else
        echo "    $n Delta-Tabellen geladen."
    fi
}

case "$MODE" in
    --dims-only) load_dimensions ;;
    --delta-only) load_delta ;;
    all) load_dimensions; load_delta ;;
    *) echo "FEHLER: unbekannter Modus '$MODE'" >&2; exit 1 ;;
esac

echo "==> Fertig."
