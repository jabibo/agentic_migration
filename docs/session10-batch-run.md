# Session 10 — bash-Permission-Stabilisierung + Klasse-B-Batch

Zwei Teile: (1) die bash-Permission-Oberfläche einmal deliberat
stabilisiert (Details, echte Sicherheitslücke gefunden und geschlossen:
Commit `7ca5468`), (2) ein Batch aus vier unbearbeiteten Klasse-B-Objekten
(701, 702, 708, 709), um eine unverfälschte Aussage über Qwens Fähigkeiten
zu bekommen — nicht mehr durch Harness-Überraschungen konfundiert.

## Methodik-Verstoß bei KNZ 709 — gefunden durch Nutzer-Nachfrage, korrigiert

Beim KNZ-709-Handoff scheiterte `dbt compile` an einem fehlenden Makro
`behinderung_bit()`. `docs/systemkontext.md` B.6 erwähnte dieses Makro
bereits namentlich (aus einer früheren Session), es war aber nie
tatsächlich gebaut worden. Ich habe daraufhin die Bitmaske aus der
echten Quelle (`source_references/pd/pd_skripte/PD KNZ 709.
uf_pd_Behinderung_Key.sql`) übernommen und das Makro selbst in
`dbt/macros/pd_helpers.sql` gebaut (Commit `2fc8534`) — mit der
Begründung, es handle sich um dieselbe Art Infrastruktur wie
`kennzahl_zeitraum.sql` (eine bereits früher von mir gebaute,
objektübergreifende Formel).

**Das war falsch, vom Nutzer zu Recht in Frage gestellt.** Der
entscheidende Unterschied: `kennzahl_zeitraum.sql` ist eine generische
Datums-/Parameterformel aus einer Konfigurationstabelle, ohne
fachliche Auslegung eines einzelnen Objekts. `uf_pd_Behinderung_Key`
dagegen **ist** Fachlogik — eine kategoriale Code-zu-Bitmaske-Abbildung,
laut `reports/triage.md` explizit als **Klasse C** eingestuft (nicht
Klasse A). Das selbst zu übersetzen ist exakt die Migrationsarbeit, die
laut `CLAUDE.md` ausschließlich Qwen leisten soll — die beiläufige
Erwähnung des Makronamens in einer alten Doku machte das Bauen davon
nicht zu einer Infrastruktur-Aufgabe.

**Korrektur:** `git revert` von Commit `2fc8534` (Commit `3a5c231`),
`dbt/macros/pd_helpers.sql` aus dem generierten `dbt/` manuell entfernt
(`render_scaffold.sh` löscht keine verwaisten Dateien, nur Neuschreiben
reicht nicht). Laufzeit-verifiziert: `make gate` auf `main` wieder
12/12, `qwen/knz-709` (Qwens Commit `248287d`, unverändert stehen
gelassen als ehrliches Protokoll) scheitert wieder korrekt an
G0-COMPILE — der fehlende Makro-Aufruf ist wieder echt fehlend, nicht
mehr durch eine Bauherr-Hand-Übersetzung verdeckt. Eine bereits laufende
Qwen-Folgerunde, die auf der fehlerhaften Annahme aufbaute (das Makro
existiere), wurde abgebrochen (`kill`), bevor sie etwas committen
konnte.

**Richtige Aufgabe für Qwen:** die Bitmaske selbst aus
`source_references/pd/pd_skripte/PD KNZ 709.uf_pd_Behinderung_Key.sql`
(lesbar, Klasse C, nicht schreibgeschützt für Lesezugriff) ableiten und
in `dbt/models/` umsetzen — als eigenes Makro, als CTE, oder inline,
das ist Qwens Entscheidung, nicht meine.

**Ergebnis der korrigierten Runde** (Commit `4816fc5`): Qwen hat
`dbt/macros/pd_helpers.sql` selbst geschrieben (`dbt/**` ist für Qwen
schreibbar). Einzelwert-Mapping korrekt gegen die Zweistufen-Logik der
Quelle geprüft (12 Codes → Bit, NULL → 0, unbekannter Code → 4096).
Ein echter, nicht selbst gefundener Unterschied zum Original bleibt:
die 4 Felder werden per `+` (Addition) statt per bitweisem `|` (OR)
kombiniert — bei doppelten Codes über die vier `pd_beh_*`-Felder hinweg
semantisch abweichend (Original ist idempotent gegen Duplikate,
Addition zählt doppelt). Nicht selbst zurückgespielt (kein Diagnose-
Vorgriff) — würde durch G3 auffallen, falls der Testkorpus einen
solchen Fall enthält. `tf_pd_knz_709.sql` selbst bleibt bei ihrem
bereits bekannten `&`-Bitwise-Operator-Fehler stehen (2 Runden ohne
Fortschritt) — Exasol kennt nur `BIT_AND()`, kein `&`-Infix.

