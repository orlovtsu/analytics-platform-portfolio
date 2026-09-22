-- Singular test: reconciliation between layers.
--
-- Generic column/table tests validate one model in isolation; this checks
-- that the marts layer didn't silently drop or duplicate rows relative to
-- staging during the join/aggregation in mart_customer_order_summary.
-- dbt fails the test if this query returns any rows.

with staging_counts as (

    select
        customer_id,
        count(*) as staging_order_count
    from {{ ref('stg_orders') }}
    where order_status != 'cancelled'
    group by customer_id

),

mart_counts as (

    select
        customer_id,
        total_orders as mart_order_count
    from {{ ref('mart_customer_order_summary') }}

),

mismatched as (

    select
        s.customer_id,
        s.staging_order_count,
        m.mart_order_count
    from staging_counts s
    join mart_counts m using (customer_id)
    where s.staging_order_count != m.mart_order_count

)

select * from mismatched
