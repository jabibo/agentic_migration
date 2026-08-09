{{ config(schema=schema_for('calc')) }}

-- Klasse C: aus source_references/pd/pd_skripte/PD LOAD.Bestandsuebernahme.sql
-- Schritt 4 (Kappung): View tf_deltant_pd_fa_k mit max. 5 Jahren Kappung

SELECT
    "pd_dat_akt",
    "pd_agent_nr",
    "pd_zeit_von",
    "pd_zeit_bis",
    "pd_dat_eing",
    "pd_asa_id",
    "pd_tkd_id",
    "pd_rks_a_id",
    "pd_anz_eingae",
    "pd_anz_in_bear",
    "bi_load_date",
    "bi_load_filename"
FROM {{ ref('tf_deltant_pd_fa') }}
WHERE "bi_load_date" >= '{{ (var("verarbeitungsmonat")[:4]|int - 4)|string }}0101'
