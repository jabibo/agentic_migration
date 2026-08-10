-- Migriert aus source_references/pd/pd_skripte/PD KNZ 706.KNZ 706.sql (Klasse B)
-- Berechnung der Kennzahl 706: Bearbeitet und unbearbeitet abgeschl. Aufträge
{{ config(schema=schema_for('fact')) }}

SELECT
  1 AS Anzahl,
  fc."pd_auftr_id",
  fc."org_id",
  CASE WHEN ref_tkb."tkb_id" IS NULL THEN 9999 ELSE fc."pd_tae_beauf" END AS "pd_tae_beauf",
  CASE WHEN ref_stl."ste_id" IS NULL THEN 99999 ELSE fc."pd_veranl_stl" END AS "pd_veranl_stl",
  {{ var('verarbeitungsmonat') }} AS "mon_id",
  CASE WHEN ref_asa."asa_id" IS NULL THEN 99999 ELSE fc."pd_abschl_art" END AS "pd_abschl_art",
  CASE WHEN ref_asg."asg_id" IS NULL THEN 0 ELSE fc."pd_abschl_grund" END AS "pd_abschl_grund"
FROM {{ ref('tf_pd_fc') }} AS fc
LEFT JOIN sqlserver__bps__dbo__con_pd_knz_{{ var('verarbeitungsmonat') }}.vd_pd_taetigkeit_beauftragt ref_tkb
  ON fc."pd_tae_beauf" = ref_tkb."tkb_id"
LEFT JOIN sqlserver__bps__dbo__con_pd_knz_{{ var('verarbeitungsmonat') }}.vd_bps_stelle ref_stl
  ON fc."pd_veranl_stl" = ref_stl."ste_id"
LEFT JOIN sqlserver__bps__dbo__con_pd_knz_{{ var('verarbeitungsmonat') }}.vd_pd_abschlussart ref_asa
  ON fc."pd_abschl_art" = ref_asa."asa_id"
LEFT JOIN sqlserver__bps__dbo__con_pd_knz_{{ var('verarbeitungsmonat') }}.vd_bps_Abschlussgrund ref_asg
  ON fc."pd_abschl_grund" = ref_asg."asg_id"
WHERE fc."pd_fehl_typ" = 0
  AND CAST(LEFT(
    CAST(CAST(TO_CHAR(fc."pd_abschl_dat", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) BETWEEN {{ knz_erster_monat(706) }} AND {{ knz_letzter_monat(706) }}
