# Regel: delta_union_dedup — dedup=false für FA/AZT

## Problem
`delta_union_dedup()` dedupliziert standardmaessig nach key_column
(ROW_NUMBER + WHERE rn=1). Das Original-T-SQL in
`PD LOAD.Bestandsuebernahme.sql` fuetr FA/AZT jedoch KEINE
zeilenweise Deduplizierung — es fuegt ALLE Zeilen der Delta-Tabellen
ein (nur Datei-Level-Pruefung via bi_load_date NOT IN).

## Korrektur
Aufruf mit `dedup=false`:
```sql
{{ delta_union_dedup('fa', '"pd_agent_nr"', false) }}
{{ delta_union_dedup('azt', '"pd_pkey"', false) }}
```
FC behaelt `dedup=true` (Standard, key_column=pd_auftr_id).

## Hintergrund
bi_load_date wird fuer FA/AZT aus mfd_quelldatei (Dateiname)
abgeleitet, nicht aus einer Quelldatenspalte. key_column ist nur
noch Platzhalter, wenn dedup=false.
