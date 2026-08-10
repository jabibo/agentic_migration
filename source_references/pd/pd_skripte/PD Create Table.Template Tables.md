# Fachnotiz — PD Create Table.Template Tables.sql

Ein dynamischer Tabellen-Generator: geht per Cursor über neu
eingetroffene Ladedateien und legt je nach Namenspräfix
(BI_DELTA_AZT/FA/FC/BL/LS) die passende Zieltabelle an. Reine
Schema-Verwaltung, keine Datenverarbeitung — die eigentlichen
Tabellendefinitionen stehen autoritativ im DDL-Verzeichnis.

`BI_DELTA_BL`/`BI_DELTA_LS` tauchen sonst nirgends in diesem
Skript-Bestand auf — vermutlich Datenflüsse außerhalb des hier
betrachteten Ausschnitts.
