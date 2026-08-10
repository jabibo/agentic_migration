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
| PD LOAD.Bestandsuebernahme (fc/fa/azt, erste Serie) | C | 3 (1) | $0,65 | Teilweise (fc ok, fa/azt G1 grün aber inhaltlich falsch) | fc: grün; fa/azt: grün aber falsch | fc später korrekt adoptiert; fa/azt: siehe unten | fc: ja; fa/azt: **nein** (Bauherr diagnostizierte `bi_load_date` statt Gate-Feedback — Session 6) |
| tf_deltant_pd_fa/azt (Multi-File-Adoption) | C (Infra-Adoption) | 6 (2) | ~$0,14 | Nein | **nie grün** | nie erreicht | **Nein** — 0/6, endgültig gescheitert (Session 9), 2 Runden davon durch Bauherr-Diagnose/`--auto`-Eingriff belastet |
| PD KNZ 706.KNZ 706.sql | B | 4 (0) | $0,10 | Ja (im ersten echten Schreibversuch, Runde 3 — Runden 1-2 scheiterten an Harness-Permissions, nicht an Qwens Modell) | G0 13/13, G1 13/13 | G2 fehlende Spalte, G3 Hash-Abweichung — **nicht weiterverfolgt** | Teilweise (Struktur ja, Inhalt offen) |
| PD KNZ 701.KNZ 701.sql | B | 3 (0) | $0,18 | Nein (korrelierte NOT-IN-in-CASE, von Exasol nicht unterstützt) | G0 15/15, G1 15/15 (nach Selbstkorrektur) | G3 Hash-Abweichung (Zeilenzahl exakt 151/151) — **offen, 1 Runde ohne Fortschritt** | Teilweise |
| PD KNZ 702.KNZ 702.sql | B | 5 (0) | $0,084 | Nein (ungültiger `config(depends_on=[...])`, brach kompletten Compile) | G0 13/13 grün, **G1 702 selbst weiterhin rot** (Case-Folding, 2 Runden ohne Fortschritt) | nicht erreicht | Teilweise |
| PD KNZ 708.KNZ 708.sql | B | 4 (0) | $0,18 | **Ja** (First-Pass) | G0/G1 grün zunächst, brach beim eigenen G3-Fix-Versuch erneut (Quotier-Bug, 2 Runden ohne Fortschritt) | nicht erreicht | Teilweise |
| PD KNZ 709.KNZ 709.sql | B | 8 (2, verworfen) | ~$0,24 (nur die 8 zählbaren Runden) | Nein (`&`-Operator von Anfang an im Modell) | G0 14/14, G1 14/14 (Runde 6) | G3 erreicht — **einziges Objekt neben 705**, 8/22 Spalten abweichend, 2 Runden ohne Fortschritt | Teilweise — am weitesten fortgeschritten von allen offenen Objekten |

## Kennzahlen

- **Autonomierate (vollständig G0-G5 grün, unaided):** 1/8 (12,5 %) —
  nur PD KNZ 705.
- **First-Pass-Yield (G0/G1 sauber im allerersten echten,
  unbelasteten Versuch):** 2/7 zählbare Klasse-B/C-Erstversuche
  (706 einmal es tatsächlich zu einem Schreibversuch kam, 708) ≈ 29 %.
  705 und die Bestand-Serie zählen wegen methodischer Verzerrung nicht
  mit; `tf_deltant_pd_fa/azt` ebenfalls nicht (nie ein sauberer
  Erstversuch, strukturell blockiert).
- **Ø Iterationen/Objekt (nur zählbare, unbelastete Runden):**
  (2+2+6+4+3+5+4+8) / 8 = 34/8 ≈ **4,25 Runden/Objekt**. Deutlich über
  `AGENTS.md`s eigener 3-Iterationen-Abbruchschwelle — kein Objekt in
  dieser Session wurde nach 3 Runden tatsächlich abgebrochen, ich habe
  wiederholt (mit Nutzerzustimmung) über die Schwelle hinaus versucht.
  Kein einziges Objekt hat sich selbst per `ledger.jsonl` als `blocked`
  gemeldet (s. `docs/session10-batch-run.md`, offene Frage).
- **Datenäquivalenz-Quote (G2+G3 exakt erreicht):** 1/8 (12,5 %) —
  wieder nur 705. Von den restlichen 7 haben 2 (701, 709) G3 überhaupt
  *erreicht* (Zeilenzahl exakt, Hash weicht ab) — 5 von 8 haben G2/G3
  nie erreicht.
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
- **Konvergenz nach dem ersten Fehlschlag ist die eigentliche
  Schwachstelle**, nicht der Erstversuch selbst. Ø 4,25 Runden/Objekt
  bei nur 1/8 vollständigem Erfolg zeigt: der Feedback-Loop *läuft*
  (Qwen bekommt echte Gate-Fehler zurück, reagiert, iteriert teils
  über viele Runden), aber er *konvergiert* selten bis zum Ziel.
- **Setup C (persistentes Regelgedächtnis) ist mit diesen Daten noch
  nicht sauber testbar.** Die Stichprobe ist zu klein und zu sehr von
  harness-bedingten Umwegen durchsetzt (permission-bedingte Blocker in
  4 von 8 Objekten), um einen Trend „Iterationen/Objekt sinkt über
  Zeit" verlässlich zu zeigen — auch wenn 708 (proaktiv korrektes
  MON_ID) und 709 (proaktive `memory/rules/exasol_bitwise.md`) echte
  Einzelbelege für funktionierendes Regelgedächtnis liefern.

## Related
`CLAUDE.md` (Ablationsdesign) · `docs/session5-qwen-run.md` ·
`docs/session6-bestand-run.md` · `docs/session8-architektur-review.md` ·
`docs/session9-multifile-loading.md` · `docs/session10-batch-run.md`
