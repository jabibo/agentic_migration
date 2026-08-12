# Regel: bi_load_date aus bi_timestamp ableiten

## Problem
`bi_load_date` wurde aus dem Dateinamen abgeleitet (`BI_DELTA_FA_202312_...`
→ `2023-12-01`), was `mon_id_load_decr = 202311` ergibt. Die Referenz
erwartet jedoch `202312`. Die CSV hat `bi_timestamp = 2024-01-02 03:00:00`,
woraus `bi_load_date = 2024-01-02` → `mon_id_load_decr = 202312` wird.

## Korrektur
In `tf_deltant_pd_fa.sql`:
```sql
CAST(SUBSTR(REPLACE(d."bi_timestamp", 'T', ' '), 1, 10) AS DATE) AS "bi_load_date"
```
Spaltenname MUSS quotiert sein (Exasol: unquotiert → uppercase, Delta-
tabellen haben quotiert-kleingeschriebene Spalten).
