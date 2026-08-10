# Fachnotiz — PD KNZ INIT.unplausibler Fallabschluss.sql (→ tf_pd_fc)

Basistabelle für praktisch alle Kennzahlen. Enthält die dichteste
Fachlogik im ganzen Korpus — bitte nicht als reines Passthrough lesen.

## pd_tae_beauf / pd_tae_durch — MySkills-Substitution
Bei Wert `2020` ("MySkills") wird `pd_bkb_id` statt des Rohwerts
verwendet (Detailsausprägung, weil die Zieldimension das so erwartet).
Kein Sonderfall am Rand, sondern eine echte Ersetzung — nicht als
Tippfehler oder redundant wegoptimieren.

## pd_veranl_stl / pd_rks_id — Wert-Konsolidierung
`23018→23015`, `23017→23016`, `52002→52003`: alte IDs werden auf neue
konsolidiert. Kein Kommentar zur Begründung im Original — einfach
1:1 übernehmen, nicht versuchen zu verstehen "warum".

## pd_geschlecht — zeitabhängige Remap (P61, April 2016)
Vor P61 (Schnittstellenversion, siehe `docs/systemkontext.md`) wird
`29003` auf `29004` gehoben. Die Bedingung dafür im Original ist
`(LEFT(CONVERT(VARCHAR(8), bi_load_date, 112), 6)) - 1 < 201604` —
**reine Ganzzahl-Subtraktion auf einem YYYYMM-Wert**, kein echter
Monats-Rückschritt (bei Januar würde `-1` z.B. `202300` ergeben, nicht
den korrekten Vormonat). Das ist im Original vermutlich unbeabsichtigt,
aber: 1:1-Migration heißt, dieses Verhalten exakt zu reproduzieren,
nicht zu "reparieren". Nicht selbst durch echte Monatsarithmetik
(`month_add()`) ersetzen.

## pd_abschl_art — Override bei fehlendem pd_tae_durch
`WHEN pd_abschl_art = 10010 AND pd_tae_durch IS NULL/0 THEN 10012` —
ein Sonderfall, der nur bei dieser Kombination greift.

## Bezug
`docs/systemkontext.md` B.1 (Schnittstellenversionen P51/P61/P72/P91/P92).
