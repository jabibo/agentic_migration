---
name: boilerplate-prozeduren
scope: pd
description: >
  Welche EXEC-Aufrufe in PD-Skripten reine Protokollierung/Aufraeumarbeit
  sind (ignorierbar) und welche echte Migrationsarbeit leisten (pruefen,
  nicht ignorieren). Vor dem Lesen eines neuen Quellskripts nachschlagen,
  spart wiederholte Bewertung.
---

# Skill: Boilerplate- vs. Framework-Prozeduren (PD-Skripte)

Häufigkeit aus `source_references/pd/pd_skripte/*.sql` (`rg`-Zählung).

## Sicher ignorierbar — reine Protokollierung/Aufräumarbeit
Kein Fachwissen, keine Datenwirkung. `render_dbt_models.py` zählt sie
schon nicht als Schreib-Statement (`WRITE_TYPES` schließt `exp.Command`/
`Execute` aus) — hier nur explizit benannt, damit niemand sie erneut
bewertet:

- `up_ueb_object_droptable`/`DropTable`/`DropFunction` — Drop vor Neubau
- `up_ueb_log_CreateTable`/`CreateFunction`/`Meldung`/`meldung` — Logging

## Nicht ignorieren — leisten echte Arbeit, brauchen Prüfung
Sehen aus wie Boilerplate, sind es aber nicht — jeweils eigene Business-
Wirkung, die migriert werden muss (nicht 1:1 übersetzbar, da SQL-Server-
Framework-Aufrufe ohne Exasol-Äquivalent):

| Aufruf | Tut tatsächlich |
|---|---|
| `usp_pd_knz_erstellt`/`usp_ms_knz_erstellt` | „Querschnittsfunktion für Partitionierung, Indizierung, Faktenviews" — nicht migriert, kein dbt-Äquivalent gebaut |
| `up_ueb_object_CreateView` | Erstellt die „_k"-Kappungsviews dynamisch — das eigentliche Schritt-4-Ergebnis in `PD LOAD.Bestandsuebernahme.sql`, kein Logging |
| `usp_dim_create_tv_olap_views` | OLAP-View-Erstellung für Dimensionen (`learning/pd/pd_skripte_excluded/usp_dim_create_tv_olap_views.proc.sql`) |
| `up_ueb_kalender_BerichtsMonatViews`/`uf_ueb_kalender_BerichtsMonatViews_Monat` | Berichtsmonat-View-Erstellung (`learning/pd/pd_skripte_excluded/UEB Kalender Funktionen.up_ueb_kalender_BerichtsMonatViews.sql`) |
| `uf_ueb_kalender_Kennzahl` | Berichtszeitraum-Lookup — gelöst, s. `skills/transpile/kennzahl-berichtszeitraum.md` |
| `uf_ueb_param_Get` | Liest echten Konfigurationswert (Business-Parameter), kein Platzhalter |

Bei Unsicherheit: Objekt `blocked` markieren statt zu raten, nicht als
Boilerplate wegargumentieren.

## Related
`skills/transpile/kennzahl-berichtszeitraum.md` · `docs/datenlage.md` §4
