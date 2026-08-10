# Fachnotiz — PD KNZ 703.KNZ 703.sql (→ tf_pd_knz_703)

Bisher nie migriert (weder Klasse A noch je an Qwen gegeben).

## Toter Sonderfall: IF Berichtsmonat = 201412
Der komplette `IF`-Zweig (dynamisches Cross-DB-`sp_executesql`, kopiert
die komplette Vormonatstabelle) ist eine **einmalige historische
Migration** vom Dezember 2014. Für jeden real testbaren
Verarbeitungsmonat (2023+) ist dieser Zweig permanent tot — er wird nie
erreicht, `Berichtsmonat` wird nie wieder `201412` sein. Das korrekt als
irrelevant zu erkennen (statt zu versuchen, das dynamische Cross-DB-SQL
zu transpilieren) ist der eigentliche Punkt hier, keine Übersetzungs-
aufgabe. Migriere nur den `ELSE`-Zweig.

## Bewusste ID-Lücke: 1, 2, 3, 5 (nicht 4)
Die drei Bucketing-CASE-Ausdrücke (`gez_id_lz`, `lpe_id_lz`, `lap_id_lz`)
mappen Wertebereiche auf `1/2/3/5` — die `4` fehlt absichtlich. Nicht
"korrigieren".

## Totes, auskommentiertes Alternativ-Mapping
Zeilen ~154-164 zeigen ein abgeschaltetes, alternatives Intervall-Schema
für `pd_lpe`/`pd_lap` ("eigenes Laufzeitintervall zunächst
deaktiviert"). Bleibt inaktiv, nicht reaktivieren.

## Struktur: Wide-to-Long-Pivot per UNION ALL
Der finale `tf_pd_knz_703` entsteht aus drei UNION-ALL-Zweigen
(gez-Daten, lpe-Daten, lap-Daten) derselben Basistabelle
`tt_pd_knz_703_all`, mit `NULL`/`99999`-Sentinels für die jeweils
"anderen" Maße. Kein Bug, gewollte Struktur.

## pd_vmz_bereinigt
Hartcodiert `0` seit "Hotfix, Schema MSTR-Projekt muss noch angepasst
werden" (26.02.2015) — absichtlicher Platzhalter, nicht vervollständigen.
