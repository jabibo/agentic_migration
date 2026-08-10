# Session 11 — G3-Gate-Bugs, Commit-Permission-Lücke, KNZ-709-Datenvintage

Ausgangspunkt: Nutzerfrage, ob die Referenzdaten für KNZ 709 falsch sein
könnten — `make compare` zeigte zuvor `zeilen_hash_abweichung` bei
gleichzeitig leerer `abweichende_spalten`-Zeile, was wie eine
Zeilen-Permutation aussah (Werte korrekt, falsch gepaart). Die
Untersuchung fand am Ende etwas anderes: zwei echte Gate-Bugs, eine
strukturelle Commit-Lücke — und erst danach ein echtes, teilweise
gelöstes Qwen-Ergebnis.

## Fund 1: `col_hash()` war der Fehler, keine Permutation

`tools/compare_data.py`s `col_hash()` aggregierte Werte-Hashes per XOR —
paritäts-, nicht mengensensitiv (`hash(v) XOR hash(v) = 0`, unabhängig
von der Häufigkeit). Bei KNZ 709/202312 hat das zwei reale
Wertabweichungen mit gerader Differenz-Häufigkeit verschluckt:
`bps_bild_abs` (74× `NULL` in live statt `55999`), `pd_rks_id` (92×
`52002` statt `52003`, beide Seiten zufällig mit ungerader Gesamtzahl
für den übereinstimmenden Rest). Per-Zeilen-Hash-Diff gegen die Referenz
zeigte: dieselbe `pd_auftr_id` ist auf beiden Seiten betroffen, keine
Vertauschung zwischen Aufträgen — schlichter Wertefehler, keine
Permutation. Fix: Counter-basierter Multiset-Vergleich statt XOR
(`765b5f2`). `skills/verify/g3-row-permutation.md` entsprechend korrigiert
(`ae70aa5`, `65d7ce4`) — die falsche "laufzeit-verifiziert"-Behauptung
entfernt, Skill bleibt für einen echten künftigen Permutationsfall stehen.

## Fund 2: `source()` statt `ref()` für Klasse-B/C-Abhängigkeiten

`tt_deltant_pd_fc_org.sql`/`tf_pd_fa.sql` (Klasse A, auto-generiert)
referenzierten `tf_deltant_pd_fc_k`/`tf_deltant_pd_fa_k` (Klasse C,
Qwens Migration aus Session 6) per `source()` statt `ref()`, obwohl auf
der Platte längst ein echtes dbt-Modell dafür lag — `render_dbt_models.py`
kannte nur Klasse-A-zu-Klasse-A-Abhängigkeiten aus `lineage.jsonl`.
`source()` trägt keine `ref()`-Abhängigkeit im dbt-DAG: ein `dbt run`
konnte das abhängige Modell vor seiner eigenen Abhängigkeit ausführen
(beobachtet: `TF_DELTANT_PD_FC_K not found`, Retry lief nur durch Zufall).
Erster Lösungsansatz (ref_map auf Basis von `lineage.jsonl` erweitern)
griff nicht: die betroffenen Ziele tauchen dort nie als `target` auf, weil
das Original-Skript sie per Cursor/`WHILE`-Schleife befüllt, nicht per
`SELECT INTO`. Fix stattdessen per Existenzprüfung auf der Platte in
`render_select_body()` (`8e599ac`) — verifiziert: 202401 lief danach im
ersten Anlauf grün statt mit Retry.

## Fund 3: G5 meldete falsch-positiv bei fehlgeschlagenem `--hash-only`

`compare.sh`s G5-Schleife verglich nur `h1 != h2` als Strings. Schlägt
`compare_data.py --hash-only` fehl (Tabelle existiert nicht), liefert es
leeren stdout — `"" == ""` wurde als "Hash stabil" gewertet, obwohl beide
Aufrufe schlicht fehlgeschlagen waren (beobachtet bei 202401/202402, bevor
die Schemata gebaut waren). Fix: Exit-Codes beider Aufrufe explizit prüfen
(`390143c`).

## Fund 4: Qwen konnte nie selbst committen

