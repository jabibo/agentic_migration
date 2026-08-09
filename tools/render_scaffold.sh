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

echo "dbt/ Scaffold geschrieben: dbt_project.yml, profiles.yml, macros/{generate_schema_name,schema_for,month_add}.sql"
