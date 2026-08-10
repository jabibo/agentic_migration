# AGENTS.md — für Qwen (Prüfling)

**Du migrierst Objekte der Klasse B/C von T-SQL nach dbt-Exasol. Klasse A
ist bereits deterministisch erledigt — fass sie nicht an, außer über den
Override-Mechanismus weiter unten.**

## Harte Regeln

- 1:1-Migration. Keine erfundene Fachlogik, Original-Objektnamen behalten.
- Schema-Rolle (`schema_for('data'|'dwh'|'calc'|'fact'|'knz'|'dim'|'strg')`)
  **nicht** aus Ordnernamen bestehender Modelle raten — aus dem `USE <db>`
  am Skriptanfang und `docs/systemkontext.md` B.1 ableiten (Layer-
  Bedeutung: DWH = Gesamtbestand inkl. Vormonat, CALC/FACT lesen nur
  daraus, akkumulieren nicht selbst). B.4 hat das DB→Rolle-Mapping.
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
  `rg <fehlertext oder EXEC-Aufruf> skills/` — u.a. Exasol-Fallstricke,
  Berichtszeitraum-Formel, Boilerplate- vs. Framework-Prozeduren.
- Verbotene Konstrukte im generierten dbt-SQL: `#temp`-Tabellen, T-SQL-
  Prozeduren, unquotierte gemischte Groß-/Kleinschreibung ohne Case-Prüfung.
- **Schreibzugriff auf Exasol ausschließlich über `dbt run`/`make gate`,
  nie per `exapump sql` mit `CREATE`/`INSERT`/`DROP`.** Fehlende Upstream-
  Tabelle/-Quelle = Blocker (Ledger, s.o.), nicht selbst fabrizieren, auch
  nicht testweise (Verstoß Session 5, Ergebnis war wertlos). Lesendes
  Debugging nur über `tools/exapump_select.sh "<SELECT ...>"` (s.u.).
- **Ausnahme Klasse A:** G3 zeigt manchmal einen echten Content-Fehler in
  einer generierten Klasse-A-Datei (z.B. `tf_pd_fa.sql`). Fix wie gewohnt,
  Modellname zusätzlich in `dbt/models/qwen_owned.txt` eintragen und
  mitcommitten — sonst verwirft der nächste `render-a`/`make gate` ihn.

## Deine Kommandos

```
make gate MONAT=<YYYYMM>            # G0 Syntax + G1 Ausfuehrung gegen dein Modell
make compare MONAT=<YYYYMM>         # G2-G5, lesend, gegen echte Referenzdaten
tools/exapump_select.sh "<SELECT>"  # lesendes Exasol-Debugging, nur ein SELECT
```

`make extract`/`make render-a` sind Bauherr-Werkzeuge (Klasse A) — nicht
aufrufen. `compare` darfst du lesend laufen lassen; ein G3-Fehler heisst:
dein Objekt ist inhaltlich falsch, nicht der Vergleich.

## Abbruchkriterium

3 Iterationen auf demselben Gate ohne Fortschritt → `blocked` (s.o.), nicht
weiterversuchen.
