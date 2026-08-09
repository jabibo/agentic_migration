-- Migriert aus source_references/pd/pd_skripte/PD KNZ 701.KNZ 701.sql (Klasse B)
-- Zwischentabelle: Summe festgestellter Behinderungen pro Auftrag
{{ config(schema=schema_for('fact')) }}

SELECT
  "pd_auftr_id",
  COUNT("pd_beh_1") + COUNT("pd_beh_2") + COUNT("pd_beh_3") + COUNT("pd_beh_4") AS "count_anz_beh"
FROM {{ ref('tt_knz701_beh') }}
GROUP BY "pd_auftr_id"