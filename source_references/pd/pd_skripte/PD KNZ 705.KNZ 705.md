# Fachnotiz — PD KNZ 705.KNZ 705.sql (tf_pd_knz_705)

Unauffällig — Standardmuster: eine Berichtszeitraum-Berechnung (s.
`docs/systemkontext.md`) und ein Sentinel-Fallback für ungültige
Dimensionswerte (`UPDATE ... SET x = <sentinel> WHERE x` nicht in der
gültigen Werteliste). Keine versteckte Fachlogik über diese beiden
Muster hinaus.
