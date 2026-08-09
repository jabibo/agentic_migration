{% macro behinderung_bit(beh1, beh2, beh3, beh4) %}
  COALESCE({{ _behinderung_map(beh1) }}, 0)
    + COALESCE({{ _behinderung_map(beh2) }}, 0)
    + COALESCE({{ _behinderung_map(beh3) }}, 0)
    + COALESCE({{ _behinderung_map(beh4) }}, 0)
{% endmacro %}

{% macro _behinderung_map(beh_col) %}
  CASE
    WHEN {{ beh_col }} = 11040   THEN 1
    WHEN {{ beh_col }} = 11041   THEN 2
    WHEN {{ beh_col }} = 11042   THEN 4
    WHEN {{ beh_col }} = 11008   THEN 8
    WHEN {{ beh_col }} = 11010   THEN 16
    WHEN {{ beh_col }} = 11043   THEN 32
    WHEN {{ beh_col }} = 11016   THEN 64
    WHEN {{ beh_col }} = 11035   THEN 128
    WHEN {{ beh_col }} = 11044   THEN 256
    WHEN {{ beh_col }} = 11045   THEN 512
    WHEN {{ beh_col }} = 11046   THEN 1024
    WHEN {{ beh_col }} = 11047   THEN 2048
    WHEN {{ beh_col }} IS NULL  THEN 0
    WHEN {{ beh_col }} IN (0, 11040, 11041, 11042, 11008, 11010, 11043, 11016, 11035, 11044, 11045, 11046, 11047)
      THEN 0
    ELSE 4096
  END
{% endmacro %}