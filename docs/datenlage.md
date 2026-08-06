# Datenlage — Herkunft, Inventar, was daraus folgt

Zusammenfassung aus `without_macros/agentic/` (Schwester-Repo, älterer
LLM-lastiger Migrationsversuch für dasselbe Verfahren) plus Bestandsaufnahme
der Test-/Referenzdaten, die inzwischen direkt in diesem Repo liegen
(`data/`, `learning/` — per Verzeichnis-Merge, nicht von mir angelegt).
Fachliches Schichtmodell/DB-Mapping: [systemkontext.md](systemkontext.md) —
hier nur, was **neu** ist: das Datenbestand-Inventar und was daraus für
Session 3 (Gates) folgt.

## 1. Datenbestand-Inventar

| Ort | Inhalt | Rolle |
|---|---|---|
| `data/pd/*.csv` | Delta-Importe: `dbo__bi_delta_{azt,bl,fa,fc,ls}_<YYYYMM>_<timestamp>.csv`, 3 Monate (202312, 202401, 202402) | Quelle für **DATA**-Schicht (`con_pd_data.bi_delta_*`) |
| `learning/pd/dimensions/*.parquet` | ~29 Dimensions-Snapshots (`dbo__vd_as_*`, `dbo__td_ueb_kalender_tag`) | **DIM**-Schicht (`con_bio_dim`), „als gegeben angesehen" |
| `learning/pd/referenz/<YYYYMM>/fct_pd_knz_*.parquet` | Erwartete Fakt-Ergebnisse je Kennzahl, 4 Monate (202312–202403) | **Ground Truth für G3** (Datenäquivalenz) |
| `learning/pd/pd_skripte/`, `learning/pd/ddl/` | Duplikat von `source_references/pd/` | keine Handlung — bereits im Repo |
| `learning/pd/pd_skripte_excluded/` | 2 Skripte, **nie** in `source_dir` | siehe 1.3 |
| `learning/pd/pd_star_schema.mmd` | Ziel-Sternschema: 8 Fakten × 14 Dimensionen | Referenz für Modellierung |
| `learning/pd/project_exasol-vormonat-bestand.md` | Bekannte Lücke im alten `dbt/` | siehe 1.4 |

### 1.1 Delta-CSVs — Struktur und eine Lücke

Beispiel `dbo__bi_delta_fc_202312_...csv` (501 Zeilen): Spalten sind exakt
die T-SQL-Feldnamen (`pd_auftr_id, pd_fehl_typ, ..., mon_id, bi_timestamp`)
— 1:1 ladbar, keine Transformation vor dem Import nötig.

**Lücke:** `learning/pd/referenz/` hat Erwartungswerte für **202403**, aber
`data/pd/` hat **keinen** Delta-Import für 202403. Der Monat lässt sich also
noch nicht end-to-end testen (Bestand käme nur aus Fortschreibung, ohne
neuen Delta) — vor Nutzung in Gates klären, ob das gewollt ist oder ein
fehlender Export.

### 1.2 Dimensionen — maskiert, Struktur real

`dbo__vd_as_pd_Geschlecht.parquet` (6 Zeilen) zeigt: Text-Label sind über
NATO-Alphabet-Codewörter anonymisiert (`sex_bez_lang` = „oscar-papa-xray"
statt Klartext), IDs/Struktur/Spalten sind unverändert real (`sex_id`,
`sex_ba_schl`, ...). Konsequenz für G3: **Label-Vergleiche sind sinnlos,
Schema/Keys/Aggregate/Rowcounts sind es nicht.**

### 1.3 Zwei verschiedene „Ausschluss"-Kategorien — nicht verwechseln

