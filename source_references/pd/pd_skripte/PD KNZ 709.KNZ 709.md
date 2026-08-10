# Fachnotiz — PD KNZ 709.KNZ 709.sql (tf_pd_knz_709)

## pd_beh_key: Bitflag-Kodierung
Vier Aufrufe von `uf_pd_Behinderung_Key()` (s. eigene Fachnotiz), über
Bit-OR zusammengeführt, später über zwölf einzelne Bit-Abfragen wieder
in `pd_beh1`..`pd_beh12` entpackt. Nichts Kompliziertes an sich, aber
durch die schiere Zahl der Wiederholungen leicht zu verzählen — beim
Nachvollziehen lieber Zeile für Zeile prüfen als überfliegen.

## pd_rks_id — bekannte, ungeklärte Abweichung
Zum Zeitpunkt dieser Notiz zeigt ein Testlauf eine Abweichung bei
`pd_rks_id` und `pd_abschl_art`. Die Alt-ID-Konsolidierung
`52002→52003` selbst (s. Fachnotiz zu `tf_pd_fc`) ist nachweislich
korrekt und wirksam — das ist nicht die Ursache. Beobachtet: ein Teil
der Zeilen landet im "nicht in Dimension gefunden"-Sentinel (`99999`),
wo eigentlich `52003` erwartet würde. Ursache noch offen — möglicherweise
ein Problem im Dimensionsabgleich selbst oder in den zugrundeliegenden
Testdaten, nicht zwingend ein Fehler in dieser Logik hier.

## pd_geschlecht-Default
`ISNULL(pd_geschlecht, 29004)` — `29004` ist der seit P61 gültige
"unbekannt"-Wert (s. Fachnotiz zu `tf_pd_fc`), nicht der ältere Wert
`29003`.
