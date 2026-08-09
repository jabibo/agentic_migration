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

## Batch-Ergebnisse (701, 702, 708, 709)

Details je Objekt in den jeweiligen Commit-Botschaften auf
`qwen/knz-701`, `qwen/knz-702`, `qwen/knz-708`, `qwen/knz-709`
(ungemerged). Kurzfassung:

| Objekt | G0/G1 | G2/G3 | Runden | Auffälligstes |
|---|---|---|---|---|
| 701 | grün (Runde 2) | offen (Hash, Zeilenzahl exakt) | 3 | Korrekte NOT-IN-Dimensionsprüfung + proaktiv korrektes MON_ID im 1. Versuch; korrigierte selbst einen von Exasol nicht unterstützten korrelierten NOT-IN-in-CASE-Ausdruck (LEFT JOIN + IS NULL) |
| 702 | grün (Runde 3) | nicht erreicht (G1 blieb an Case-Folding hängen) | 4 | Eigener Fehler brach den kompletten Compile (ungültiger `config(depends_on=[...])`-Block) — selbst gefunden und behoben; Dateiname-Verwechslung (`knk` statt `knz`) kostete eine Runde |
| 708 | grün (Runde 1, First-Pass) | nicht erreicht (Quotier-Bug 2x nicht selbst behoben) | 4 | Ausgezeichnete Eigendiagnose per `exapump_select.sh` (fand die fehlende Dimensionsprüfung selbst), aber ein selbst eingeführter, trivialer Quotier-Fehler blieb 2 Runden lang unkorrigiert |
| 709 | offen (s. Methodik-Verstoß oben) | — | 1 (dann Neustart faellig) | Nutzte korrekt den dokumentierten (aber nie gebauten) Makronamen — kein Qwen-Fehler; echte Aufgabe (Bitmaske selbst bauen) steht noch aus |

## Zwischenfazit (vorläufig, Batch noch nicht abgeschlossen)

- **Kein Verständnisproblem, sondern ein Konvergenzproblem** (bestätigt
  über 3 von 4 Objekten hinweg, s. auch Session 9): Diagnosen sind
  regelmäßig korrekt und werden per `exapump_select.sh` selbst verifiziert
  (708 ist das Paradebeispiel), aber die letzte Meile — eine konkrete,
  syntaktisch saubere Korrektur landen — gelingt nicht zuverlässig.
- **Selbstständige Anwendung von Skills variiert:** 701 und 708 wandten
  das dokumentierte MON_ID-Fix proaktiv an, ohne Aufforderung — ein
  echtes Setup-C-Signal (Regelgedächtnis wirkt). Kein Objekt bisher mit
  demselben Fehler zweimal — noch kein Gegenbeispiel für „wird die Regel
  ignoriert", aber auch noch keine große Stichprobe.
- **Wiederkehrende, aber nicht blockierende Kleinfehler:** falscher
  Testmonat (702, keine Seiteneffekte), Dateiname-Verwechslungen
  (`knk` statt `knz`, mehrfach beobachtet).

## Related
`docs/session9-multifile-loading.md` · `CLAUDE.md` „Kernregel: Bauherr
migriert nicht" · `reports/triage.md`
