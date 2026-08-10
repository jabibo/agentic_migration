# Fachnotiz — PD KNZ 702.KNZ 702.sql (→ tf_pd_knz_702)

## ~17 hartcodierte 0-Platzhalter-Spalten
`GLZ_NETTO_in_Wochen`, `sm_10_days`..`sm_50_days`,
`bg_15_days`..`bg_45_days` usw. sind seit "Hotfix MR 26.02.2015, Schema
MSTR-Projekt muss noch angepasst werden" fest auf `0` gesetzt — die
Bucketing-Logik existiert an anderer Stelle bereits erkennbar
(`btw_31_to_50_days`, `bg_50_days`, `sm_11_days`, `bg_10_days` sind
echt berechnet), das lädt dazu ein, das fehlende Muster für die
0-Spalten zu "vervollständigen". **Nicht tun** — das wäre erfundene
Fachlogik. Die Referenz erwartet exakt 15 Spalten mit den 0-Werten
so, wie sie im Original stehen.

## Zeitraum-Sonderfälle im Kommentarheader
Mehrere historische Sonderbehandlungen (BM 201312, BM 201412) werden
im Header erwähnt, sind aber im aktiven SQL selbst nicht mehr als
Verzweigung sichtbar (anders als bei KNZ 703) — nur Dokumentation
vergangener Migrationsschritte, nicht als aktive Logik zu übersetzen.
