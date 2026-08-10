# Fachnotiz — PD KNZ 702.KNZ 702.sql (tf_pd_knz_702)

## ~17 hartcodierte 0-Spalten
`GLZ_NETTO_in_Wochen`, `sm_10_days`..`sm_50_days`,
`bg_15_days`..`bg_45_days` usw. stehen seit einem Hotfix vom
26.02.2015 ("Schema MSTR-Projekt muss noch angepasst werden") fest
auf `0` — obwohl die Bucketing-Logik für benachbarte Tagesgrenzen
(`btw_31_to_50_days`, `bg_50_days`, `sm_11_days`, `bg_10_days`) direkt
daneben echt berechnet wird. Das sieht aus wie eine unvollständige
Implementierung, die sich naheliegend "vervollständigen" ließe — ist
aber ein zehn Jahre alter, offenbar nie aufgegriffener Zwischenstand.
Wer das anfasst, sollte wissen, dass die 0-Werte Absicht sind, kein
Auftrag zum Nachrüsten.

## Historische Sonderfälle im Kommentarkopf
Der Header erwähnt mehrere frühere Sonderbehandlungen (z.B. BM 201312,
BM 201412), die im aktiven SQL selbst nicht mehr als Verzweigung
auftauchen (anders als bei KNZ 703) — reine Entstehungsgeschichte.
