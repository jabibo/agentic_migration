# Monatsschema-Namenskonvention. Urspruenglich portiert (unveraendert) aus
# without_macros/agentic/scripts/lib/monatsschema.sh mit hier hart kodierter
# Rollen-Zuordnung -- diese Datei behauptete "einzige Quelle der Wahrheit"
# zu sein, obwohl sie unabhaengig von tools/compare_data.py,
# tools/render_dbt_models.py, tools/extract.py und den dbt-Makros
# schema_for.sql/prev_month_schema.sql denselben Stand pflegte (7-fache
# Duplikation, keine tatsaechlich gemeinsame Quelle). Jetzt echt konsolidiert:
# Praefix/Rollen kommen aus tools/schema_roles.json (via python3, einzige
# textuelle Quelle fuer alle sechs Verwender). Namenskonvention selbst
# weiterhin wiederverwendbares Domaenenwissen, siehe
# skills/schema/monatsschema-konvention.md (without_macros/agentic) und
# docs/systemkontext.md B.4. Quelle, nicht ausfuehren -- setzt CWD=Projekt-
# root voraus (Aufrufer cd'en vorher dorthin, s. tools/load_reference_data.sh).

# vormonat_of <YYYYMM> -> Vormonat als YYYYMM
vormonat_of() {
    local mon="$1"
    local year=$((10#${mon:0:4}))
    local month=$((10#${mon:4:2}))
    month=$((month - 1))
    if [ "$month" -eq 0 ]; then
        month=12
        year=$((year - 1))
    fi
    printf "%04d%02d\n" "$year" "$month"
}

# schema_for <rolle> <YYYYMM>
# Rollen: data|dwh|calc|fact|knz|strg|dim (Alias bio_dim -> dim)
schema_for() {
    local role="$1" monat="$2"
    [ "$role" = "bio_dim" ] && role="dim"
    python3 -c "
import json, sys
data = json.loads(open('tools/schema_roles.json').read())
role, monat = sys.argv[1], sys.argv[2]
if role not in data['roles']:
    print(f'unbekannte rolle: {role}', file=sys.stderr)
    sys.exit(1)
print(f\"{data['schema_prefix']}{data['roles'][role]}_{monat}\")
" "$role" "$monat"
}
