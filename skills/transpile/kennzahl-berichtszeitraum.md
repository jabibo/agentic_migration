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
[laufzeit-verifiziert, `tf_pd_knz_705`, `docs/session8-architektur-review.md`]:
das Original-T-SQL berechnet `MON_ID` aus `pd_abschl_dat`
(`CAST(LEFT(CONVERT(VARCHAR(8), fc.pd_abschl_dat, 112), 6) AS INT)`) —
bei einem Ein-Monats-Fenster meist unsichtbar (Abschlussdatum liegt
ohnehin im aktuellen Monat), bei einem **Mehrmonats**-Fenster (s. o.)
weicht das von der Referenz ab. Referenz erwartet `MON_ID` = aktueller
Verarbeitungsmonat für **alle** Zeilen, unabhängig vom tatsächlichen
`pd_abschl_dat`. Fix: `{{ var('verarbeitungsmonat') }} AS MON_ID` statt
aus `pd_abschl_dat` ableiten.

**Betrifft potenziell 6 weitere Objekte** mit identischem CONVERT-Muster
für `[mon_id]`: 701, 702, 703, 706, 708, 709 (`rg`-bestätigt). Nicht
automatisch für alle übernehmen — erst gegen G3 prüfen, das Muster kann
je Objekt anders wirken (711 nutzt z. B. `pd_zeit_von` statt
`pd_abschl_dat`, andere Spalte).

## Related
`skills/transpile/exasol-dialect-gotchas.md` · `docs/session7-compare.md` ·
`docs/session8-architektur-review.md`
