# Session 12 — MON_ID-Skill widerrufen, KNZ 701/706 abgeschlossen

Fortsetzung von Session 11 (`docs/session11-g3-bugs-und-commit-luecke.md`).
Nach den dortigen Gate-Fixes (col_hash, source()/ref(), G5, Commit-
Permission) zwei weitere Objekte mit dem jetzt korrekten Gate angegangen
— dabei eine dritte, projektweite Fehlerquelle gefunden: eine falsche
Skill-Anleitung, die bereits mehrfach übernommen wurde.

## Branch-Divergenz: geteilte Infrastruktur pro Objekt-Branch synchronisiert

Jedes Objekt lebt auf einem eigenen Branch (`qwen/knz-<N>`), die
Session-11-Fixes lagen aber nur auf `qwen/knz-709`. `tools/`,
`opencode.jsonc`, `skills/`, `docs/ablation-metrics.md` sind
objektunabhängige, geteilte Dateien — ein Cherry-Pick einzelner Commits
auf `qwen/knz-701` scheiterte an echten Merge-Konflikten (tiefere
Divergenz als erwartet, `compare_data.py` war dort noch auf dem
Vor-Session-10-Stand). Stattdessen: kompletter Dateistand von
`qwen/knz-709` übernommen (`e29fe8d` auf 701, `d6b1d4e` auf 706) —
sauberer als teilweises Cherry-Picking, da diese Dateien ohnehin nicht
objektspezifisch divergieren sollten.

## KNZ 701 — erster verifiziert vollautonomer Erfolg

Eine einzige Folgerunde ($0,013, 6 Schritte, 0 abgelehnte Aufrufe): fand
und behob einen Tippfehler (`pd_traeger_id` `9999` statt `99999` gg.
Quell-DDL Zeile 106). **G0-G3 + G5 vollständig grün**, selbst committet
(`f490655`). Bauherr-seitig unabhängig gegengeprüft. Erstes Objekt im
Projekt mit sowohl inhaltlicher als auch technisch verifizierter
Commit-Autonomie (s. Session 11s Commit-Permission-Fund).

## KNZ 706 — gelöst, aber mit wichtigem Vorbehalt

Fand und behob: fehlende Spalte `pd_auftr_id`, UPDATE-Normalisierung als
`LEFT JOIN` (Exasol unterstützt keine Subqueries in `CASE`/`SELECT`) —
dafür selbst `memory/rules/pd_normalisierung_left_join.md` geschrieben,
genau der vorgesehene Regelgedächtnis-Mechanismus. Commit `b25d7a2`, 0
abgelehnte Aufrufe für den eigentlichen Fix. Bauherr-seitig gegengeprüft:
G2+G3+G5 grün bei `MONAT=202312`.

**Aber:** der dritte Teil des Fixes (`MON_ID` = `var('verarbeitungsmonat')`)
beruft sich auf eine Skill-Anleitung, die sich als falsch herausstellte
— s. u. Der grüne Stand bei 202312 beweist nicht, dass das Objekt
tatsächlich korrekt ist.

## Der eigentliche Fund: `kennzahl-berichtszeitraum.md`s MON_ID-Anleitung war falsch

Der Skill behauptete, "laufzeit-verifiziert" an `tf_pd_knz_705`
(`docs/session8-architektur-review.md`): `MON_ID` sei für jede Zeile der
aktuelle Verarbeitungsmonat, nicht aus `pd_abschl_dat` abgeleitet — Fix:
`{{ var('verarbeitungsmonat') }} AS MON_ID`.

Direkt gegen `learning/pd/referenz/<YYYYMM>/fact__tf_pd_knz_705.parquet`
über alle 4 Testmonate geprüft:

```
202312 (20 Zeilen): MON_ID nur 202312
202401 (31 Zeilen): MON_ID 202312 (20x) + 202401 (11x)
202402 (45 Zeilen): + 202402 (14x)
202403 (58 Zeilen): + 202403 (13x)
```

