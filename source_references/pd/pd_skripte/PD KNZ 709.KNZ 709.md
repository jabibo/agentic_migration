# Fachnotiz — PD KNZ 709.KNZ 709.sql (→ tf_pd_knz_709)

## pd_beh_key: Bitflag-Kodierung
Vier Aufrufe von `uf_pd_Behinderung_Key()` (s. eigene Fachnotiz),
per `|` (Bit-OR) zusammengeführt, danach über 12 einzelne `& <2^n>`-
Bedingungen wieder in `pd_beh1`..`pd_beh12` entpackt. Mechanisch
korrekt übersetzbar, aber lang und fehleranfällig durch schiere Menge,
nicht durch Komplexität — sorgfältig gegenprüfen, nicht auf einen Blick
verifizieren.

## pd_rks_id — bekannte, ungeklärte Restabweichung
`pd_rks_id`/`pd_abschl_art` zeigen in G3 eine Abweichung. Die
Wert-Konsolidierung `52002→52003` selbst ist in `tf_pd_fc` (s. dessen
Fachnotiz) korrekt und laufzeit-verifiziert wirksam — das ist **nicht**
die Ursache. Beobachtet: ~92 Zeilen landen live im `99999`-Sentinel
("nicht in Dimension gefunden"), wo die Referenz `52003` erwartet.
Ursache offen (Stand: `docs/ablation-metrics.md`) — möglicherweise ein
Problem im `NOT IN`-Dimensionscheck selbst oder der geladenen
Testdimension, nicht notwendigerweise ein Modellfehler.

## pd_geschlecht-Default
`ISNULL(pd_geschlecht, 29004)` — `29004` ist der post-P61-"unbekannt"-
Wert (s. `tf_pd_fc`-Fachnotiz, P61-Geschlechts-Remap). Bewusst dieser
Wert, nicht `29003`.
