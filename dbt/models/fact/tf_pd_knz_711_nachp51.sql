-- Deterministisch generiert (Klasse A, kein LLM) aus source_references/pd/pd_skripte/PD KNZ 711.KNZ 711.sql
-- tools/render_dbt_models.py, Ziel table_key=sqlserver__bps__dbo__con_pd_fact.tf_pd_knz_711_nachP51
{{ config(schema=schema_for('fact')) }}

SELECT
  SUM(
    CASE
      WHEN "fa"."mon_id_eing" = "fa"."mon_id_load_decr" /* wenn Eingang im Lademonat-1, (-1 da Liefermonat mit Daten aus Vormonat) */
      THEN 1
      ELSE 0
    END
  ) AS "pd_anz_eingae",
  SUM(CASE WHEN "fa"."pd_asa_id" IN (10010, 10011) THEN 0 ELSE 1 END) AS "pd_anz_in_bear",
  COALESCE("fa"."pd_asa_id", 99999) AS "asa_id", /* neu mit P51, Anpassung Spaltenname wegen MSTR */
  COALESCE("fa"."pd_tkd_id", 9999) AS "tkd_id", /* neu mit P51, Anpassung Spaltenname wegen MSTR */
  COALESCE("fa"."pd_rks_a_id", 99999) AS "rks_a_id", /* neu mit P51, Anpassung Spaltenname wegen MSTR */
  "fa"."org_id",
  "fa"."mon_id_load_decr" AS "mon_id"
FROM {{ ref('tf_pd_fa') }} AS "fa"
WHERE
  "fa"."mon_id_load_decr" BETWEEN '201504' AND {{ knz_letzter_monat(711) }}
GROUP BY
  "fa"."mon_id_load_decr",
  "fa"."pd_asa_id",
  "fa"."pd_tkd_id",
  "fa"."pd_rks_a_id",
  "fa"."org_id" /* ---------------------------------------------------------------------------------------------------------------------- */
