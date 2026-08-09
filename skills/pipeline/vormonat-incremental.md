---
name: vormonat-incremental
scope: generic
description: >
  Hinweis (kein Rezept) fuer Vormonat-Fortschreibung + Dedup-Load-Muster
  (TRUNCATE+Copy-from-Vormonat, dann WHERE key NOT IN Insert). Betrifft
  Bestand-Layer-Objekte.
---

# Skill: Vormonat-Fortschreibung / Dedup-Load

**Nur ein Hinweis auf den Mechanismus — die Entscheidung (welcher Key,
Full-Merge vs. echtes Incremental) triffst du am konkreten Objekt.**

Wenn ein T-SQL-Skript dieses Muster zeigt: bestehende Tabelle aus Vormonat
übernehmen (`TRUNCATE` + `INSERT ... SELECT * FROM vormonat.tbl`), danach
neue Zeilen nachladen mit `WHERE key NOT IN (SELECT key FROM tbl)` —
das ist dbts eingebautes Incremental-Muster, kein Fall für Custom-SQL:

```sql
{{ config(materialized='incremental', unique_key='<dedup-spalte>') }}
SELECT ... FROM {{ source(...) }}
{% if is_incremental() %}
WHERE <dedup-spalte> NOT IN (SELECT <dedup-spalte> FROM {{ this }})
{% endif %}
```

`unique_key` ist objektspezifisch (z.B. `pd_auftr_id` vs. `bi_load_date`) —
das musst du aus dem Quellskript ableiten, nicht raten.

Vormonat-Referenz (voriger Verarbeitungsmonat als Tabelle): nicht als
eigenes Schema, sondern über den Vormonat-Mechanismus des Ziel-Schemas
auflösen (Details: `docs/systemkontext.md` B.1, Zeile zu
`con_pd_dwh_vormonat`).
