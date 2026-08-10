"""Einzige Quelle der Wahrheit fuer Schema-Praefix und Rollen-Zuordnung
(SCHEMA_PREFIX, ROLE_TO_DB/ROLE_BY_DB) -- vorher siebenfach dupliziert:
compare_data.py, render_dbt_models.py, extract.py (Werte-Ebene),
dbt/macros/schema_for.sql + prev_month_schema.sql (ueber
render_scaffold.sh generiert) und tools/lib/monatsschema.sh (bash-
Aequivalent fuer Lade-Skripte). Alle sechs lasen unabhaengig voneinander
denselben Stand, ohne dass ein Aenderungsfehler an einer Stelle
irgendwo sonst aufgefallen waere -- s. Diskussion "Rolle->DB-Zuordnung
in eine zentrale Config ziehen".

Bei einem neuen Verfahren/Prozess (andere Datenbanknamen, anderes
Schema-Praefix): NUR schema_roles.json aendern. Kein Python-/Jinja-/
Bash-Code sonst.
"""
from __future__ import annotations

import json
from pathlib import Path

_DATA = json.loads((Path(__file__).parent / "schema_roles.json").read_text())
SCHEMA_PREFIX: str = _DATA["schema_prefix"]
ROLE_TO_DB: dict[str, str] = _DATA["roles"]
ROLE_BY_DB: dict[str, str] = {v: k for k, v in ROLE_TO_DB.items()}
