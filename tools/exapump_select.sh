#!/usr/bin/env bash
#
# Read-only Exasol-Debugging fuer Qwen (AGENTS.md: "exapump sql SELECT
# (lesend) ist zur Fehlersuche in Ordnung"). Bisher technisch nicht
# nutzbar: opencode.jsonc's bash-Allowlist kennt kein "exapump *" (aus
# gutem Grund -- ein blanko "exapump sql *": "allow" wuerde CREATE/INSERT/
# DROP genauso durchlassen und den Session-5-Bypass wiedereroeffnen, s.
# CLAUDE.md/docs/session5-qwen-run.md). Dieser Wrapper schliesst die
# Luecke sicher: nur EXAKT ein reines SELECT-Statement wird durchgereicht,
# validiert per sqlglot-Parse (nicht per Regex/String-Suche -- ein
# Semikolon-Split o.ae. liesse sich per Kommentar/String-Trick umgehen,
# ein echter Parser nicht).
#
# Aufruf: tools/exapump_select.sh "<SELECT ...>"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

QUERY="${1:?Aufruf: tools/exapump_select.sh \"<SELECT ...>\"}"
PROFILE="${EXAPUMP_PROFILE:-napc}"

.venv/bin/python3 -c "
import sys
import sqlglot
from sqlglot import exp

query = sys.argv[1]
try:
    statements = sqlglot.parse(query, read='exasol')
except Exception as e:
    print(f'FEHLER: SQL nicht parsbar -- {e}', file=sys.stderr)
    sys.exit(1)

statements = [s for s in statements if s is not None]
if len(statements) != 1:
    print(f'FEHLER: genau 1 Statement erwartet, {len(statements)} gefunden -- nur Einzel-SELECTs erlaubt.', file=sys.stderr)
    sys.exit(1)

stmt = statements[0]
if not isinstance(stmt, exp.Select):
    print(f'FEHLER: nur SELECT erlaubt, gefunden: {type(stmt).__name__}.', file=sys.stderr)
    sys.exit(1)

# Guertel + Hosentraeger: kein eingebetteter Command/DDL/DML-Knoten irgendwo im Baum
# (z.B. via Subquery-Trick), keine INTO-Klausel (SELECT ... INTO ist ein CREATE in Exasol).
forbidden = (exp.Command, exp.Insert, exp.Update, exp.Delete, exp.Create, exp.Drop, exp.Alter, exp.Merge)
if stmt.args.get('into') or any(stmt.find_all(forbidden)):
    print('FEHLER: Statement enthaelt einen nicht-lesenden Teil (INTO/Command/DDL/DML).', file=sys.stderr)
    sys.exit(1)
" "$QUERY"

exapump sql -p "$PROFILE" -f json "$QUERY"
