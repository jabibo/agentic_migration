-- Migriert aus source_references/pd/pd_skripte/PD KNZ 703.KNZ 703.sql (Klasse C)
-- Berechnung der Kennzahl 703: Vormerkzeiten und Gutachtenerstellungszeiten
-- Sonderfall BM 201412 (IF-Zweig) ist tote Logik (AFM068953 Übergangslösung)
-- pd_vmz_bereinigt: fest 0 seit Hotfix 26.02.2015
{{ config(schema=schema_for('fact')) }}

WITH base AS (
    SELECT
        fc."org_id",
        fc."pd_tae_durch",
        1 AS "anzahl",
        fc."pd_gez",
        CASE
            WHEN COALESCE(fc."pd_gez", 99999) BETWEEN 0 AND 1 THEN 1
            WHEN COALESCE(fc."pd_gez", 99999) BETWEEN 2 AND 3 THEN 2
            WHEN COALESCE(fc."pd_gez", 99999) BETWEEN 4 AND 5 THEN 3
            ELSE 5
        END AS "gez_id_lz",
        fc."pd_lpe",
        CASE
            WHEN COALESCE(fc."pd_lpe", 99999) BETWEEN 0 AND 1 THEN 1
            WHEN COALESCE(fc."pd_lpe", 99999) BETWEEN 2 AND 3 THEN 2
            WHEN COALESCE(fc."pd_lpe", 99999) BETWEEN 4 AND 5 THEN 3
            ELSE 5
        END AS "lpe_id_lz",
        fc."pd_lap",
        CASE
            WHEN COALESCE(fc."pd_lap", 99999) BETWEEN 0 AND 1 THEN 1
            WHEN COALESCE(fc."pd_lap", 99999) BETWEEN 2 AND 3 THEN 2
            WHEN COALESCE(fc."pd_lap", 99999) BETWEEN 4 AND 5 THEN 3
            ELSE 5
        END AS "lap_id_lz",
        0 AS "pd_vmz_bereinigt"
    FROM {{ ref('tf_pd_fc') }} AS fc
    WHERE fc."pd_abschl_art" = 10010
      AND fc."pd_veranl_stl" <> 23006
      AND fc."pd_fehl_typ" = 0
      AND CAST(LEFT(CAST(CAST(TO_CHAR(fc."pd_abschl_dat", 'YYYYMMDD') AS VARCHAR(8)) AS LONG VARCHAR), 6) AS INT)
        BETWEEN {{ knz_erster_monat(703) }} AND {{ knz_letzter_monat(703) }}
)

SELECT
    b."org_id",
    {{ var('verarbeitungsmonat') }} AS "mon_id",
    b."pd_tae_durch",
    b."anzahl",
    b."pd_gez",
    b."gez_id_lz",
    NULL AS "pd_lpe",
    99999 AS "lpe_id_lz",
    NULL AS "pd_lap",
    99999 AS "lap_id_lz",
    b."pd_vmz_bereinigt"
FROM base AS b

UNION ALL

SELECT
    b."org_id",
    {{ var('verarbeitungsmonat') }} AS "mon_id",
    b."pd_tae_durch",
    0 AS "anzahl",
    NULL AS "pd_gez",
    b."lpe_id_lz" AS "gez_id_lz",
    b."pd_lpe",
    b."lpe_id_lz",
    NULL AS "pd_lap",
    99999 AS "lap_id_lz",
    b."pd_vmz_bereinigt"
FROM base AS b
WHERE b."pd_lpe" IS NOT NULL

UNION ALL

SELECT
    b."org_id",
    {{ var('verarbeitungsmonat') }} AS "mon_id",
    b."pd_tae_durch",
    0 AS "anzahl",
    NULL AS "pd_gez",
    b."lap_id_lz" AS "gez_id_lz",
    NULL AS "pd_lpe",
    99999 AS "lpe_id_lz",
    b."pd_lap",
    b."lap_id_lz",
    b."pd_vmz_bereinigt"
FROM base AS b
WHERE b."pd_lap" IS NOT NULL