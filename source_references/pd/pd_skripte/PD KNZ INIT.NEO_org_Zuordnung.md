# Fachnotiz — PD KNZ INIT.NEO_org_Zuordnung.sql (tt_deltant_pd_fc_org, tf_pd_fa)

## tf_pd_fa: mon_id_load_decr
Wendet die "-1"-Regel an (s. Fachnotiz zu `PD LOAD.Bestandsuebernahme.
sql`, Lademonat vs. Inhaltsmonat) — setzt voraus, dass `bi_load_date`
ein korrekt geparster Lade-Zeitstempel ist.

## org_id-Auflösung über zwei Dimensionen
Neben der Standard-Dienststellen-Zuordnung kommt eine zweite Zuordnung
über `vd_as_bps_Region` dazu (seit Schnittstellenversion P92,
TRAEGERNUMMER→gst_id), gefiltert auf `gst_guelt_bis_dat IS NULL` — das
übliche Muster für "aktuell gültiger Datensatz" in einer
historisierten Dimension.

## Historische NEO-Wellen (W2/W3)
Der Dateikopf erwähnt größere Umbauten der Zuordnungstabellen
(AFM047655/047669, org_ids alt→NEO_W3). Im aktuell aktiven Code ist
davon nichts mehr direkt sichtbar — laut Änderungshistorie wieder
zurückgebaut. Die Erwähnung im Kopf ist reine Entstehungsgeschichte,
keine versteckte, noch wirksame Logik.
