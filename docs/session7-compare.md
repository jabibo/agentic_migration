# Session 7 — compare.sh (G2–G5)

Ziel laut ADR: G2 (Schema-Äquivalenz), G3 (Datenäquivalenz), G4 (dbt-Tests),
G5 (Idempotenz) — **read-only für den Agenten**, damit ein Objekt nicht nur
„läuft" (G0/G1), sondern nachweislich das Richtige berechnet.

## Gebaut

- `tools/compare_data.py`: G2 (Spaltenmengen-Vergleich, case-insensitiv)
  + G3 (Rowcount, ordnungsunabhängiger Zeilen-Hash: MD5 je Zeile über
  sortierte, normalisierte Spaltenwerte, XOR-aggregiert — exakt wie in
  der ADR beschrieben). Liest Referenzparquets aus
  `learning/pd/referenz/<YYYYMM>/`, fragt Exasol nur lesend über
  `exapump sql -f json` ab.
- `tools/compare.sh <YYYYMM> [MODEL...]`: orchestriert G2+G3, G4
  (`dbt test`, sofern `schema.yml` mit Tests existiert — aktuell noch
  keine, ehrlich als „nicht befüllt" gemeldet statt fingiert), G5
  (Modell zweimal bauen, Zeilen-Hash vergleichen).
- Konvention: `tf_pd_knz_<N>` ↔ `fct_pd_knz_<N>.parquet`. Nur Objekte mit
  passender Referenzdatei sind prüfbar — andere werden übersprungen, kein
  Fehler. Aktuell nur `tf_pd_knz_705` betroffen (einziges fertiges
  KNZ-Kennzahl-Objekt).
- `make compare MONAT=<YYYYMM>` installiert `pandas`/`pyarrow` bei Bedarf
  automatisch in `.venv`.

## Erster Lauf — sofortiger Fund

```
E G2-SCHEMA model=tf_pd_knz_705 fehlende_spalten=pd_auftr_id
E G3-DATA model=tf_pd_knz_705 rowcount live=13 ref=20
E G3-DATA model=tf_pd_knz_705 zeilen_hash_abweichung live=... ref=...
G5: OK (Hash stabil über 2 Läufe — erwartet, kein Modell ist
    materialized='incremental', ein Full-Rebuild ist deterministisch)
```

**`tf_pd_knz_705` lief in Session 5/6 durchgehend „grün" (G0 Syntax, G1
Ausführung) — ist aber inhaltlich falsch.** Fehlt eine Spalte
(`pd_auftr_id`, die die Referenz hat, das Modell nicht), und liefert nur
13 von 20 erwarteten Zeilen. Kurz geprüft: `PD_TAE_DURCH`-Werte in der
Referenz (`2003`/`2006`) matchen den Modell-Filter — die fehlenden 7
Zeilen sind keine offensichtliche Filterlücke im Objekt selbst, sondern
vermutlich eine Datenvollständigkeits-Lücke weiter oben in der Kette
(`tf_pd_fc` ← `tt_deltant_pd_fc_org` ← Bestand-Modelle ← Delta-Import).
**Nicht root-caused in dieser Session** — das ist der nächste, eigenständige
Untersuchungsfaden, kein Bug in `compare.sh` selbst.

## Warum das der eigentliche Beweiswert der Session ist

Genau das Szenario, vor dem die ADR warnt: „ein System, das grün läuft
aber still falsche Daten produziert, ist schlechter als eines, das sich
als blocked meldet." G0/G1 allein hätten das nie gefunden — sie prüfen
Syntax und Ausführbarkeit, nicht Inhalt. Erst G2/G3 gegen echte
Referenzdaten macht den Unterschied sichtbar. Das war der ganze Sinn,
`compare.sh` überhaupt zu bauen — der erste echte Lauf hat ihn sofort
eingelöst.

## Offen

- Root Cause der 13-vs-20-Lücke (Pipeline-Rückverfolgung nötig).
- `pd_auftr_id`-Spalte: fehlt im Original-T-SQL-SELECT von KNZ 705 auch
  schon (nicht Qwens Fehler) — oder die Referenz enthält eine Spalte, die
  aus einem anderen/späteren Skriptstand stammt. Nicht verifiziert.
- G4 (dbt-Tests) ist nur die Mechanik, keine Tests definiert — sinnvoller
  Kandidat für später: `not_null`/`unique` auf Schlüsselspalten.
- Weitere Objekte (KNZ 711 u.a.) haben Referenzdaten, aber noch keine
  passenden 1:1-Modelle (`tf_pd_knz_711` ist in vorP51/nachP51 gesplittet).
