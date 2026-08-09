{{ config(schema=schema_for('dwh')) }}

-- Klasse C: aus source_references/pd/pd_skripte/PD LOAD.Bestandsuebernahme.sql
-- Schritt 4 (Kappung): View tf_deltant_pd_azt_k mit max. 5 Jahren Kappung

SELECT
    "pd_pkey",
    "pd_aufzaehl_Name",
    "pd_status",
    "pd_bez",
    "pd_kurzbez",
    "bi_load_date",
    "bi_load_filename"
FROM {{ ref('tf_deltant_pd_azt') }}
WHERE "bi_load_date" >= CAST('{{ (var("verarbeitungsmonat")[:4]|int - 4)|string }}-01-01' AS DATE)
