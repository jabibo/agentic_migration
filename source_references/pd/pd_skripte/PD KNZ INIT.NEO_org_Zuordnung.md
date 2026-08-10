# Fachnotiz — PD KNZ INIT.NEO_org_Zuordnung.sql (→ tt_deltant_pd_fc_org, tf_pd_fa)

## tf_pd_fa: mon_id_load_decr
`uf_ueb_kalender_MonatAdd(LEFT(CONVERT(VARCHAR(8), bi_load_date, 112),
6), -1)` — die "-1"-Regel (s. `PD LOAD.Bestandsuebernahme.md`:
Lademonat vs. Inhaltsmonat). `bi_load_date` muss dafür ein korrekt
geparster Lade-Zeitstempel sein, kein zusammengesetzter String.

## org_id-Auflösung, zwei JOINs
`vd_pd_dienststelle` (Standard) und zusätzlich `vd_as_bps_Region`
(P92, TRAEGERNUMMER→gst_id-Umwandlung) mit
`reg.gst_guelt_bis_dat IS NULL` — klassisches "aktueller Datensatz"-
Muster einer historisierten Dimension (SCD), kein Bug, keine
zusätzliche Filterbedingung nötig.

## Historische NEO-Wellen (W2/W3) — im aktiven Code nicht mehr sichtbar
Der Datei-Header erwähnt AFM047655/047669 (Reduktion/Umbau der
Zuordnungstabellen für org_ids alt→NEO_W3). Im aktuellen (aktiven)
SQL ist davon nichts mehr direkt sichtbar — laut Kommentarhistorie
zurückgebaut. Nicht versuchen, wellenspezifische Logik zu rekonstruieren,
die im Code gar nicht mehr existiert.
