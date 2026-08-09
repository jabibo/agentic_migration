#!/usr/bin/env bash
#
# Erzeugt dbt/ reproduzierbar (dbt_project.yml, profiles.yml, macros/).
# dbt/ ist Build-Ergebnis und .gitignore'd (docs/adr/0001-deterministik-
# first.md) -- DIESES Skript ist die committete Quelle, dbt/ selbst nie
# von Hand pflegen. Idempotent: ueberschreibt bestehende dbt/-Scaffold-
# Dateien, laesst dbt/models/ (von tools/render_dbt_models.py) unberuehrt.
#
# Aufruf: bash tools/render_scaffold.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p dbt/models dbt/macros

cat > dbt/dbt_project.yml <<'EOF'
name: agentic_migration
version: "1.0.0"
config-version: 2
profile: agentic_migration

model-paths: ["models"]
macro-paths: ["macros"]

vars:
  verarbeitungsmonat: "202312"

models:
  agentic_migration:
    +materialized: table
EOF

# Lokale Test-Exasol (Docker, exapump-Profil "napc" -- gleiche Credentials,
# siehe docs/datenlage.md). Kein Geheimnis-Handling-Problem: lokaler
# Dev-Container mit Default-Passwort, kein Produktivzugang.
cat > dbt/profiles.yml <<'EOF'
agentic_migration:
  target: napc
  outputs:
    napc:
      type: exasol
      dsn: "localhost:8563"
      user: sys
      password: exasol
      database: EXA_DB
      schema: unconfigured_no_schema
      encryption: true
      validate_server_certificate: false
      threads: 2
EOF

# Schema-je-Verarbeitungsmonat-Modell: das custom schema (aus config(schema=...))
# ist die VOLLSTAENDIGE Zielschema-Angabe, kein dbt-Default-Suffix. Portiert
# aus without_macros/agentic (skills/schema/monatsschema-konvention.md).
cat > dbt/macros/generate_schema_name.sql <<'EOF'
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
EOF

# Jinja-Aequivalent zu tools/lib/monatsschema.sh:schema_for() -- dieselbe
# Konvention, zwei Laufzeiten (bash fuer Laden, dbt fuer Modelle). Bei
# Aenderung beide synchron halten.
cat > dbt/macros/schema_for.sql <<'EOF'
{% macro schema_for(role) %}
  {%- set prefix = "sqlserver__bps__dbo__" -%}
  {%- set roles = {
      "data": "con_pd_data", "dwh": "con_pd_dwh", "calc": "con_pd_calc",
      "fact": "con_pd_fact", "knz": "con_pd_knz", "strg": "con_strg",
      "dim": "con_bio_dim"
  } -%}
  {%- if role not in roles -%}
    {{ exceptions.raise_compiler_error("schema_for: unbekannte rolle '" ~ role ~ "'") }}
  {%- endif -%}
  {{ return(prefix ~ roles[role] ~ "_" ~ var("verarbeitungsmonat")) }}
{% endmacro %}
EOF

# Ersetzt dbo.uf_ueb_kalender_MonatAdd(yyyymm, n) -- reine Kalenderarithmetik
# (Monatsverschiebung), kein Fachwissen. [Annahme, laufzeit-verifiziert nur
# gegen G0/G1-Syntax, NICHT gegen G3-Datenaequivalenz -- Semantik aus dem
# Funktionsnamen abgeleitet, nicht aus einer Quelle]. Analog zu
# without_macros/agentic's month_add()-Makro (docs/systemkontext.md B.6),
# unabhaengig neu geschrieben (dortiger Quellcode liegt uns nicht vor).
cat > dbt/macros/month_add.sql <<'EOF'
{% macro month_add(yyyymm_expr, n) %}
  TO_CHAR(ADD_MONTHS(TO_DATE({{ yyyymm_expr }} || '01', 'YYYYMMDD'), {{ n }}), 'YYYYMM')
{% endmacro %}
EOF

