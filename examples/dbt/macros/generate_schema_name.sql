{#
    Custom schema-naming macro.

    dbt's default behaviour concatenates the target schema with the schema
    configured on the model (e.g. "analytics_staging"), which multiplies
    schemas unnecessarily when every layer already has a dedicated schema
    (staging, marts, ...). This override makes the model's own `+schema`
    config authoritative, so warehouse permissions can be granted cleanly
    per layer (e.g. BI tools get read-only on `marts` only).
#}

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
