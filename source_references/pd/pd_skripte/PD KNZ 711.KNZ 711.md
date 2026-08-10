# Fachnotiz — PD KNZ 711.KNZ 711.sql (→ tf_pd_knz_711)

## vor/nach P51 (Schnittstellenversion, April 2015)
Zwei komplett unterschiedliche Berechnungswege für denselben Zeitraum,
per `UNION ALL` zusammengeführt: vor P51 liest `mon_id` direkt aus
`pd_zeit_von`, nach P51 aus `mon_id_load_decr` (s. Fachnotiz zu
`PD LOAD.Bestandsuebernahme.md` — die "-1"-Regel). Kein Fehler, zwei
echte, historisch gewachsene Zweige. Grenze: `'201503'`/`'201504'`,
hartcodiert im Original, nicht ableiten.

## pd_anz_eingae (nach P51)
`SUM(CASE WHEN mon_id_eing = mon_id_load_decr THEN 1 ELSE 0 END)` —
`mon_id_eing` kommt aus einem JOIN gegen die Kalendertages-Dimension
(`tf_pd_fa.sql`/`NEO_org_Zuordnung.sql`: `pd_dat_eing = tag_dat`). Der
Vergleich ist im Original ein naiver Gleichheitsvergleich ohne
Datums-Trunkierung — funktioniert im T-SQL, weil dortige `DATE`-Spalten
nie einen Zeitanteil führen. In Exasol/aus CSV-Import hat `pd_dat_eing`
oft einen Zeitanteil, `tag_dat` nie — ohne Trunkierung matcht der JOIN
praktisch nie (verifiziert: 499/500 NULL). Das ist eine reale
Cross-System-Falle, keine erfundene Fachlogik, wenn man sie trunkiert.
