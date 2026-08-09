{{ config(schema=schema_for('calc')) }}

-- Klasse C: aus source_references/pd/pd_skripte/PD LOAD.Bestandsuebernahme.sql
-- Schritt 4 (Kappung): View tf_deltant_pd_fc_k mit max. 5 Jahren Kappung

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
    "bi_load_date",
    "bi_load_filename"
FROM {{ ref('tf_deltant_pd_fc') }}
WHERE "pd_abschl_dat" >= CAST('{{ (var("verarbeitungsmonat")[:4]|int - 4)|string }}-01-01' AS DATE)
