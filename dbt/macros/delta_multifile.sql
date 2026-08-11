{% macro discover_delta_files(kuerzel) %}
  {%- set schema = schema_for('data') -%}
  {%- set pattern = 'BI\_DELTA\_' ~ kuerzel|upper ~ '\_' ~ var('verarbeitungsmonat') ~ '\_%' -%}
  {%- if execute -%}
    {%- set query -%}
      SELECT table_name FROM exa_all_tables
      WHERE table_schema = '{{ schema|upper }}'
        AND table_name LIKE '{{ pattern }}' ESCAPE '\'
        AND table_name <> 'BI_DELTA_{{ kuerzel|upper }}'
      ORDER BY table_name
    {%- endset -%}
    {%- set results = run_query(query) -%}
    {%- set tables = results.columns[0].values() -%}
  {%- else -%}
    {%- set tables = [] -%}
  {%- endif -%}
  {{ return(tables) }}
{% endmacro %}

{% macro delta_union_dedup(kuerzel, key_column, dedup=true) %}
  {#- Hilfsspalten ohne fuehrenden Unterstrich: Exasol erlaubt bei
      unquotierten Identifiern kein "_"/"__" als erstes Zeichen
      (laufzeit-verifiziert, "expecting IDENTIFIER_PART_"). Praefix
      "mfd_" (multi-file-dedup) statt Unterstrich, um Kollision mit
      echten Geschaeftsspalten unwahrscheinlich zu machen.
      key_column MUSS die Quotierung des Aufrufers tragen, z.B.
      '"pd_auftr_id"' -- die per exapump/CSV geladenen Delta-Tabellen
      haben quotiert-kleingeschriebene Spalten (laufzeit-verifiziert:
      unquotiertes d.pd_auftr_id faltet zu D.PD_AUFTR_ID -> "object
      not found", da real "pd_auftr_id" quotiert existiert).

      mfd_quelldatei: volle Quell-Tabelle (== Dateiname ohne .csv, s.
      tools/load_reference_data.sh) je Zeile -- noetig, weil einzelne
      Objekte (z.B. tf_deltant_pd_fa/azt, s. docs/session9-multifile-
      loading.md, Runde 3) im Original-T-SQL bi_timestamp/bi_load_date
      NICHT aus einer Datenspalte, sondern aus dem Tabellen-/Dateinamen
      ableiten (REPLACE([tabelle], 'BI_DELTA_FA', '') o.ae.) -- ohne
      diese Spalte war die Ableitung dbt-seitig gar nicht abbildbar.

      dedup: TRUE (Standard) = ROW_NUMBER-Deduplizierung nach key_column
      (fuer FC mit pd_auftr_id); FALSE = keine Deduplizierung, alle
      Zeilen werden uebernommen -- fuer FA/AZT, deren Original-T-SQL
      keine zeilenweise Deduplizierung durchfuehrt (Qwen-Fund, Commit
      c9c97c0, memory/rules/delta_union_dedup_fazt.md). Nachtraeglich
      hier ins Scaffold-Template gezogen, nachdem eine render_scaffold.sh-
      Neuausfuehrung Qwens Direktaenderung an der generierten Datei
      stillschweigend zurueckgesetzt hatte (Session 14) -- derselbe
      Klasse-Konflikt wie bei dbt/models/qwen_owned.txt, nur fuer
      dbt/macros/ noch ungeloest; hier durch Aufnahme ins Template
      geloest statt durch einen Override-Mechanismus, weil es sich um
      eine generische Erweiterung (nicht objektspezifisch) handelt. -#}
  {%- set schema = schema_for('data') -%}
  {%- set tables = discover_delta_files(kuerzel) -%}
  {%- if execute and tables|length == 0 -%}
    {{ exceptions.raise_compiler_error(
        "delta_union_dedup: keine Datei-Tabelle fuer '" ~ kuerzel
        ~ "' im Verarbeitungsmonat " ~ var('verarbeitungsmonat')
        ~ " gefunden (Schema " ~ schema ~ "). Fehlt der Import "
        ~ "(tools/load_reference_data.sh)?") }}
  {%- endif -%}
  {% if dedup %}
  (
    SELECT u.*
    FROM (
      SELECT d.*, ROW_NUMBER() OVER (
               PARTITION BY d.{{ key_column }} ORDER BY d.mfd_quellreihenfolge ASC
             ) AS mfd_rn
      FROM (
        {% for t in tables %}
        SELECT *, {{ loop.index }} AS mfd_quellreihenfolge, '{{ t }}' AS mfd_quelldatei
        FROM {{ schema }}.{{ t }}
        {% if not loop.last %}UNION ALL{% endif %}
        {% endfor %}
      ) d
    ) u
    WHERE u.mfd_rn = 1
  )
  {% else %}
  (
    {% for t in tables %}
    SELECT *, {{ loop.index }} AS mfd_quellreihenfolge, '{{ t }}' AS mfd_quelldatei
    FROM {{ schema }}.{{ t }}
    {% if not loop.last %}UNION ALL{% endif %}
    {% endfor %}
  )
  {% endif %}
{% endmacro %}
