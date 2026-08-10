# Ablation-Metriken — Setup B (LLM + Feedback-Loop), Stand nach Session 10

Quantifizierung der bisher migrierten/versuchten Objekte, wie in
`CLAUDE.md`s Ablationstabelle vorgesehen (Autonomierate, First-Pass-
Yield, Ø Iterationen/Objekt, Token-Kosten/Objekt). Reine Analyse
bereits gelaufener Runden — keine neuen Läufe für dieses Dokument.

**Quellenlage:** Rundenanzahl und G0-G5-Status stammen aus den
Session-Dokumenten (`docs/session5-qwen-run.md` bis `docs/
session10-batch-run.md`) und `git log`, dort präzise. Kosten pro Runde
stammen aus `opencode`s eigener Session-Datenbank
(`~/.local/share/opencode/opencode.db`) — bei den Objekten mit vielen
kurz aufeinanderfolgenden Runden (KNZ 702, 708, 709) per Session-Titel
und Zeitstempel den Runden zugeordnet, nicht immer 1:1 eindeutig
rekonstruierbar aus dem Titel allein. Wo eine Runde methodisch belastet
war (Bauherr-Diagnose/-Content-Fix statt reines Gate-Feedback), ist das
explizit markiert — diese Runden sind für die Bewertung von Qwens
eigener Autonomie nicht zählbar, nur ihre Kosten sind real angefallen.

**Kritischer Nachtrag (2026-08-10):** `opencode.jsonc` enthielt über die
gesamte Historie der Datei (`git log -p` gegen jede Revision geprüft)
**kein einziges `git`-Pattern** in der `bash`-Permission-Liste. Qwen
konnte technisch nie selbst `git add`/`git commit` ausführen — jeder
Versuch fiel auf den Bash-Catch-all `deny` zurück. Laufzeit-verifiziert
an einer KNZ-709-Runde dieser Session: vier identische, nacheinander
abgelehnte `git add -f ... && git commit`-Versuche, Änderung blieb
uncommitted im Working Tree liegen.

Konsequenz: **jeder `Qwen:`-präfigierte Commit in der Historie bis zu
diesem Zeitpunkt — einschließlich aller in der Tabelle unten gezählten
Objekte — wurde nicht von Qwens eigenem Agent-Loop erzeugt**, sondern
muss vom Bauherr stellvertretend committet worden sein (vermutlich in
früheren, inzwischen zusammengefassten Sessions, nicht mehr im Detail
rekonstruierbar). Die Spalte „Autonomie unaided" unten bewertet
inhaltliche Eigenständigkeit (kein Bauherr-Diagnose-/Content-Fix) —
**nicht** den Commit-Schritt selbst; „Ja"/„Teilweise" darf also nicht
als „Qwen hat den Vorgang bis zum Commit selbst abgeschlossen"
gelesen werden. Fix (selbes Datum): `opencode.jsonc` um eng gescopte
`git add -f dbt/models/*`/`git add ledger.jsonl`/`git add -f
memory/rules/*`/`git commit -m *`-Patterns ergänzt — deckungsgleich mit
den einzigen für Qwen schreibbaren Pfaden. Objekte/Runden **vor** diesem
Fix sind vom Fund betroffen; alles danach kann den Commit-Schritt
erstmals echt (unaided) testen.

## Objekttabelle

