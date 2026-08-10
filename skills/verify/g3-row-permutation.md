---
name: g3-row-permutation
scope: generic
description: >
  Hypothetisches Signatur-Muster, NICHT laufzeit-verifiziert -- der
  KNZ-709-Fall, der diesen Skill urspruenglich ausgeloest hat, stellte
  sich bei genauerer Pruefung als etwas anderes heraus: ein Bug in
  compare_data.py's col_hash() selbst (XOR-Aggregation war paritaets-
  statt mengensensitiv, inzwischen gefixt) plus fehlende Dimensions-
  Validierungslogik im Modell. Keine echte Zeilen-Permutation gefunden.
  Skill bleibt fuer einen moeglichen KUENFTIGEN echten Fall stehen --
  seit dem Fix ist das Signaturmuster unten ein deutlich verlaesslicheres
  Signal als vorher, aber weiterhin ohne einen einzigen bestaetigten
  Fall in diesem Projekt.
---

# Skill: G3-Zeilen-Hash-Abweichung trotz stimmender Spalten

## Erkennungsmerkmal
`make compare` meldet `zeilen_hash_abweichung`, dabei:
- Rowcount live == ref (kein `E G3-DATA ... rowcount ...`), UND
- `abweichende_spalten` fehlt in der Ausgabe (jede Spalte stimmt fuer
  sich als Multiset), UND trotzdem bleibt die Abweichung bestehen.

**Bevor du das als Permutation einordnest: pruefe zuerst, ob es einfach
ein Wertefehler auf einzelnen Zeilen ist, keine Paarung zwischen zwei
Zeilen.** Genau das war der KNZ-709-Fall (s.o.) -- `abweichende_spalten`
war nur leer, weil `col_hash()` einen echten Bug hatte, nicht weil die
Spalten wirklich stimmten. Der Bug ist seit `tools/compare_data.py`
Commit "col_hash() von XOR- auf Multiset-Vergleich umgestellt" behoben --
`abweichende_spalten` ist jetzt wieder verlaesslich. Erst wenn `make
compare` NACH diesem Fix weiterhin `zeilen_hash_abweichung` ohne jede
`abweichende_spalten`-Zeile meldet, ist eine echte Paarungsfehler-Diagnose
(unten) ueberhaupt sinnvoll.

Falls doch: alle Werte sind vorhanden und in der richtigen Menge, aber
falsch **kombiniert** -- Spalte X aus Zeile A steht bei euch an Zeile B.
Kein Wertefehler, ein Paarungsfehler. Der Vergleich sieht das nur als
Gesamt-Hash-Differenz, weil er bewusst keine Referenzwerte offenlegt
(s. `docs/adr/0001-deterministik-first.md`) -- diese Diagnose musst du
selbst mit deinem eigenen Modell-SQL und `source_references/` machen.

## Typische Ursachen (generisches SQL-Wissen, hier noch nicht bestaetigt)
1. **JOIN-Fan-out vor Dedup**: ein JOIN auf einen nicht-eindeutigen
   Schluessel vervielfacht Zeilen, ein nachfolgendes `ROW_NUMBER()`/
   `DISTINCT` waehlt dann pro Gruppe die falsche Kombination, weil
   `PARTITION BY` nicht die volle Zeilengranularitaet abdeckt.
2. **GROUP BY unvollstaendig**: eine Spalte, die eigentlich Teil der
   Zeilenidentitaet ist, fehlt in `GROUP BY`/`PARTITION BY` -- Werte aus
   verschiedenen logischen Zeilen werden zusammengefasst.
3. **Nicht-deterministisches Tie-Breaking**: `ORDER BY` in `ROW_NUMBER()`/
   `RANK()` ohne eindeutigen letzten Tie-Breaker -- T-SQL und Exasol
   koennen bei Gleichstand unterschiedliche Zeilen waehlen (Engine-
   Unterschied, kein Fehler in der fachlichen Formel selbst).

## Vorgehen (nur mit bereits erlaubten Werkzeugen)
1. Modell-SQL gegen `source_references/pd_skripte/<objekt>` Schritt fuer
   Schritt auf JOIN-Kardinalitaet und GROUP BY/PARTITION BY-Vollstaendigkeit
   pruefen -- nicht gegen Referenzwerte, die sind nicht sichtbar.
2. `tools/exapump_select.sh` gezielt auf eine einzelne konkrete
   Schluessel-Kombination anwenden (z.B. `WHERE pd_auftr_id = X`) und
   jede CTE-Zwischenstufe einzeln nachvollziehen, statt das
   Gesamtergebnis zu vergleichen.
3. Bei `ROW_NUMBER()`/`RANK()`: expliziten, vollstaendigen Tie-Breaker
   ergaenzen (z.B. Primaerschluessel als letztes `ORDER BY`-Kriterium).

## Related
`skills/transpile/exasol-dialect-gotchas.md` ·
`memory/rules/exasol_bitwise.md` (verwandter, bereits behobener
`pd_beh_key`-Fund, andere Ursache) ·
`docs/adr/0001-deterministik-first.md`
