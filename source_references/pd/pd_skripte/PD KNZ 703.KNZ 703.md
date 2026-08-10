# Fachnotiz — PD KNZ 703.KNZ 703.sql (tf_pd_knz_703)

## Toter Sonderfall: IF Berichtsmonat = 201412
Der komplette IF-Zweig (dynamisches Cross-DB-SQL, kopiert die
komplette Vormonatstabelle) war eine einmalige Übergangslösung für
Dezember 2014 — als mitten im Monat eine Strukturänderung eingeführt
und die Dezemberdaten kurzerhand durch Novemberdaten ersetzt wurden.
Für jeden Monat danach ist dieser Zweig irrelevant, er wird nie wieder
erreicht. Wer diese Datei liest, kann sich auf den `ELSE`-Zweig
konzentrieren — der `IF`-Zweig ist historisches Gedächtnis, keine
aktive Logik.

## Bewusste Lücke: 1, 2, 3, 5 (keine 4)
Die drei Bucketing-Ausdrücke (`gez_id_lz`, `lpe_id_lz`, `lap_id_lz`)
mappen Wertebereiche auf `1/2/3/5` — die `4` fehlt, und das ist so
gewollt, nicht übersehen.

## Auskommentiertes Alternativ-Mapping
Zeilen ~154-164 zeigen ein früher verworfenes, alternatives
Intervall-Schema für `pd_lpe`/`pd_lap` ("eigenes Laufzeitintervall
zunächst deaktiviert") — ein Blick in die Entstehungsgeschichte,
keine tot geglaubte, aber eigentlich noch gültige Logik.

## Struktur: drei Sichten auf dieselben Daten
Der finale `tf_pd_knz_703` entsteht aus drei UNION-ALL-Zweigen
derselben Basistabelle (gez-, lpe-, lap-Daten), mit `NULL`/`99999` als
Platzhalter für die jeweils anderen beiden Maße — ein Long-Format-
Pivot, keine Datenverdopplung.

## pd_vmz_bereinigt
Fest auf `0` gesetzt seit einem Hotfix vom 26.02.2015 ("Schema
MSTR-Projekt muss noch angepasst werden") — ein seit zehn Jahren
offener Punkt, der offenbar nie wieder aufgegriffen wurde.
