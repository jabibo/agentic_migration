#!/usr/bin/env python3
"""G2 (Schema-Aequivalenz) + G3 (Datenaequivalenz) + G5-Hilfsfunktion
(Zeilen-Hash fuer Idempotenz-Vergleich) gegen die Referenzparquets in
learning/pd/referenz/<YYYYMM>/. Read-only fuer Exasol (nur SELECT) --
Vergleichs-Harness darf vom Agenten nicht beeinflussbar sein, siehe
docs/adr/0001-deterministik-first.md.

Konvention: Modell <rolle>/tf_pd_knz_<N>.sql <-> Referenz
fct_pd_knz_<N>.parquet (Praefix tf_->fct_, Rest identisch). Nur Objekte
mit passender Referenzdatei sind pruefbar -- andere werden von
tools/compare.sh uebersprungen, nicht als Fehler gewertet.

Aufruf:
  python3 tools/compare_data.py --month 202312 --model tf_pd_knz_705 [--hash-only]
Fehlerkanal: eine normalisierte Zeile pro Befund (wie tools/gate.sh).
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import re
import subprocess
import sys

import pandas as pd

SCHEMA_PREFIX = "sqlserver__bps__dbo__"
ROLE_BY_FOLDER = {"data": "data", "dwh": "dwh", "calc": "calc", "fact": "fact", "knz": "knz"}
NULL_SENTINEL = "\x00NULL\x00"


def find_role(model: str) -> str | None:
    matches = glob.glob(f"dbt/models/*/{model}.sql")
    if not matches:
        return None
    folder = matches[0].split("/")[2]
    return ROLE_BY_FOLDER.get(folder, folder)


def reference_path(month: str, model: str) -> str | None:
    ref_name = re.sub(r"^tf_", "fct_", model) + ".parquet"
    path = f"learning/pd/referenz/{month}/{ref_name}"
    import os

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
    schema = f"{SCHEMA_PREFIX}con_pd_{role}_{month}" if role != "dwh" else f"{SCHEMA_PREFIX}con_pd_dwh_{month}"
    rows = exapump_json(f"SELECT * FROM {schema}.{model}")
    return pd.DataFrame(rows)


def row_hash(df: pd.DataFrame) -> int:
    """Ordnungsunabhaengiger Zeilen-Hash: MD5 je Zeile ueber sortierte,
    normalisierte Spaltenwerte, XOR-aggregiert -- siehe ADR."""
    cols = sorted(df.columns, key=str.lower)
    agg = 0
    for _, row in df.iterrows():
        parts = [NULL_SENTINEL if pd.isna(row[c]) else str(row[c]).strip() for c in cols]
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
    """G3: Rowcount, Zeilen-Hash (ordnungsunabhaengig). Nur auf der
    gemeinsamen Spaltenmenge -- G2 hat Abweichungen schon gemeldet."""
    errors = []
    common = [c for c in ref.columns if c.lower() in {x.lower() for x in live.columns}]
    if not common:
        errors.append(f"E G3-DATA model={model} keine gemeinsamen Spalten, Hash uebersprungen")
        return errors
    live_common = live[[c for c in live.columns if c.lower() in {x.lower() for x in common}]]
    if len(live) != len(ref):
        errors.append(f"E G3-DATA model={model} rowcount live={len(live)} ref={len(ref)}")
    live_hash = row_hash(live_common)
    ref_hash = row_hash(ref[common])
    if live_hash != ref_hash:
        errors.append(
            f"E G3-DATA model={model} zeilen_hash_abweichung live={live_hash:x} ref={ref_hash:x}"
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

    ref_path = reference_path(args.month, args.model)
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
