# Fachnotiz — PD LOAD.Bestandsuebernahme.sql (Bestandstabellen tf_deltant_pd_fc/fa/azt)

## bi_load_date ist ein reiner String, kein Datum
Laut Tabellendefinition ist `bi_load_date` `NCHAR(15)` — ein Textfeld,
keine Datumsspalte. Befüllt wird es hier über
`REPLACE([tabelle], 'BI_DELTA_FA', '')` — der komplette Rest des
Tabellennamens nach dem Präfix, nicht nur ein Datumsanteil. Die Logik
geht also von genau einem Zeitstempel-Suffix pro Ladetabelle aus (z.B.
`BI_DELTA_FA_20240102030000`). An anderer Stelle (`NEO_org_
Zuordnung.sql`) wird dieser String implizit als Datum interpretiert —
das funktioniert nur, wenn er tatsächlich als einzelner, parsbarer
Zeitstempel vorliegt. Wer hier auf zusammengesetzte oder anders
strukturierte Tabellennamen stößt, sollte vorsichtig sein, bevor er
annimmt, dass die Ableitung stimmt.

## Lademonat vs. Inhaltsmonat: die "-1"-Regel
`mon_id_load_decr = MonatAdd(bi_load_date als YYYYMM, -1)`. Der
Kommentar in `KNZ 711.sql` erklärt das Prinzip: "wenn Eingang im
Lademonat-1, (-1 da Liefermonat mit Daten aus Vormonat)" — eine Datei
wird im Monat X geliefert, enthält aber inhaltlich Daten aus Monat
X-1. `bi_load_date` muss also den Liefer-/Lademonat abbilden, nicht
den Inhaltsmonat; die spätere Berechnung zieht selbst einen Monat ab.

## Cursor-Struktur
Drei separate Cursor über die geladenen Tabellen (gefiltert nach
Namensmuster FC/FA/AZT). Für jede gefundene Tabelle wird ein
dynamischer INSERT-Befehl zusammengebaut und ausgeführt — das übliche
Muster für "verarbeite jede neu eingetroffene Datei", strukturell,
nicht Zeile für Zeile nachbaubar, sondern nur als Prinzip
(Datei-Erkennung + Einfügen + Duplikatsprüfung).

## 5-Jahres-Kappung
`WHERE pd_abschl_dat >= (Jahr(Berichtsmonat)-4)-01-01` — reine
Jahresarithmetik, anders als die "-1"-Regel oben ohne
Monats-Rollover-Risiko.
