---
name: exasol-dialect-gotchas
scope: generic
description: >
  Laufzeit-verifizierte T-SQL->Exasol-Fallstricke aus Session 3
  (Klasse-A-Gate-Laeufe) und Session 9 (Mehrfach-Datei-Ladepfad). Vor
  eigenem Fix-Versuch per exaktem Fehlertext suchen -- das ist
  deterministisches Lookup, kein Ratespiel.
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

## Unquotierte Identifier duerfen nicht mit `_` beginnen
Fehlertext: `syntax error, unexpected invalid token, expecting
IDENTIFIER_PART_ or '*'`. Gilt fuer Spalten- **und** Tabellen-/Modell-
namen gleichermassen (laufzeit-verifiziert: sowohl eine Hilfsspalte
`__rn` als auch ein Modell `_scratch_test.sql` scheitern daran). Fix:
kein fuehrender Unterstrich bei unquotierten Namen — Praefix statt
Unterstrich (z.B. `mfd_rn` statt `__rn`).

## Per `exapump upload` geladene CSV-Spalten sind quotiert-kleingeschrieben
Fehlertext: `object <ALIAS>.<SPALTE_GROSS> not found`, obwohl die Spalte
existiert. Ursache: `exapump upload` legt Spalten quotiert in Original-
Schreibweise an (meist Kleinschreibung aus dem CSV-Header) — ein
unquotierter Verweis (`d.pd_auftr_id`) faltet zu Grossschreibung
(`D.PD_AUFTR_ID`) und findet die real quotierte `"pd_auftr_id"` nicht.
Fix: Spaltenverweise auf CSV-geladene Tabellen quotieren
(`d."pd_auftr_id"`) — betrifft unter anderem
`dbt/macros/delta_multifile.sql` (`key_column`-Parameter muss vom
Aufrufer bereits quotiert uebergeben werden, z.B. `'"pd_auftr_id"'`).

## Related
`docs/session3-gates.md` (Herleitung, betroffene Objektzahl je Fallstrick) ·
`skills/pipeline/vormonat-incremental.md` ·
`skills/transpile/kennzahl-berichtszeitraum.md` (`@von_mon_id`/`@bis_mon_id`)
