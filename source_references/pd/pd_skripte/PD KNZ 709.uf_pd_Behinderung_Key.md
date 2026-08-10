# Fachnotiz — PD KNZ 709.uf_pd_Behinderung_Key.sql

Eine kleine Hilfsfunktion, die einen Behinderungs-Schlüssel
normalisiert und auf einen Bitwert abbildet. Die Lookup-Tabelle ist
vollständig explizit im Code — kein zusätzliches Fachwissen nötig,
nur sorgfältig lesen: Normalisierung auf 13 bekannte Codes (sonst
`99999`), danach Mapping auf Zweierpotenzen (1, 2, 4, 8 ... 4096,
keine Lücke). Die `0` steht sowohl für "keine Behinderung" als auch
für den Rückfall bei unbekanntem Normalwert — das ist im Original so
angelegt, keine Ungenauigkeit.
