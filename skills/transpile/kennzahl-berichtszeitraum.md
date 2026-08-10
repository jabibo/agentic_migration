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

## `MON_ID` in der Ausgabe — WIDERRUFEN, korrigiert (2026-08-10)
**Frühere Fassung dieses Abschnitts war falsch und ist inzwischen für
mindestens 3 Objekte (705, 706, 709) als tatsächliche Ursache eines
latenten Bugs bestätigt.** Sie behauptete, `MON_ID` sei für alle Zeilen
der aktuelle Verarbeitungsmonat (`{{ var('verarbeitungsmonat') }} AS
MON_ID`), "laufzeit-verifiziert" an `tf_pd_knz_705`. Das war ein
Fehlschluss: die Verifikation lief ausschließlich gegen `MONAT=202312`,
den Kaltstart-Monat des Testkorpus, an dem `pd_abschl_dat` jeder Zeile
zwangsläufig im aktuellen Verarbeitungsmonat liegt (kein Vormonat-Delta
geladen, s. `dbt/models/dwh/tf_deltant_pd_fc.sql`-Kommentar) — dort sind
Konstante und Pro-Zeile-Ableitung numerisch nicht unterscheidbar.

**Direkt gegengeprüft** (`learning/pd/referenz/<YYYYMM>/fact__tf_pd_knz_705.parquet`
über alle 4 Testmonate): `MON_ID` **akkumuliert** über die Monate —
202312: nur `202312` (20 Zeilen); 202401: `202312`+`202401` (20+11);
202402: drei Werte; 202403: vier Werte. Das ist das bereits bestätigte
rollierende 60-Monats-Fenster (`docs/session8-architektur-review.md`),
nicht ein einzelner Monat pro Verarbeitungslauf — `MON_ID` muss also
**pro Zeile aus dem jeweiligen Business-Datum abgeleitet werden**
(`pd_abschl_dat` bei den meisten Objekten, `pd_zeit_von` bei 711 — je
nach Objekt prüfen), nicht aus `var('verarbeitungsmonat')` konstant
gesetzt werden. Der ursprüngliche T-SQL-Ausdruck
(`CAST(LEFT(CONVERT(VARCHAR(8), fc.pd_abschl_dat, 112), 6) AS INT)`) war
die ganze Zeit richtig — **nicht** durch die Konstante ersetzen.

**Konsequenz:** 705, 706, 709 zeigen aktuell G2/G3 "grün" bei
`MONAT=202312`, aber nur weil der Testaufbau diesen Bug an diesem einen
Monat strukturell nicht aufdecken kann — nicht, weil sie tatsächlich
korrekt sind. Würde man denselben Monat mit echtem Vormonat-Bestand oder
einen späteren Monat (202401+) testen, würde `MON_ID` für alle
Vormonats-Zeilen falsch auf den aktuellen Verarbeitungsmonat gesetzt.
Betrifft potenziell weitere Objekte mit identischem CONVERT-Muster:
701, 702, 703, 708 (`rg`-bestätigt, noch nicht individuell geprüft).

## Related
`skills/transpile/exasol-dialect-gotchas.md` · `docs/session7-compare.md` ·
`docs/session8-architektur-review.md`
