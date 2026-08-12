# Regel: pd_fa Kalender-JOIN mit CAST AS DATE

## Problem
`pd_dat_eing` aus CSV-Import ist TIMESTAMP mit Zeitanteil (z.B.
`2023-10-30T00:46:00`). Der JOIN gegen `td_ueb_kalender_Tag.tag_dat`
(immer Mitternacht) mit exakter Gleichheit matcht praktisch nie.

## Korrektur
In `tf_pd_fa.sql` CAST auf DATE:
```sql
ON CAST("f"."pd_dat_eing" AS DATE) = "kal_eing"."tag_dat"
```
Auch in `tf_deltant_pd_fa.sql`: `"mon_id"` aus CSV hinzufuegen.
