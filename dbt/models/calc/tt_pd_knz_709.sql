-- Migriert aus source_references/pd/pd_skripte/PD KNZ 709.KNZ 709.sql (Klasse B)
-- Zwischenschritt: Fakten mit Behinderungs-Bitmaske und mon_id vorbereiten
{{ config(schema=schema_for('calc')) }}

SELECT
  fc."pd_auftr_id",
  fc."org_id",
  fc."pd_schul_abschl",
  COALESCE(fc."pd_geschlecht", 29004) AS "pd_geschlecht",
  {{ behinderung_bit("fc.\"pd_beh_1\"", "fc.\"pd_beh_2\"", "fc.\"pd_beh_3\"", "fc.\"pd_beh_4\"") }} AS "pd_beh_key",
  EXTRACT(YEAR FROM fc."pd_abschl_dat") * 100 + EXTRACT(MONTH FROM fc."pd_abschl_dat") AS "mon_id",
  fc."pd_abschl_art",
  fc."bps_bild_abs",
  fc."pd_rks_id",
  fc."pd_tae_durch"
FROM {{ ref('tf_pd_fc') }} AS fc
WHERE fc."pd_veranl_stl" <> 23006
  AND fc."pd_fehl_typ" = 0
  AND EXTRACT(YEAR FROM fc."pd_abschl_dat") * 100 + EXTRACT(MONTH FROM fc."pd_abschl_dat") BETWEEN {{ knz_erster_monat(709) }} AND {{ knz_letzter_monat(709) }}
