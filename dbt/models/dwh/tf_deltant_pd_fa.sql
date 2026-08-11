{{ config(schema=schema_for('dwh')) }}

-- Klasse C: aus source_references/pd/pd_skripte/PD LOAD.Bestandsuebernahme.sql
-- Schritt 1+2: Vormonatsdaten + Ladedaten in tf_deltant_pd_fa uebernehmen
--
-- Akkumulation (T-SQL Schritt 1): In Produktion wird zuerst die Vormonats-DB
-- con_pd_dwh_vm gelesen und als Basis verwendet. Hier nur Delta aus DATA, da
-- fuer Testlaufe mit einem Monat kein Vormonat-Delta existiert.
-- In Produktion muss das Vormonat-Schema vorab geladen werden.

SELECT
    TIMESTAMP '1900-01-01 00:00:00' AS "pd_dat_akt",
    "pd_agent_nr",
    TIMESTAMP '1900-01-01 00:00:00' AS "pd_zeit_von",
    TIMESTAMP '1900-01-01 00:00:00' AS "pd_zeit_bis",
    "pd_dat_eing",
    "pd_asa_id",
    "pd_tkd_id",
    "pd_rks_a_id",
    "mon_id",
    0 AS "pd_anz_eingae",
    0 AS "pd_anz_in_bear",
    CAST(SUBSTR(REPLACE(d.mfd_quelldatei, 'BI_DELTA_FA_', ''), 1, 4) || '-'
    || SUBSTR(REPLACE(d.mfd_quelldatei, 'BI_DELTA_FA_', ''), 5, 2) || '-01' AS DATE) AS "bi_load_date",
    d.mfd_quelldatei AS "bi_load_filename"
FROM {{ delta_union_dedup('fa', '"pd_agent_nr"', false) }} AS d
