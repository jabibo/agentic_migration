#!/usr/bin/env python3
"""Materialisiert ALLE Klasse-A-Objekte aus reports/triage.json als dbt-
Modelle -- vollstaendig generisch: kein Dateiname, kein Tabellenname im
Code. ref() vs. source() wird mechanisch entschieden: Klasse-A-Ziel (aus
Lineage-Daten, wird in diesem Lauf garantiert geschrieben) -> ref(); sonst
existiert bereits ein dbt-Modell auf der Platte fuer diese Tabelle
(Klasse-B/C-Migration, Existenzpruefung -- lineage.jsonl allein reicht
nicht, s. render_select_body()) -> ebenfalls ref(); sonst -> source().
Schema-Rolle und Modellname werden aus dem table_key abgeleitet (Konvention:
skills/schema/monatsschema-konvention.md, docs/systemkontext.md B.4).

Das ist die Grenze zur Fachlogik: was hier NICHT passiert, ist irgendeine
Entscheidung ueber *was* ein Statement fachlich bedeutet -- nur strukturelle
Ableitung aus Lineage-Daten, die extract.py bereits erzeugt hat. Klasse B/C
bleiben unberuehrt (Qwens Aufgabe, siehe AGENTS.md).

Voraussetzung: reports/lineage.jsonl + reports/triage.json aktuell
(`make extract`). Ausgabe: dbt/models/<rolle>/*.sql, dbt/models/sources.yml
(beide idempotent neu geschrieben, nicht von Hand nachpflegen).
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from extract import (  # noqa: E402
    find_month_range_vars,
    fix_exasol_quirks,
    rewrite_placeholders,
    split_batches,
    split_statements,
    table_key,
)

import sqlglot  # noqa: E402
from sqlglot import exp  # noqa: E402
from sqlglot.errors import ErrorLevel  # noqa: E402

from schema_roles import ROLE_BY_DB, SCHEMA_PREFIX  # noqa: E402

SOURCE_DIR = Path("source_references/pd/pd_skripte")


def split_db_table(key: str) -> tuple[str | None, str]:
    """'<db>.dbo.<table>' oder '<db>.<table>' -> (db, table); 'dbo' als
    einziger Praefix (Ambient-DB nicht aufloesbar) -> (None, table)."""
    parts = key.split(".")
    if len(parts) >= 3 and parts[-2].lower() == "dbo":
        return ".".join(parts[:-2]), parts[-1]
    if len(parts) >= 2 and parts[-2].lower() != "dbo":
        return ".".join(parts[:-1]), parts[-1]
    return None, parts[-1]


def role_and_db(db: str | None) -> tuple[str | None, str | None]:
    if not db or not db.startswith(SCHEMA_PREFIX):
        return None, None
    short = db[len(SCHEMA_PREFIX):]
    return ROLE_BY_DB.get(short), short


# T-SQL-UDF -> dbt-Makro, reine Infrastruktur (Kalenderarithmetik ohne
# Fachwissen), siehe tools/render_scaffold.sh:month_add fuer die Herleitung
# und den [Annahme]-Hinweis.
FUNC_MAP = {"uf_ueb_kalender_monatadd": "month_add"}


def parse_all_statements(path: Path):
    raw = path.read_text(encoding="utf-8", errors="replace")
    rewritten, _ = rewrite_placeholders(raw)
    ambient_db = None
    out = []
    for batch in split_batches(rewritten):
        for chunk in split_statements(batch):
            try:
                stmt = sqlglot.parse_one(chunk, read="tsql", error_level=ErrorLevel.IGNORE)
            except Exception:
                continue
            if stmt is None:
                continue
            if isinstance(stmt, exp.Use) and isinstance(stmt.this, exp.Table):
                ambient_db = table_key(stmt.this)
            out.append((stmt, ambient_db))
    return out


def render_select_body(
    stmt: exp.Select, ambient_db: str | None, ref_map: dict, month_range_vars: dict, out_dir: Path
) -> tuple[str, set]:
    """Gibt (SQL mit ref()/source()/Makro-Aufrufen, Menge externer (db,table)-Quellen) zurueck."""
    select = stmt.copy()
    # Bei UNION/UNION ALL traegt nur der linkeste SELECT die INTO-Klausel
    # (s. extract.py:statement_lineage) -- dort, nicht auf dem Union-Knoten
    # selbst, muss sie entfernt werden. No-op fuer einfache SELECT INTO.
    into_node = select
    while isinstance(into_node, exp.Union):
        into_node = into_node.this
    into_node.set("into", None)

    # Kalenderdimension-JOINs (=<alias>.tag_dat) vergleichen ein Kalender-
    # datum (immer Mitternacht) gegen die Gegenseite -- die ist ueber den
    # CSV-Import haeufig ein voller TIMESTAMP mit Uhrzeitanteil, ein exakter
    # Vergleich matcht dadurch praktisch nie [laufzeit-verifiziert:
    # tf_pd_fa.sql, pd_dat_eing = kal_eing.tag_dat, G3 zeigte pd_anz_eingae
    # durchgaengig 0 statt der von der Referenz erwarteten Mischung]. Das
    # Original-T-SQL hat dieselbe naive Gleichheit ohne Trunkierung, aber
    # T-SQL DATE-Spalten fuehren dort nie einen Zeitanteil -- Cross-System-
    # Typkorrektur, keine erfundene Fachlogik: der Vergleich selbst bleibt
    # unveraendert, nur auf Datumsebene statt Zeitstempelebene. Generisch
    # ueber die Spalte "tag_dat" (die einzige Kalendertages-Dimension im
    # Projekt), kein Objekt-/Tabellenname im Code.
    for eq in select.find_all(exp.EQ):
        left, right = eq.this, eq.expression
        left_is_tag_dat = isinstance(left, exp.Column) and (left.name or "").lower() == "tag_dat"
        right_is_tag_dat = isinstance(right, exp.Column) and (right.name or "").lower() == "tag_dat"
        if right_is_tag_dat and not left_is_tag_dat:
            eq.set("this", exp.Cast(this=left.copy(), to=exp.DataType.build("DATE")))
        elif left_is_tag_dat and not right_is_tag_dat:
            eq.set("expression", exp.Cast(this=right.copy(), to=exp.DataType.build("DATE")))

    placeholders = {}
    external_sources = set()
    counter = [0]

    def new_ph(jinja: str) -> str:
        ph = f"XJINJAX{counter[0]}X"
        counter[0] += 1
        placeholders[ph] = jinja
        return ph

    for t in list(select.find_all(exp.Table)):
        key = table_key(t, ambient_db)
        db, tbl = split_db_table(key)
        role, short_db = role_and_db(db)
        if key in ref_map:
            jinja = "{{ ref('%s') }}" % ref_map[key]
        elif role and (out_dir / role / f"{tbl.lower()}.sql").exists():
            # Kein Klasse-A-Ziel (sonst waere es in ref_map), aber ein echtes
            # dbt-Modell liegt bereits auf Platte -- eine Klasse-B/C-Migration
            # (Qwen). ref_map allein reicht hier nicht: solche Ziele tauchen in
            # reports/lineage.jsonl nie als "target" auf, wenn das Original-
            # Skript sie per Cursor/WHILE-Schleife befuellt statt per simplem
            # SELECT INTO (extract.py erkennt dann keinen Target-Eintrag) --
            # die Existenzpruefung auf der Platte ist das einzig verlaessliche
            # Signal dafuer. dbt kennt unsere Klassen-Einteilung nicht:
            # source() wuerde die Modell-Abhaengigkeit aus dem DAG nehmen und
            # eine Build-Reihenfolge-Race ermoeglichen [laufzeit-verifiziert:
            # tt_deltant_pd_fc_org/tf_pd_fa gegen tf_deltant_pd_fc_k/
            # tf_deltant_pd_fa_k, diese Session].
            jinja = "{{ ref('%s') }}" % tbl.lower()
        else:
            if not short_db:
                raise SystemExit(
                    f"Quelle {key!r} nicht aufloesbar (kein bekanntes Schema-Praefix) "
                    "-- Ambient-DB-Erkennung in extract.py pruefen."
                )
            external_sources.add((short_db, tbl))
            jinja = "{{ source('%s', '%s') }}" % (short_db, tbl)
        # Alias mitnehmen (f, dst, reg, ...) -- sonst bleiben SELECT-/ON-
        # Referenzen wie "f.pd_dnst_nr" nach dem Ersetzen unaufloesbar
        # [laufzeit-verifiziert: von Qwen in Session 5 gefunden, ledger.jsonl
        # PD-KNZ-705-Eintrag -- kein Klasse-A/B-Grenzfall, reiner Tooling-Bug].
        new_table = exp.to_table(new_ph(jinja))
        if t.args.get("alias"):
            new_table.set("alias", t.args["alias"].copy())
        t.replace(new_table)

    # T-SQL-UDF-Aufrufe (dbo.uf_ueb_kalender_MonatAdd(...) o.ae.) -> dbt-Makro.
    # Argumente sind rohes SQL (CAST/TRY_CAST/...), das Jinja NICHT als
    # Jinja-Ausdruck parsen kann ("AS" ist kein gueltiges Jinja-Token) --
    # deshalb als Jinja-String-Literal uebergeben; das Makro gibt sie
    # unescaped als SQL-Text zurueck ({{ arg }} innerhalb des Makros).
    for node in list(select.find_all(exp.Anonymous)):
        name = (node.name or "").lower()
        if name not in FUNC_MAP:
            continue
        args = [
            '"%s"' % a.sql(dialect="exasol", identify=True).replace("\\", "\\\\").replace('"', '\\"')
            for a in node.expressions
        ]
        jinja = "{{ %s(%s) }}" % (FUNC_MAP[name], ", ".join(args))
        root = node.parent if isinstance(node.parent, exp.Dot) and node.parent.expression is node else node
        root.replace(exp.column(new_ph(jinja)))

    # T-SQL-Lokalvariablen aus dem ErsterMonat/LetzterMonat-Boilerplate --
    # month_range_vars liefert bereits den vollstaendigen Makroaufruf
    # (z.B. "knz_erster_monat(705)"), keine var()-Umhuellung mehr noetig.
    for node in list(select.find_all(exp.Parameter)):
        if node.name in month_range_vars:
            jinja = "{{ %s }}" % month_range_vars[node.name]
            node.replace(exp.column(new_ph(jinja)))

    # identify=True: alle Bezeichner quoted -- konsistent mit Qwens Klasse-C-
    # Konvention (T-SQL [bracket]-Bezeichner 1:1 als quoted-lowercase uebernommen).
    # Ohne das foldet Exasol unquotierte Bezeichner (auch unsere Platzhalter-
    # Aliase) auf Grossschreibung -- bricht an Klasse-C-Grenzen, wo die
    # Gegenseite quoted-lowercase erwartet [laufzeit-verifiziert: Session 6,
    # "F.PD_DNST_NR not found" gegen Qwens "pd_dnst_nr"].
    sql = select.sql(dialect="exasol", pretty=True, identify=True)
    for ph, jinja in placeholders.items():
        # identify=True quotet auch den Platzhalter-Token selbst ("XJINJAX0X")
        # -- Anfuehrungszeichen mit entfernen, sonst wird der Jinja-Aufruf
        # zum literalen String statt zur Tabellen-/Spaltenreferenz.
        sql = sql.replace(f'"{ph}"', jinja).replace(ph, jinja)
    return fix_exasol_quirks(sql), external_sources


def main() -> int:
    triage = json.loads(Path("reports/triage.json").read_text())
    class_a_files = [row["file"] for row in triage if row["class"] == "A"]
    if not class_a_files:
        print("Keine Klasse-A-Objekte -- nichts zu rendern.")
        return 0

    lineage = [json.loads(line) for line in Path("reports/lineage.jsonl").open()]
    class_a_set = set(class_a_files)

    # ref_map: jeder target_key eines Klasse-A-Statements -> Modellname (letztes
    # Segment, kleingeschrieben). Nur Klasse-A-Targets sind ref()-faehig -- fuer
    # alles andere existiert in diesem Lauf kein Modell, das ref() aufloesen koennte.
    ref_map = {}
    for row in lineage:
        if row["file"] in class_a_set and row.get("target"):
            model_name = row["target"].split(".")[-1].lower()
            ref_map[row["target"]] = model_name

    out_dir = Path("dbt/models")
    all_external = set()
    written = []
    for row in lineage:
        if row["file"] not in class_a_set or not row.get("target"):
            continue
        target_key = row["target"]
        model_name = ref_map[target_key]
        db, _ = split_db_table(target_key)
        role, short_db = role_and_db(db)
        if not role:
            raise SystemExit(f"Ziel {target_key!r} (Datei {row['file']}) -- Rolle nicht ableitbar.")

        path = SOURCE_DIR / row["file"]
        found = None
        for stmt, ambient_db in parse_all_statements(path):
            # UNION/UNION ALL: INTO sitzt nur auf dem linkesten SELECT (s.
            # render_select_body) -- stmt selbst bleibt der volle Union-Baum,
            # damit beide Seiten mitgerendert werden.
            into_stmt = stmt
            while isinstance(into_stmt, exp.Union):
                into_stmt = into_stmt.this
            if isinstance(into_stmt, exp.Select) and into_stmt.args.get("into"):
                into_table = into_stmt.args["into"].this
                if isinstance(into_table, exp.Table) and table_key(into_table, ambient_db) == target_key:
                    found = (stmt, ambient_db)
                    break
        if not found:
            raise SystemExit(f"Ziel {target_key!r} nicht wiedergefunden in {row['file']} (P0-P2 deterministisch?).")
        stmt, ambient_db = found
        raw = path.read_text(encoding="utf-8", errors="replace")
        rewritten, _ = rewrite_placeholders(raw)
        month_range_vars = find_month_range_vars(rewritten)
        body, externals = render_select_body(stmt, ambient_db, ref_map, month_range_vars, out_dir)
        all_external |= externals

        role_dir = out_dir / role
        role_dir.mkdir(parents=True, exist_ok=True)
        header = (
            f"-- Deterministisch generiert (Klasse A, kein LLM) aus source_references/pd/pd_skripte/{row['file']}\n"
            f"-- tools/render_dbt_models.py, Ziel table_key={target_key}\n"
            "{{ config(schema=schema_for('%s')) }}\n\n" % role
        )
        out_path = role_dir / f"{model_name}.sql"
        out_path.write_text(header + body + "\n", encoding="utf-8")
        written.append(out_path)

    sources_by_db = defaultdict(set)
    for short_db, tbl in all_external:
        sources_by_db[short_db].add(tbl)

    # sources.yml deckt nicht nur Klasse-A-Objekte ab: Klasse-B/C-Skripte
    # (Qwens Aufgabe) referenzieren haeufig externe Dimensions-/Referenz-
    # Tabellen (z.B. KNZ 706 -> con_pd_knz.vd_pd_taetigkeit_beauftragt),
    # die render_select_body() nie sieht, weil es nur auf Klasse-A-SELECTs
    # laeuft. Ohne diesen Zweig ueberschreibt jeder `make gate`-Lauf Qwens
    # manuelle sources.yml-Ergaenzungen (Klasse-A-Regenerierung) -- das
    # Objekt scheitert dann nicht am Modell, sondern an der eigenen
    # Infrastruktur [laufzeit-verifiziert, docs/session9-multifile-loading.md
    # bzw. das KNZ-706-Handoff]. Fix bleibt deterministisch (kein Objektname
    # im Code): reports/lineage.jsonl deckt bereits ALLE Objekte/Klassen ab
    # (extract.py laeuft ueber den ganzen source_dir) -- "extern" heisst hier
    # schlicht "wird irgendwo gelesen, aber nirgends von irgendeinem Objekt
    # geschrieben", ueber Statement-Arten beschraenkt, die echte Tabellen-
    # referenzen sind (kein EXEC/USE/DECLARE/Block -- das waeren Prozedur-
    # aufrufe bzw. Kontrollfluss, keine Tabellen).
    DATA_KINDS = {"SelectInto", "Select", "Update", "Insert", "Union"}
    all_targets_ever = {row["target"] for row in lineage if row.get("target")}
    for row in lineage:
        if row["kind"] not in DATA_KINDS:
            continue
        for src in row.get("sources") or []:
            if not src or src in all_targets_ever:
                continue
            db, tbl = split_db_table(src)
            role, short_db = role_and_db(db)
            if not short_db:
                continue  # kein bekanntes Schema-Praefix (z.B. sys.databases) -- kein echtes Objekt, still ignoriert
            if role and (out_dir / role / f"{tbl.lower()}.sql").exists():
                continue  # echtes dbt-Modell auf der Platte -- render_select_body() nutzt bereits ref(),
                # nicht source() dafuer (dieselbe Luecke wie dort: all_targets_ever allein sieht
                # Klasse-B/C-Ziele nicht, die per Cursor/WHILE statt SELECT INTO befuellt werden)
            sources_by_db[short_db].add(tbl)

    lines = ["version: 2", "", "sources:"]
    for short_db in sorted(sources_by_db):
        lines.append(f"  - name: {short_db}")
        lines.append(f'    schema: "{SCHEMA_PREFIX}{short_db}_{{{{ var(\'verarbeitungsmonat\') }}}}"')
        lines.append("    tables:")
        for tbl in sorted(sources_by_db[short_db]):
            lines.append(f"      - name: {tbl}")
    (out_dir / "sources.yml").write_text("\n".join(lines) + "\n", encoding="utf-8")

    total_sources = sum(len(v) for v in sources_by_db.values())
    for p in written:
        print(f"geschrieben: {p}")
    print(f"geschrieben: {out_dir / 'sources.yml'} ({total_sources} externe Quelltabellen)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
