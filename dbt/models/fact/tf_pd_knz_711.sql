-- Deterministisch generiert (Klasse A, kein LLM) aus source_references/pd/pd_skripte/PD KNZ 711.KNZ 711.sql
-- tools/render_dbt_models.py, Ziel table_key=sqlserver__bps__dbo__con_pd_fact.tf_pd_knz_711
{{ config(schema=schema_for('fact')) }}

SELECT
  *
FROM {{ ref('tf_pd_knz_711_vorp51') }}
UNION ALL
SELECT
  *
FROM {{ ref('tf_pd_knz_711_nachp51') }}
