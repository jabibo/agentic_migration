# agentic-migration — Deterministik-first PoC: SQL Server → dbt-Exasol

Beweist, wieviel einer T-SQL→Exasol/dbt-Migration **ohne LLM** deterministisch
lösbar ist (via `sqlglot`), und dass nur der Rest ein LLM (Qwen, über
OpenCode) tatsächlich braucht — mit Feedback-Gates und einem Regelgedächtnis,
das durch Promotion in Code wieder schrumpft statt zu wachsen.

| Frage | Wo nachsehen |
|---|---|
| Substanz/Entscheidungen (warum so gebaut) | [docs/adr/0001-deterministik-first.md](docs/adr/0001-deterministik-first.md) |
| Wie arbeite ich hier als Bauherr (Claude Code)? | [CLAUDE.md](CLAUDE.md) |
| Wie arbeitet der Prüfling (Qwen)? | [AGENTS.md](AGENTS.md) — bewusst ≤ 60 Zeilen |
| Fachlicher Originalkontext (Referenzverfahren BPS/PD) | [docs/systemkontext.md](docs/systemkontext.md) |
| Aktueller Stand: wieviel ist deterministisch (Triage A/B/C)? | `make extract` → [reports/triage.md](reports/triage.md) |

## Schnellstart

```bash
make extract   # P0-P4, kein Token: Platzhalter, Parse, Lineage, Exasol-Transpile-Vorschlag
make report    # dasselbe + Ausgabe des Triage-Reports
```

`transpile`/`gate`/`compare` existieren als Makefile-Targets, sind aber noch
nicht implementiert (Session 3, siehe Sessionfolge in [CLAUDE.md](CLAUDE.md)).

## Stand Session 1

15 Objekte (Referenzverfahren PD, `source_references/pd/pd_skripte/`):
Klasse A 20 %, Klasse B 40 %, Klasse C 33 %, davon 1 vollständig
auskommentiert (`excluded`). Details: [reports/triage.md](reports/triage.md).
