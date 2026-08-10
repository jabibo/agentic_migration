# Fachnotiz — PD KNZ 706.KNZ 706.sql (→ tf_pd_knz_706)

Keine zusätzliche Fachlogik über die Standardmuster hinaus (s. Fachnotiz
zu KNZ 705): Berichtszeitraum-Formel + Sentinel-Fallback für vier
Dimensionsspalten (`pd_tae_beauf`, `pd_veranl_stl`, `pd_abschl_art`,
`pd_abschl_grund`). Alle vier Sentinels unterschiedlich (`9999`,
`99999`, `99999`, `0`) — exakt wie im Original übernehmen, nicht
vereinheitlichen.
