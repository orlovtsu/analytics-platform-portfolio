-- Staging layer: 1:1 with the raw source table, light typing/renaming only.
-- Materialized as a table (see dbt_project.yml) because it's the point of
-- reuse for every downstream mart, and re-scanning `raw` repeatedly would
-- compete with the ingestion writes landing in that schema.

with source as (

    select * from {{ source('raw', 'source_orders') }}

),

renamed as (

    select
        order_id::bigint                as order_id,
        customer_id::bigint              as customer_id,
        order_status::text               as order_status,
        order_placed_at::timestamptz     as placed_at,
        order_total_amount::numeric(12,2) as total_amount

    from source

)

select * from renamed