# ErsterMonat/LetzterMonat je Kennzahl -- KEINE Annahme mehr, sondern aus
# der echten Quelle uebernommen: learning/pd/pd_skripte_excluded/
# UEB Kalender Dimensionen.td_ueb_kalender_KennzahlZeitraum.sql (Zeilen
# 90-97, 102-110). uf_ueb_kalender_Kennzahl() ist dort ein reines Lookup
# gegen eine Tabelle, die AUS DIESER Formel befuellt wird -- die Formel
# selbst ist die Quelle der Wahrheit, nicht die Lookup-Tabelle.
# [Quelle: learning/pd/pd_skripte_excluded/UEB Kalender Dimensionen.
#  td_ueb_kalender_KennzahlZeitraum.sql] -- widerlegt die fruehere
# [Annahme] "ErsterMonat==LetzterMonat==Verarbeitungsmonat" aus Session 3/4
# (siehe skills/transpile/exasol-dialect-gotchas.md, docs/session7-compare.md).
#
# Parameter nur fuer die 8 migrierten PD-Kennzahlen (701-711 ohne 721,
# das ist excluded) -- nicht die volle FIS-Tabelle mit >40 Kennzahlen.
# Alle 8 haben anzahl_berichtsmonate=60, diff_bm_letzter_monat=0; nur
# min_erster_monat unterscheidet sich (702/703 hart auf 201501, sonst
# dynamischer 4-Jahres-Boden).
cat > dbt/macros/kennzahl_zeitraum.sql <<'EOF'
{% macro knz_zeitraum_params(knz) %}
  {%- set params = {
      "701": {"anzahl": 60, "diff": 0, "min_erster_monat": none},
      "702": {"anzahl": 60, "diff": 0, "min_erster_monat": 201501},
      "703": {"anzahl": 60, "diff": 0, "min_erster_monat": 201501},
      "705": {"anzahl": 60, "diff": 0, "min_erster_monat": none},
      "706": {"anzahl": 60, "diff": 0, "min_erster_monat": none},
      "708": {"anzahl": 60, "diff": 0, "min_erster_monat": none},
      "709": {"anzahl": 60, "diff": 0, "min_erster_monat": none},
      "711": {"anzahl": 60, "diff": 0, "min_erster_monat": none}
  } -%}
  {%- if knz|string not in params -%}
    {{ exceptions.raise_compiler_error(
        "knz_zeitraum_params: unbekannte Kennzahl '" ~ knz ~ "' -- Parameter aus "
        ~ "td_ueb_kalender_KennzahlZeitraum ergaenzen, nicht raten.") }}
  {%- endif -%}
  {{ return(params[knz|string]) }}
{% endmacro %}

