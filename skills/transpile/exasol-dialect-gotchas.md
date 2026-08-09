---
name: exasol-dialect-gotchas
scope: generic
description: >
  Drei laufzeit-verifizierte T-SQL->Exasol-Fallstricke aus Session 3
  (Klasse-A-Gate-Laeufe). Vor eigenem Fix-Versuch per exaktem Fehlertext
  suchen -- das ist deterministisches Lookup, kein Ratespiel.
---

# Skill: Exasol-Dialekt-Fallstricke

## `TRY_CAST` — existiert in Exasol nicht
Fehlertext: `syntax error, unexpected AS_`. Ursache meist: sqlglot erzeugt
`TRY_CAST` selbst als Uebersetzung von T-SQLs `CONVERT(typ, x, <stilcode>)`
(z.B. Stil 112 = YYYYMMDD) — kein Tippfehler in der Quelle. Fix: `CAST`
statt `TRY_CAST`. **Achtung:** Exasol wirft bei ungueltigem Wert hart,
T-SQL/TRY_CAST gaebe NULL zurueck — bei Datumsformatierung meist
unkritisch (Wert ist immer gueltig), bei Nutzerdaten ggf. Vorab-Filter
noetig, nicht blind ersetzen.

## T-SQL-UDF-Aufrufe ohne Exasol-Aequivalent
Fehlertext: `syntax error, unexpected AS_` (bei Funktionsaufrufen mit
`dbo.`-Praefix) oder `object ... not found` (bei Objekt-UDFs). Kalender-
arithmetik (`dbo.uf_ueb_kalender_MonatAdd(yyyymm, n)`): Makro
`{{ month_add(arg1, arg2) }}` (`dbt/macros/month_add.sql`) verwenden.
**Wichtig:** Argumente sind oft rohes SQL (CAST/CONVERT-Ketten) — Jinja
parst das NICHT als Ausdruck (`AS` ist kein Jinja-Token). Immer als
String-Literal uebergeben: `{{ month_add("CAST(...)", "-1") }}`.
Andere UDFs (z.B. `uf_pd_Behinderung_Key`): kein bekanntes Makro — Objekt
`blocked` markieren, nicht selbst erfinden.

## Related
`docs/session3-gates.md` (Herleitung, betroffene Objektzahl je Fallstrick) ·
`skills/pipeline/vormonat-incremental.md` ·
`skills/transpile/kennzahl-berichtszeitraum.md` (`@von_mon_id`/`@bis_mon_id`)
