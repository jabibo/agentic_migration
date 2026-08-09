{% macro prev_month_schema(role) %}
  {%- set prefix = "sqlserver__bps__dbo__" -%}
  {%- set roles = {
      "data": "con_pd_data", "dwh": "con_pd_dwh", "calc": "con_pd_calc",
      "fact": "con_pd_fact", "knz": "con_pd_knz", "strg": "con_strg",
      "dim": "con_bio_dim"
  } -%}
  {%- if role not in roles -%}
    {{ exceptions.raise_compiler_error("prev_month_schema: unbekannte Rolle '" ~ role ~ "'") }}
  {%- endif -%}
  {{ return(prefix ~ roles[role] ~ "_" ~ month_add(var("verarbeitungsmonat"), "-1")) }}
{% endmacro %}
