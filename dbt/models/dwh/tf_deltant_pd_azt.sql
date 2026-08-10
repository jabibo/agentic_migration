{{ config(schema=schema_for('dwh')) }}

-- Klasse C: aus source_references/pd/pd_skripte/PD LOAD.Bestandsuebernahme.sql
-- Schritt 1+2: Vormonatsdaten + Ladedaten in tf_deltant_pd_azt uebernehmen
--
-- Akkumulation (T-SQL Schritt 1): In Produktion wird zuerst die Vormonats-DB
-- con_pd_dwh_vm gelesen und als Basis verwendet. Hier nur Delta aus DATA, da
-- fuer Testlaufe mit einem Monat kein Vormonat-Delta existiert.
-- In Produktion muss das Vormonat-Schema vorab geladen werden.

SELECT
    "pd_pkey",
    "pd_aufzaehl_Name",
    "pd_status",
    "pd_bez",
    "pd_kurzbez",
    CAST(SUBSTR(REPLACE(d.mfd_quelldatei, 'BI_DELTA_AZT_', ''), 1, 4) || '-'
    || SUBSTR(REPLACE(d.mfd_quelldatei, 'BI_DELTA_AZT_', ''), 5, 2) || '-01' AS DATE) AS "bi_load_date",
    d.mfd_quelldatei AS "bi_load_filename"
FROM {{ delta_union_dedup('azt', '"pd_pkey"', false) }} AS d
