-- Migriert aus source_references/pd/pd_skripte/PD KNZ 709.KNZ 709.sql (Klasse B)
-- Berechnung der Kennzahl 709: Kundenbezogene Auftragsdaten
{{ config(schema=schema_for('fact')) }}

SELECT
  "tt"."pd_auftr_id",
  "tt"."org_id",
  CASE WHEN "tt"."pd_schul_abschl" IS NULL OR "dim_schul"."bn_id" IS NULL THEN 99999 ELSE "tt"."pd_schul_abschl" END AS "pd_schul_abschl",
  "tt"."pd_geschlecht",
  "tt"."mon_id",
  CASE WHEN "tt"."pd_abschl_art" IS NULL OR "dim_abschl"."asa_id" IS NULL THEN 99999 ELSE "tt"."pd_abschl_art" END AS "pd_abschl_art",
  CASE WHEN "tt"."bps_bild_abs" IS NULL OR "dim_bild"."bas_id" IS NULL THEN 55999 ELSE "tt"."bps_bild_abs" END AS "bps_bild_abs",
  "tt"."pd_beh_key",
  CASE WHEN (MOD(FLOOR("tt"."pd_beh_key" / 1), 2) <> 0) OR ("tt"."pd_beh_key" = 0) THEN 1 ELSE 0 END AS "pd_beh1",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 2), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh2",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 4), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh3",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 8), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh4",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 16), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh5",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 32), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh6",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 64), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh7",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 128), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh8",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 256), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh9",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 512), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh10",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 1024), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh11",
  CASE WHEN MOD(FLOOR("tt"."pd_beh_key" / 2048), 2) <> 0 THEN 1 ELSE 0 END AS "pd_beh12",
  CASE WHEN "tt"."pd_rks_id" IS NULL OR "dim_rks"."rks_a_id" IS NULL THEN 99999 ELSE "tt"."pd_rks_id" END AS "pd_rks_id",
  CASE WHEN "tt"."pd_tae_durch" IS NULL OR "dim_tae"."tkd_id" IS NULL THEN 9999 ELSE "tt"."pd_tae_durch" END AS "pd_tae_durch"
FROM {{ ref('tt_pd_knz_709') }} AS "tt"
LEFT JOIN {{ source('con_pd_knz', 'vd_bps_Bildungsniveau') }} AS "dim_schul"
  ON "tt"."pd_schul_abschl" = "dim_schul"."bn_id"
LEFT JOIN {{ source('con_pd_knz', 'vd_pd_abschlussart') }} AS "dim_abschl"
  ON "tt"."pd_abschl_art" = "dim_abschl"."asa_id"
LEFT JOIN {{ source('con_pd_knz', 'vd_bps_Bildungsabschluss') }} AS "dim_bild"
  ON "tt"."bps_bild_abs" = "dim_bild"."bas_id"
LEFT JOIN {{ source('con_pd_knz', 'vd_bps_rechtskreis_auftraggeber') }} AS "dim_rks"
  ON "tt"."pd_rks_id" = "dim_rks"."rks_a_id"
LEFT JOIN {{ source('con_pd_knz', 'vd_pd_taetigkeit_durchgefuehrt') }} AS "dim_tae"
  ON "tt"."pd_tae_durch" = "dim_tae"."tkd_id"