- **`pd_skripte_excluded/`** (`usp_pd_knz_init.sql`, `PD Knz Init.sql"):
  vom Prozess her **nie** migrierbar, bewusst außerhalb `source_dir`
  gehalten. Andere Kategorie als:
- **KNZ 721** (mein `excluded` in `reports/triage.md`): Skript **liegt im
  Quellverzeichnis**, ist aber vollständig auskommentiert (Fundstelle
  historisch bestätigt in `knowledge/procedures/pd/kennzahlen.md` →
  „Deliberate exclusions" — dort ausdrücklich als Warnung dokumentiert,
  weil ein früherer Agent-Lauf den auskommentierten Code fälschlich als
  aktive Quelle gelesen hat). Mein automatischer
  `all_commented`-Check in `tools/extract.py` trifft exakt diesen Fall —
  **externe Bestätigung, nicht nur meine eigene Heuristik.**

### 1.4 Bekannte Architektur-Lücke: Vormonat-Union

`learning/pd/project_exasol-vormonat-bestand.md` (Format wie eine Claude-
Memory-Notiz, `metadata.type: project`) dokumentiert einen Fehler im alten
`dbt/`: `tf_deltant_pd_fc` soll `con_pd_dwh_vormonat` (Bestand bis M-1)
**union** aktueller `bi_delta_fc` **WHERE NOT IN** Vormonat sein (Idempotenz-
Wächter) — tatsächlich liest die alte Implementierung einfach **alle**
`bi_delta_fc`-Zeilen, was im Testsystem nur zufällig funktioniert, weil dort
alle Monate gleichzeitig geladen sind. **Für diesen Harness relevant:** Der
Bestand-Layer (Klasse C, `PD LOAD.Bestandsuebernahme.sql`) muss dieses
Muster korrekt nachbilden — genau die Art Regel, die ins Regelgedächtnis
(`memory/rules/`) gehört, sobald ein Gate sie aufdeckt, nicht nur ins
Prompt-Gedächtnis.

## 2. Externe Bestätigung der Session-1-Triage

`learning/pd/dbt-remigration-2026-07.md` dokumentiert ein Konvergenz-
Experiment (17.07.2026): komplette Neu-Migration aus `source_references/`
gegen den kuratierten `dbt/`-Stand verglichen — **keine kritischen
Abweichungen** bei allen 8 Kennzahlen (Bestand-Merge und Calc-Logik
äquivalent). Das Objekt-zu-Layer-Mapping aus diesem Experiment deckt sich
mit meiner Triage:

| Objekt(e) | Experiment-Layer | Meine Triage (Session 1) |
|---|---|---|
| `PD LOAD.Bestandsuebernahme.sql` | Bestand | **C** (cursor+kontrollfluss) |
| `PD KNZ INIT.unplausibler Fallabschluss`, `NEO_org_Zuordnung` | Calc | **A** |
| `PD KNZ INIT.vd_pd_KalenderMonat` | Calc (Orchestrierung) | **C** (nur EXEC) |
| `PD KNZ 701–711` (ohne 721) | Facts | **A**(711) / **B**(701,702,705,706,708,709) / **C**(703) |
| `PD KNZ 721` | — | **excluded** |

Zwei unabhängige Quellen (mein deterministischer Parse vs. ein früherer
vollständiger LLM-Remigrationslauf) kommen auf dieselbe Objekt-Einteilung —
das stützt die Triage-Methodik selbst, nicht nur das Ergebnis.

## 3. Konsequenzen für den Harness

1. **`CLAUDE.md`-Layout ergänzen** um `data/` und `learning/` (bisher nicht
   im dokumentierten Baum — nachgezogen).
2. **Session 3 (Gates) hat jetzt eine Datengrundlage**, die vorher offen
   war: Dimensionen ladbar via `exapump` (Muster:
   `without_macros/agentic/skills/loading/exapump-load-sources.md`,
   Profil `napc`), G3-Vergleich hat echte Erwartungswerte
   (`learning/pd/referenz/`) statt nur Schema-Struktur-Checks.
3. **Vor Session 3 klären:** 202403-Delta-Lücke (1.1), und ob
   `learning/pd/dimensions/` + `learning/pd/referenz/` ins Repo committet
   werden (aktuell `?? ` bei `git status` — weder getrackt noch
   `.gitignore`d) oder bewusst lokal/außerhalb Git bleiben (Parquet-Binärdaten
   in Git sind meist die falsche Wahl — eher exapump-Ladepfad + `.gitignore`).
