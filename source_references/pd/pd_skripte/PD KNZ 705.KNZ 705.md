# Fachnotiz — PD KNZ 705.KNZ 705.sql (→ tf_pd_knz_705)

Keine zusätzliche Fachlogik über die Standardmuster hinaus: Berichts-
zeitraum-Formel (`uf_ueb_kalender_Kennzahl`, s. `docs/systemkontext.md`
und `dbt/macros/kennzahl_zeitraum.sql`) und Sentinel-Fallback für
ungültige Dimensionswerte (`UPDATE ... SET x = <sentinel> WHERE x NOT
IN (SELECT ... FROM vd_...)`). Beides Typ-1/mechanisch, keine
Fachentscheidung nötig.
