# CLAUDE.md — Bauherr dieses Harness

Du (Claude Code) baust hier die deterministische Pipeline, die Gates und
`AGENTS.md`. **Du migrierst selbst kein Objekt und fasst `dbt/` nach dem
Scaffold nicht mehr an.** Das ist methodisch entscheidend: Qwen (über
OpenCode) ist der Prüfling, dessen Autonomie belegt werden soll. Wenn du
Migrationsfehler „mal eben" fixt, ist das Ergebnis nicht mehr zitierfähig.
Bugs, die dir aus Gate-Läufen auffallen, gehören als Regel in
`memory/rules/` oder — nach zweitem Auftreten — als Fix in `tools/*.py`
bzw. `AGENTS.md`, nie als Handkorrektur an einem `dbt/`-Modell.

Substanz/Entscheidungen: [docs/adr/0001-deterministik-first.md](docs/adr/0001-deterministik-first.md) — lies das zuerst, es ist die Kondensation
einer längeren Architekturdiskussion.

## Was bewiesen werden soll

Nicht „Qwen kann migrieren", sondern eine Ablation über drei Konfigurationen
auf derselben Objektmenge:

| Setup | Erwartung |
|---|---|
| A: LLM only | Baseline, ~30–50 % First-Pass |
| B: + Feedback-Loop (Gates) | höher, aber konstante Iterationszahl |
| C: + persistentes Regelgedächtnis | Iterationen/Objekt sinken über Zeit |

Kennzahlen: Autonomierate, First-Pass-Yield, Ø Iterationen/Objekt über
Zeit, Datenäquivalenz-Quote, Token-Kosten/Objekt — plus der Triage-Anteil
A/B/C selbst als eigene Kernaussage („x % ist beweisbar deterministisch").

## Layout

```
agentic_migration/
├─ CLAUDE.md                 # diese Datei
├─ AGENTS.md                 # für Qwen — ≤ 60 Zeilen, hart begrenzt
├─ docs/
│  ├─ adr/0001-deterministik-first.md
│  └─ systemkontext.md       # fachlicher Originalkontext (Kopie aus without_macros/agentic)
├─ tools/
│  ├─ extract.py             # P0–P4: Platzhalter, GO-Split, Parse, Lineage, Transpile-Vorschlag
│  ├─ gate.sh                 # TODO Session 3: G0/G1, normalisierter Fehlerkanal
│  └─ compare.sh              # TODO Session 3: G2–G5, read-only für den Agenten
├─ memory/rules/              # Regelgedächtnis, schrumpft durch Promotion in Code
├─ skills/                    # je Datei ein Thema, ≤ 40 Zeilen, Retrieval per rg
├─ source_references/pd/      # reale T-SQL-Quellobjekte (Referenzverfahren BPS/PD)
│  ├─ pd_skripte/              # Migrationsziele (14 Kennzahl-/Load-Skripte)
│  └─ ddl/                     # autoritatives Original-Schema (Bestand-Layer)
├─ reports/                   # generiert: lineage.jsonl, triage.md — nicht committen als Wahrheit, nur als Zwischenstand
├─ dbt/                       # Build-Ergebnis, entsteht erst ab Session 3 (Scaffold)
├─ ledger.jsonl               # append-only, 1 Zeile/Versuch
└─ Makefile
```

Quelle der `source_references/pd/`-Objekte und der Schema-Namenskonvention
(`sourcesys__verfahren__db__schema_verarbeitungsmonat`, hier
`sqlserver__bps__dbo__con_pd_<YYYYMM>`): `without_macros/agentic/` — dort
existiert bereits ein älterer, LLM-lastiger Migrationsversuch für dasselbe
Verfahren. Dieses Repo ersetzt ihn nicht, sondern testet einen anderen
Zuschnitt (Deterministik zuerst). Domänenwissen (Schema-Konvention,
bekannte Exasol-Fallstricke) ist wiederverwendbar, der alte Skill-/Prompt-
Ansatz nicht.

## Sessionfolge (ein Pass pro Session, mit echtem Testlauf)

1. **`tools/extract.py` + Triage-Report** ← aktuelle Session. Ergebnis:
   Tabelle „x Skripte, y Statements, Verteilung A/B/C". Sagt, ob der PoC
   trägt, bevor ein Token in Qwen investiert wird.
2. DAG-Kreuzprüfung entfällt hier bewusst — keine separate
   Ablaufsteuerungs-Tabelle vorhanden/nötig, Reihenfolge ergibt sich aus
   der AST-Lineage selbst (siehe ADR).
3. Gates + Makefile: `sqlfluff --dialect exasol`, `dbt parse`, `dbt run`
   gegen Ephemeral-Schema, `compare.sh`. Fehlerkanal auf eine Zeile
   normalisiert (`E EXA-0002 stmt=12 col=BA_SCHL rule=case-folding`).
4. `AGENTS.md` + `skills/` aus den echten Gate-Ausgaben ableiten, nicht aus
   Vermutung.
5. Übergabe an Qwen: OpenCode gegen das Repo als Working Directory, ein
   Objekt = ein Branch = ein Commit.

## Betriebsregeln

- Der Harness gehört nicht dem Agenten: `tools/compare.sh`,
  `source_references/`, `ledger.jsonl` sind für Qwen laut `AGENTS.md`
  tabu — nach jedem Qwen-Lauf `git diff` auf genau diese Pfade prüfen.
- Ein Objekt = ein Commit. `git log` ist das Rohprotokoll, `ledger.jsonl`
  nur die Auswertungsschicht darüber.
- Python bleibt schmal (~200 Zeilen Zielgröße für `extract.py`); Ledger-
  Update und Hash-Vergleich sind die einzigen größeren Python-Blöcke.
  Orchestrierung sonst über Makefile/Bash + einen bestehenden CLI-Agenten
  (OpenCode), kein eigenes Framework.
