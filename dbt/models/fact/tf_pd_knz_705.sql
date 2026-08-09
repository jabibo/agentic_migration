-- Migriert aus source_references/pd/pd_skripte/PD KNZ 705.KNZ 705.sql (Klasse B)
-- Berechnung der Kennzahl 705: Anzahl der durchgef. Psychologischen Tätigkeiten
{{ config(schema=schema_for('fact')) }}

SELECT
  1 AS Anzahl,
  fc.ORG_ID,
  fc.PD_TAE_DURCH,
  fc.PD_RKS_ID,
  CASE
    WHEN COALESCE(fc.PD_ANZAHL_PT, 0) < 4 THEN COALESCE(fc.PD_ANZAHL_PT, 0)
    ELSE 4
  END AS PD_ANZAHL_PT_ID,
  CAST(LEFT(
    CAST(CAST(TO_CHAR(fc.PD_ABSCHL_DAT, 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) AS MON_ID
FROM {{ ref('tf_pd_fc') }} AS fc
WHERE fc.PD_ABSCHL_ART = 10010
  AND fc.PD_VERANL_STL <> 23006
  AND fc.PD_TAE_DURCH IN (2003, 2006)
  AND fc.PD_FEHL_TYP = 0
  AND CAST(LEFT(
    CAST(CAST(TO_CHAR(fc.PD_ABSCHL_DAT, 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) BETWEEN {{ var('verarbeitungsmonat') }} AND {{ var('verarbeitungsmonat') }}