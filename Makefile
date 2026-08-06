.PHONY: extract transpile gate compare report clean

PY ?= python3

# P0-P4, kein LLM, kein DB-Roundtrip. Ergebnis: reports/triage.md (+.json, lineage.jsonl).
extract:
	$(PY) tools/extract.py

# Session 3 (siehe CLAUDE.md, Sessionfolge): Klasse-B/C-Objekte an Qwen/OpenCode
# uebergeben. Existiert noch nicht -- Klasse A ist bereits per extract.py (P4)
# deterministisch vorgeschlagen, braucht kein LLM.
transpile:
	@echo "transpile: noch nicht implementiert (Session 3, siehe CLAUDE.md)" >&2
	@exit 1

# Session 3: sqlfluff --dialect exasol (G0), dbt parse/run gegen Ephemeral-Schema (G1),
# Fehlerkanal auf eine Zeile normalisiert.
gate:
	@echo "gate: noch nicht implementiert (Session 3, siehe CLAUDE.md)" >&2
	@exit 1

# Session 3: G2-G5 (Schema-/Datenaequivalenz, Tests, Idempotenz). Read-only fuer
# den Agenten -- AGENTS.md verbietet Qwen den Aufruf zur Selbstoptimierung.
compare:
	@echo "compare: noch nicht implementiert (Session 3, siehe CLAUDE.md)" >&2
	@exit 1

report: extract
	@cat reports/triage.md

clean:
	rm -rf reports/*.jsonl reports/*.json reports/*.md
