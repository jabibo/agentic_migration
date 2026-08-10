# Fachnotiz — PD KNZ 711.KNZ 711.sql (tf_pd_knz_711)

## vor/nach P51 (Schnittstellenversion, April 2015)
Zwei komplett unterschiedliche Berechnungswege für denselben
Kennzahlentyp, per UNION ALL zusammengeführt: vor P51 wird `mon_id`
direkt aus `pd_zeit_von` abgeleitet, nach P51 aus `mon_id_load_decr`
(s. Fachnotiz zu `PD LOAD.Bestandsuebernahme.sql`, "-1"-Regel). Kein
Fehler, sondern zwei historisch gewachsene Zweige nebeneinander. Die
Grenze (`201503`/`201504`) ist hartcodiert.

## pd_anz_eingae (nach P51)
Zählt Zeilen, bei denen `mon_id_eing` gleich `mon_id_load_decr` ist.
`mon_id_eing` kommt aus einem Abgleich mit der Kalendertages-Dimension
(`pd_dat_eing = tag_dat`, s. `tf_pd_fa`). Im Ursprungssystem
funktioniert dieser einfache Gleichheitsvergleich, weil dortige
Datumsspalten nie einen Zeitanteil führen. Wer diese Daten aus einer
anderen Quelle neu einliest (z.B. per CSV-Import mit Zeitstempel),
sollte damit rechnen, dass derselbe Vergleich dann fast nie mehr
zutrifft, weil ein Zeitanteil dazukommt, den es im Original nie gab.
