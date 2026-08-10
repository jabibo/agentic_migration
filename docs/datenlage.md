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
| `learning/pd/pd_skripte/`, `learning/pd/ddl/` | war inhaltsgleiches Duplikat von `source_references/pd/` | **gelöscht** (Session 14) — technisch für Qwen schreibbar (`opencode.jsonc` deckte `learning/` nirgends ab, anders als das geschützte Original), kein bekannter Ausnutzungsfall, aber unnötige Lücke; Pfade zusätzlich in `opencode.jsonc`s Deny-Liste, falls je wieder angelegt |
| `learning/pd/pd_skripte_excluded/` | 6 Skripte, **nie** in `source_dir` | siehe 1.3; 4 davon (Kalenderfunktionen, OLAP-Views) sind Referenzquellen für Session 8, nicht Migrationsziele |
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
3. **Erledigt:** `data/` und `learning/` sind jetzt `.gitignore`d (nicht
   committet). Ladepfad: [tools/load_reference_data.sh](../tools/load_reference_data.sh)
   (`make load-data MONAT=<YYYYMM>`, exapump-Profil `napc`) — Schema-Konvention
   per [tools/lib/monatsschema.sh](../tools/lib/monatsschema.sh) (portiert aus
   `without_macros/agentic/scripts/lib/monatsschema.sh`, unverändert). Getestet
   für 202312 (25 Dimensions- + 5 Delta-Tabellen, Rowcounts stimmen: 500/500
   Zeilen `bi_delta_fc`) und 202401.
4. **Weiterhin offen:** 202403-Delta-Lücke (1.1) — vor Nutzung dieses Monats
   in Gates klären, ob Absicht oder fehlender Export.

## 4. Vier Architektur-Punkte aus Session 8 (Nutzer-Review)

Nutzer-Review der Pipeline-Architektur, mit realen Quellskripten belegt
(`learning/pd/pd_skripte_excluded/` — 4 neue Dateien: Kalenderfunktionen,
OLAP-View-Prozedur). Bewusst dokumentiert, nicht überall sofort
umgesetzt — s. jeweils „Konsequenz".

**1. CSV→DB-Laden ist mehrdateifähig, nicht single-file.** Laut `PD
Create Table.Template Tables.sql` (Datei nicht mehr im Repo verfügbar,
Inhalt hier aus der damaligen Sichtung zusammengefasst): `xp_dirtree`
listet alle Dateien im Import-Verzeichnis, ein Cursor iteriert über
**jede gefundene Datei** und legt pro Datei eine eigene, nach dem exakten
Dateinamen benannte Tabelle an, mit `NOT IN`-Check gegen bereits
eingefügte Schlüssel (erste Datei in Cursor-Reihenfolge gewinnt bei
Duplikat). `PD LOAD.Bestandsuebernahme.sql` (Schritt 2) liest aus genau
diesen dateispezifischen Tabellen, nicht aus einer festen `bi_delta_fc`.