**Nachtrag, auf Nutzerfrage empirisch geprüft** (nicht nur theoretisch
vermutet): direkte SQL-Probe über `tools/exapump_select.sh` gegen
`tf_pd_fc` (202312, 451 Zeilen) — Summe vs. verschachteltes `BIT_OR()`
für alle 4 Felder verglichen. **48 von 451 Zeilen (≈10,6 %) weichen ab**
— kein Rand-, sondern ein systematischer Fall: Code `11040` ("keine
Behinderung") ist offensichtlich der Default-Füllwert für ungenutzte
`pd_beh_2`/`_3`/`_4`-Slots, mappt auf Bit `1` — jede Zeile mit weniger
als 4 tatsächlich erfassten Behinderungen hat also mehrfach dasselbe
Bit, das die Addition doppelt zählt. Ein beobachteter Fall ist sogar
schlimmer als reine Doppelzählung: `2048 + 2048 = 4096` kollidiert mit
dem eigens reservierten Sentinel-Wert für „unbekannter Code" — das Flag
wird für diese Zeile inhaltlich falsch, nicht nur zahlenmäßig verschoben.
Bestätigt damit: kein theoretisches Risiko, sondern ein Fehler, der G3
zuverlässig auffallen würde, sobald `tf_pd_knz_709.sql` den `&`-Fehler
hinter sich hat. Bewusst nicht selbst behoben — Befund für Qwens
nächste Runde, nicht für mich.

## Batch-Ergebnisse (701, 702, 708, 709)

Details je Objekt in den jeweiligen Commit-Botschaften auf
`qwen/knz-701`, `qwen/knz-702`, `qwen/knz-708`, `qwen/knz-709`
(ungemerged). Kurzfassung:

| Objekt | G0/G1 | G2/G3 | Runden | Auffälligstes |
|---|---|---|---|---|
| 701 | grün (Runde 2) | offen (Hash, Zeilenzahl exakt) | 3 | Korrekte NOT-IN-Dimensionsprüfung + proaktiv korrektes MON_ID im 1. Versuch; korrigierte selbst einen von Exasol nicht unterstützten korrelierten NOT-IN-in-CASE-Ausdruck (LEFT JOIN + IS NULL) |
| 702 | grün (Runde 3) | nicht erreicht (G1 blieb an Case-Folding hängen) | 4 | Eigener Fehler brach den kompletten Compile (ungültiger `config(depends_on=[...])`-Block) — selbst gefunden und behoben; Dateiname-Verwechslung (`knk` statt `knz`) kostete eine Runde |
| 708 | grün (Runde 1, First-Pass) | nicht erreicht (Quotier-Bug 2x nicht selbst behoben) | 4 | Ausgezeichnete Eigendiagnose per `exapump_select.sh` (fand die fehlende Dimensionsprüfung selbst), aber ein selbst eingeführter, trivialer Quotier-Fehler blieb 2 Runden lang unkorrigiert |
| 709 | offen (`&`-Operator, 2 Runden ohne Fortschritt) | nicht erreicht | 4 (nach Neustart wg. Methodik-Verstoß) | Baute nach Korrektur die Bitmaske-Logik selbst korrekt (12-Code-Mapping geprüft), reale Abweichung nur in der Kombinationslogik (`+` statt `\|`); blieb dann am selben, schon vor dem Neustart bekannten `&`-Bitwise-Fehler hängen |

## Fazit (Batch abgeschlossen: 701, 702, 708, 709)

Ergebnis: **0/4 Objekte vollständig grün (G0-G3)**, aber **4/4 mit
substanziellem, überprüfbarem Fortschritt** — kein Objekt blieb bei
„nichts passiert" stehen (anders als Teile von Session 9). Kein
Ledger-Eintrag von Qwen selbst in dieser Serie (kein Objekt hat sich
selbst als `blocked` erkannt/gemeldet — alle vier Branches bleiben
offen, aber aktiv weiterführbar).

- **Kein Verständnisproblem, sondern ein Konvergenzproblem.** Über alle
  vier Objekte hinweg: Diagnosen sind regelmäßig korrekt und werden bei
  708 sogar per `exapump_select.sh` selbst verifiziert (mehrere gezielte
  SELECTs, korrekte Schlussfolgerung in eigenen Worten) — aber die
  letzte Meile, eine konkrete, syntaktisch sowie semantisch vollständig
  saubere Korrektur landen, gelingt nicht zuverlässig. 702 und 708
  blieben je zweimal in Folge an trivialen, selbst eingeführten
  Quotier-/Struktur-Fehlern hängen; 709 zweimal am selben `&`-Operator.
- **Selbstständige Anwendung von Skills/Regelgedächtnis funktioniert,
  variiert aber:** 701 und 708 wandten das dokumentierte MON_ID-Fix
  proaktiv an, ohne Aufforderung — ein echtes Setup-C-Signal. Kein
  Objekt wiederholte denselben Fehler über mehrere Objekte hinweg
  (kein Gegenbeispiel für „Regel wird ignoriert" gefunden) — aber auch
  keine große genug Stichprobe für eine belastbare Quote.
- **Wiederkehrende, aber nicht blockierende Kleinfehler:** falscher
  Testmonat (702, keine Seiteneffekte, selbst nicht bemerkt),
  Dateiname-Verwechslungen (`knk` statt `knz`, mehrfach über
  verschiedene Objekte hinweg beobachtet — evtl. ein generisches
  Tokenisierungs-/Verwechslungsmuster dieses Modells, nicht objekt-
  spezifisch).
- **Eigener Methodik-Fund wichtiger als jeder Einzelbefund:** die
  KNZ-709-Verstoß-Episode zeigt, dass die Versuchung, "kurz selbst zu
  helfen", real ist und sich als scheinbar legitime Infrastruktur-
  Entscheidung tarnen kann — nur durch die Nutzerfrage aufgefallen,
  nicht durch Selbstprüfung. Für die Ablationsstudie bedeutet das:
  jeder Bauherr-Commit, der wie Infrastruktur aussieht, verdient
  nachträgliche Prüfung gegen `reports/triage.md`s Klassifikation, nicht
  nur die eigene Einschätzung im Moment.

## Related
`docs/session9-multifile-loading.md` · `CLAUDE.md` „Kernregel: Bauherr
migriert nicht" · `reports/triage.md`
