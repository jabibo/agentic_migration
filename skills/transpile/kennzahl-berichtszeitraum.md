---
name: kennzahl-berichtszeitraum
scope: pd
description: >
  @von_mon_id/@bis_mon_id sind KEIN Einzelmonat, sondern ein rollierendes
  Fenster je Kennzahl -- Formel und Makro, aus echter Quelle belegt (nicht
  Annahme). Vor jeder Kennzahl-Migration lesen, sonst falsche Zeilenzahl.
---

# Skill: Kennzahl-Berichtszeitraum (`@von_mon_id`/`@bis_mon_id`)

**Frühere `[Annahme]` "Erster==Letzter==Verarbeitungsmonat" war falsch**,
durch G3 widerlegt (`docs/session7-compare.md`: `tf_pd_knz_705` lieferte
13 statt 20 Zeilen). `uf_ueb_kalender_Kennzahl('<N>')` ist ein reines
Lookup gegen eine Tabelle, die aus einer festen Formel berechnet wird
[Quelle: `learning/pd/pd_skripte_excluded/UEB Kalender Dimensionen.
td_ueb_kalender_KennzahlZeitraum.sql`, Zeilen 90–110]: ein **rollierendes
Fenster**, nicht der aktuelle Monat allein.

## Muster erkennen
`DECLARE @x INT, @y INT; SELECT @x = ErsterMonat, @y = LetzterMonat
FROM dbo.uf_ueb_kalender_Kennzahl('<N>')` — Standard-Boilerplate in fast
jedem Kennzahl-Skript. `unparsable` bei `@<name>` (sqlfluff, G0) ist das
Symptom, wenn die Variable unaufgelöst bleibt.

## Fix
`@x`/`@y` ersetzen durch `{{ knz_erster_monat(<N>) }}` /
`{{ knz_letzter_monat(<N>) }}` (`dbt/macros/kennzahl_zeitraum.sql`, `<N>`
= die Kennzahl-Nummer aus dem `uf_ueb_kalender_Kennzahl('<N>')`-Aufruf,
z.B. `705`).

## Deckung
Parameter (`anzahl_berichtsmonate`, `diff_bm_letzter_monat`,
`min_erster_monat`) liegen **nur für die 8 migrierten PD-Kennzahlen**
(701–711 ohne 721) im Makro vor. Bei neuer/unbekannter Kennzahl bricht
das Makro kontrolliert ab (`raise_compiler_error`) statt einen Wert zu
raten — dann Parameter aus der Quelldatei ergänzen (Zeilen 90–97 dort),
nicht selbst schätzen.

## `MON_ID` in der Ausgabe — Verarbeitungsmonat, nicht `pd_abschl_dat`
**Zwei widersprüchliche Korrekturen an diesem Abschnitt in derselben
Session (2026-08-10) — die zweite (diese) ist die durch einen direkten
Row-für-Row-Vergleich abgesicherte.** Kurzfassung: `{{
var('verarbeitungsmonat') }} AS MON_ID` ist richtig. Die Zwischenversion
dieses Abschnitts, die stattdessen eine Pro-Zeile-Ableitung aus
`pd_abschl_dat` forderte, war selbst ein Fehlschluss — nicht nur eine
unbewiesene Behauptung wie die ursprüngliche Fassung.

**Beweis** (`tools/compare_data.py`s `live_df()` gegen
`learning/pd/referenz/202312/fact__tf_pd_knz_705.parquet`, identische
`pd_auftr_id`-Menge auf beiden Seiten bestätigt, 20/20): mit `MON_ID`
testweise auf Pro-Zeile-Ableitung aus `pd_abschl_dat` umgestellt, zeigt
das Live-Ergebnis 3 verschiedene Werte (`202310`: 1x, `202311`: 6x,
`202312`: 13x) für dieselben 20 Aufträge, für die die Referenz
**einheitlich** `202312` zeigt — inklusive der 7 Aufträge, deren eigenes
`pd_abschl_dat` nachweislich in einem früheren Monat liegt. Das
widerlegt Pro-Zeile-Ableitung direkt, nicht nur durch Abwesenheit von
Gegenbeweisen.

**Warum das trotz des T-SQL-Quelltexts (`CAST(LEFT(CONVERT(VARCHAR(8),
fc.pd_abschl_dat, 112), 6) AS INT) [mon_id]`, pro Zeile aus dem
Business-Datum) so ist, bleibt ungeklärt** — plausibelste Hypothese:
`MON_ID` wird in der echten Produktion einmalig beim Bestandseintritt
eines Datensatzes vergeben und danach nie neu berechnet (klassische
Bestandsfortschreibung: neue Zeilen bekommen den aktuellen
Verarbeitungsmonat, alte Zeilen behalten ihren ursprünglichen Wert für
immer) — das erklärt sowohl die Konstante innerhalb eines Monats als
auch die Akkumulation über Monate (`202312`→`202401` addiert neue,
mit `202401` markierte Zeilen, ohne die alten `202312`-Zeilen
anzufassen) ohne Widerspruch. Der Testkorpus enthält vermutlich
Datensätze mit `pd_abschl_dat` aus Vormonaten, die in der echten
Produktion so nicht in einem einzelnen Monats-Delta vorkämen (Timing-
Artefakt des Testkorpus, nicht der Fachlogik) — nicht verifiziert, nur
die plausibelste Erklärung für den Widerspruch zum T-SQL-Quelltext.

**Konsequenz:** 705, 706, 709 (`{{ var('verarbeitungsmonat') }} AS
MON_ID`) sind bei `MONAT=202312` korrekt **grün, weil sie richtig sind**
— nicht trotz eines verdeckten Bugs. Nicht erneut auf Pro-Zeile-Ableitung
umstellen, ohne diesen Beweis zu widerlegen.

## Related
`skills/transpile/exasol-dialect-gotchas.md` · `docs/session7-compare.md` ·
`docs/session8-architektur-review.md`
