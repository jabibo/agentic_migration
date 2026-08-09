-- Migriert aus source_references/pd/pd_skripte/PD KNZ 701.KNZ 701.sql (Klasse B)
-- Berechnung der Kennzahl 701: Erbrachte Dienstleistungen des PD
{{ config(schema=schema_for('fact')) }}

SELECT
  1 AS Anzahl,
  fc."pd_auftr_id",
  fc."org_id",
  CASE
    WHEN td."tkd_id" IS NULL OR fc."pd_tae_durch" IS NULL THEN 9999
    ELSE fc."pd_tae_durch"
  END AS "pd_tae_durch",
  CASE
    WHEN bs."ste_id" IS NULL OR fc."pd_veranl_stl" IS NULL THEN 99999
    ELSE fc."pd_veranl_stl"
  END AS "pd_veranl_stl",
  CASE
    WHEN ra."rks_a_id" IS NULL OR fc."pd_rks_id" IS NULL THEN 99999
    ELSE fc."pd_rks_id"
  END AS "pd_rks_id",
  COALESCE(tt."count_anz_beh", 0) AS "anz_beh",
  CASE COALESCE(fc."pd_anzahl_pt", 0)
    WHEN 0 THEN 0
    WHEN 1 THEN 9
    WHEN 2 THEN 18
    ELSE 27
  END AS "pt_mit_faktor",
  9999 AS "pd_traeger_id",
  {{ var('verarbeitungsmonat') }} AS "mon_id"
FROM {{ ref('tf_pd_fc') }} AS fc
LEFT JOIN {{ ref('tt_knz701_sum_beh') }} AS tt
  ON fc."pd_auftr_id" = tt."pd_auftr_id"
LEFT JOIN {{ source('con_pd_knz', 'vd_pd_taetigkeit_durchgefuehrt') }} AS td
  ON fc."pd_tae_durch" = td."tkd_id"
LEFT JOIN {{ source('con_pd_knz', 'vd_bps_stelle') }} AS bs
  ON fc."pd_veranl_stl" = bs."ste_id"
LEFT JOIN {{ source('con_pd_knz', 'vd_bps_rechtskreis_auftraggeber') }} AS ra
  ON fc."pd_rks_id" = ra."rks_a_id"
WHERE fc."pd_abschl_art" = 10010
  AND fc."pd_fehl_typ" = 0
  AND {{ var('verarbeitungsmonat') }} BETWEEN {{ knz_erster_monat(701) }} AND {{ knz_letzter_monat(701) }}