-- Migriert aus source_references/pd/pd_skripte/PD KNZ 702.KNZ 702.sql (Klasse B)
-- Berechnung der Kennzahl 702: Gesamtlaufzeiten für die Auftragsbearbeitung durch den PD
{{ config(
    schema=schema_for('fact'),
    tags=['knz702']
) }}

SELECT
  1 AS Anzahl,
  fc."org_id",
  CASE
    WHEN fc."pd_tae_durch" IS NULL
      OR d.tkd_id IS NULL THEN 9999
    ELSE fc."pd_tae_durch"
  END AS pd_tae_durch,
  CASE
    WHEN fc."pd_veranl_stl" IS NULL
      OR d.ste_id IS NULL THEN 99999
    ELSE fc."pd_veranl_stl"
  END AS pd_veranl_stl,
  CASE
    WHEN fc."pd_rks_id" IS NULL
      OR d.rks_a_id IS NULL THEN 99999
    ELSE fc."pd_rks_id"
  END AS pd_rks_id,
  CASE
    WHEN fc."pd_leist_art_1" IS NULL
      OR d.lst_id IS NULL THEN 99999
    ELSE fc."pd_leist_art_1"
  END AS pd_leist_art_1,
  CAST(LEFT(
    CAST(CAST(TO_CHAR(fc."pd_abschl_dat", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) AS mon_id,
  fc."pd_lz",
  CASE
    WHEN fc."pd_dgk_id" IS NULL
      OR d.dgk_id IS NULL THEN 9999
    ELSE fc."pd_dgk_id"
  END AS pd_dgk_id,
  CASE WHEN fc."pd_lz" BETWEEN 31 AND 50 THEN 1 ELSE 0 END AS btw_31_to_50_days,
  CASE WHEN fc."pd_lz" > 50 THEN 1 ELSE 0 END AS bg_50_days,
  CASE WHEN fc."pd_lz" BETWEEN 0 AND 10 THEN 1 ELSE 0 END AS sm_11_days,
  CASE WHEN fc."pd_lz" > 10 THEN 1 ELSE 0 END AS bg_10_days,
  0 AS GLZ_NETTO_in_Wochen,
  0 AS sm_10_days,
  0 AS sm_15_days,
  0 AS bg_15_days,
  0 AS sm_20_days,
  0 AS bg_20_days,
  0 AS sm_25_days,
  0 AS bg_25_days,
  0 AS sm_30_days,
  0 AS bg_30_days,
  0 AS sm_35_days,
  0 AS bg_35_days,
  0 AS sm_40_days,
  0 AS bg_40_days,
  0 AS sm_45_days,
  0 AS bg_45_days,
  0 AS sm_50_days,
  0 AS pd_traeger_id
FROM {{ ref('tf_pd_fc') }} AS fc
LEFT JOIN {{ source('con_pd_knz', 'vd_pd_taetigkeit_durchgefuehrt') }} AS d
  ON fc."pd_tae_durch" = d.tkd_id
LEFT JOIN {{ source('con_pd_knz', 'vd_bps_stelle') }} AS d_stelle
  ON fc."pd_veranl_stl" = d_stelle.ste_id
LEFT JOIN {{ source('con_pd_knz', 'vd_bps_rechtskreis_auftraggeber') }} AS d_rks
  ON fc."pd_rks_id" = d_rks.rks_a_id
LEFT JOIN {{ source('con_pd_knz', 'vd_pd_leistung') }} AS d_leist
  ON fc."pd_leist_art_1" = d_leist.lst_id
LEFT JOIN {{ source('con_pd_knz', 'vd_as_bps_Dringlichkeit') }} AS d_dgk
  ON fc."pd_dgk_id" = d_dgk.dgk_id
WHERE fc."pd_abschl_art" = 10010
  AND fc."pd_fehl_typ" = 0
  AND CAST(LEFT(
    CAST(CAST(TO_CHAR(fc."pd_abschl_dat", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) BETWEEN {{ knz_erster_monat(702) }} AND {{ knz_letzter_monat(702) }}