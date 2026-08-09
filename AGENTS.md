# AGENTS.md — für Qwen (Prüfling)

**Du migrierst Objekte der Klasse B/C von T-SQL nach dbt-Exasol. Klasse A
ist bereits deterministisch erledigt — fass sie nicht an.**

## Harte Regeln

- 1:1-Migration. Keine erfundene Fachlogik, Original-Objektnamen behalten.
- Du bekommst pro Aufgabe genau: Quell-DDL, direkte Vorgänger-Interfaces,
  gematchte `memory/rules/*.md`, letzte Fehlerzeile. Nichts sonst anfordern.
- **Nicht anfassen — schreibgeschützt:** `tools/`, `source_references/`,
  `skills/`, `docs/`, `reports/`, `AGENTS.md`, `CLAUDE.md`, `opencode.jsonc`.
  Das ist keine reine Konvention — `opencode.jsonc`
  (`agent.migrator.permission.edit`) verweigert Schreibzugriff auf diese
  Pfade technisch. Ein Versuch scheitert am Tool, nicht erst im Review.
  `ledger.jsonl` und `memory/rules/` sind explizit schreibbar (s.u.).
- Ein Objekt = ein Branch = ein Commit. `dbt/` ist `.gitignore`d (Klasse-A-
  Build-Ergebnis) — dein Modell trotzdem committen: `git add -f dbt/models/...`.
- Bei Blockade (Cursor, dynamisches SQL über Batch-Grenzen, EXEC unklar,
  3 Iterationen ohne Fortschritt): Zeile an `ledger.jsonl` anhängen —
  `{"objekt": "...", "klasse": "B|C", "status": "blocked", "grund": "...",
  "iteration": N}` — dann nicht weiterversuchen.
- Neue Regel nach behobenem Fehler: `memory/rules/<code>.md`, ≤ 5 Zeilen,
  generalisiert (nicht objektspezifisch). Vor jedem eigenen Fix-Versuch:
  `rg <fehlertext> skills/` — `skills/transpile/exasol-dialect-gotchas.md`
  hat 3 laufzeit-verifizierte Fälle exakt nach Fehlertext durchsuchbar.
- Verbotene Konstrukte im generierten dbt-SQL: `#temp`-Tabellen, T-SQL-
  Prozeduren, unquotierte gemischte Groß-/Kleinschreibung bei Schlüsseln
  ohne Case-Prüfung.

## Dein einziges Kommando

```
make gate MONAT=<YYYYMM>   # G0 (Syntax) + G1 (Ausfuehrung) gegen dein Modell
```

`make extract`/`make render-a` sind Bauherr-Werkzeuge (Klasse A) — nicht
deine Aufgabe, nicht aufrufen. `make compare` (G2–G5) existiert noch nicht.

## Abbruchkriterium

3 Iterationen auf demselben Gate ohne Fortschritt → `blocked` (s.o.), nicht
weiterversuchen.
