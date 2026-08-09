-- Migriert aus source_references/pd/pd_skripte/PD KNZ 709.KNZ 709.sql (Klasse B)
-- Berechnung der Kennzahl 709: Kundenbezogene Auftragsdaten
{{ config(schema=schema_for('fact')) }}

SELECT
  1 AS "Anzahl",
  "tt"."pd_auftr_id",
  "tt"."org_id",
  "tt"."pd_schul_abschl",
  "tt"."pd_geschlecht",
  "tt"."mon_id",
  "tt"."pd_abschl_art",
  "tt"."bps_bild_abs",
  "tt"."pd_beh_key",
  CASE WHEN ("tt"."pd_beh_key" & 1 <> 0) OR ("tt"."pd_beh_key" = 0) THEN 1 ELSE 0 END AS "pd_beh1",
  CASE WHEN "tt"."pd_beh_key" & 2 <> 0 THEN 1 ELSE 0 END AS "pd_beh2",
  CASE WHEN "tt"."pd_beh_key" & 4 <> 0 THEN 1 ELSE 0 END AS "pd_beh3",
  CASE WHEN "tt"."pd_beh_key" & 8 <> 0 THEN 1 ELSE 0 END AS "pd_beh4",
  CASE WHEN "tt"."pd_beh_key" & 16 <> 0 THEN 1 ELSE 0 END AS "pd_beh5",
  CASE WHEN "tt"."pd_beh_key" & 32 <> 0 THEN 1 ELSE 0 END AS "pd_beh6",
  CASE WHEN "tt"."pd_beh_key" & 64 <> 0 THEN 1 ELSE 0 END AS "pd_beh7",
  CASE WHEN "tt"."pd_beh_key" & 128 <> 0 THEN 1 ELSE 0 END AS "pd_beh8",
  CASE WHEN "tt"."pd_beh_key" & 256 <> 0 THEN 1 ELSE 0 END AS "pd_beh9",
  CASE WHEN "tt"."pd_beh_key" & 512 <> 0 THEN 1 ELSE 0 END AS "pd_beh10",
  CASE WHEN "tt"."pd_beh_key" & 1024 <> 0 THEN 1 ELSE 0 END AS "pd_beh11",
  CASE WHEN "tt"."pd_beh_key" & 2048 <> 0 THEN 1 ELSE 0 END AS "pd_beh12",
  "tt"."pd_rks_id",
  "tt"."pd_tae_durch"
FROM {{ ref('tt_pd_knz_709') }} AS "tt"
