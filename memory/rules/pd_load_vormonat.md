# Regel: PD LOAD.Bestandsuebernahme — Vormonat-Schritt und Akkumulation

## Problem
Das T-SQL Skript hat 2 Schritte: (1) Vormonats-DWH als Basis kopieren,
(2) Delta aus DATA appenden. Die dbt-Models implementieren nur Schritt 2
(Delta lesen). Schritt 1 (Vormonat-Basis) fehlt komplett.

## Ursache
Fuer Testlaufe mit nur einem Monat (202312) existiert kein Vormonat-DWH
→ Schema fehlt → Lauf scheitert. Daher wurde Schritt 1 uebersprungen.

## Loesung
Schritt 1 (Vormonat-Akkumulation) ist fuer Testlaufe nicht nachbildbar, da
kein Vormonats-DWH zur Verfuegung steht. Models liefern daher nur das
Delta, nicht den Gesamtbestand. In Produktion muss con_pd_dwh_vm
(Vormonats-Schema) vorab geladen werden; dann muessen die Models um eine
UNION ALL mit prev_month_schema('dwh') erweitert werden.

## Korrektur
Befindet sich in calc/ mit schema_for('calc') — falsch. Korrigiert nach
dwh/ mit schema_for('dwh') gemaess USE con_pd_dwh im Quellskript.
