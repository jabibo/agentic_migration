# Fachnotiz — PD KNZ INIT.unplausibler Fallabschluss.sql (Basistabelle tf_pd_fc)

Diese Tabelle ist die gemeinsame Grundlage für praktisch alle
Kennzahlen. Sie enthält die dichteste Fachlogik im ganzen Verfahren.

## pd_tae_beauf / pd_tae_durch — MySkills-Sonderfall
Bei Wert `2020` ("MySkills") wird statt des Rohwerts `pd_bkb_id`
verwendet — die feinere Detailsausprägung, weil die Zieldimension die
genauere Untergliederung erwartet. Eine bewusste Ersetzung, kein
Kopierfehler.

## pd_veranl_stl / pd_rks_id — Alt-ID-Konsolidierung
`23018→23015`, `23017→23016`, `52002→52003`: alte IDs wurden
irgendwann auf neue zusammengeführt. Keine Begründung im Code
hinterlegt — einfach als gegeben hinnehmen.

## pd_geschlecht — zeitabhängige Regel seit P61 (April 2016)
Vor der Schnittstellenversion P61 wird `29003` auf `29004` gehoben (s.
`docs/systemkontext.md` zu Schnittstellenversionen). Die Bedingung
dafür lautet im Original `(LEFT(CONVERT(VARCHAR(8), bi_load_date,
112), 6)) - 1 < 201604` — das ist reine Ganzzahl-Subtraktion auf
einem YYYYMM-Wert, kein echter Kalender-Rückschritt (bei Januar würde
das z.B. `202300` statt des korrekten Vormonats ergeben). Vermutlich
ein Bug aus der Entstehungszeit, der seither einfach weiterlebt — wer
diese Stelle anfasst, sollte wissen, dass hier keine korrekte
Monatsarithmetik steckt, bevor er sich über das Ergebnis wundert.

## pd_abschl_art — Override bei fehlendem pd_tae_durch
Wenn `pd_abschl_art = 10010` und gleichzeitig `pd_tae_durch` NULL/0
ist, wird auf `10012` umgesetzt — ein Sonderfall, der nur bei dieser
Kombination greift.
