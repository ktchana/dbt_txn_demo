{% macro freeze_view(view_name, source_table) %}
    
    {# 1. Run query to fetch the current BigQuery server timestamp #}
    {% set get_ts_query %}
        SELECT CURRENT_TIMESTAMP()
    {% endset %}
    
    {% set results = run_query(get_ts_query) %}
    
    {% if execute %}
        {# Extract the timestamp value from the query results #}
        {% set current_ts = results.columns[0].values()[0] %}
        
        {# 2. Execute CREATE OR REPLACE VIEW statement pinned to the timestamp #}
        {% set create_view_query %}
            CREATE OR REPLACE VIEW {{ target.schema }}.{{ view_name }} AS
            SELECT * FROM {{ target.schema }}.{{ source_table }}
            FOR SYSTEM_TIME AS OF TIMESTAMP '{{ current_ts }}'
        {% endset %}
        
        {% do run_query(create_view_query) %}
        {{ log("View " ~ target.schema ~ "." ~ view_name ~ " frozen at timestamp: " ~ current_ts, info=True) }}
    {% endif %}

{% endmacro %}


{% macro thaw_view(view_name, source_table) %}

    {# Execute CREATE OR REPLACE VIEW statement without time travel clause #}
    {% set create_view_query %}
        CREATE OR REPLACE VIEW {{ target.schema }}.{{ view_name }} AS
        SELECT * FROM {{ target.schema }}.{{ source_table }}
    {% endset %}
    
    {% if execute %}
        {% do run_query(create_view_query) %}
        {{ log("View " ~ target.schema ~ "." ~ view_name ~ " thawed (live).", info=True) }}
    {% endif %}

{% endmacro %}
