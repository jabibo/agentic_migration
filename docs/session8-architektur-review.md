# Session 8 — Architektur-Review (4 Punkte), löst den 13-vs-20-Fund auf

Nutzer-Review, ausgelöst durch die G3-Abweichung aus Session 7. Vier
Punkte, alle mit echten Quellskripten belegt (`learning/pd/
pd_skripte_excluded/` — 4 neue Dateien vom Nutzer ergänzt: Kalender-
funktionen, OLAP-View-Prozedur). Details/Umsetzung: `docs/datenlage.md` §4.

## Der zentrale Fund: `uf_ueb_kalender_Kennzahl()` ist ein Lookup, keine Formel

`UEB Kalender Funktionen.uf_ueb_kalender_Kennzahl.sql`: reines `SELECT`
gegen `td_ueb_kalender_KennzahlZeitraum` — keine Berechnung. Die
Berechnung selbst steht in `UEB Kalender Dimensionen.
td_ueb_kalender_KennzahlZeitraum.sql` (Zeilen 90–110): pro Kennzahl feste
Parameter (`anzahl_berichtsmonate`, `diff_bm_letzter_monat`,
`min_erster_monat`), daraus ein **rollierendes Fenster**, kein
Einzelmonat.

Für alle 8 migrierten PD-Kennzahlen (701–711 ohne 721):
`anzahl_berichtsmonate=60` (5 Jahre), `diff_bm_letzter_monat=0`. Nur
`min_erster_monat` unterscheidet sich (702/703 hart auf `201501`, sonst
dynamischer 4-Jahres-Boden). Formel:

```
letzter_monat = Verarbeitungsmonat
erster_monat  = MAX(Verarbeitungsmonat − 59 Monate, 4-Jahres-Boden|201501)
```

Für 202312/KNZ705: `ErsterMonat=201901, LetzterMonat=202312` — bestätigt
per `dbt compile` gegen `dbt/macros/kennzahl_zeitraum.sql`.

**Warum das den 13-vs-20-Fund erklärt:** unsere Testdaten (eine gelieferte
Datei) enthalten ohnehin nichts vor Oktober 2023 — mit dem korrekten
60-Monats-Fenster und mit gar keinem Fenster kommt bei uns dasselbe
Ergebnis heraus (20 Zeilen). Die *frühere* Annahme (nur der aktuelle
Monat) war die einzige falsche Variante — sie hat 7 gültige Zeilen
(Oktober/November) ausgeschlossen.

## Umgesetzt

- `dbt/macros/kennzahl_zeitraum.sql` (`tools/render_scaffold.sh`):
  `knz_erster_monat(N)`/`knz_letzter_monat(N)`, Parameter nur für die 8
  migrierten Kennzahlen — unbekannte Kennzahl bricht kontrolliert ab
  (`raise_compiler_error`), rät nicht.
- `tools/extract.py`: `find_month_range_vars()` erkennt jetzt zusätzlich
  die Kennzahl-Nummer aus `uf_ueb_kalender_Kennzahl('<N>')` und mappt auf
  die neuen Makros statt pauschal auf `var('verarbeitungsmonat')`.
- `tools/render_dbt_models.py` entsprechend angepasst (keine Regression:
  aktuell nutzt kein Klasse-A-Objekt dieses Muster, geprüft via
  `make gate` — weiterhin 12/12).
- Skills neu strukturiert: `skills/transpile/exasol-dialect-gotchas.md`
  (jetzt nur noch TRY_CAST + UDF, ≤ 40 Zeilen) und neu
  `skills/transpile/kennzahl-berichtszeitraum.md` (die Formel),
  `skills/transpile/boilerplate-prozeduren.md` (Punkt 4, s. u.).

## Punkt 1 — Mehrfach-Datei-Ladepfad (dokumentiert, nicht nachgebaut)

`PD Create Table.Template Tables.sql`: `xp_dirtree` + Cursor legt pro
gefundener Datei eine eigene, dateinamen-benannte Tabelle an;
`Bestandsuebernahme.sql` Schritt 2 liest daraus. Unser
`tools/load_reference_data.sh` vereinfacht auf eine feste Datei/Typ/Monat
— für den dreimonatigen Testkorpus ausreichend, nicht nachgebaut
(Aufwand/Nutzen). Details: `docs/datenlage.md` §4.1.

## Punkt 4 — Boilerplate- vs. Framework-Prozeduren

`skills/transpile/boilerplate-prozeduren.md`: `rg`-Auszählung über alle
PD-Skripte, zwei Kategorien. Sicher ignorierbar (Logging/Drop):
`up_ueb_log_*`, `up_ueb_object_droptable/DropTable/DropFunction`. **Nicht**
ignorierbar, obwohl sie wie Boilerplate aussehen — echte Arbeit:
`usp_pd_knz_erstellt` (Partitionierung/Views, nicht migriert),
`up_ueb_object_CreateView` (baut die „_k"-Kappungsviews, kein Logging),
`usp_dim_create_tv_olap_views`, `up_ueb_kalender_BerichtsMonatViews`.

## Nachtrag: Qwen-Folgerunde — erstes Objekt mit G0–G3 komplett grün

56 Schritte, $0,33, keine direkte SQL-DDL/DML. Qwen hat nicht nur die
Berichtszeitraum-Substitution korrigiert, sondern per Zeilen-für-Zeile-
Vergleich (`live.merge(ref, on='PD_AUFTR_ID')`) zwei weitere echte
Abweichungen selbst gefunden:

1. **`pd_auftr_id` fehlte** — im Original-T-SQL-SELECT nicht enthalten,
   die Referenz erwartet die Spalte trotzdem. Aus `tf_pd_fc` ergänzt.
2. **`MON_ID` wich ab**: das Original-T-SQL berechnet `MON_ID` aus
   `pd_abschl_dat` — bei einem Mehrmonats-Fenster (s. o.) weicht das von
   der Referenz ab, die `MON_ID` = Verarbeitungsmonat für alle Zeilen
   erwartet, unabhängig vom tatsächlichen Abschlussdatum. Betrifft
   vermutlich 6 weitere Objekte mit demselben CONVERT-Muster (701, 702,
   703, 706, 708, 709) — dokumentiert in
   `skills/transpile/kennzahl-berichtszeitraum.md`, nicht automatisch
   übernommen (erst gegen G3 prüfen, wenn die Objekte migriert werden).

**Vollständig unabhängig verifiziert** (nicht Qwens `make compare`-Output
geglaubt): `git diff` gegen alle geschützten Pfade leer, frischer
`make gate` + `make compare` selbst ausgeführt →
**G0 12/12, G1 12/12, G2+G3 exakt (20 Zeilen, 7 Spalten), G5 stabil.**
Erstes Objekt im Projekt, das G0 bis G3 besteht, nicht nur G0/G1.
