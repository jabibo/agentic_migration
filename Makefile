.PHONY: extract transpile gate compare report clean load-data load-dims load-delta render-a

PY ?= python3
MONAT ?= 202312

# P0-P4, kein LLM, kein DB-Roundtrip. Ergebnis: reports/triage.md (+.json, lineage.jsonl).
extract:
	$(PY) tools/extract.py

# Test-/Referenzdaten nach Exasol (exapump, Profil napc), siehe docs/datenlage.md.
# MONAT=<YYYYMM> ueberschreiben, Default 202312. Voraussetzung fuer G1b/G3.
load-data:
	bash tools/load_reference_data.sh $(MONAT)

load-dims:
	bash tools/load_reference_data.sh $(MONAT) --dims-only

load-delta:
	bash tools/load_reference_data.sh $(MONAT) --delta-only

# Materialisiert alle Klasse-A-Objekte als dbt-Modelle (vollstaendig generisch,
# kein Objektname im Code -- siehe tools/render_dbt_models.py Docstring).
render-a: extract
	$(PY) tools/render_dbt_models.py

# Klasse-B/C-Objekte an Qwen/OpenCode uebergeben. Noch nicht implementiert
# (Session 4/5, siehe CLAUDE.md) -- Klasse A ist bereits per render-a
# deterministisch erledigt, braucht kein LLM.
transpile:
	@echo "transpile: noch nicht implementiert (Session 4, siehe CLAUDE.md)" >&2
	@exit 1

# G0 (sqlfluff --dialect exasol auf kompiliertes SQL) + G1 (dbt run gegen
# Schema-je-Monat). Fehlerkanal auf eine Zeile normalisiert. MONAT=<YYYYMM>.
gate: render-a
	bash tools/gate.sh $(MONAT)

# Session 3: G2-G5 (Schema-/Datenaequivalenz, Tests, Idempotenz). Read-only fuer
# den Agenten -- AGENTS.md verbietet Qwen den Aufruf zur Selbstoptimierung.
compare:
	@echo "compare: noch nicht implementiert (Session 3, siehe CLAUDE.md)" >&2
	@exit 1

report: extract
	@cat reports/triage.md

clean:
	rm -rf reports/*.jsonl reports/*.json reports/*.md
