# Fachnotiz — PD KNZ 709.uf_pd_Behinderung_Key.sql

T-SQL-Skalarfunktion, verboten im generierten dbt-SQL (s. `AGENTS.md`
"Verbotene Konstrukte"). Muss an jeder Aufrufstelle als CASE-Ausdruck
inline übersetzt werden (4 Aufrufe in `KNZ 709.KNZ 709.sql`).

Die Lookup-Tabelle selbst ist vollständig explizit im Quellcode — kein
zusätzlicher Kontext nötig, nur sorgfältig übertragen: Normalisierung
auf 13 bekannte Codes (sonst `99999`), danach Mapping auf Bitwerte
`1,2,4,8,...,4096` (Zweierpotenzen, keine Lücke). `0` ist sowohl
"keine Behinderung" als auch der Rückfall bei unbekanntem Normalwert —
im Original so, nicht als Bug behandeln.
