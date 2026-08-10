# Fachnotiz — PD Create Table.Template Tables.sql

Dynamischer DDL-Generator (Cursor + `WHILE`-Schleife über entdeckte
Ladedateien, per `CHARINDEX`-Präfix-Erkennung `BI_DELTA_AZT/FA/FC/BL/LS`
verzweigt in jeweils eigene `CREATE TABLE`). Reine Schema-Verwaltung,
keine Datentransformation — die Zieltabellen selbst sind bereits
autoritativ in `source_references/pd/ddl/*.table.sql` dokumentiert.
Kein Migrationsziel für dbt-Modelle.

`BI_DELTA_BL`/`BI_DELTA_LS`-Präfixe kommen nirgends sonst im Korpus vor
— vermutlich Feeds außerhalb des aktuellen Objekt-Scopes.