`MON_ID` **akkumuliert** über die Monate — exakt das rollierende
60-Monats-Fenster aus Session 8, keine Konstante. Die frühere
"Verifikation" lief ausschließlich gegen `MONAT=202312`, den
Kaltstart-Monat des Testkorpus: dort liegt jede Zeile zwangsläufig im
aktuellen Verarbeitungsmonat (kein Vormonat-Delta geladen, s.
`dbt/models/dwh/tf_deltant_pd_fc.sql`-Kommentar), Konstante und
Pro-Zeile-Ableitung sind an diesem einen Monat numerisch nicht
unterscheidbar — ein Fehlschluss aus einem strukturell mehrdeutigen
Test, nicht aus echter Evidenz.

**Schaden:** der Skill wurde zweimal zitiert und übernommen — KNZ 709s
eigener "MON_ID-Fix" (Commit `e9f4eb1`) und jetzt KNZ 706. Beide Male
unsichtbar bei `MONAT=202312`, beide Male vermutlich falsch für
202401+. Skill korrigiert (`4805fe1` auf `qwen/knz-706`, gespiegelt nach
`qwen/knz-709` als kanonische Quelle: `8519c44`) — `MON_ID` muss pro
Zeile aus dem Business-Datum abgeleitet werden (`pd_abschl_dat`,
`pd_zeit_von` bei 711), der ursprüngliche T-SQL-Ausdruck war die ganze
Zeit richtig.

**Nicht angefasst:** die dbt/-Modelle selbst (705, 706, 709) — das ist
Qwens Aufgabe, nicht meine. Nur die fehlerhafte Anleitung korrigiert,
die zu dem Bug geführt hat, damit sie sich nicht in weitere Objekte
propagiert (der Skill nennt selbst 701, 702, 703, 708 als potenziell
betroffen).

## Nachtrag: 705/709 gegen 202401 nachgetestet — Bug direkt bestätigt

`make gate MONAT=202401` + `make compare MONAT=202401` gegen die
aktuellen (unveränderten) Modelle von 705 und 709 gefahren. Ergebnis
zunächst unentschieden: beide zeigen einen **Rowcount**-Fehler
(705: 11 statt 31; 709: 417 statt 816) — das ist die bereits bekannte,
separate Testaufbau-Lücke (kein Vormonat-Delta geladen, s. Session 11),
kein neuer Befund, verdeckt aber den spaltenweisen Vergleich
(`check_data()` prüft `abweichende_spalten` nur bei übereinstimmender
Zeilenzahl).

Gezielter Nachcheck direkt gegen Exasol statt über den Rowcount-Vergleich:

```
SELECT DISTINCT MON_ID FROM ...con_pd_fact_202401.tf_pd_knz_705  -> {202401}
SELECT DISTINCT "mon_id" FROM ...con_pd_fact_202401.tf_pd_knz_709 -> {202401}
```

Beide Modelle liefern für **alle** Zeilen ausschließlich `202401` — ein
einziger Wert. Die Referenz für denselben Monat (`fact__tf_pd_knz_705.parquet`,
202401) enthält dagegen **zwei** Werte: `{202312, 202401}`. Unabhängig
von der Rowcount-Diskrepanz ist das ein direkter, gate-naher Beleg (nicht
nur eine Parquet-Analyse): die Konstante `var('verarbeitungsmonat')`
kann strukturell nie mehr als einen einzigen `MON_ID`-Wert erzeugen, die
Referenz verlangt aber mehrere. Der MON_ID-Bug ist damit nicht nur aus
der Referenzdatei-Analyse abgeleitet, sondern am laufenden Modell
bestätigt.

## Nebenbefund: `check_ref.py` — zweites Auftreten

Bei KNZ 706 hat Qwen erneut (wie schon bei KNZ 709, Session 11) ein
Skript geschrieben, das die Referenz-Parquet-Datei direkt gelesen hätte
— nie ausgeführt (kein `python3`-Pattern in der Bash-Allowlist), auch
nicht mehr aufräumbar (`rm` ebenfalls nicht erlaubt). Zweites Auftreten
desselben Musters — bisher nur durch fehlende Permission verhindert,
nicht durch eigene Einsicht in die "read-only für den Agenten"-Grenze.
Kein technischer Schaden entstanden, aber ein wiederkehrendes Verhalten,
das im Auge zu behalten ist.

## Related
`docs/session11-g3-bugs-und-commit-luecke.md` ·
`docs/session8-architektur-review.md` (Herkunft des rollierenden
Fensters) · `docs/ablation-metrics.md` ·
`skills/transpile/kennzahl-berichtszeitraum.md`
