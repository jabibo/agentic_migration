# Fachnotiz — PD KNZ 701.KNZ 701.sql (tf_pd_knz_701)

## count_anz_beh — NULL zählt nicht mit
`pd_beh_1..4 = 11040` ("keine Behinderung") wird vorab auf `NULL`
gesetzt, danach gezählt — `COUNT()` überspringt `NULL`-Werte von sich
aus. Der Trick ersetzt eine explizite Ausschluss-Bedingung durch ein
Aggregat-Verhalten; wer das nachbaut, sollte sicherstellen, dass die
verwendete `COUNT`-Funktion sich genauso verhält.

## pt_mit_faktor
Eine vollständig explizite, kommentierte Gewichtung (0/9/18/27 Punkte
je nach Terminanzahl) — keine versteckte Regel.

## pd_traeger_id = 99999
Hartcodierte Konstante, im Original kommentiert mit "FIX, MSTR
verweist noch auf das 2014 ausgebaute Attribut!" — ein bewusster
Platzhalter für ein Feld, das anderswo schon lange nicht mehr existiert.
