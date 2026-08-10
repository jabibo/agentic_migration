# Session 13 — Bestand-Objekte über KNZ 711 validiert

Fortsetzung von Session 12 (`docs/session12-mon_id-skill-korrektur.md`),
nach dem Branch-Konsolidierungs-Merge nach `main`. Auftrag: die
Bestand-Objekte (Klasse C, `PD LOAD.Bestandsuebernahme.sql`: fc/fa/azt)
angehen — seit Session 6/9 als "grün aber inhaltlich ungeprüft" (fc) bzw.
"endgültig gescheitert" (Multi-File-Adoption von fa/azt) dokumentiert.

## Ausgangslage: keine direkte Prüfmöglichkeit

`tf_deltant_pd_fa`/`tf_deltant_pd_azt` (und ihre `_k`-Varianten) liefen
G0/G1 grün, hatten aber nie eine Referenzdatei und keinen Downstream-
Konsumenten unter den 6 bereits validierten Kennzahl-Objekten (die
nutzen alle nur die fc-Kette über `tf_pd_fc`). Einziger echter Konsument:
`tf_pd_knz_711`, referenziert `tf_pd_fa` — aber dieses Modell existierte
gar nicht als Datei, nur `tf_pd_knz_711_vorp51.sql`/`_nachp51.sql`
(Klasse A, autogeneriert).

## Fund 1: UNION-Statement wurde beim Parsen zerschnitten

Quell-Skript (`PD KNZ 711.KNZ 711.sql`, Zeilen 92-97) hat einen dritten,
finalen Schritt: `SELECT * INTO tf_pd_knz_711 FROM tf_pd_knz_711_vorP51
UNION ALL SELECT * FROM tf_pd_knz_711_nachP51` — die zusammenführende
Ziel-Tabelle selbst. `extract.py`s `split_statements()` behandelt jedes
zeilenanfangs-`SELECT` als neue Statement-Grenze, auch eine UNION-
Fortsetzung — der rechte UNION-Zweig ging beim Parsen komplett verloren,
`sqlglot` bekam nur die linke Haelfte. Lineage zeigte konsequent
`"kind": "Union", "target": null` fuer dieses Statement. Fix: `after_set_op`-
Tracking analog zum bestehenden `after_update`-Muster in
`split_statements()`, unterdrückt den Schnitt am nächsten `SELECT` nach
`UNION`/`INTERSECT`/`EXCEPT`.

## Fund 2: render_dbt_models.py kannte nur exp.Select, nie exp.Union

Selbst mit korrekt aufgelöstem `target` hätte weder der Matching-Loop in
`main()` noch `render_select_body()`s INTO-Entfernung das Union-Statement
gefunden/korrekt gerendert (die `INTO`-Klausel sitzt bei UNION nur auf
dem linkesten SELECT). Fix: Walk durch verschachtelte Union-Knoten bis
zum linkesten SELECT, an beiden Stellen.

## Fund 3: UNION-Typkonflikt — month_add() gab VARCHAR zurück

Nach Fund 1+2 rendert `tf_pd_knz_711.sql`, aber G1 schlägt fehl:
"datatypes are not compatible for Union". `mon_id` ist in `vorp51`
`DECIMAL(18,0)` (expliziter `CAST(...AS INT)` im Quell-SQL), in `nachp51`
`VARCHAR(6)` (unverändert aus `month_add()`s `TO_CHAR`-Rückgabe). T-SQL
toleriert das implizit, Exasol nicht. `month_add()` (nur eine Verwendung
im ganzen Projekt: `tf_pd_fa.mon_id_load_decr`) gibt jetzt `CAST(...AS
INT)` zurück — konsistent mit jeder anderen `mon_id`-artigen Spalte im
Projekt, kein Blast Radius.

Nach Fund 1-3: `tf_pd_knz_711` G0/G1 grün, G2/G3 zeigt **6 von 7 Spalten
korrekt** — bestätigt indirekt, dass die Bestand-fa-Ladekette selbst
größtenteils korrekt ist.

## Fund 4: Kalenderdimension-JOIN ohne Datums-Trunkierung

