{% materialization no_op, default %}
  -- 1. Run Pre-Hooks (if any)
  {{ run_hooks(pre_hooks, inside_transaction=False) }}
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

-- 2. Run the Main Dummy Statement
{% call statement('main') -%}
SELECT 1
{%- endcall %}

-- 3. Run Post-Hooks (This is where our freeze logic lives!)
{{ run_hooks(post_hooks, inside_transaction=True) }}
{{ run_hooks(post_hooks, inside_transaction=False) }}

-- 4. Return success
{{ return({'relations': []}) }}
{% endmaterialization %}
