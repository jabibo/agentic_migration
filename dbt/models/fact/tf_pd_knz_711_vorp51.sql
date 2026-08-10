-- Deterministisch generiert (Klasse A, kein LLM) aus source_references/pd/pd_skripte/PD KNZ 711.KNZ 711.sql
-- tools/render_dbt_models.py, Ziel table_key=sqlserver__bps__dbo__con_pd_fact.tf_pd_knz_711_vorP51
{{ config(schema=schema_for('fact')) }}

SELECT
  "fa"."pd_anz_eingae",
  "fa"."pd_anz_in_bear",
  "fa"."pd_asa_id" AS "asa_id", /* neu mit P51, Anpassung Spaltenname wegen MSTR */
  "fa"."pd_tkd_id" AS "tkd_id", /* neu mit P51, Anpassung Spaltenname wegen MSTR */
  "fa"."pd_rks_a_id" AS "rks_a_id", /* neu mit P51, Anpassung Spaltenname wegen MSTR */
  "fa"."org_id",
  CAST(LEFT(
    CAST(CAST(TO_CHAR("fa"."pd_zeit_von", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) AS "mon_id"
FROM {{ ref('tf_pd_fa') }} AS "fa"
WHERE
  CAST(LEFT(
    CAST(CAST(TO_CHAR("fa"."pd_zeit_von", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR),
    6
  ) AS INT) BETWEEN {{ knz_erster_monat(711) }} AND '201503' /* von Anfang bis vor P51 */ /* ---------------------------------------------------------------------------------------------------------------------- */
