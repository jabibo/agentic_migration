# Fachnotiz — PD KNZ 701.KNZ 701.sql (→ tf_pd_knz_701)

## count_anz_beh — NULL zählt nicht
`pd_beh_1..4 = 11040` ("keine Behinderung") wird vorab auf `NULL`
gesetzt, danach per `COUNT()` gezählt — `COUNT()` überspringt `NULL`
standardmäßig. Der Trick ersetzt eine explizite Ausschluss-Bedingung.
Beim Übersetzen sicherstellen, dass die Ziel-Aggregatfunktion dasselbe
NULL-Verhalten hat (bei Exasol der Fall).

## pt_mit_faktor
Vollständig explizite, kommentierte Gewichtung (0/9/18/27 Punkte je
Terminanzahl) — keine versteckte Regel, nur sorgfältig übertragen.

## pd_traeger_id = 99999 (hartcodierte Konstante)
Kommentar im Original: "FIX, MSTR verweist noch auf das 2014
ausgebaute Attribut!" — absichtlicher Platzhalter, keine echte
Herleitung nötig oder gewünscht.
