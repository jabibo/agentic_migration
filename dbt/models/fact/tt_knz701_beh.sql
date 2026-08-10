-- Migriert aus source_references/pd/pd_skripte/PD KNZ 701.KNZ 701.sql (Klasse B)
-- Zwischentabelle: festgestellte Behinderungen (11040 = "keine Behinderung" → NULL)
{{ config(schema=schema_for('fact')) }}

SELECT
  "pd_auftr_id",
  CASE WHEN "pd_beh_1" = 11040 THEN NULL ELSE "pd_beh_1" END AS "pd_beh_1",
  CASE WHEN "pd_beh_2" = 11040 THEN NULL ELSE "pd_beh_2" END AS "pd_beh_2",
  CASE WHEN "pd_beh_3" = 11040 THEN NULL ELSE "pd_beh_3" END AS "pd_beh_3",
  CASE WHEN "pd_beh_4" = 11040 THEN NULL ELSE "pd_beh_4" END AS "pd_beh_4"
FROM {{ ref('tf_pd_fc') }}