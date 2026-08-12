# AGENTS_B.md — Setup B (Feedback-Loop, kein Regelgedächtnis), Ablationsvergleich

**Nur für den Setup-A/B/C-Vergleich (`docs/setup-a-b-vergleich.md`), nicht
für reguläre Objektmigration — dafür gilt `AGENTS.md`.** Identisch zu
`AGENTS.md`, außer: kein Zugriff auf `memory/rules/*.md` (weder lesen
noch schreiben) — das ist die isolierte Variable gegenüber Setup C.

## Harte Regeln

- 1:1-Migration. Keine erfundene Fachlogik, Original-Objektnamen behalten.
- Schema-Rolle aus `USE <db>` + `docs/systemkontext.md` B.1/B.4 ableiten,
  nicht aus Ordnernamen bestehender Modelle raten.
- Du bekommst pro Aufgabe genau: Quell-DDL (+ gleichnamige `.md`-Fachnotiz
  falls vorhanden), direkte Vorgänger-Interfaces, letzte Fehlerzeile.
  **Kein `memory/rules/*.md`** — `skills/*.md` per `rg <fehlertext oder
  EXEC-Aufruf> skills/` bleibt verfügbar (gegebenes Fachwissen, kein
  Regelgedächtnis).
- **Nicht anfassen — schreibgeschützt:** `tools/`, `source_references/`,
  `skills/`, `docs/`, `reports/`, `AGENTS*.md`, `CLAUDE.md`,
  `opencode.jsonc`, **`memory/rules/`** (Unterschied zu Setup C). Technisch
  durchgesetzt, nicht nur Konvention.
- Ein Objekt = ein Branch = ein Commit. `git add -f dbt/models/...`.
- Bei Blockade (Cursor, dynamisches SQL über Batch-Grenzen, EXEC unklar,
  3 Iterationen ohne Fortschritt): Zeile an `ledger.jsonl` anhängen —
  `{"objekt": "...", "klasse": "B|C", "status": "blocked", "grund": "...",
  "iteration": N}` — dann nicht weiterversuchen. **Keine neue Regel nach
  behobenem Fehler schreiben** (kein `memory/rules/`-Zugriff in diesem
  Setup, das ist beabsichtigt).
- Verbotene Konstrukte: `#temp`-Tabellen, T-SQL-Prozeduren, unquotierte
  gemischte Groß-/Kleinschreibung ohne Case-Prüfung.
- **Schreibzugriff auf Exasol ausschließlich über `dbt run`/`make gate`,
  nie per `exapump sql` mit `CREATE`/`INSERT`/`DROP`.** Lesendes Debugging
  nur über `tools/exapump_select.sh "<SELECT ...>"`.

## Deine Kommandos

```
make gate MONAT=<YYYYMM>            # G0 Syntax + G1 Ausfuehrung gegen dein Modell
make compare MONAT=<YYYYMM>         # G2-G5, lesend, gegen echte Referenzdaten
tools/exapump_select.sh "<SELECT>"  # lesendes Exasol-Debugging, nur ein SELECT
```

## Abbruchkriterium

3 Iterationen auf demselben Gate ohne Fortschritt → `blocked` (s.o.), nicht
weiterversuchen.
