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

**Nicht selbst behoben** — das wäre Handmigration an einem Klasse-C-
Objekt, dieselbe Grenze wie immer. Offen für nächste Entscheidung:
Qwen mit genau diesem Befund erneut ansetzen (Folge-Iteration auf
demselben Branch/Objekt), oder als bekannte Grenze so stehen lassen und
später mit G3 verifizieren.

## Branch-Status

`qwen/bestand-fc-fa-azt`, 1 Commit, **noch nicht nach `main` gemerged** —
bewusst offen gelassen bis zur Entscheidung über die Akkumulations-Lücke.
