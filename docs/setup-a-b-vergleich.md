---
description: Vorbereitung des Setup-A/B/C-Ablationsvergleichs (CLAUDE.md-Tabelle) — Mechanismus, Objektauswahl, Ablaufprotokoll. Stand Session 15, noch kein Testlauf ausgeführt.
status: vorbereitet, wartet auf Freigabe zum Start
---

# Setup-A/B/C-Vergleich — Vorbereitung (Session 15)

**Wichtig zur Begriffskollision:** „Setup A/B/C" (dieses Dokument, aus
`CLAUDE.md`s Ablationstabelle) und „Klasse A/B/C" (Triage-Einordnung der
T-SQL-Objekte, `reports/triage.md`) sind zwei unabhängige Bedeutungen
derselben Buchstaben. Im Folgenden immer explizit „Setup X" bzw. „Klasse X"
geschrieben, nie nackt „A"/„B"/„C".

## Ausgangslage

Alle bisherigen Qwen-Läufe (Sessions 5–14, `docs/ablation-metrics.md`)
liefen technisch unter **Setup C** (Gates + Regelgedächtnis + `skills/`) —
der `migrator`-Agent hatte immer vollen `memory/rules/`-Zugriff. Ein
sauberer Setup-A/B-Vergleich fehlte bisher komplett; `docs/
ablation-metrics.md`s Interpretation vermerkt das explizit als offene
Lücke.

## Was genau isoliert wird

| Setup | Task-Material | Gate-Feedback | `memory/rules/` |
|---|---|---|---|
| A (LLM only) | Quell-DDL + Fachnotiz + Vorgänger-Interfaces + `docs/systemkontext.md` + `skills/*.md` | **nein** — ein Schuss, kein `make gate`/`compare` | nein |
| B (+ Feedback-Loop) | dieselben | **ja** — `make gate`/`make compare`, bis 3 Iterationen | nein |
| C (+ Regelgedächtnis) | dieselben | ja | **ja** — genau das, was bisher lief |

`skills/*.md` bleibt in allen drei Setups konstant verfügbar: es ist
Bauherr-kuratiertes, gegebenes Fachwissen (Exasol-Dialekt-Fallstricke,
Berichtszeitraum-Formel), keine von Qwen selbst akkumulierte Erfahrung —
anders als `memory/rules/`, das Qwen objektübergreifend selbst schreibt.
Diese Grenzziehung ist die Voraussetzung dafür, dass A→B ausschließlich
den Feedback-Loop misst und B→C ausschließlich das Regelgedächtnis.

## Mechanismus (gebaut, empirisch verifiziert)

- `AGENTS_A.md` / `AGENTS_B.md` — abgespeckte Aufgabenbeschreibung, siehe
  Dateien selbst. `AGENTS.md` (Setup C) unverändert.
- `opencode.jsonc`: zwei neue Agenten `migrator_a`/`migrator_b` neben dem
  bestehenden `migrator` (Setup C). Jeder Agent hat jetzt ein eigenes
  `"prompt": "{file:./AGENTS_*.md}"` statt eines globalen `"instructions"`-
  Schlüssels — verifiziert mit `opencode debug agent migrator_b`: der
  aufgelöste Prompt enthält ausschließlich `AGENTS_B.md`, keine Vermischung
  mit `AGENTS.md`.
  - `migrator_a`: `"bash": {"*": "deny"}` (kein Gate, kein Debugging, keine
    Iteration möglich), `memory/rules/**` und `ledger.jsonl` editiert-deny.
  - `migrator_b`: identisches Bash-Allowlist wie `migrator` (Gate/Compare/
    `exapump_select.sh`/Commit), aber `memory/rules/**` editiert-deny plus
    Redirect-Guard `*>*memory/rules/*` (Bypass-Schutz, analog zu den
    anderen geschützten Pfaden).
- `tools/ablation_trial_setup.sh <trial-name> <a|b> <model-file>...` —
  legt einen isolierten `git worktree --detach` auf `main` an, entfernt
  darin nur das Zielmodell (geteilte Infrastruktur/Makros bleiben
  konstant — bewusste Entscheidung, s. Skript-Docstring: Zeitreise zu
  einem historischen Vor-Objekt-Commit wäre bei mit anderen Objekten
  verflochtener Infra wie `behinderung_bit()` fragiler), leert lokal
  `memory/rules/*.md` (nur Arbeitskopie des Trial-Worktrees, nie
  committet). Smoke-getestet (`smoketest-a`, Session 15): `main` bleibt
  nachweislich unverändert, Cleanup per `git worktree remove --force`.

