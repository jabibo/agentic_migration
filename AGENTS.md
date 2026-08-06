# AGENTS.md — für Qwen (Prüfling)

**Du migrierst Objekte der Klasse B/C von T-SQL nach dbt-Exasol. Klasse A
ist bereits deterministisch erledigt — fass sie nicht an.**

## Harte Regeln

- 1:1-Migration. Keine erfundene Fachlogik, Original-Objektnamen behalten.
- Du bekommst pro Aufgabe genau: Quell-DDL, direkte Vorgänger-Interfaces,
  gematchte `memory/rules/*.md`, letzte Fehlerzeile. Nichts sonst anfordern.
- **Nicht anfassen — schreibgeschützt:** `tools/`, `source_references/`,
  `skills/`, `docs/`, `ledger.jsonl`, `reports/`, `AGENTS.md`, `CLAUDE.md`,
  `opencode.jsonc`. Das ist keine reine Konvention — `opencode.jsonc`
  (`agent.migrator.permission.edit`) verweigert Schreibzugriff auf diese
  Pfade technisch. Ein Versuch scheitert am Tool, nicht erst im Review.
- Ein Objekt = ein Branch = ein Commit.
- Bei Blockade (Cursor, dynamisches SQL über Batch-Grenzen, EXEC unklar):
  Objekt im Ledger als `blocked` mit Grund eintragen, nicht raten.
- Neue Regel nach behobenem Fehler: `memory/rules/<code>.md`, ≤ 5 Zeilen,
  generalisiert (nicht objektspezifisch).
- Verbotene Konstrukte im generierten dbt-SQL: `#temp`-Tabellen, T-SQL-
  Prozeduren, unquotierte gemischte Groß-/Kleinschreibung bei Schlüsseln
  ohne Case-Prüfung.

## make-Targets

```
make extract    # P0–P3, kein LLM
make transpile   # P4-Vorschlag + Klasse-B/C-Objekte an dich
make gate        # G0–G1 (compile/run), normalisierter Fehlerkanal
make compare      # G2–G5, read-only — nie selbst aufrufen um „grün" zu erzwingen
```

## Abbruchkriterium

3 Iterationen auf demselben Gate ohne Fortschritt → `blocked`, nicht
weiterversuchen. Details/Mapping: `rg` gegen `skills/`, nicht raten.
