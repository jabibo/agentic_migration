-- Deterministisch generiert (Klasse A, kein LLM) aus source_references/pd/pd_skripte/PD KNZ INIT.NEO_org_Zuordnung.sql
-- tools/render_dbt_models.py, Ziel table_key=sqlserver__bps__dbo__con_pd_fact.tf_pd_fa
{{ config(schema=schema_for('fact')) }}

SELECT
  "f".*,
  "kal_eing"."mon_id" AS "mon_id_eing",
  {{ month_add("LEFT(CAST(CAST(TO_CHAR(\"bi_load_date\", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR), 6)", "-1") }} AS "mon_id_load_decr",
  "dst"."org_id" AS "org_id"
FROM {{ ref('tf_deltant_pd_fa_k') }} AS "f"
LEFT OUTER JOIN {{ source('con_pd_knz', 'vd_pd_dienststelle') }} AS "dst"
  ON "dst"."ba_schl" = "f"."pd_agent_nr"
LEFT JOIN {{ source('con_pd_calc', 'td_ueb_kalender_Tag') }} AS "kal_eing"
  ON "f"."pd_dat_eing" = "kal_eing"."tag_dat"
