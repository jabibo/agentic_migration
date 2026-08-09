{{ config(schema=schema_for('calc')) }}

-- Klasse C: aus source_references/pd/pd_skripte/PD LOAD.Bestandsuebernahme.sql
-- Schritt 1+2: Vormonatsdaten + Ladedaten in tf_deltant_pd_azt uebernehmen

SELECT
    "pd_pkey",
    "pd_aufzaehl_Name",
    "pd_status",
    "pd_bez",
    "pd_kurzbez",
    "mon_id" AS "bi_load_date",
    "bi_timestamp" AS "bi_load_filename"
FROM {{ schema_for('data') }}.bi_delta_azt
