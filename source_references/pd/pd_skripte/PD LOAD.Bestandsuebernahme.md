# Fachnotiz — PD LOAD.Bestandsuebernahme.sql (→ tf_deltant_pd_fc/fa/azt)

## bi_load_date ist ein reiner String, kein Datum
Laut DDL (`source_references/pd/ddl/tf_deltant_pd_fa.table.sql`):
`bi_load_date NCHAR(15) NOT NULL`. Befüllt wird die Spalte hier per
`REPLACE([tabelle], 'BI_DELTA_FA', '')` — **der komplette Rest des
Tabellennamens nach dem Präfix**, nicht nur ein Datumsanteil. Das
Original geht von genau einem Zeitstempel-Suffix pro geladener Tabelle
aus (z.B. `BI_DELTA_FA_20240102030000`). Downstream (`NEO_org_
Zuordnung.sql`) wird dieser String per `CONVERT(VARCHAR(8), ...,112)`
implizit als Datum interpretiert — das funktioniert nur, wenn der
String tatsächlich ein einzelner, parsbarer Zeitstempel ist.

**Bekannter Confound**: falls die Testdaten (Multi-File-Ladepfad) eine
Tabelle mit einem zusammengesetzten Namen wie
`BI_DELTA_FA_202312_20240102030000` (Inhaltsmonat + Lade-Zeitstempel)
zeigen, ist das eine Eigenheit der Testharness-Namenskonvention, nicht
etwas, das im Original-T-SQL vorkommt. Vor einer Content-Diagnose bei
einem `bi_load_date`-bezogenen G3-Fehler erst prüfen, ob der
tatsächlich geladene Tabellenname überhaupt zum Ein-Zeitstempel-Schema
passt.

## Lademonat vs. Inhaltsmonat: die "-1"-Regel
`mon_id_load_decr = MonatAdd(bi_load_date_als_YYYYMM, -1)`. Kommentar
in `KNZ 711.sql`: "wenn Eingang im Lademonat-1, (-1 da Liefermonat mit
Daten aus Vormonat)" — die Datei wird im Monat X geladen/geliefert,
enthält aber inhaltlich Daten aus Monat X-1. `bi_load_date` muss also
den **Liefer-/Lademonat** abbilden, nicht den Inhaltsmonat — die
Downstream-Berechnung dekrementiert selbst.

## Cursor-Struktur (FC/FA/AZT je einzeln)
Drei separate Cursor über `tt_pd_loaded`, gefiltert per `[tabelle] LIKE
'%FC%'` / `'%FA%'` / `'%AZT%'`. Für jede gefundene Tabelle wird per
zusammengesetztem `EXEC(@script)`-String eingefügt — dynamisches SQL,
keine Möglichkeit, das 1:1 als statisches dbt-Modell zu spiegeln, dafür
existiert `delta_union_dedup()`/`discover_delta_files()` als generisches
Makro (`dbt/macros/delta_multifile.sql`).

## 5-Jahres-Kappung (`_k`-Views)
`WHERE pd_abschl_dat >= (Jahr(Berichtsmonat)-4)-01-01` — reine
Jahresarithmetik, kein Monats-Rollover-Risiko (anders als die
"-1"-Regel oben).
