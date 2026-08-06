# ADR 0001 — Deterministik zuerst, LLM nur für den Rest

- Ziel des PoC: belegen, wieviel einer SQL-Server→Exasol/dbt-Migration
  **beweisbar deterministisch** lösbar ist (Skript, kein Token), und dass
  nur der Rest ein LLM (Qwen, über OpenCode) tatsächlich braucht.
- `sqlglot` unterstützt `read="tsql", write="exasol"` nativ. Passes P0–P4
  laufen als Skript (`tools/extract.py`) gegen jedes Quellobjekt, bevor
  irgendein Prompt gebaut wird.
- Triage pro Objekt aus der Schreibzähler-Analyse (P3), nicht aus
  Vermutung: **A** (1 Ziel, 1 schreibendes Statement) rein deterministisch;
  **B** (1 Ziel, n Statements) LLM eng geführt; **C** (prozedural: Cursor,
  dynamisches SQL, Kontrollfluss) LLM + Mensch, sofort `blocked`.
- Reihenfolge/DAG kommt **nicht** aus einer separaten Ablaufsteuerungs-
  Tabelle, sondern ausschließlich aus der AST-Lineage (P3): Zieltabelle(n)
  und Quelltabellen je Statement ergeben den Graphen; die Objekte referen-
  zieren sich selbst. [Chat-Entscheidung, 2026-08-06]
- Regelgedächtnis (`memory/rules/*.md`) ist temporär: jede Regel, die ein
  zweites Mal zutrifft, wird in Code promoviert (sqlglot-Transform,
  dbt-Makro oder P0-Rewrite) und danach aus dem Prompt gelöscht. Wachsendes
  Markdown ist bei schmalem Kontextfenster der sichere Tod.
- Vergleichs-Harness (`tools/compare.sh`, Gates G2–G5) ist **read-only**
  für den Agenten. Ein `git diff`-Check nach jedem Lauf erzwingt das —
  sonst optimiert der Agent die Prüfung statt die Migration.
- Zwei Agent-Dateien: `CLAUDE.md` (Bauherr, darf ausführlich sein) und
  `AGENTS.md` (Prüfling Qwen, ≤ 60 Zeilen, nur Invarianten). Claude Code
  baut den Harness und fasst danach die Migration selbst nicht mehr an —
  sonst ist das Ergebnis nicht zitierfähig.
- Erfolgskorridor: 70–85 % vollautonom (A+B), Rest sauber `blocked`/
  `excluded` mit Begründung. 100 % ist kein Ziel; ein System, das seine
  Grenzen erkennt, ist der stärkere Beweis als eines, das durchläuft.

Verworfen: eigenes Orchestrierungs-Framework (LangGraph o.ä.) — der Loop
existiert bereits in vorhandenen CLI-Agenten (OpenCode/cline); eigener
Python-Code beschränkt sich auf Ledger-Pflege und Extraktion (~200 Zeilen).