`opencode.jsonc` enthielt über die gesamte Historie der Datei (`git log
-p` gegen jede Revision geprüft) kein einziges `git`-Pattern in der
`bash`-Permission-Liste. Laufzeit-verifiziert: eine KNZ-709-Runde hat
ihren fertigen Fix viermal hintereinander identisch abgelehnt bekommen
(`git add -f ... && git commit` fällt auf den Bash-Catch-all `deny`
zurück). Konsequenz: jeder `Qwen:`-präfigierte Commit in der Historie bis
zu diesem Zeitpunkt wurde nicht von Qwens eigenem Agent-Loop erzeugt,
sondern muss vom Bauherr stellvertretend committet worden sein — nicht
mehr im Detail rekonstruierbar, da aus einem zusammengefassten
Sessionabschnitt. `docs/ablation-metrics.md` um einen entsprechenden
Nachtrag ergänzt. Fix: fünf eng gescopte Patterns, deckungsgleich mit den
einzigen für Qwen schreibbaren Pfaden (`dbt/**`, `ledger.jsonl`,
`memory/rules/**`) — `50dde11`.

## Ergebnis: Qwens erster echter autonomer Commit

Folgerunde nach dem Fix (`c359554`, Commit-Message von Qwen selbst
verfasst): `pd_schul_abschl`, `bps_bild_abs`, `pd_abschl_art` jetzt
korrekt migriert (fehlende Dimensions-Validierungs-`UPDATE`s aus dem
Original-Skript per `LEFT JOIN` + `CASE WHEN` nachgebaut, analog zum
bereits vorhandenen `pd_tae_durch`-Muster). `pd_rks_id` bleibt abweichend
— dazu unten. Nebenbefund: Qwen hat zwischenzeitlich `check_ref.py`
geschrieben, ein Skript, das die Referenz-Parquet-Datei direkt gelesen
hätte (Verstoß gegen die "read-only für den Agenten"-Grenze) — nie
ausgeführt (kein `python3`-Pattern in der Allowlist, technisch verhindert,
nicht durch eigenes Urteilsvermögen unterlassen), auch nicht mehr
aufräumbar (`rm` ebenfalls nicht erlaubt). Vom Bauherr manuell entfernt,
war nur Working-Tree-Debris, nicht committet.

## Offen, vermutlich nicht fixbar: `pd_rks_id`-Datenvintage

Qwens eigene Diagnose ("Exasol-Dimension `vd_bps_rechtskreis_auftraggeber`
enthält `rks_a_id=52002` nicht") wurde vom Bauherr nachgeprüft und
bestätigt, aber präzisiert:

- Exasol-Dimension `vd_bps_rechtskreis_auftraggeber.rks_a_id`:
  `{52001, 52003, 52004, 99999}` — 52002 fehlt tatsächlich, direkt
  abgefragt.
- Rohe Quell-CSV (`data/pd/dbo__bi_delta_fc_202312_...csv`, Auftrag
  `202312000004`): enthält buchstäblich `52002` als `pd_rks_id`-Wert,
  unverändert seit dem Import.
- Referenz (`learning/pd/referenz/202312/fact__tf_pd_knz_709.parquet`):
  `pd_rks_id`-Werte sind `{52001: 95, 52003: 201, 52004: 103}` — **kein**
  `52002`, **kein** `99999`.

Qwens Modell ist damit 1:1 korrekt zur Original-`UPDATE ... NOT IN`-Logik,
gegeben die Daten, die tatsächlich in Exasol liegen (`52002` → nicht in
Dimension → `99999`). Aber die Referenz erwartet `52003` — weder `52002`
unverändert (was "Dimension enthält 52002 doch" bedeuten würde) noch
`99999` (Sentinel). Das lässt sich nicht durch eine Modell- oder
Dimensions-Korrektur erklären: die **rohe Quell-CSV selbst** enthält für
diesen Auftrag einen anderen Wert als das, wovon die Referenz offenbar
ausging. Plausibelste Erklärung: `data/pd/*.csv` und
`learning/pd/referenz/` stammen aus unterschiedlichen Ständen/Vintages
der Quelldaten, zumindest für dieses Feld — kein Modell-Bug, kein
Gate-Bug, außerhalb des Einflussbereichs von Qwen oder diesem Harness.
Nicht weiterverfolgt (Nutzerentscheidung) — eine weitere Qwen-Runde würde
hier vermutlich nur Tokens ohne Aussicht auf Fortschritt verbrauchen.

## Related
`docs/ablation-metrics.md` (Commit-Attribution-Nachtrag) ·
`skills/verify/g3-row-permutation.md` ·
`docs/session9-multifile-loading.md` (verwandtes Muster: Bauherr-Diagnose
statt Gate-Feedback, hier vermieden — Qwens eigene Diagnose wurde nur
nachträglich verifiziert, nicht vorgegeben) ·
`docs/adr/0001-deterministik-first.md`