{% macro knz_letzter_monat(knz) %}
  {%- set p = knz_zeitraum_params(knz) -%}
  {%- set vm = var("verarbeitungsmonat")|int -%}
  {%- set total = (vm // 100) * 12 + (vm % 100) - 1 + p.diff -%}
  {{ return((total // 12) * 100 + (total % 12) + 1) }}
{% endmacro %}

{% macro knz_erster_monat(knz) %}
  {%- set p = knz_zeitraum_params(knz) -%}
  {%- set vm = var("verarbeitungsmonat")|int -%}
  {%- set vm_year = vm // 100 -%}
  {%- set total = (vm // 100) * 12 + (vm % 100) - 1 - (p.anzahl - 1) -%}
  {%- set rolling = (total // 12) * 100 + (total % 12) + 1 -%}
  {%- set floor = p.min_erster_monat if p.min_erster_monat is not none else (vm_year - 4) * 100 + 1 -%}
  {{ return([rolling, floor] | max) }}
{% endmacro %}
EOF

# Mehrfach-Datei-Ladepfad (Session 8, Punkt 1 -- doch nachgebaut, s.
# docs/datenlage.md §4.1). Original-T-SQL (docs/datenlage.md §4.1,
# Quelldatei "PD Create Table.Template Tables.sql" -- Inhalt dort
# zusammengefasst, Originaldatei nicht mehr im Repo verfuegbar):
# xp_dirtree listet alle Dateien im Importverzeichnis, ein Cursor legt
# pro gefundener Datei eine eigene dateinamen-benannte Tabelle an und
# fuegt sie sequenziell in die Zieltabelle ein, mit einem "NOT IN"-Check
# gegen bereits eingefuegte Schluessel -- die ERSTE Datei (Cursor-
# Reihenfolge) gewinnt bei doppeltem Schluessel, nicht die letzte.
# tools/load_reference_data.sh legt seit Session 8 zusaetzlich zur festen
# Komfort-Tabelle (bi_delta_<kuerzel>) je Datei eine eigene, nach dem
# vollen Dateinamen benannte Tabelle an (bi_delta_<kuerzel>_<YYYYMM>_<ts>).
# Diese zwei Makros bauen den Mehrfach-Datei-Pfad dbt-nativ:
# discover_delta_files() findet zur Compile-/Laufzeit (run_query gegen
# EXA_ALL_TABLES) alle Datei-Tabellen eines Kuerzels/Monats,
# delta_union_dedup() unioniert sie und dedupliziert per ROW_NUMBER()
# nach der Cursor-Reihenfolge.
# [Annahme, NICHT gegen G3 verifizierbar]: Cursor-Reihenfolge = xp_dirtree-
# Reihenfolge, hier nachgebildet als alphabetische Sortierung der vollen
# Datei-Tabellennamen -- da der Bereitstellungs-Timestamp im Dateinamen
# sortierbar (YYYYMMDDHHMMSS) hinten steht, entspricht das zugleich der
# chronologischen Ankunftsreihenfolge. Unser Testkorpus hat nur je eine
# Datei pro Kuerzel/Monat (docs/datenlage.md §4.1) -- die Tie-Break-Regel
# bleibt bis zu echten Mehrdatei-Testdaten unverifiziert.
cat > dbt/macros/delta_multifile.sql <<'EOF'
{% macro discover_delta_files(kuerzel) %}
  {%- set schema = schema_for('data') -%}
  {%- set pattern = 'BI\_DELTA\_' ~ kuerzel|upper ~ '\_' ~ var('verarbeitungsmonat') ~ '\_%' -%}
  {%- if execute -%}
    {%- set query -%}
      SELECT table_name FROM exa_all_tables
      WHERE table_schema = '{{ schema|upper }}'
        AND table_name LIKE '{{ pattern }}' ESCAPE '\'
        AND table_name <> 'BI_DELTA_{{ kuerzel|upper }}'
      ORDER BY table_name
    {%- endset -%}
    {%- set results = run_query(query) -%}
    {%- set tables = results.columns[0].values() -%}
  {%- else -%}
    {%- set tables = [] -%}
  {%- endif -%}
  {{ return(tables) }}
{% endmacro %}

{% macro delta_union_dedup(kuerzel, key_column) %}
  {#- Hilfsspalten ohne fuehrenden Unterstrich: Exasol erlaubt bei
      unquotierten Identifiern kein "_"/"__" als erstes Zeichen
      (laufzeit-verifiziert, "expecting IDENTIFIER_PART_"). Praefix
      "mfd_" (multi-file-dedup) statt Unterstrich, um Kollision mit
      echten Geschaeftsspalten unwahrscheinlich zu machen.
      key_column MUSS die Quotierung des Aufrufers tragen, z.B.
      '"pd_auftr_id"' -- die per exapump/CSV geladenen Delta-Tabellen
      haben quotiert-kleingeschriebene Spalten (laufzeit-verifiziert:
      unquotiertes d.pd_auftr_id faltet zu D.PD_AUFTR_ID -> "object
      not found", da real "pd_auftr_id" quotiert existiert).

      mfd_quelldatei: volle Quell-Tabelle (== Dateiname ohne .csv, s.
      tools/load_reference_data.sh) je Zeile -- noetig, weil einzelne
      Objekte (z.B. tf_deltant_pd_fa/azt, s. docs/session9-multifile-
      loading.md, Runde 3) im Original-T-SQL bi_timestamp/bi_load_date
      NICHT aus einer Datenspalte, sondern aus dem Tabellen-/Dateinamen
      ableiten (REPLACE([tabelle], 'BI_DELTA_FA', '') o.ae.) -- ohne
      diese Spalte war die Ableitung dbt-seitig gar nicht abbildbar. -#}
  {%- set schema = schema_for('data') -%}
  {%- set tables = discover_delta_files(kuerzel) -%}
  {%- if execute and tables|length == 0 -%}
    {{ exceptions.raise_compiler_error(
        "delta_union_dedup: keine Datei-Tabelle fuer '" ~ kuerzel
        ~ "' im Verarbeitungsmonat " ~ var('verarbeitungsmonat')
        ~ " gefunden (Schema " ~ schema ~ "). Fehlt der Import "
        ~ "(tools/load_reference_data.sh)?") }}
  {%- endif -%}
  (
    SELECT u.*
    FROM (
      SELECT d.*, ROW_NUMBER() OVER (
               PARTITION BY d.{{ key_column }} ORDER BY d.mfd_quellreihenfolge ASC
             ) AS mfd_rn
      FROM (
        {% for t in tables %}
        SELECT *, {{ loop.index }} AS mfd_quellreihenfolge, '{{ t }}' AS mfd_quelldatei
        FROM {{ schema }}.{{ t }}
        {% if not loop.last %}UNION ALL{% endif %}
        {% endfor %}
      ) d
    ) u
    WHERE u.mfd_rn = 1
  )
{% endmacro %}
EOF

echo "dbt/ Scaffold geschrieben: dbt_project.yml, profiles.yml, macros/{generate_schema_name,schema_for,month_add,kennzahl_zeitraum,delta_multifile}.sql"
