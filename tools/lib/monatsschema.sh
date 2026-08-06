# Monatsschema-Namenskonvention — einzige Quelle der Wahrheit fuer Praefix,
# Rollen, Vormonat. Portiert (unveraendert) aus without_macros/agentic/
# scripts/lib/monatsschema.sh — Namenskonvention ist wiederverwendbares
# Domaenenwissen, siehe skills/schema/monatsschema-konvention.md dort und
# docs/systemkontext.md B.4 hier. Quelle, nicht ausfuehren.
#
# shellcheck disable=SC2034
SCHEMA_PREFIX="sqlserver__bps__dbo__"

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
# Rollen: data|dwh|calc|fact|knz|strg|dim (Alias bio_dim)
schema_for() {
    local role="$1" monat="$2"
    case "$role" in
        data) echo "${SCHEMA_PREFIX}con_pd_data_${monat}" ;;
        dwh) echo "${SCHEMA_PREFIX}con_pd_dwh_${monat}" ;;
        calc) echo "${SCHEMA_PREFIX}con_pd_calc_${monat}" ;;
        fact) echo "${SCHEMA_PREFIX}con_pd_fact_${monat}" ;;
        knz) echo "${SCHEMA_PREFIX}con_pd_knz_${monat}" ;;
        strg) echo "${SCHEMA_PREFIX}con_strg_${monat}" ;;
        dim|bio_dim) echo "${SCHEMA_PREFIX}con_bio_dim_${monat}" ;;
        *)
            echo "unbekannte rolle: ${role}" >&2
            return 1
            ;;
    esac
}