Verbleibende Abweichung: `pd_anz_eingae` (live durchgängig `0`, Referenz
erwartet 335×`0`/165×`1`). Zunächst vermutet: fehlende Klasse-C-
Berechnungslogik (Frage an Nutzer: "sollte evtl. Qwen die Funktion
stellen?"). Bei Prüfung widerlegt: die echte "P51"-Berechnung
(`SUM(CASE WHEN mon_id_eing = mon_id_load_decr THEN 1 ELSE 0 END)`)
steckt in `nachp51.sql` bereits korrekt — kein fehlender Qwen-Job.

Tatsächliche Ursache: `tf_pd_fa.sql` (Klasse A) joint `pd_dat_eing`
(voller TIMESTAMP mit Uhrzeitanteil aus dem CSV-Import, z. B.
`2023-10-30T00:46:00`) gegen `td_ueb_kalender_Tag.tag_dat` (immer
Mitternacht) mit exakter Gleichheit — matcht praktisch nie (direkt via
`exapump_select.sh` verifiziert: `mon_id_eing` war für 499 von 500 Zeilen
`NULL`). Das Original-T-SQL macht denselben naiven Vergleich ohne
Trunkierung, aber T-SQL-`DATE`-Spalten führen dort nie einen Zeitanteil —
die Referenz beweist einen gemeinten Datumsvergleich.

**Nutzerentscheidung** (da an der Grenze zu "erfundener Fachlogik", CAST
steht nicht wörtlich im Quell-Skript): als Cross-System-Typkorrektur
behandeln, nicht an Qwen weitergeben — gleiche Kategorie wie die übrigen
Exasol-Dialekt-Fixes dieser Session. Fix: `render_select_body()` erkennt
generisch jede `= <alias>.tag_dat`-Bedingung (die einzige
Kalendertages-Dimension im Projekt, kein Objektname im Code) und
trunkiert die Gegenseite per `CAST(...AS DATE)`.

## Ergebnis

`tf_pd_knz_711`: **G0-G3 + G5 vollständig grün** (500 Zeilen, 7 Spalten,
exakt die Referenz). Bestätigt die komplette Bestand-fa-Ladekette
(`tf_deltant_pd_fa`/`tf_deltant_pd_fa_k`, Session 6) als inhaltlich
korrekt — zum ersten Mal überhaupt gate-verifizierbar, seit Session 6 nie
geprüft, weil der einzige Downstream-Konsument nie existierte. Keine
Regression bei den 6 bereits validierten Kennzahl-Objekten.

## Nachtrag: azt-Kette — Direktprüfung statt G2/G3, strukturell nicht lösbar

Auf Nutzeranfrage die `azt`-Kette (`tf_deltant_pd_azt`/`_k`) geprüft, in
der Annahme, ein KNZ-711-artiger versteckter Konsument könnte dort
ebenfalls fehlen. Ergebnis: **es gibt keinen** — anders als `fa`.
`grep` über alle 15 Quellskripte und `reports/lineage.jsonl` zeigt:
`tf_deltant_pd_azt` wird ausschließlich in seinem eigenen Ladeschritt
(`PD LOAD.Bestandsuebernahme.sql`) referenziert, nirgends sonst, auch
nicht als Quelle in der Lineage. Kein Downstream-Objekt existiert im
aktuellen Korpus, das eine Referenzdatei und damit eine Gate-Prüfung
ermöglichen würde.

Stattdessen eine Direktprüfung (Zeilenzahl + Stichprobe gegen die rohe
CSV, analog zur Methodik bei `fa`s `pd_dat_eing`-Fund, aber ohne eine
Referenz zum Abgleichen): 500 CSV-Datenzeilen = 500 geladene Zeilen,
3 Beispielzeilen wertgenau identisch, `tf_deltant_pd_azt_k` (Kappung)
ebenfalls 500 Zeilen (Lade-Zeitstempel liegt weit im Kappungsfenster).
Reine 1:1-Passthrough-Struktur ohne abgeleitete Spalten, die einen Bug
verstecken könnten. Kein Hinweis auf einen Fehler — aber das ist eine
Direktprüfung, kein Gate-Beweis, und bleibt es auch, solange kein
Objekt migriert wird, das `azt` tatsächlich konsumiert. Bewusst nicht
weiterverfolgt (Scope-Erweiterung, keine Fortsetzung der aktuellen
Prüfung) -- `ablation-metrics.md` entsprechend präzise formuliert
(nicht mit `fa`s Gate-bewiesenem Status gleichgesetzt).

## Related
`docs/session12-mon_id-skill-korrektur.md` · `docs/session6-bestand-run.md` ·
`docs/session9-multifile-loading.md` · `docs/ablation-metrics.md`
