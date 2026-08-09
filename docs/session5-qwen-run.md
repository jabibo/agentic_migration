# Session 5 — erster echter Qwen-Lauf (PD KNZ 705)

Erste tatsächliche Übergabe an Qwen (über OpenCode), nicht mehr nur
Infrastruktur. Ziel: ein Klasse-B-Objekt end-to-end, verifiziert — inkl.
der Frage, ob der Lauf wirklich Qwen trifft (der alte cline-Lauf in
`without_macros/agentic` hatte genau das nicht sichergestellt).

## Vorab-Verifikation

```
opencode run "Antworte NUR mit: PONG" --agent migrator --format json
→ Antwort: "PONG", Kosten $0.0012
opencode export <sessionID> → providerID: openrouter, modelID: qwen/qwen3.6-35b-a3b
```
Bestätigt vor dem eigentlichen Lauf, nicht danach angenommen.

## Der Lauf

Objekt: `PD KNZ 705.KNZ 705.sql` (Klasse B, 9 Statements, kleinstes
B-Objekt). Branch `qwen/knz-705`. Prompt bewusst minimal (Objektname +
Verarbeitungsmonat + Validierungsbefehl) — keine Zielpfade, keine
Hinweise auf die Lösung (answer-key leakage vermeiden, wie im alten
Projekt).

**158 Modell-Schritte, 6 Iterationen (Ledger-Zählung: Compile/Run/
Vergleich/Fix-Zyklen), Kosten $1.70.** Kein Prompt-Caching sichtbar
(`cache.read`/`cache.write` durchgehend 0) — bei wachsendem Kontext über
158 Schritte ist das ein relevanter Kostentreiber, wert für spätere
Objekte zu beobachten (Token-Kosten/Objekt ist eine der in `CLAUDE.md`
genannten Kennzahlen).

## Was Qwen selbständig getan hat

Ohne dass es im Prompt stand: `reports/triage.json` und `ledger.jsonl`
gelesen, bestehende Klasse-A-Modelle als Konventionsbeispiel geprüft,
mehrere strukturell ähnliche KNZ-Skripte (701, 706, 708) zum Vergleich
gelesen, `skills/transpile/exasol-dialect-gotchas.md` konsultiert (das
`var('verarbeitungsmonat')`-Muster für den Berichtszeitraum selbständig
übernommen — genau das Muster, das in Session 3 für Klasse A gebaut
wurde), `dbt compile`/`dbt run --select tf_pd_knz_705` isoliert getestet,
sogar `learning/pd/referenz/202312/fct_pd_knz_705.parquet` selbst nach
Exasol geladen und mit dem eigenen Ergebnis verglichen (G3-artige
Eigeninitiative, obwohl `compare.sh` gar nicht existiert).

## Der Fund: ein echter Bug in meiner eigenen Klasse-A-Pipeline

Qwen versuchte `make gate` (Full-Pipeline) und scheiterte — meldete das
korrekt als **fremden** Fehler, nicht als eigenen: `tools/` ist laut
`AGENTS.md`/`opencode.jsonc` schreibgeschützt, Qwen hat **nicht**
versucht, `render_dbt_models.py` selbst zu reparieren, sondern den Befund
präzise in `ledger.jsonl` dokumentiert:

> „Full-Gate scheitert an Alias-Bugs in render_dbt_models.py generierten
> Klasse-A-Modellen (tt_deltant_pd_fc_org, tf_pd_fa: JOINs ohne
> Table-Aliases obwohl ON-Klauseln Aliases verwenden)."

**Verifiziert und bestätigt:** `render_dbt_models.py`s Tabellen-Platzhalter-
Ersetzung (`t.replace(exp.to_table(ph))`) erzeugte eine neue Tabelle ohne
den ursprünglichen Alias (`f`, `dst`, `reg`) — FROM/JOIN verloren ihn,
obwohl SELECT-/ON-Klauseln ihn weiter referenzierten. War in Session 3
nicht aufgefallen, weil beide betroffenen Modelle dort schon vorher an
der fehlenden Klasse-C-Abhängigkeit scheiterten — die Alias-Auflösung kam
nie zum Zug. **Behoben** (Alias wird jetzt mitkopiert), Commit
`f0614a0`, unabhängig von Qwens Commit `3ec5f88`.

Das ist der eigentliche Beweiswert dieses Laufs: zwei unabhängige Agenten
(Claude als Bauherr, Qwen als Prüfling) gegen dieselbe Infrastruktur —
Qwen hat einen Fehler in Claudes Code gefunden, den Session 3 übersehen
hatte, und die Grenze respektiert statt ihn selbst zu fixen.

## Endzustand (nach dem Fix, `make gate MONAT=202312`)

```
G0: 6/6 Modelle syntaktisch OK
G1: 0/6 erfolgreich, 2 Fehler (tt_deltant_pd_fc_org, tf_pd_fa — beide
    weiterhin fehlende Klasse-C/Dimension-Abhaengigkeit, nur praeziser:
    "REG.GST_BA_SCHL not found" / "KAL_EING.TAG_DAT not found" statt nur
    des ersten Tabellennamens), 4 uebersprungen (inkl. tf_pd_knz_705 —
    per ref()-Kette korrekt uebersprungen, nicht fehlgeschlagen)
```

`tf_pd_knz_705` selbst: **kein eigener Fehler**, nur `skipped` wegen der
Upstream-Kette. Isoliert (Qwens eigener Test) lief es erfolgreich.

## Geprüft (nicht nur behauptet)

- `git diff main..qwen/knz-705 --stat` gegen alle geschützten Pfade
  (`tools/`, `source_references/`, `skills/`, `docs/`, `reports/`,
  `AGENTS.md`, `CLAUDE.md`, `opencode.jsonc`): **leer** — Qwen hat sie
  nicht angerührt, weder direkt noch über Bash-Umweg.
- Ein Commit für das Objekt (`3ec5f88`), Branch korrekt benannt.
- `ledger.jsonl`-Eintrag inhaltlich korrekt und nachvollziehbar, nicht nur
  „lief durch".

## Offen für weitere Objekte

- Kostenprofil (kein Prompt-Caching) vor größeren B-Objekten (KNZ 709:
  17 Statements) im Auge behalten.
- Klasse-C-Bestand (`PD LOAD.Bestandsuebernahme.sql`) migrieren, bevor
  ein Klasse-A/B-Objekt tatsächlich grün laufen kann — aktuell blockiert
  jedes Objekt, das `con_pd_dwh`/`con_pd_knz`-Quellen braucht.
