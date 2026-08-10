# Regel: Referenzdaten vs. Live-Daten — Datenstand prüfen

## Problem
G3-Abweichung bei mon_id/pd_anz_eingae kann durch unterschiedliche
Quell-Delta-Dateien entstehen (Referenz von Nov 2023, Live von Dez 2023).
Modellogik ist korrekt — Abweichung nur bei Data-Versioning-Mismatch.

## Diagnose
- Rowcount gleich, aber mon_id um 1 Monat verschoben → unterschiedliche
  Quelldateien (BI_DELTA_FA_202311 vs BI_DELTA_FA_202312).
- bi_load_date aus Dateinamen konstruiert → unterschiedliche Dateinamen
  = unterschiedliche bi_load_date = unterschiedliche mon_id_load_decr.

## Vorgehen
1. tools/exapump_select.sh auf bi_load_date im DWH prüfen
2. Mit Referenz-Parquet abgleichen (gleicher Datenstand?)
3. Nur bei echter Modellogik-Abweichung fixen, nicht bei Data-Mismatch