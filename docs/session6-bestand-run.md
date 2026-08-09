# Session 6 — Qwen-Lauf auf dem Bestand-Objekt (Klasse C)

`PD LOAD.Bestandsuebernahme.sql` (385 Zeilen, Cursor + dynamisches SQL,
Klasse C). Branch `qwen/bestand-fc-fa-azt`. 66 Schritte, $0.36 — deutlich
günstiger und kürzer als KNZ 705 (158 Schritte, $1,70), obwohl das
Quellobjekt größer und komplexer ist.

## Was gut lief

- **Korrekte Dekomposition**: 6 Modelle aus einem Objekt (`tf_deltant_pd_{fc,fa,azt}`
  + die drei „_k"-Kappungsviews) — nicht vorgegeben, selbst erkannt.
- **Exasol-Fallstricke selbst gefunden und behoben**: `SMALLDATETIME`
  existiert nicht, Case-Sensitivity bei unquotierten vs. CSV-erzeugten
  Spaltennamen (Anführungszeichen nötig) — beides ohne Skill-Eintrag dazu,
  per Fehlermeldung und Vergleich mit bestehenden Modellen selbst gelöst.
- **Grenze respektiert**: erkannte die 2 verbleibenden Gate-Fehler als
  Klasse-A-Zuständigkeit („nicht mein Problem laut AGENTS.md") und hat
  `tools/` nicht angefasst — **unabhängig verifiziert**: `git diff`
  gegen alle geschützten Pfade leer.
- **Einen echten Design-Konflikt in meiner eigenen Pipeline gefunden**:
  `render_dbt_models.py` schreibt `dbt/models/sources.yml` bei jedem Lauf
  komplett neu (nur aus Klasse-A-Referenzen) — eigene `source()`-Einträge
  wären beim nächsten `make gate` wieder weg. Qwen hat das erkannt und
  bewusst `{{ schema_for('data') }}.bi_delta_fc` direkt referenziert statt
  `source()` zu nutzen, statt sources.yml zu manipulieren oder sich zu
  blockieren. Pragmatisch richtig, aber **Konvention weicht von Klasse A
  ab** (die nutzt konsequent `source()`) — noch nicht behoben, s. u.
- **Eigene, saubere Makro-Erweiterung**: `prev_month_schema.sql`,
  konsistent zu `schema_for()`/`month_add()` — korrekt mit `git add -f`
  committet (sonst durch `.gitignore` verloren gegangen).
- **Ledger/Memory-Nutzung korrekt**: `memory/rules/pd_load_vormonat.md`
  geschrieben, dokumentiert die bewusste Vereinfachung.

**Unabhängig verifiziert** (nicht nur Commit-Message geglaubt):
`bash tools/gate.sh 202312` erneut selbst ausgeführt → **6/12 Modelle
erfolgreich** bestätigt (Qwens 6 Bestand-Modelle alle grün), 2 Fehler
(unverändert Klasse A, jetzt aber präziser: `REG.GST_BA_SCHL`/
`KAL_EING.TAG_DAT not found` — fehlende KNZ-Dimensionsviews, nicht mehr
die vorher fehlende `tf_deltant_pd_fc_k` selbst, die Qwen gerade gebaut
hat), 4 übersprungen.

## Wichtiger, ungelöster Fund: keine echte Mehrmonats-Akkumulation

Die 6 Modelle lesen **ausschließlich** aus `{{ schema_for('data') }}`
(aktueller Monat) — **keine** `materialized='incremental'`, kein
`is_incremental()`, kein UNION mit `prev_month_schema()` trotz des dafür
gebauten Makros. `memory/rules/pd_load_vormonat.md` beschreibt das als
„Schritt 1 (Vormonat) für Testlauf übersprungen, fehlende Testdaten" —
das **untertreibt die Lücke**: es fehlt nicht nur Testdaten, es fehlt die
Akkumulations-**Logik** selbst. Selbst mit vorhandenem Vormonat-Schema
würde das aktuelle Modell ihn nicht einbeziehen.

Konsequenz: `tf_deltant_pd_fc` enthält pro Verarbeitungsmonat nur die
Zeilen **dieses** Monats, nicht den historisch akkumulierten Bestand, den
der Objektname verspricht. Läuft (G0/G1 grün), ist aber vermutlich
**inhaltlich nicht das, was „Bestand" bedeuten soll** — genau die Klasse
Fehler, die G3 (Datenäquivalenz, noch nicht gebaut) auffangen sollte,
und die die ADR explizit als Risiko benennt: ein Objekt, das grün läuft
aber still falsche Daten produziert, ist schlechter als eines, das sich
als `blocked` meldet. Qwen hat es nicht als `blocked` markiert, sondern
als erledigt committet.

## Follow-up-Runde (nach Nutzer-Hinweis: Vormonat-Logik gilt nur DWH-Layer)

Nutzerkorrektur: laut `systemkontext.md` akkumuliert **nur** die DWH-Schicht
(DATA+Vormonat); CALC/FACT/KNZ lesen danach nur noch aus DWH, ohne selbst
zu akkumulieren. Dabei aufgefallen: **Qwen hat `docs/systemkontext.md` im
ersten Lauf nie gelesen** — kein Pointer dorthin in `AGENTS.md`. Behoben
(`48aa7fb`) — echte Lücke im Harness, nicht nur im Objekt.

Zweiter Qwen-Lauf (27 Schritte, $0,14, `4fdb333`), Ergebnis **unabhängig
verifiziert**:
- **Schema-Rolle korrigiert**: `USE con_pd_dwh` im Quellskript → alle 6
  Modelle von `calc/` nach `dwh/` verschoben, `schema_for('dwh')`.
- **Akkumulationslücke ehrlich präzisiert, nicht implementiert**: Regel
  jetzt klar „Modelle liefern nur das Delta, nicht den Gesamtbestand" statt
  der vorherigen Untertreibung. Bewusst nicht nachgebaut — 202312 ist
  unser Genesis-Monat im Testkorpus (keine echten Vormonatsdaten zum
  Testen vorhanden), ein UNION mit einer nicht-existenten Tabelle wäre
  nicht verifizierbar gewesen. `prev_month_schema()`-Makro steht für
  später bereit, referenziert in der Regel.

## Dritter, eigener Fund beim Nachprüfen: Case-Folding-Inkonsistenz

Nach der Schema-Korrektur lief `make gate` erneut — neuer Fehler:
`F.PD_DNST_NR not found`. Ursache: meine eigene `render_dbt_models.py`
(Klasse A) erzeugt **unquotierte** Bezeichner (Exasol faltet sie auf
Großschreibung), Qwens Klasse-C-Modelle **quoted-lowercase** (aus T-SQLs
`[bracket]`-Bezeichnern 1:1 übernommen). An der Klasse-A/C-Grenze
(mein `tt_deltant_pd_fc_org` referenziert Qwens `tf_deltant_pd_fc_k`)
brach das. **Selbst behoben** (`bc60291`, `identify=True` in sqlglots
Serialisierung) — das ist Bauherr-Tooling, nicht Qwens Aufgabe.

Nach dem Fix: Fehler ist jetzt `dst.ba_schl not found` — das ist die in
`systemkontext.md` B.6 von Anfang an dokumentierte Lücke
(`con_pd_knz.vd_pd_dienststelle` liegt nicht in verwertbarem Format vor,
POC-Ersatz `vd_as_pd_dienststelle.csv` noch nicht geladen). **Keine
weitere Code-Ursache mehr** — echte, erwartete Datenlücke, kein Bug.

## Endstand

```
G0: 11/11 Modelle syntaktisch OK
G1: 6/11 erfolgreich (alle 6 Klasse-C-Bestand-Modelle grün), 2 Fehler
    (beide: fehlende con_pd_knz-Dimensionsdaten, dokumentierte POC-Lücke),
    3 uebersprungen
```

Chronologie der Fehlerkette über beide Sessions: fehlende Tabelle (Klasse
C nicht migriert) → fehlender Alias (mein Bug) → fehlende Schema-Rolle
(Qwens Bug, korrigiert) → Case-Folding (mein Bug) → echte Datenlücke
(dokumentiert, kein Bug). Jede Schicht musste erst behoben werden, um die
nächste sichtbar zu machen.

## Branch-Status

`qwen/bestand-fc-fa-azt`, 5 Commits (2× Qwen, 3× Bauherr-Fixes), nach
`main` gemerged.

## Nachtrag: `vd_pd_dienststelle` geladen — nächste Fehlerschicht sichtbar

`vd_as_pd_dienststelle.csv` (aus `without_macros/agentic`) als Parquet
konvertiert, `con_pd_knz.vd_pd_dienststelle` als Pass-Through-View gebaut
(`tools/load_reference_data.sh` → `load_knz_views()`). G1: 6/12 → **7/12**
(`tt_deltant_pd_fc_org` läuft jetzt durch).

**Neuer, echter Datenfehler dahinter**, kein Lade-/Infrastrukturproblem
mehr: `tf_pd_fa`/`tf_pd_fc` scheitern an
`data exception - Invalid numeric format; Format String: 'YYYYMMDD'`.
Wahrscheinliche Ursache: Qwens Bestand-Modelle mappen
`"mon_id" AS "bi_load_date"` — `mon_id` ist ein INTEGER (z. B. `202312`),
kein Datum. Klasse-A-Code (`TO_CHAR(bi_load_date, 'YYYYMMDD')`) erwartet
aber ein echtes Datum/Timestamp. Genau die Vereinfachung, die schon beim
ersten Bestand-Lauf als Verdacht notiert wurde (oben, „`mon_id`/
`bi_timestamp` statt echter Datei-Metadaten") — jetzt mit konkretem
Fehlerbeleg. **Nicht selbst gefixt** — Qwens Klasse-C-Inhalt.

## Nachtrag: alle drei Dimensionslücken geschlossen

`vd_as_bps_Region` und `td_ueb_kalender_Tag` waren als Rohdimension
bereits über `load_dimensions` geladen (`learning/pd/dimensions/`) — es
fehlten nur die erwarteten Pass-Through-Views (`load_knz_views()`
erweitert). Zielschema aus dem Quellskript abgeleitet, nicht geraten:
`vd_as_bps_Region` → KNZ (expliziter `<DBNAME_PD_KNZ>`-Platzhalter im
Quellskript), `td_ueb_kalender_Tag` → CALC (ambient aus `USE con_pd_calc`).

**Ergebnis: G1 unverändert 7/12** — die beiden verbleibenden Fehler
(`tf_pd_fa`, `tf_pd_fc`) hingen schon vorher am `bi_load_date`-Typfehler,
nicht an fehlenden Dimensionen. Damit ist die Fehlerkette jetzt bis zum
letzten bekannten Fund durchgearbeitet: **alle drei Dimensionslücken
(systemkontext.md B.6) geschlossen, ein einziger, bereits präzise
diagnostizierter Fund bleibt übrig** — `bi_load_date`/`mon_id`-Typmismatch
in Qwens Bestand-Modellen. Nächster Schritt: Qwen damit erneut ansetzen.
