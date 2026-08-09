-- Migriert aus source_references/pd/pd_skripte/PD KNZ 708.KNZ 708.sql (Klasse B)
-- Berechnung der Kennzahl 708: Durchgef. Aktivitaeten und Verw. computergest. Tests
{{ config(schema=schema_for('fact')) }}

SELECT
  1 AS Anzahl,
  fc."pd_auftr_id",
  fc."org_id",
  fc."pd_tae_durch",
  {{ var('verarbeitungsmonat') }} AS MON_ID
FROM {{ ref('tf_pd_fc') }} AS fc
WHERE fc."pd_abschl_art" = 10010
  AND fc."pd_veranl_stl" <> 23006
  AND fc."pd_tae_durch" <> 2001
  AND fc."pd_fehl_typ" = 0
  AND CAST(LEFT(
    CAST(CAST(TO_CHAR(fc."pd_abschl_dat", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) BETWEEN {{ knz_erster_monat(708) }} AND {{ knz_letzter_monat(708) }}