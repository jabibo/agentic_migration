-- Migriert aus source_references/pd/pd_skripte/PD KNZ 706.KNZ 706.sql (Klasse B)
-- Berechnung der Kennzahl 706: Bearbeitet und unbearbeitet abgeschl. Aufträge
{{ config(schema=schema_for('fact')) }}

SELECT
  1 AS Anzahl,
  fc."org_id",
  COALESCE(fc."pd_tae_beauf", 9999) AS "pd_tae_beauf",
  COALESCE(fc."pd_veranl_stl", 99999) AS "pd_veranl_stl",
  CAST(LEFT(
    CAST(CAST(TO_CHAR(fc."pd_abschl_dat", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) AS "mon_id",
  COALESCE(fc."pd_abschl_art", 99999) AS "pd_abschl_art",
  COALESCE(fc."pd_abschl_grund", 0) AS "pd_abschl_grund"
FROM {{ ref('tf_pd_fc') }} AS fc
WHERE fc."pd_fehl_typ" = 0
  AND CAST(LEFT(
    CAST(CAST(TO_CHAR(fc."pd_abschl_dat", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) BETWEEN {{ knz_erster_monat(706) }} AND {{ knz_letzter_monat(706) }}