# Regel: PD Kennzahl — UPDATE-Normalisierung als LEFT JOIN

## Problem
Kennzahl-Skripte normalisieren Dimensionswerte per UPDATE (NOT IN
Lookup-Tabelle → Default). Exasol unterstützt keine subqueries in
SELECT/CASE (sqlcode 0A000 "correlated IN-predicate in select-list").

## Korrektur
LEFT JOIN gegen die Lookup-Tabelle ON data_col = lookup_pk, dann
`CASE WHEN ref.pk IS NULL THEN default ELSE data_col END`.
Vorraussetzung: Lookup-PK hat keine NULLs (bei vd_*-Views gegeben).