| Objekt | Klasse | Runden (davon belastet) | Kosten gesamt | Erster Versuch G0/G1 sauber? | Finaler G0/G1-Status | Finaler G2-G5-Status | Autonomie unaided |
|---|---|---|---|---|---|---|---|
| PD KNZ 705.KNZ 705.sql | B | 2 (0) | $2,03 | Nein (Klasse-A-Bug in `render_dbt_models.py` gefunden, Bauherr-Infra-Fix, kein Content-Fix) | G0 12/12, G1 12/12 | **G0-G5 alle grün** | Ja |
| PD LOAD.Bestandsuebernahme (fc/fa/azt, erste Serie) | C | 3 (1) | $0,65 | Teilweise (fc ok, fa/azt G1 grün aber inhaltlich falsch) | fc/fa/azt: alle grün | fc: **G0-G3+G5 alle grün** (via `tf_pd_knz_711`, Session 13); fa: **ebenso** (via `tf_pd_knz_711`, dieselbe Kette); azt: **nur Direktprüfung, kein G2/G3 möglich** — Zeilenzahl (500=500) und Stichprobe wertgenau gegen die rohe CSV verifiziert, aber kein Skript im gesamten Korpus konsumiert `tf_deltant_pd_azt` (auch nicht in der Lineage als Quelle), also keine Referenzdatei und kein Downstream-Modell, das eine Gate-Prüfung ermöglichen würde — strukturell, nicht behebbar ohne Scope-Erweiterung | fc/fa: ja, gate-bewiesen; azt: **inhaltlich plausibel** (Session 6 + Direktprüfung Session 13), aber nie gate-verifizierbar und das bleibt so, solange kein Konsument migriert wird |
| tf_deltant_pd_fa/azt (Multi-File-Adoption) | C (Infra-Adoption) | 6 (2) | ~$0,14 | Nein | **nie grün** | nie erreicht | **Nein** — 0/6, endgültig gescheitert (Session 9), 2 Runden davon durch Bauherr-Diagnose/`--auto`-Eingriff belastet |
| PD KNZ 706.KNZ 706.sql | B | 4 (0) + 1 (Session 12) | $0,10 + $0,321 | Ja (im ersten echten Schreibversuch, Runde 3 — Runden 1-2 scheiterten an Harness-Permissions, nicht an Qwens Modell) | G0 13/13, G1 13/13 | **G0-G3 + G5 alle grün** (Session 12: fehlende Spalte `pd_auftr_id` ergänzt, UPDATE-Normalisierung als `LEFT JOIN`, eigene `memory/rules/pd_normalisierung_left_join.md` geschrieben) | **Ja** — verifiziert autonomer Commit (`b25d7a2`) |
| PD KNZ 701.KNZ 701.sql | B | 3 (0) + 1 (Session 11) | $0,18 + $0,013 | Nein (korrelierte NOT-IN-in-CASE, von Exasol nicht unterstützt) | G0 15/15, G1 15/15 (nach Selbstkorrektur) | **G0-G3 + G5 alle grün** (Session 11: Tippfehler `pd_traeger_id`, 1 Runde) | **Ja** — erstes Objekt mit verifiziertem Selbst-Commit (`f490655`) |
| PD KNZ 702.KNZ 702.sql | B | 5 (0) + 1 (Session 12) | $0,084 + $0,033 | Nein (ungültiger `config(depends_on=[...])`, brach kompletten Compile) | G0 13/13 grün, G1 702 selbst zuvor weiterhin rot (Case-Folding, 2 Runden ohne Fortschritt vor Session 11/12) | **G0-G3 + G5 alle grün** (Session 12: 5× Case-Mismatch in `con_pd_knz`-JOINs, `pd_auftr_id` ergänzt, `MON_ID` korrekt auf Konstante umgestellt, **17 erfundene Platzhalter-Spalten** `0 AS sm_XX_days`/`bg_XX_days`/`GLZ_NETTO_in_Wochen` entfernt — Bauherr-seitig gegen die Referenz verifiziert: die hat tatsächlich nur 15 Spalten, kein Zufallstreffer) | **Ja** — verifiziert autonomer Commit (`9492330`) |
| PD KNZ 708.KNZ 708.sql | B | 4 (0) + 2 (Session 12) | $0,18 + $0,025 (Stillstand, 11 Min. ohne Aktion) + $0,040 (Erfolg) | **Ja** (First-Pass) | G0/G1 grün zunächst, brach beim eigenen G3-Fix-Versuch erneut (Quotier-Bug, 2 Runden ohne Fortschritt vor Session 11/12) | **G0-G3 + G5 alle grün** (Session 12, Versuch 2: Case-Mismatch `Anzahl`/`"anzahl"` **und** ein zweiter, vorher verdeckter Bug — correlated IN-Predicate in SELECT, von Exasol nicht unterstützt — beide selbst gefunden und mit demselben LEFT-JOIN-Muster wie 706/709 gelöst) | **Ja** — verifiziert autonomer Commit (`66b5a29`) |
| PD KNZ 709.KNZ 709.sql | B | 8 (2, verworfen) + Folgerunden (Session 11) | ~$0,24 + $0,652 | Nein (`&`-Operator von Anfang an im Modell) | G0 14/14, G1 14/14 (Runde 6) | G3: 3/4 vormals fehlende Dimensions-Checks korrekt, `pd_rks_id` offen (vermutlich Datenvintage, kein Modell-Bug) | Teilweise — erster autonomer Commit (`c359554`), inhaltlich 3/4 gelöst |

