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
├─ opencode.jsonc             # Runner-Config: Agent "migrator", Permission-Gates, Modell
├─ docs/
│  ├─ adr/0001-deterministik-first.md
│  ├─ systemkontext.md       # fachlicher Originalkontext (Kopie aus without_macros/agentic)
│  └─ datenlage.md           # Datenbestand-Inventar + externe Bestätigung der Triage
├─ data/pd/*.csv              # Delta-Importe (DATA-Schicht), 3 Monate — s. docs/datenlage.md
├─ learning/pd/                # Dimensionen, Referenzwerte (G3), Star-Schema — s. docs/datenlage.md
├─ tools/
│  ├─ extract.py             # P0–P4: Platzhalter, GO-Split, Parse, Lineage, Transpile-Vorschlag
│  ├─ render_dbt_models.py    # Klasse A -> dbt/models/ (generisch, kein Objektname im Code)
│  ├─ render_scaffold.sh      # dbt/dbt_project.yml, profiles.yml, macros/ reproduzierbar
│  ├─ load_reference_data.sh  # Test-/Referenzdaten -> Exasol (exapump)
│  ├─ gate.sh                 # G0 (sqlfluff)/G1 (dbt run), normalisierter Fehlerkanal ✅
│  ├─ compare.sh              # G2-G5 gegen learning/pd/referenz/, read-only für den Agenten ✅
│  └─ compare_data.py          # G2 Schema + G3 Datenaequivalenz (Zeilen-Hash), von compare.sh genutzt
├─ memory/rules/              # Regelgedächtnis, schrumpft durch Promotion in Code
├─ skills/                    # je Datei ein Thema, ≤ 40 Zeilen, Retrieval per rg
│  └─ transpile/exasol-dialect-gotchas.md  # 3 laufzeit-verifizierte Faelle, s. docs/session3-gates.md
├─ source_references/pd/      # reale T-SQL-Quellobjekte (Referenzverfahren BPS/PD)
│  ├─ pd_skripte/              # Migrationsziele (14 Kennzahl-/Load-Skripte)
│  └─ ddl/                     # autoritatives Original-Schema (Bestand-Layer)
├─ reports/                   # generiert: lineage.jsonl, triage.md — nicht committen als Wahrheit, nur als Zwischenstand
├─ dbt/                       # Build-Ergebnis (tools/render_scaffold.sh + render_dbt_models.py), .gitignore'd
├─ ledger.jsonl               # append-only, 1 Zeile/Versuch — entsteht erst mit Qwens erstem Lauf (Session 5)
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

1. **`tools/extract.py` + Triage-Report** ✅. Ergebnis: A=20% B=40% C=33%
   excluded=6% (15 Objekte). Extern bestätigt, siehe `docs/datenlage.md`.
2. DAG-Kreuzprüfung entfällt bewusst — keine separate Ablaufsteuerungs-
   Tabelle nötig, Reihenfolge ergibt sich aus der AST-Lineage (ADR).
3. **Gates + Makefile** ✅ (`tools/gate.sh`, `make gate MONAT=<YYYYMM>`,
   Details/echte Laufergebnisse: `docs/session3-gates.md`).
3b. **`compare.sh` (G2–G5)** ✅ (`make compare MONAT=<YYYYMM>`, Details:
   `docs/session7-compare.md`). Findet beim ersten Lauf gegen echte
   Referenzdaten sofort einen inhaltlichen Fehler in `tf_pd_knz_705`
   (Klasse B, G0/G1 bis dahin „grün"): fehlende Spalte, 13 statt 20
   Zeilen — Ursache noch offen. Genau der Beweis, den G2-G5 liefern soll.
4. **`AGENTS.md` + `skills/`** ✅. Ledger-Schema in `AGENTS.md` definiert
   (existierte vorher nur als Wort, kein Format); dabei einen echten
   Widerspruch gefunden und behoben — `AGENTS.md` verlangte Ledger-
   Einträge bei Blockade, `opencode.jsonc` verweigerte aber Schreibzugriff
   auf `ledger.jsonl`. `skills/transpile/exasol-dialect-gotchas.md` aus
   den drei Session-3-Funden (nicht aus Vermutung).
5. **Übergabe an Qwen** ✅ (erstes Objekt: PD KNZ 705, Klasse B). Details,
   Kosten, Funde: `docs/session5-qwen-run.md`. Modell-Treffer vor dem
   eigentlichen Lauf verifiziert (`opencode export` → `modelID: qwen/
   qwen3.6-35b-a3b`) — der alte cline-Fehler (`<cline-default>`) wurde
   nicht wiederholt. Qwen hat einen echten Bug in `render_dbt_models.py`
   gefunden (Alias-Verlust beim Platzhalter-Ersetzen), korrekt als fremden
   Fehler gemeldet statt `tools/` anzufassen — behoben in `f0614a0`.
   `git diff` gegen alle geschützten Pfade war leer.

**Runner-Entscheidung (statt `cline`):** [opencode.jsonc](opencode.jsonc)
definiert den Agenten `migrator`. Grund für den Wechsel: OpenCodes
Permission-System (`agent.migrator.permission.edit`) erzwingt den
Read-only-Schutz technisch (Glob-Pattern, „letzte passende Regel
gewinnt") statt ihn nur als Konvention zu dokumentieren und per
`git diff` nachträglich zu prüfen — im alten `without_macros/agentic`-
Repo (cline) war das nur eine `AGENTS.md`-Regel.

**Weiterhin offen** (nicht blockierend, aber ungelöst):
- `permission.bash` steht auf `"ask"`, ist aber pfadunspezifisch — ein
  Bash-Aufruf könnte die `edit`-Sperre umgehen (z.B. `echo x > tools/y`).
  Im ersten Lauf nicht passiert (`git diff` leer), aber nicht durch das
  Tool selbst ausgeschlossen, nur durch den Nachcheck.
- Kein Prompt-Caching im ersten Lauf (`docs/session5-qwen-run.md`) — bei
  158 Schritten $1.70 für ein kleines Klasse-B-Objekt. Vor größeren
  Objekten (KNZ 709, 17 Statements) im Auge behalten.

## Betriebsregeln

- Der Harness gehört nicht dem Agenten: `tools/`, `source_references/`,
  `skills/`, `docs/`, `reports/` sind für Qwen technisch schreibgeschützt
  (`opencode.jsonc`), nicht nur Konvention. `ledger.jsonl` und
  `memory/rules/` sind bewusst die Ausnahme — Qwens eigenes Protokoll/
  Regelgedächtnis, kein Prüf-Orakel. Trotzdem nach jedem Qwen-Lauf
  `git diff` gegen die geschützten Pfade prüfen (Permission-Umgehung via
  Bash ist technisch nicht ausgeschlossen, nur erschwert).
- Ein Objekt = ein Commit. `git log` ist das Rohprotokoll, `ledger.jsonl`
  nur die Auswertungsschicht darüber.
- Python bleibt schmal (~200 Zeilen Zielgröße für `extract.py`); Ledger-
  Update und Hash-Vergleich sind die einzigen größeren Python-Blöcke.
  Orchestrierung sonst über Makefile/Bash + einen bestehenden CLI-Agenten
  (OpenCode), kein eigenes Framework.
