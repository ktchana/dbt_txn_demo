{% materialization raw_sql, adapter='bigquery' %}
  -- 1. Grab the sql defined in the model
  {%- set identifier = model['alias'] -%}
-- 2. Execute the SQL directly. We do not want to create a table.
{% call statement('main') -%}
{{ sql }}
{%- endcall %}

-- 3. Return a success message
{{ adapter.commit() }}
{{ return({'relations': []}) }}
{% endmaterialization %}