## Kennzahlen

- **Autonomierate (vollständig G0-G5 grün, unaided):** 6/8 (75 %) —
  705, 701, 706, 708, 702, Bestand-Serie (fc/fa/azt). Wichtiger
  Unterschied (s. Nachtrag oben): 705s und der Bestand-Seriens Commits
  sind vermutlich Bauherr-vermittelt (Permission-Lücke existierte damals
  bereits), 701/706/708/702 sind die einzigen vier Objekte mit
  *verifiziert* eigenständigem Commit-Schritt. Bestand-Serie war
  inhaltlich seit Session 6 korrekt, aber bis Session 13 nie
  gate-verifizierbar (kein Downstream-Konsument existierte als
  dbt-Modell) — Autonomie der Migration selbst unabhängig davon zu
  bewerten von der Frage, wann sie *nachweisbar* wurde.
- **First-Pass-Yield (G0/G1 sauber im allerersten echten,
  unbelasteten Versuch):** 2/7 zählbare Klasse-B/C-Erstversuche
  (706 einmal es tatsächlich zu einem Schreibversuch kam, 708) ≈ 29 %.
  705 und die Bestand-Serie zählen wegen methodischer Verzerrung nicht
  mit; `tf_deltant_pd_fa/azt` ebenfalls nicht (nie ein sauberer
  Erstversuch, strukturell blockiert). Unverändert durch Session 11/12 —
  First-Pass-Yield misst den allerersten Versuch, der liegt in der
  Vergangenheit und wird durch spätere Folgerunden nicht rückwirkend
  verändert.
- **Ø Iterationen/Objekt (nur zählbare, unbelastete Runden):**
  (2+2+6+4+3+5+4+8) / 8 = 34/8 ≈ **4,25 Runden/Objekt** (Stand vor
  Session 11/12, unverändert als historische Basiszahl — die
  Folgerunden dieser Session sind ein separates, nachgeschaltetes
  Kapitel, kein Ersatz für die ursprüngliche Iterationszahl bis zum
  ersten Abbruch). Deutlich über `AGENTS.md`s eigener
  3-Iterationen-Abbruchschwelle — kein Objekt in dieser Session wurde
  nach 3 Runden tatsächlich abgebrochen, ich habe wiederholt (mit
  Nutzerzustimmung) über die Schwelle hinaus versucht. Kein einziges
  Objekt hat sich selbst per `ledger.jsonl` als `blocked` gemeldet
  (s. `docs/session10-batch-run.md`, offene Frage).
- **Datenäquivalenz-Quote (G2+G3 exakt erreicht):** 6/8 (75 %) — 705,
  701, 706, 708, 702, Bestand-Serie (fc/fa/azt, via `tf_pd_knz_711`,
  Session 13). 709 hat G3 erreicht und zu 3/4 gelöst, zählt aber wegen der
  offenen `pd_rks_id`-Abweichung nicht als exakt. Nur noch Multi-File-
  Adoption (1 von 8) hat G2/G3 nie erreicht — strukturell blockiert
  (Cursor-/Multi-File-Ladepfad), nicht durch Inhaltsfehler.
- **Token-Kosten/Objekt:** stark gestreut ($0,084 bis $2,03), Median
  ≈ $0,18. Der teuerste Fall (705, $2,03) war der allererste Lauf des
  Projekts ohne jede Vorerfahrung/Regelgedächtnis — spätere Objekte
  trotz mehr Runden günstiger, vermutlich Cache-Treffer + gereiftere
  `skills/`/`memory/rules/`-Basis.
