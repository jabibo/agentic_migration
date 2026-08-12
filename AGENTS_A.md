# AGENTS_A.md — Setup A (LLM only), Ablationsvergleich

**Nur für den Setup-A/B/C-Vergleich (`docs/setup-a-b-vergleich.md`), nicht
für reguläre Objektmigration — dafür gilt `AGENTS.md`.** Du bekommst genau
einen Versuch, keine Rückmeldung, kein Gate, keine Regelgedächtnis-Dateien.

## Aufgabe

Migriere das genannte T-SQL-Objekt (Klasse B/C) 1:1 nach dbt-Exasol.
1:1-Migration, keine erfundene Fachlogik, Original-Objektnamen behalten.
Schema-Rolle (`schema_for('data'|'dwh'|'calc'|'fact'|'knz'|'dim'|'strg')`)
aus dem `USE <db>` am Skriptanfang und `docs/systemkontext.md` B.1/B.4
ableiten — nicht aus Ordnernamen bestehender Modelle raten.

Du bekommst genau: Quell-DDL (+ gleichnamige `.md`-Fachnotiz falls
vorhanden), direkte Vorgänger-Interfaces, `docs/systemkontext.md`.
**Keine `memory/rules/*.md`, kein Gate-Feedback** (Bash-Zugriff ist für
diesen Versuch vollständig gesperrt) — `skills/*.md` darfst du lesend
per `rg` konsultieren, das ist gegebenes Fachwissen, kein Regelgedächtnis.

Verbotene Konstrukte: `#temp`-Tabellen, T-SQL-Prozeduren, unquotierte
gemischte Groß-/Kleinschreibung ohne Case-Prüfung.

## Schreibzugriff

Schreibe genau eine Datei: `dbt/models/<rolle>/<name>.sql`. Sonst nichts —
kein `ledger.jsonl`, kein `memory/rules/`, kein Commit (wird extern
ausgewertet). `tools/`, `source_references/`, `skills/`, `docs/`,
`reports/`, `AGENTS*.md`, `CLAUDE.md`, `opencode.jsonc` bleiben
schreibgeschützt (technisch durchgesetzt, kein Konventionsvertrauen).

Kein Gate verfügbar in diesem Setup — schreibe nach bestem Wissen, ohne
Selbstkorrektur-Möglichkeit. Das ist beabsichtigt (Baseline-Messung).