## Objektauswahl (Vorschlag, noch nicht final freigegeben)

Drei bereits unter Setup C gelöste Objekte, quer über den Schwierigkeitsgrad
— Referenzdaten/Ground-Truth existiert bereits, Qwen hat aber (frische
`opencode run`-Session, kein `-s`-Fortsetzen) keine Erinnerung an vorige
Läufe:

| Objekt | Klasse | Setup-C-Historie | Warum |
|---|---|---|---|
| KNZ 703 | C | 2 Runden, First-Try-Erfolg, nie zuvor angefasst | Baseline/„einfacher" Fall |
| KNZ 706 | B | mehrere echte Content-Bugs (Case-Mismatch, fehlende Spalte, LEFT-JOIN-Normalisierung) über 4+1 Runden | mittlerer Schwierigkeitsgrad, mehrere reale Fehlerklassen |
| KNZ 709 | B | mit Abstand meiste Runden (8+), brauchte Fachnotiz-Hilfe | oberes Ende, testet ob Setup A/B ganz ohne Regelgedächtnis überhaupt konvergiert |

Zielmodell-Dateien für `ablation_trial_setup.sh`:
- 703: `dbt/models/fact/tf_pd_knz_703.sql`
- 706: `dbt/models/fact/tf_pd_knz_706.sql`
- 709: `dbt/models/fact/tf_pd_knz_709.sql` `dbt/models/calc/tt_pd_knz_709.sql`

## Ablaufprotokoll pro Objekt × Setup

1. `tools/ablation_trial_setup.sh <objekt>-<setup> <a|b> <model-file>...`
2. Im Trial-Worktree: `opencode run --agent migrator_<setup> "<Aufgabentext:
   Quell-Datei(en) aus source_references/pd/pd_skripte/, Zielpfad(e)>"`
   — Setup A: genau ein Aufruf, keine Fortsetzung. Setup B: bis zu 3
   Iterationen (`-s <sessionID>`), Abbruch bei `blocked` oder nach 3 ohne
   Fortschritt, exakt wie `AGENTS_B.md`s Abbruchkriterium.
3. Bauherr-Verifikation **unabhängig von Qwens Selbstbericht** (dieselbe
   Disziplin wie bei jedem realen Objekt in diesem Projekt): eigener
   `make gate MONAT=<YYYYMM>` + `bash tools/compare.sh <YYYYMM>`-Lauf im
   Trial-Worktree.
4. Metriken festhalten: G0/G1 First-Pass (ja/nein), Iterationen bis
   G0-G5 grün (oder „nie"), finaler G2/G3-Status, Kosten (`opencode
   stats`/Session-Export).
5. `git worktree remove --force ../ablation-trials/<objekt>-<setup>` —
   nie nach `main` mergen, reine Vergleichsdaten.
6. Ergebnisse in `docs/ablation-metrics.md` als neue Vergleichstabelle
   (Setup A vs. B vs. C, je Objekt) ergänzen.

## Kostenschätzung

Bisherige Setup-C-Kosten pro Objekt: $0,08–$2,03 (Median ≈ $0,18,
`docs/ablation-metrics.md`). 3 Objekte × 2 neue Setups × bis zu 3
Iterationen (nur Setup B iteriert) ≈ vergleichbare Größenordnung wie ein
einzelnes bereits gelaufenes Objekt-Batch — grob geschätzt $2–6 gesamt,
abhängig davon, wie schnell Setup A/B ohne Regelgedächtnis in dieselben
Fehler laufen, die Setup C schon kannte.

## Offene Entscheidung

Objektauswahl und Startzeitpunkt sind **noch nicht freigegeben** — dieses
Dokument beschreibt den vorbereiteten, verifizierten Mechanismus, keinen
laufenden Versuch. Nächster Schritt liegt beim Nutzer.

## Related
`CLAUDE.md` (Ablationsdesign, ursprüngliche Setup-Tabelle) ·
`docs/ablation-metrics.md` (bisherige Setup-C-Ergebnisse) · `AGENTS.md` ·
`AGENTS_A.md` · `AGENTS_B.md` · `opencode.jsonc` ·
`tools/ablation_trial_setup.sh`