- **Gesamtkosten aller in diesem Dokument gezählten Runden:** ≈ $3,60
  (Summe der Objekttabelle). Gesamtkosten aller 46 in `opencode.db`
  verzeichneten Sessions (inkl. Permission-Proben, Setup-Checks,
  verworfene/belastete Runden): $3,64 — die Differenz (~$0,04) sind
  die kurzen Permission-/Setup-Proben, keine Objektarbeit.

## Interpretation

- Die **First-Pass-Yield von ~29 %** deckt sich überraschend gut mit
  der ursprünglich in `CLAUDE.md` für **Setup A (LLM only)** erwarteten
  Bandbreite (~30–50 %) — obwohl alle diese Läufe bereits *mit*
  Feedback-Loop (Setup B) liefen. Das ist kein Widerspruch: First-Pass-
  Yield misst per Definition den *ersten* Versuch, bevor der Loop
  überhaupt greift. Der eigentliche Setup-B-Effekt zeigt sich erst in
  der Iterationszahl danach — und dort ist das Bild gemischt (s. u.).
- **Konvergenz nach dem ersten Fehlschlag war die ursprünglich
  beobachtete Schwachstelle** — Ø 4,25 Runden/Objekt bei nur 1/8
  vollständigem Erfolg (Stand vor Session 11/12). **Nach den
  Harness-Fixes (col_hash-Bug, source()/ref()-Race, G5-Falsch-Positiv,
  vor allem die Commit-Permission-Lücke) sieht das Bild deutlich anders
  aus:** 701, 706, 708 kamen jeweils in 1-2 Folgerunden zum vollständigen,
  selbst committeten Erfolg; 709 zu 3/4. Das relativiert die frühere
  Diagnose "Feedback-Loop läuft, konvergiert aber selten" erheblich —
  ein relevanter Teil der schlechten Konvergenz war die Harness selbst
  (Qwen konnte gefundene, korrekte Fixes nie committen; das Gate gab bei
  706/709 teils falsche Spalten-Diagnosen zurück), nicht Qwens Fähigkeit,
  Fehler zu beheben. Wie viel davon reine Harness-Artefakte waren und
  wie viel echte Modellverbesserung (z. B. durch gereifte `skills/`), ist
  mit dieser Stichprobe nicht sauber trennbar — beide Effekte wirkten
  gleichzeitig.
- **Neuer Befund, methodisch wichtiger als die Erfolgsquote selbst:**
  bis zur Commit-Permission-Fix in dieser Session enthielt `opencode.jsonc`
  über die *gesamte* Projekthistorie kein einziges `git`-Pattern in der
  `bash`-Allowlist — Qwen konnte zu keinem Zeitpunkt selbst committen.
  Jeder `Qwen:`-präfigierte Commit vor diesem Fix (705 eingeschlossen)
  wurde folglich stellvertretend vom Bauherr committet, nicht von Qwens
  eigenem Agent-Loop. Das bedeutet: die *historische* Autonomierate von
  1/8 war vermutlich nie eine reine Autonomiemessung, sondern (teilweise)
  eine Bauherr-vermittelte. Erst 701/706/708/709 in dieser Session sind
  echte End-to-End-Autonomiebelege (inkl. Commit), gemessen unter
  identischen Bedingungen.
- **Setup C (persistentes Regelgedächtnis) ist mit diesen Daten noch
  nicht sauber testbar.** Die Stichprobe ist klein, und die drei
  Erfolge dieser Session profitierten alle direkt von zuvor
  angelegten `skills/`-Einträgen bzw. eigenen `memory/rules/`-Einträgen
  (706 hat z. B. selbst `pd_normalisierung_left_join.md` geschrieben,
  708 hat dasselbe LEFT-JOIN-Muster direkt wiederverwendet) — ein echter,
  wenn auch nicht randomisiert kontrollierter Beleg für wirkendes
  Regelgedächtnis über Objekte hinweg.

## Related
`CLAUDE.md` (Ablationsdesign) · `docs/session5-qwen-run.md` ·
`docs/session6-bestand-run.md` · `docs/session8-architektur-review.md` ·
`docs/session9-multifile-loading.md` · `docs/session10-batch-run.md` ·
`docs/session11-g3-bugs-und-commit-luecke.md` ·
`docs/session12-mon_id-skill-korrektur.md` ·
`docs/session13-bestand-711-fixes.md`
