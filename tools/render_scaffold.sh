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

echo "dbt/ Scaffold geschrieben: dbt_project.yml, profiles.yml, macros/{generate_schema_name,schema_for,month_add,kennzahl_zeitraum}.sql"
