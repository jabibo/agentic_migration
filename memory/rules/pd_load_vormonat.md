# Regel: PD LOAD.Bestandsuebernahme — Vormonat-Schritt ohne Testdaten

## Problem
Das T-SQL skript kopiert Schritt 1 Daten aus der Vormonats-DB
(con_pd_dwh_vm). Fuer Testlaufe mit nur einem Monat (202312) existiert
kein Vormonat-Delta → Schema fehlt → Lauf scheitert.

## Lösung
Schritt 1 (Vormonat) fuer Testlauf ueberspringen. Nur Schritt 2
(Ladedaten aus aktuellem Delta) implementieren. In Produktion muss
das Vormonats-Schema vorab geladen werden.