**Nachträglich doch nachgebaut** (Session 9 — ursprüngliche Entscheidung
"nicht nachgebaut" revidiert, Nutzer: „ich bin mir nicht sicher ob wir
Punkt 1 nicht nachbauen müssen"): `tools/load_reference_data.sh`
`load_delta()` lädt seit Session 9 jede gefundene Delta-Datei **zusätzlich
zur** bisherigen festen Komfort-Tabelle (`bi_delta_<kuerzel>`) auch in
eine eigene, voll dateinamen-benannte Tabelle
(`bi_delta_<kuerzel>_<YYYYMM>_<timestamp>`) — nicht-brechend, Qwens
bestehende Klasse-C-Modelle referenzieren weiterhin die feste Tabelle.
Dbt-seitig: `dbt/macros/delta_multifile.sql` (`tools/render_scaffold.sh`)
— `discover_delta_files(kuerzel)` findet zur Laufzeit (`run_query()`
gegen `EXA_ALL_TABLES`) alle Datei-Tabellen eines Kürzels/Monats,
`delta_union_dedup(kuerzel, key_column)` unioniert sie und dedupliziert
per `ROW_NUMBER() PARTITION BY key_column ORDER BY <Dateireihenfolge>`
(erste Datei gewinnt, wie im Original-Cursor). **Laufzeit-verifiziert**
gegen den Ein-Datei-Testkorpus (202312, `bi_delta_fc`): `discover_delta_files`
findet genau 1 Tabelle, `delta_union_dedup` liefert 500/500 Zeilen,
alle Schlüssel eindeutig — exakt deckungsgleich mit der bisherigen
festen Tabelle (Non-Regression bestätigt, `make gate`/`make compare`
weiterhin G0 12/12, G1 12/12, G2+G3 exakt, G5 stabil).

**[Annahme, NICHT gegen G3 verifizierbar]:** Cursor-Reihenfolge =
alphabetische Sortierung der vollen Datei-Tabellennamen (der
Bereitstellungs-Timestamp im Dateinamen ist sortierbar, `YYYYMMDDHHMMSS`,
entspricht also zugleich der chronologischen Ankunftsreihenfolge). Unser
Testkorpus hat nur je eine Datei pro Kürzel/Monat — die Tie-Break-Regel
bei echten Duplikat-Schlüsseln über mehrere Dateien bleibt bis zu
echten Mehrdatei-Testdaten unverifiziert.

**Zwei laufzeit-verifizierte Exasol-Fallstricke** dabei gefunden (neu in
`skills/transpile/exasol-dialect-gotchas.md`): (a) unquotierte Identifier
dürfen in Exasol nicht mit `_` beginnen (`expecting IDENTIFIER_PART_`) —
betrifft sowohl Hilfsspalten als auch Modell-/Tabellennamen; (b) per
`exapump upload` geladene CSV-Spalten sind quotiert-kleingeschrieben,
Fremdschlüssel-Vergleiche in generiertem SQL müssen entsprechend
quotiert referenziert werden, sonst faltet Exasol auf Großschreibung und
findet die Spalte nicht.

**Offen für eine Qwen-Folgerunde:** `delta_union_dedup()` ist gebaute
Infrastruktur (Klasse A, von mir), aber noch **nicht** in einem
Klasse-C-Modell (Bestand) adoptiert — das darf ich nicht selbst tun
(Kernregel `CLAUDE.md`). Nächster Schritt: Prompt für Qwen, das
Bestand-Objekt auf den neuen Discovery-Pfad umzustellen, sobald
Mehrdatei-Testdaten vorliegen oder als vorbereitende Migration.

**2+3. Verarbeitungsmonat ≠ Berichtsmonat — mit echter Formel belegt.**
Eine Lieferung (Verarbeitungsmonat) kann mehrere Berichtsmonate enthalten;
Monatsfilter (`@von_mon_id`/`@bis_mon_id`) wirken ausschließlich auf den
Berichtsmonat. Vollständig aufgelöst: `skills/transpile/
kennzahl-berichtszeitraum.md`, `dbt/macros/kennzahl_zeitraum.sql`. War
zuvor eine `[Annahme]`, jetzt durch `learning/pd/pd_skripte_excluded/
UEB Kalender Dimensionen.td_ueb_kalender_KennzahlZeitraum.sql` belegt —
siehe `docs/session7-compare.md` für den Fund, der die Annahme widerlegt
hat.

**4. Teil-SQL-Klassifikation (Logging-/Drop-Prozeduren) vorab
entscheiden.** Boilerplate-Aufrufe wie `up_ueb_log_Meldung`,
`up_ueb_log_CreateTable`, `up_ueb_object_droptable/DropTable/
DropFunction`, `up_ueb_object_CreateView` sind nie migrationsrelevant —
reine Protokollierung/Aufräumarbeit der alten Ablaufsteuerung, nicht
Fachlogik. `tools/extract.py`/`render_dbt_models.py` behandeln das
bereits implizit richtig (`EXEC`-Aufrufe zählen nicht als Schreib-
Statement, siehe `WRITE_TYPES` in `extract.py`), aber nie explizit
benannt. **Konsequenz:** `skills/transpile/boilerplate-prozeduren.md`
als Referenzliste angelegt — für Qwen, damit es diese Aufrufe beim
Lesen eines neuen Quellskripts sofort als „ignorieren" erkennt, statt
jedes Mal neu zu bewerten.
