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
#   bash tools/load_reference_data.sh <YYYYMM> [--dims-only|--delta-only|--views-only]
set -euo pipefail

MONAT="${1:?Aufruf: tools/load_reference_data.sh <YYYYMM> [--dims-only|--delta-only|--views-only]}"
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
        local base tbl tbl_perfile
        base="$(basename "$f" .csv)"
        tbl_perfile="${base#dbo__}"  # bi_delta_<kuerzel>_<YYYYMM>_<ts> -- volle,
                                       # eindeutige Pro-Datei-Tabelle (Konvention wie
                                       # PD Create Table.Template Tables.sql: Dateiname
                                       # = Tabellenname, siehe docs/datenlage.md §4.1)
        tbl="${tbl_perfile%_*}"      # Bereitstellungs-Timestamp entfernen
        tbl="${tbl%_*}"              # Verarbeitungsmonat entfernen -> bi_delta_<kuerzel>
                                       # (feste Komfort-Tabelle, bisherige Konvention --
                                       # bleibt bestehen, damit nichts Vorhandenes bricht)
        exapump sql -p "$PROFILE" "DROP TABLE IF EXISTS ${schema}.${tbl}" >/dev/null
        exapump upload "$f" --table "${schema}.${tbl}" -p "$PROFILE" < /dev/null >/dev/null
        exapump sql -p "$PROFILE" "DROP TABLE IF EXISTS ${schema}.${tbl_perfile}" >/dev/null
        exapump upload "$f" --table "${schema}.${tbl_perfile}" -p "$PROFILE" < /dev/null >/dev/null
        n=$((n + 1))
    done
    if [ "$n" -eq 0 ]; then
        echo "    WARNUNG: kein Delta-Import fuer $MONAT gefunden (siehe docs/datenlage.md, Luecke 202403)." >&2
    else
        echo "    $n Delta-Dateien geladen (je 2 Tabellen: feste Komfort-Tabelle + Pro-Datei-Tabelle)."
    fi
}

# Views, die als externe Quellen deklariert sind (dbt/models/sources.yml)
# aber im Quellsystem nicht direkt als Tabelle/View vorliegen -- POC-
# Ersatz per Rohdimension (bereits via load_dimensions in $dim_schema
# geladen) + Pass-Through-View "dieselbe Abbildung", keine Transformation,
# keine Fachentscheidung. Zielschema variiert je Objekt (aus dem
# Quellskript abgeleitet, docs/systemkontext.md B.1/B.4 -- nicht geraten):
# vd_pd_dienststelle/vd_as_bps_Region -> KNZ (per <DBNAME_PD_KNZ>-
# Platzhalter im Quellskript), td_ueb_kalender_Tag -> CALC (ambient-
# resolved aus USE con_pd_calc, siehe docs/session6-bestand-run.md).
load_knz_views() {
    local dim_schema knz_schema calc_schema
    dim_schema="$(schema_for dim "$MONAT")"
    knz_schema="$(schema_for knz "$MONAT")"
    calc_schema="$(schema_for calc "$MONAT")"
    echo "==> Pass-Through-Views fuer fehlende Quellen"
    exapump sql -p "$PROFILE" "CREATE SCHEMA IF NOT EXISTS $knz_schema" >/dev/null
    exapump sql -p "$PROFILE" "CREATE SCHEMA IF NOT EXISTS $calc_schema" >/dev/null

    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_pd_dienststelle AS
        SELECT \"ba_schl\", \"org_id\" FROM ${dim_schema}.vd_as_pd_dienststelle" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_as_bps_Region AS
        SELECT * FROM ${dim_schema}.vd_as_bps_region" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${calc_schema}.td_ueb_kalender_Tag AS
        SELECT * FROM ${dim_schema}.td_ueb_kalender_tag" >/dev/null

    # KNZ-706-Handoff (Session 9): dieselbe Luecke, vier weitere Dimensionen
    # -- reale Daten liegen unter vd_as_* in DIM, con_pd_knz erwartet andere
    # Namen. Wie oben: voller Pass-Through (SELECT *), keine Spaltenauswahl,
    # keine Fachentscheidung -- nur bei vd_pd_dienststelle war die Spalten-
    # einschraenkung ein bereits dokumentierter, spezifischer Fund.
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_pd_taetigkeit_beauftragt AS
        SELECT * FROM ${dim_schema}.vd_as_pd_taetigkeitbeauftragt" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_bps_stelle AS
        SELECT * FROM ${dim_schema}.vd_as_bps_stelle" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_pd_abschlussart AS
        SELECT * FROM ${dim_schema}.vd_as_pd_abschlussart" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_bps_Abschlussgrund AS
        SELECT * FROM ${dim_schema}.vd_as_bps_abschlussgrund" >/dev/null

    # KNZ-701-Handoff (Session 10, Batch-Lauf): dieselbe Luecke, restliche
    # con_pd_knz-Quellen aus dbt/models/sources.yml (deterministisch aus
    # reports/lineage.jsonl, s. tools/render_dbt_models.py) auf einmal
    # nachgezogen -- vermeidet, dass jedes Batch-Objekt einzeln an derselben
    # Infra-Luecke haengen bleibt, bevor es zur eigentlichen Migrations-
    # arbeit kommt.
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_as_bps_Dringlichkeit AS
        SELECT * FROM ${dim_schema}.vd_as_bps_dringlichkeit" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_bps_Bildungsabschluss AS
        SELECT * FROM ${dim_schema}.vd_as_pd_bildungsabschluss" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_bps_Bildungsniveau AS
        SELECT * FROM ${dim_schema}.vd_as_pd_bildungsniveau" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_bps_rechtskreis_auftraggeber AS
        SELECT * FROM ${dim_schema}.vd_as_bps_rechtskreisauftraggeber" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_pd_geschlecht AS
        SELECT * FROM ${dim_schema}.vd_as_pd_geschlecht" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_pd_leistung AS
        SELECT * FROM ${dim_schema}.vd_as_pd_leistung" >/dev/null
    exapump sql -p "$PROFILE" "CREATE OR REPLACE VIEW ${knz_schema}.vd_pd_taetigkeit_durchgefuehrt AS
        SELECT * FROM ${dim_schema}.vd_as_pd_taetigkeitdurchgefuehrt" >/dev/null
    echo "    14 Views erstellt (con_pd_knz: vd_pd_dienststelle, vd_as_bps_Region,"
    echo "    vd_pd_taetigkeit_beauftragt, vd_bps_stelle, vd_pd_abschlussart, vd_bps_Abschlussgrund,"
    echo "    vd_as_bps_Dringlichkeit, vd_bps_Bildungsabschluss, vd_bps_Bildungsniveau,"
    echo "    vd_bps_rechtskreis_auftraggeber, vd_pd_geschlecht, vd_pd_leistung,"
    echo "    vd_pd_taetigkeit_durchgefuehrt; calc: td_ueb_kalender_Tag)."
}

case "$MODE" in
    --dims-only) load_dimensions ;;
    --delta-only) load_delta ;;
    --views-only) load_knz_views ;;
    all) load_dimensions; load_delta; load_knz_views ;;
    *) echo "FEHLER: unbekannter Modus '$MODE'" >&2; exit 1 ;;
esac

echo "==> Fertig."
