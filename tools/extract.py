#!/usr/bin/env python3
"""P0-P4: deterministic extraction pipeline. No LLM involved.

P0 Platzhalter   /*<NAME>*/dummy/*<NAME>*/ -> kanonischer Schema-Name
P1 Split         GO (Batch) + eigener Statement-Splitter (Zeilenanfang +
                 Klammer-/BEGIN-END-Tiefe) -> Statement-Liste je Skript
P2 Parse         sqlglot.parse_one(read=tsql), je Statement isoliert
                 -> AST je Statement, Parse-Fehler = Triage-Kante
P3 Lineage       AST-Walk    -> {target, sources, stmt_type} je Statement, Schreibzaehler je Ziel
P4 Transpile     write=exasol -> Exasol-SQL-Vorschlag (best effort, kein Fix)

Ausgabe:
  reports/lineage.jsonl   eine Zeile je Statement
  reports/triage.json     ein Datensatz je Quellobjekt (Klasse A/B/C)
  reports/triage.md       Zusammenfassung, menschenlesbar

Kein DB-Roundtrip, kein Netzwerk. Siehe docs/adr/0001-deterministik-first.md.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

import sqlglot
from sqlglot import exp
from sqlglot.errors import ErrorLevel

from schema_roles import ROLE_TO_DB, SCHEMA_PREFIX  # noqa: E402

# --------------------------------------------------------------------------
# P0 -- Platzhalter-Rewrite
# --------------------------------------------------------------------------
# Konvention: skills/schema/monatsschema-konvention.md (without_macros/agentic)
#   sourcesys__verfahren__db__schema[_verarbeitungsmonat]
# Nur DB-Namens-Platzhalter werden aufgeloest -- sie bestimmen Lineage-Identitaet.
# Wert-Platzhalter (Audit_ID, Berichtsmonat) sind fuer die Tabellen-Lineage
# irrelevant und bleiben unangetastet (der dummy-Wert parst als harmloses Literal).

PLACEHOLDER_RE = re.compile(r"/\*<([A-Za-z0-9_.]+)>\*/.*?/\*<\1>\*/", re.DOTALL)

# Platzhalter-Name (aus dem Quell-SQL-Template) -> DB-Name. Die Werte kommen
# aus schema_roles.py (einzige Quelle der Wahrheit) -- nur die Zuordnung
# "welcher Platzhalter-Token bedeutet welche Rolle" ist hier lokal, weil sie
# vom Templating-Format der Quellskripte abhaengt (bei einem neuen Prozess
# ggf. andere Token-Namen, aber dieselben Rollen/DB-Namen aus der Config).
DB_PLACEHOLDER_SCHEMA = {
    "DBNAME_PD_FACT": ROLE_TO_DB["fact"],
    "DBNAME_PD_KNZ": ROLE_TO_DB["knz"],
    "DBNAME_PD_CALC": ROLE_TO_DB["calc"],
    "DBNAME_PD_DATA": ROLE_TO_DB["data"],
    "DBNAME_PD_DWH": ROLE_TO_DB["dwh"],
    "DBNAME_PD_DWH_Vormonat": ROLE_TO_DB["dwh"] + "__vormonat",  # dbt: source ueber month_add()-Makro, kein ref()
    "DBNAME_CON_DIM": ROLE_TO_DB["dim"],
    "DBNAME_CON_STRG": ROLE_TO_DB["strg"],
}


def rewrite_placeholders(sql: str) -> tuple[str, list[str]]:
    unknown: list[str] = []

    def _sub(m: re.Match) -> str:
        name = m.group(1)
        if name in DB_PLACEHOLDER_SCHEMA:
            return f"{SCHEMA_PREFIX}{DB_PLACEHOLDER_SCHEMA[name]}"
        if "." in name:  # Wert-Platzhalter (Strg.Audit_ID, Ablauf.Berichtsmonat) -- unangetastet
            return m.group(0)
        unknown.append(name)
        return f"__unknown_{name}__"

    return PLACEHOLDER_RE.sub(_sub, sql), unknown


# Boilerplate-Erkennung: @von = ErsterMonat, @bis = LetzterMonat FROM
# dbo.uf_ueb_kalender_Kennzahl('<N>') -- identisch in 8/9 Kennzahl-Skripten
# (grep-bestaetigt), Spaltennamen sind selbstbeschreibend. NICHT mehr
# [Annahme]: ErsterMonat/LetzterMonat sind kein Einzelmonat, sondern ein
# rollierendes Fenster -- Formel + Parameter je Kennzahl [Quelle:
# learning/pd/pd_skripte_excluded/UEB Kalender Dimensionen.
# td_ueb_kalender_KennzahlZeitraum.sql]. Die fruehere "Erster==Letzter==
# Verarbeitungsmonat"-Annahme war falsch -- widerlegt durch G3
# (docs/session7-compare.md). Berechnung: dbt/macros/kennzahl_zeitraum.sql
# (tools/render_scaffold.sh), Aufloesung hier nur strukturell (welche
# Variable -> welches Makro), keine erneute Fachentscheidung.
MONTH_RANGE_RE = re.compile(
    r"@(\w+)\s*=\s*ErsterMonat.*?@(\w+)\s*=\s*LetzterMonat"
    r".*?FROM\s+(?:dbo\.)?uf_ueb_kalender_Kennzahl\(\s*'(\d+)'\s*\)",
    re.IGNORECASE | re.DOTALL,
)


def find_month_range_vars(rewritten_sql: str) -> dict[str, str]:
    """@von_mon_id/@bis_mon_id (oder wie auch immer benannt) -> Jinja-Makroaufruf
    (jeweils an die konkrete Kennzahl-Nummer gebunden, nicht generisch)."""
    m = MONTH_RANGE_RE.search(rewritten_sql)
    if not m:
        return {}
    von, bis, knz = m.group(1), m.group(2), m.group(3)
    return {von: f"knz_erster_monat({knz})", bis: f"knz_letzter_monat({knz})"}


# --------------------------------------------------------------------------
# P1 -- Batch-Split (GO) und Statement-Split (Zeilenanfang + Klammer-/Block-Tiefe)
# --------------------------------------------------------------------------
# WARUM NICHT sqlglot.parse() auf den ganzen Batch: dieser Codestil terminiert
# Statements oft nicht mit ";" (Boundary ergibt sich aus dem naechsten
# Schluesselwort am Zeilenanfang). sqlglot.parse() versucht dann den ganzen
# Rest ab einem unbekannten Token (typischerweise ein EXEC mit benannten
# Parametern) als ein Statement zu lesen -- scheitert das, werden nachfolgende
# echte Statements (SELECT INTO, UPDATE, ...) still und leise verschluckt,
# ohne Fehler. Deshalb: eigener Splitter, jedes Statement einzeln geparst.

GO_RE = re.compile(r"^\s*GO\s*$", re.IGNORECASE | re.MULTILINE)


def split_batches(sql: str) -> list[str]:
    return [b for b in GO_RE.split(sql) if b.strip()]


STMT_KEYWORDS = {
    "SELECT", "INSERT", "UPDATE", "DELETE", "EXEC", "EXECUTE", "DECLARE",
    "CREATE", "ALTER", "DROP", "USE", "TRUNCATE", "MERGE", "IF", "WHILE", "WITH",
}
# SET ist eigenstaendiges Statement (SET NOCOUNT ON, SET @var = ...) AUSSER
# direkt nach UPDATE (dessen SET-Klausel) -- dort nicht schneiden.
_TOKEN_RE = re.compile(
    r"--[^\n]*"                       # Zeilenkommentar
    r"|/\*.*?\*/"                     # Blockkommentar
    r"|'(?:[^']|'')*'"                # String-Literal (mit '' escape)
    r"|[()]"                          # Klammern
    r"|\b[A-Za-z_][A-Za-z0-9_]*\b",    # Wort
    re.DOTALL,
)


def split_statements(batch: str) -> list[str]:
    """Schneidet an Zeilenanfaengen mit einem Top-Level-Schluesselwort,
    solange Klammertiefe==0 und wir nicht in einem BEGIN..END-Block stecken
    (dessen Inhalt bleibt bewusst ein Klumpen -- er ist prozedural und wird
    ohnehin nicht Klasse A/B)."""
    cuts = []
    paren_depth = 0
    block_depth = 0
    after_update = False  # naechstes SET ist die UPDATE-Klausel, nicht eigenstaendig
    after_set_op = False  # naechstes SELECT ist UNION/UNION ALL/INTERSECT/EXCEPT-
    # Fortsetzung derselben Anweisung, keine neue Statement-Grenze
    # [laufzeit-verifiziert: "SELECT ... INTO x FROM a UNION ALL SELECT * FROM
    # b" wurde vorher an der zweiten SELECT-Zeile in zwei Chunks zerschnitten
    # -- sqlglot bekam dann nur die linke Haelfte, der rechte UNION-Zweig ging
    # komplett verloren (PD KNZ 711.KNZ 711.sql, vorP51/nachP51-Zusammenfuehrung)].
    for m in _TOKEN_RE.finditer(batch):
        tok = m.group(0)
        if tok == "(":
            paren_depth += 1
            continue
        if tok == ")":
            paren_depth = max(0, paren_depth - 1)
            continue
        if tok.startswith("--") or tok.startswith("/*") or tok.startswith("'"):
            continue
        upper = tok.upper()
        if upper == "BEGIN":
            block_depth += 1
            continue
        if upper == "END":
            block_depth = max(0, block_depth - 1)
            continue
        if upper in ("UNION", "INTERSECT", "EXCEPT"):
            after_set_op = True
            continue
        is_stmt_kw = upper in STMT_KEYWORDS or (upper == "SET" and not after_update)
        if paren_depth == 0 and block_depth == 0 and is_stmt_kw:
            if upper == "SELECT" and after_set_op:
                after_set_op = False
                continue
            line_start = batch.rfind("\n", 0, m.start()) + 1
            if batch[line_start:m.start()].strip() == "":
                cuts.append(m.start())
                after_update = upper == "UPDATE"

    bounds = [0] + cuts + [len(batch)]
    stmts = []
    for a, b in zip(bounds, bounds[1:]):
        chunk = batch[a:b].strip()
        if chunk and _has_code(chunk):
            stmts.append(chunk)
    return stmts


def _has_code(chunk: str) -> bool:
    """False wenn der Chunk nur aus Kommentaren/Whitespace besteht (z.B. der
    --<doku>-Header) -- solche Chunks sind kein Statement und sollen keinen
    Parse-Error erzeugen."""
    for m in _TOKEN_RE.finditer(chunk):
        tok = m.group(0)
        if not (tok.startswith("--") or tok.startswith("/*")):
            return True
    return False


# --------------------------------------------------------------------------
# P2/P3 -- Parse + Lineage je Statement
# --------------------------------------------------------------------------

WRITE_TYPES = (exp.Insert, exp.Update, exp.Delete, exp.Create)
DYNAMIC_SQL_RE = re.compile(r"sp_executesql|EXEC\s*\(", re.IGNORECASE)
CURSOR_RE = re.compile(r"\bCURSOR\b", re.IGNORECASE)


def table_key(t: exp.Table, ambient_db: str | None = None) -> str:
    """Kanonischer 'db.tabelle'-Bezeichner. 'dbo' ist T-SQLs Standard-Schema
    und in diesem Datensatz NIE die tatsaechlich unterscheidende Datenbank --
    egal ob es explizit dasteht (catalog.dbo.tabelle, 3-teilig) oder implizit
    gemeint ist (dbo.tabelle bzw. nackt tabelle, aufgeloest ueber das
    Batch-`USE <db>`): 'dbo' wird immer durch die wirkliche DB ersetzt.
    Ohne das waeren z.B. 'con_pd_calc.dbo.x' (expliziter Verweis) und
    'dbo.x' unter USE con_pd_calc (Ambient-Verweis auf dieselbe Tabelle)
    zwei verschiedene Keys -- bricht jede ref()/source()-Zuordnung."""
    catalog, db, name = t.catalog, t.db, t.name
    if db and db.lower() == "dbo":
        db = catalog or ambient_db
        catalog = None
    if catalog and db:
        return f"{catalog}.{db}.{name}"
    if db:
        return f"{db}.{name}"
    if catalog:
        return f"{catalog}.{name}"
    if ambient_db and name:
        return f"{ambient_db}.{name}"
    return t.sql()


def statement_lineage(stmt: exp.Expression, ambient_db: str | None = None) -> dict:
    kind = type(stmt).__name__
    target = None
    # UNION/UNION ALL traegt die INTO-Klausel nur auf dem linkesten SELECT
    # (T-SQL-Syntax: "SELECT ... INTO x FROM a UNION ALL SELECT ... FROM b") --
    # ohne diesen Walk bleibt target=None fuer jedes "SELECT INTO ... UNION
    # ALL ..."-Statement, unabhaengig davon wie oft verschachtelt.
    into_stmt = stmt
    while isinstance(into_stmt, exp.Union):
        into_stmt = into_stmt.this
    if isinstance(into_stmt, exp.Select) and into_stmt.args.get("into"):
        into_table = into_stmt.args["into"].this
        if isinstance(into_table, exp.Table):
            target = table_key(into_table, ambient_db)
        kind = "SelectInto"
    elif isinstance(stmt, WRITE_TYPES):
        this = stmt.this
        tbl = this.this if isinstance(this, exp.Schema) else this
        if isinstance(tbl, exp.Table):
            target = table_key(tbl, ambient_db)

    sources = set()
    for t in stmt.find_all(exp.Table):
        key = table_key(t, ambient_db)
        if key != target:
            sources.add(key)

    is_command = isinstance(stmt, exp.Command)
    return {
        "kind": kind,
        "target": target,
        "sources": sorted(sources),
        "is_command": is_command,
    }


def is_control_flow_command(lineage: dict, raw_stmt_sql: str) -> bool:
    """Command-Fallback zaehlt nur als Prozedural-Treiber, wenn es sich NICHT
    um einen einfachen EXEC-Aufruf handelt. Boilerplate-EXECs (Logging,
    Housekeeping-Procs wie up_ueb_log_meldung) sind fuer die Lineage
    irrelevant und sollen ein Objekt nicht faelschlich nach C ziehen -- nur
    genuine Kontrollstrukturen (CURSOR/WHILE/IF-Bloecke, CREATE FUNCTION mit
    Body) tun das."""
    if not lineage["is_command"]:
        return False
    return not raw_stmt_sql.strip().upper().startswith(("EXEC", "EXECUTE"))


# Exasol kennt kein TRY_CAST -- sqlglot erzeugt es selbst als Artefakt seiner
# eigenen CONVERT(...,<style>)-Uebersetzung (T-SQL CONVERT mit Formatcode,
# z.B. 112 = YYYYMMDD), nicht weil die Quelle TRY_CONVERT verwendet
# [laufzeit-verifiziert: TRY_CAST(...) scheitert an echtem Exasol mit
# "syntax error, unexpected AS_"]. Reine Dialekt-Ersetzung, betrifft
# 10/15 Objekte -- kein Fachentscheid, deshalb hier zentral, nicht je Objekt.
_TRY_CAST_RE = re.compile(r"\bTRY_CAST\s*\(", re.IGNORECASE)


def fix_exasol_quirks(sql: str) -> str:
    return _TRY_CAST_RE.sub("CAST(", sql)


def transpile_suggestion(stmt: exp.Expression) -> tuple[str | None, str | None]:
    try:
        return fix_exasol_quirks(stmt.sql(dialect="exasol")), None
    except Exception as e:  # sqlglot raises plain Exception subclasses on unsupported nodes
        return None, f"{type(e).__name__}: {e}"


@dataclass
class ObjectResult:
    file: str
    statements: list[dict] = field(default_factory=list)
    parse_errors: list[str] = field(default_factory=list)
    unknown_placeholders: list[str] = field(default_factory=list)
    all_commented: bool = False

    def classify(self) -> tuple[str, str]:
        # Vollstaendig auskommentierte Skripte (z.B. abgeloeste Kennzahlen wie
        # KNZ 721) sind kein Migrationsfall -- als eigene Kategorie fuehren,
        # sonst verzerrt das die Autonomierate nach unten [Chat-Entscheidung].
        if self.all_commented and not self.statements and not self.parse_errors:
            return "excluded", "datei vollstaendig auskommentiert, kein aktiver code"

        has_cursor = any(s.get("_cursor") for s in self.statements)
        has_dynamic = any(s.get("_dynamic_sql") for s in self.statements)
        has_command = any(s.get("_control_flow_command") for s in self.statements)
        if self.parse_errors or has_cursor or has_dynamic or has_command:
            reasons = []
            if self.parse_errors:
                reasons.append("parse-error")
            if has_cursor:
                reasons.append("cursor")
            if has_dynamic:
                reasons.append("dynamic-sql")
            if has_command:
                reasons.append("kontrollfluss/unsupported-syntax")
            return "C", "+".join(reasons)

        writes = Counter(s["target"] for s in self.statements if s["target"])
        if not writes:
            if any(s["kind"] == "Execute" for s in self.statements):
                return "C", "nur EXEC auf externe prozeduren, keine eigene schreiboperation"
            return "C", "kein-schreibendes-statement-erkannt"
        max_writes = max(writes.values())
        if max_writes <= 1:
            return "A", f"{len(writes)} ziel(e), je 1 schreibendes statement"
        return "B", f"ziel mit {max_writes} schreibenden statements"


def process_file(path: Path) -> ObjectResult:
    raw = path.read_text(encoding="utf-8", errors="replace")
    rewritten, unknown = rewrite_placeholders(raw)
    result = ObjectResult(
        file=path.name, unknown_placeholders=unknown, all_commented=not _has_code(rewritten)
    )

    ambient_db = None  # ueberlebt GO-Batchgrenzen (GO trennt nur Sende-Batches,
    # kein Session-Reset) -- nur ein neues USE-Statement aendert es.
    for batch in split_batches(rewritten):
        for chunk in split_statements(batch):
            try:
                stmt = sqlglot.parse_one(chunk, read="tsql", error_level=ErrorLevel.IGNORE)
            except Exception as e:
                result.parse_errors.append(f"{type(e).__name__}: {e}")
                continue
            if stmt is None:
                continue
            if isinstance(stmt, exp.Use) and isinstance(stmt.this, exp.Table):
                ambient_db = table_key(stmt.this)
            lineage = statement_lineage(stmt, ambient_db)
            raw_stmt_sql = stmt.sql(dialect="tsql")
            lineage["_cursor"] = bool(CURSOR_RE.search(raw_stmt_sql))
            lineage["_dynamic_sql"] = bool(DYNAMIC_SQL_RE.search(raw_stmt_sql))
            lineage["_control_flow_command"] = is_control_flow_command(lineage, raw_stmt_sql)
            exasol_sql, transpile_error = (None, None)
            if not lineage["is_command"]:
                exasol_sql, transpile_error = transpile_suggestion(stmt)
            lineage["exasol_suggestion"] = exasol_sql
            lineage["transpile_error"] = transpile_error
            result.statements.append(lineage)
    return result


# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------


def write_reports(results: list[ObjectResult], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)

    with (out_dir / "lineage.jsonl").open("w", encoding="utf-8") as f:
        for r in results:
            for i, s in enumerate(r.statements):
                row = {"file": r.file, "stmt_index": i, **s}
                f.write(json.dumps(row, ensure_ascii=False) + "\n")

    triage_rows = []
    counts = Counter()
    for r in results:
        cls, reason = r.classify()
        counts[cls] += 1
        triage_rows.append(
            {
                "file": r.file,
                "class": cls,
                "reason": reason,
                "statements": len(r.statements),
                "parse_errors": r.parse_errors,
                "unknown_placeholders": r.unknown_placeholders,
                "transpile_failures": sum(1 for s in r.statements if s.get("transpile_error")),
            }
        )
    (out_dir / "triage.json").write_text(
        json.dumps(triage_rows, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    total = len(results) or 1
    summary = " | ".join(
        f"{cls}={counts[cls]} ({counts[cls]*100//total}%)"
        for cls in ("A", "B", "C", "excluded")
        if counts[cls]
    )
    lines = [
        "# Triage-Report",
        "",
        f"Objekte: {len(results)} | {summary}",
        "",
        "| Datei | Klasse | Statements | Grund | Transpile-Fehler |",
        "|---|---|---|---|---|",
    ]
    for row in sorted(triage_rows, key=lambda r: (r["class"], r["file"])):
        lines.append(
            f"| {row['file']} | {row['class']} | {row['statements']} | "
            f"{row['reason']} | {row['transpile_failures']} |"
        )
    unknown_all = sorted({p for r in results for p in r.unknown_placeholders})
    if unknown_all:
        lines += ["", f"**Unbekannte Platzhalter (P0-Luecke):** {', '.join(unknown_all)}"]
    (out_dir / "triage.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--source-dir", default="source_references/pd/pd_skripte")
    ap.add_argument("--out", default="reports")
    args = ap.parse_args()

    source_dir = Path(args.source_dir)
    files = sorted(source_dir.glob("*.sql"))
    if not files:
        print(f"Keine .sql-Dateien in {source_dir}", file=sys.stderr)
        return 1

    results = [process_file(f) for f in files]
    write_reports(results, Path(args.out))

    counts = Counter(r.classify()[0] for r in results)
    total = len(results)
    print(
        f"{total} Objekte verarbeitet -> A={counts['A']} B={counts['B']} "
        f"C={counts['C']} excluded={counts['excluded']}"
    )
    print(f"Reports: {args.out}/triage.md, {args.out}/triage.json, {args.out}/lineage.jsonl")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
