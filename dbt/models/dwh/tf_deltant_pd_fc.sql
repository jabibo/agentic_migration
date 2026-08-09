{{ config(schema=schema_for('dwh')) }}

-- Klasse C: aus source_references/pd/pd_skripte/PD LOAD.Bestandsuebernahme.sql
-- Schritt 1+2: Vormonatsdaten + Ladedaten in tf_deltant_pd_fc uebernehmen
--
-- Akkumulation (T-SQL Schritt 1): In Produktion wird zuerst die Vormonats-DB
-- con_pd_dwh_vm gelesen und als Basis verwendet. Hier nur Delta aus DATA, da
-- fuer Testlaufe mit einem Monat kein Vormonat-Delta existiert.
-- In Produktion muss das Vormonat-Schema vorab geladen werden.

SELECT
    "pd_auftr_id",
    "pd_fehl_typ",
    "pd_fehler_txt",
    "pd_dnst_nr",
    "pd_tae_beauf",
    "pd_tae_durch",
    "pd_veranl_stl",
    "pd_rks_id",
    "pd_schul_abschl",
    "pd_geschlecht",
    "pd_leist_art_1",
    "pd_leist_art_2",
    "pd_beh_1",
    "pd_beh_2",
    "pd_beh_3",
    "pd_beh_4",
    "pd_anzahl_pt",
    "pd_eing_dat",
    "pd_abschl_dat",
    "pd_abschl_art",
    "pd_abschl_grund",
    "pd_gez",
    "pd_lz",
    "pd_create_dat",
    "pd_update_dat",
    "bps_bild_abs",
    "pd_lpe",
    "pd_lap",
    "pd_bkb_id",
    "pd_dgk_id",
    "pd_spr_id",
    "pd_trg_schl",
    CAST("bi_timestamp" AS DATE) AS "bi_load_date",
    "bi_timestamp" AS "bi_load_filename"
FROM {{ delta_union_dedup('fc', '"pd_auftr_id"') }} AS d
WHERE "pd_auftr_id" IS NOT NULL
  AND "pd_fehl_typ" = 0
  AND "pd_fehl_typ" IS NOT NULL
  AND "pd_dnst_nr" IS NOT NULL
  AND "pd_eing_dat" IS NOT NULL
  AND "pd_abschl_dat" IS NOT NULL
  AND "pd_abschl_art" IS NOT NULL
  AND "pd_create_dat" IS NOT NULL
  AND "pd_update_dat" IS NOT NULL
