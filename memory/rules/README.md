# Regelgedächtnis

Leer bis Session 3/5 (erst nutzbar, sobald Gates existieren und Qwen echte
Fehler produziert — siehe [../../CLAUDE.md](../../CLAUDE.md) Sessionfolge).

Konvention (Details: [docs/adr/0001-deterministik-first.md](../../docs/adr/0001-deterministik-first.md)):

- Eine Regel = eine Datei, `<fehlercode-oder-thema>.md`, **max. 5 Zeilen**.
- Generalisiert, nicht objektspezifisch — „#temp-Tabelle → CTE oder
  ref()-Modell", nicht „KNZ 703 Zeile 45 fixen".
- **Tritt eine Regel ein zweites Mal auf → Promotion in Code** (sqlglot-
  Transform in `tools/`, dbt-Makro, oder P0-Rewrite in `tools/extract.py`)
  und die Datei wird gelöscht. Regelgedächtnis bleibt dadurch konstant
  klein — ein wachsendes Markdown ist bei schmalem Kontextfenster (Qwen)
  der sichere Tod.
- Qwen schreibt hier nach jedem selbst behobenen Gate-Fehler; darf sonst
  nichts außerhalb `dbt/` und der eigenen Branch ändern (`AGENTS.md`).
