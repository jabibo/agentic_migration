#!/usr/bin/env python3
"""G2 (Schema-Aequivalenz) + G3 (Datenaequivalenz) + G5-Hilfsfunktion
(Zeilen-Hash fuer Idempotenz-Vergleich) gegen die Referenzparquets in
learning/pd/referenz/<YYYYMM>/. Read-only fuer Exasol (nur SELECT) --
Vergleichs-Harness darf vom Agenten nicht beeinflussbar sein, siehe
docs/adr/0001-deterministik-first.md.

Konvention (Session 10, ersetzt die alte tf_->fct_-Praefix-Regel):
Referenzdatei = <rolle>__<exakter-modellname>.parquet, <rolle> aus
derselben Vokabular wie dbt/macros/schema_for.sql (data/dwh/calc/fact/
knz/dim/strg). Modellnamen sind in dbt ohnehin eindeutig -- kein
Praefix-Trick noetig, das deckt jetzt jede Ebene ab, nicht nur
Kennzahl-Fakten, sobald fuer diese Ebene eine Referenzdatei vorliegt.
Fehlt sie: G2/G3 fuer dieses Modell uebersprungen, kein Fehler.

Aufruf:
  python3 tools/compare_data.py --month 202312 --model tf_pd_knz_705 [--hash-only]
Fehlerkanal: eine normalisierte Zeile pro Befund (wie tools/gate.sh).
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
from collections import Counter
from decimal import Decimal

import pandas as pd

SCHEMA_PREFIX = "sqlserver__bps__dbo__"
# Deckungsgleich mit dbt/macros/schema_for.sql (tools/render_scaffold.sh) --
# bei Aenderung dort auch hier nachziehen.
ROLE_TO_DB = {
    "data": "con_pd_data", "dwh": "con_pd_dwh", "calc": "con_pd_calc",
    "fact": "con_pd_fact", "knz": "con_pd_knz", "strg": "con_strg",
    "dim": "con_bio_dim",
}
NULL_SENTINEL = "\x00NULL\x00"
# Erkennt SQL-Server- (Leerzeichen) und Exasol-JSON- ("T") Datums-/
# Zeitstempel-Trennzeichen gleichermassen -- s. normalize_value().
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}:\d{2}(\.\d+)?)?$")


def find_role(model: str) -> str | None:
    matches = glob.glob(f"dbt/models/*/{model}.sql")
    if not matches:
        return None
    return matches[0].split("/")[2]


def reference_path(month: str, role: str, model: str) -> str | None:
    path = f"learning/pd/referenz/{month}/{role}__{model}.parquet"
    return path if os.path.exists(path) else None


def exapump_json(sql: str) -> list[dict]:
    proc = subprocess.run(
        ["exapump", "sql", "-p", "napc", "-f", "json", sql],
        capture_output=True, text=True, timeout=60,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"exapump fehlgeschlagen: {proc.stderr.strip()}")
    m = re.search(r"(\[.*\])\s*$", proc.stdout, re.DOTALL)
    if not m:
        return []
    return json.loads(m.group(1))


def live_df(month: str, model: str, role: str) -> pd.DataFrame:
    db = ROLE_TO_DB.get(role)
    if not db:
        raise SystemExit(f"live_df: unbekannte Rolle {role!r} (dbt/models/<rolle>/-Ordner) -- "
                          f"ROLE_TO_DB in tools/compare_data.py ergaenzen, nicht raten.")
    schema = f"{SCHEMA_PREFIX}{db}_{month}"
    rows = exapump_json(f"SELECT * FROM {schema}.{model}")
    return pd.DataFrame(rows)


def normalize_value(v) -> str:
    """Kanonische String-Form eines Zellwerts, unabhaengig davon, ob er aus
    einem SQL-Server-Referenz-Parquet (pandas-natives dtype) oder aus einer
    Exasol-JSON-Antwort (immer String/Zahl/None) stammt -- beide Systeme
    serialisieren identische Werte unterschiedlich, s. docs/session10-
    batch-run.md (Nutzer-Fund): pandas-Timestamp -> "2010-01-01 00:00:00"
    (Leerzeichen), Exasol-JSON -> "2023-12-18T03:51:00" ("T") fuer denselben
    logischen Zeitpunkt; int 5 vs. float 5.0 fuer denselben Zahlenwert.
    Laufzeit-verifiziert: beide Faelle vorher fälschlich als Abweichung
    erkannt, jetzt gleich normalisiert.
    """
    if v is None:
        return NULL_SENTINEL
    if isinstance(v, float) and pd.isna(v):
        return NULL_SENTINEL
    try:
        if pd.isna(v):
            return NULL_SENTINEL
    except (TypeError, ValueError):
        pass
    if isinstance(v, pd.Timestamp):
        return v.isoformat()
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return format(Decimal(str(v)).normalize(), "f")
    if isinstance(v, str):
        s = v.strip()
        if DATE_RE.match(s):
            return pd.to_datetime(s).isoformat()
        return s
    return str(v).strip()


def col_hash(series: pd.Series) -> frozenset:
    """Ordnungsunabhaengiger Multiset-Vergleich EINER Spalte -- braucht
    keinen Join-Schluessel, deckt aber nur auf, DASS eine Spalte abweicht,
    nicht WELCHE Zeile/WARUM (bewusst: Sichtbarkeit fuer Qwens eigene
    Recherche, keine vorgefertigte Diagnose).

    Frueher (bis Session 10): XOR-Aggregation von MD5-Hashes -- laufzeit-
    verifiziert paritaetsblind, nicht mengensensitiv (hash(v) XOR hash(v)
    = 0 unabhaengig davon, ob v 2x oder 200x vorkommt). Hat bei KNZ 709
    zwei reale Wertabweichungen mit gerader Vorkommenshaeufigkeit
    systematisch verschluckt (bps_bild_abs: 74x NULL statt 55999;
    pd_rks_id: 92x 52002 statt 52003 -- beide von der alten Implementierung
    als "Spalte stimmt ueberein" gemeldet, s. Diskussion in dieser Session).
    Jetzt: echter Multiset-Vergleich (Counter) -- zaehlt Vorkommen statt
    nur Paritaet."""
    return frozenset(Counter(normalize_value(v) for v in series).items())


def row_hash(df: pd.DataFrame) -> int:
    """Ordnungsunabhaengiger Zeilen-Hash: MD5 je Zeile ueber sortierte,
    normalisierte Spaltenwerte, XOR-aggregiert -- siehe ADR."""
    cols = sorted(df.columns, key=str.lower)
    agg = 0
    for _, row in df.iterrows():
        parts = [normalize_value(row[c]) for c in cols]
        digest = hashlib.md5("\x1f".join(parts).encode("utf-8")).hexdigest()
        agg ^= int(digest, 16)
    return agg


def check_schema(live: pd.DataFrame, ref: pd.DataFrame, model: str) -> list[str]:
    """G2: Spaltennamen-Aequivalenz (case-insensitive -- Case selbst ist
    ein separater, bekannter Exasol-Fallstrick, hier nicht doppelt gewertet)."""
    live_cols = {c.lower() for c in live.columns}
    ref_cols = {c.lower() for c in ref.columns}
    errors = []
    missing = ref_cols - live_cols
    extra = live_cols - ref_cols
    if missing:
        errors.append(f"E G2-SCHEMA model={model} fehlende_spalten={','.join(sorted(missing))}")
    if extra:
        errors.append(f"E G2-SCHEMA model={model} zusaetzliche_spalten={','.join(sorted(extra))}")
    return errors


def check_data(live: pd.DataFrame, ref: pd.DataFrame, model: str) -> list[str]:
    """G3: Rowcount, Zeilen-Hash (ordnungsunabhaengig), bei Abweichung
    zusaetzlich Attribut-fuer-Attribut-Hash je gemeinsamer Spalte -- zeigt,
    WELCHE Spalte(n) abweichen (Sichtbarkeit), nicht WARUM (keine Diagnose)."""
    errors = []
    common_lower = {c.lower() for c in ref.columns} & {c.lower() for c in live.columns}
    if not common_lower:
        errors.append(f"E G3-DATA model={model} keine gemeinsamen Spalten, Hash uebersprungen")
        return errors
    ref_common = ref[[c for c in ref.columns if c.lower() in common_lower]]
    live_common = live[[c for c in live.columns if c.lower() in common_lower]]

    if len(live) != len(ref):
        errors.append(f"E G3-DATA model={model} rowcount live={len(live)} ref={len(ref)}")

    live_hash = row_hash(live_common)
    ref_hash = row_hash(ref_common)
    if live_hash == ref_hash:
        return errors

    errors.append(
        f"E G3-DATA model={model} zeilen_hash_abweichung live={live_hash:x} ref={ref_hash:x}"
    )
    # Attribut-Ebene: nur bei Gesamt-Abweichung, nur wenn Zeilenzahl
    # uebereinstimmt (sonst ist ein Multiset-Spaltenvergleich ohnehin
    # unscharf -- Rowcount-Fehler oben deckt den Fall schon ab).
    if len(live) == len(ref):
        live_by_col = {c.lower(): c for c in live_common.columns}
        ref_by_col = {c.lower(): c for c in ref_common.columns}
        divergent = []
        for key in sorted(common_lower):
            if col_hash(live_common[live_by_col[key]]) != col_hash(ref_common[ref_by_col[key]]):
                divergent.append(key)
        if divergent:
            errors.append(
                f"E G3-DATA model={model} abweichende_spalten={','.join(divergent)} "
                f"({len(common_lower) - len(divergent)} von {len(common_lower)} Spalten stimmen ueberein)"
            )
    return errors


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--month", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--hash-only", action="store_true", help="nur Zeilen-Hash ausgeben (fuer G5)")
    args = ap.parse_args()

    role = find_role(args.model)
    if not role:
        print(f"E COMPARE-SETUP model={args.model} kein dbt-Modell gefunden", file=sys.stderr)
        return 1
    live = live_df(args.month, args.model, role)

    if args.hash_only:
        print(f"{row_hash(live):x}")
        return 0

    ref_path = reference_path(args.month, role, args.model)
    if not ref_path:
        print(f"model={args.model}: keine Referenzdatei -- G2/G3 uebersprungen, kein Fehler")
        return 0
    ref = pd.read_parquet(ref_path)

    errors = check_schema(live, ref, args.model) + check_data(live, ref, args.model)
    if errors:
        print("\n".join(errors))
        return 1
    print(f"model={args.model}: G2+G3 OK ({len(ref)} Zeilen, {len(ref.columns)} Spalten)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
