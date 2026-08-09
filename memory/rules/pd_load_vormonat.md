# Regel: PD LOAD.Bestandsuebernahme — bi_load_date aus bi_timestamp ableiten

## Problem
bi_load_date wurde von mon_id (YYYYMM-String wie '202312') befuellt.
Downstream-Klasse-A-Code ruft TO_CHAR(bi_load_date, 'YYYYMMDD') auf, was
ein DATE/TIMESTAMP erwartet — Exasol sqlcode=22123 'Invalid numeric format'.

## Korrektur
bi_load_date = CAST("bi_timestamp" AS DATE) in allen tf_deltant_pd_[fa|fc|azt].
Klassifizierung als Datum, nicht als String._mon_id_ bleibt fuer fachliche
Monatszuordnung weiter verfuegbar.

## Nachschlageregeln
- _k-Modelle: bi_load_date-Vergleich mit CAST(... AS DATE), nicht String-
  comparison (T-SQL verwendet VARCHAR-Vergleich).
- Klasse-A-TO_CHAR: bi_load_date muss vor Aufruf nach VARCHAR(8) gecastet
  werden, da Exasol TO_CHAR ein STRING als erstes Argument erwartet.
