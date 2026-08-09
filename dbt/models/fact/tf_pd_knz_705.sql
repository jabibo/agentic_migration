-- Migriert aus source_references/pd/pd_skripte/PD KNZ 705.KNZ 705.sql (Klasse B)
-- Berechnung der Kennzahl 705: Anzahl der durchgef. Psychologischen Tätigkeiten
{{ config(schema=schema_for('fact')) }}

SELECT
  1 AS Anzahl,
  fc."pd_auftr_id",
  fc."org_id",
  fc."pd_tae_durch",
  fc."pd_rks_id",
  CASE
    WHEN COALESCE(fc."pd_anzahl_pt", 0) < 4 THEN COALESCE(fc."pd_anzahl_pt", 0)
    ELSE 4
  END AS PD_ANZAHL_PT_ID,
  {{ var('verarbeitungsmonat') }} AS MON_ID
FROM {{ ref('tf_pd_fc') }} AS fc
WHERE fc."pd_abschl_art" = 10010
  AND fc."pd_veranl_stl" <> 23006
  AND fc."pd_tae_durch" IN (2003, 2006)
  AND fc."pd_fehl_typ" = 0
  AND CAST(LEFT(
    CAST(CAST(TO_CHAR(fc."pd_abschl_dat", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) BETWEEN {{ knz_erster_monat(705) }} AND {{ knz_letzter_monat(705) }}