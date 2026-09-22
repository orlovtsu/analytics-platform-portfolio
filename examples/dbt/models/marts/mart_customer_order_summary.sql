-- Marts layer: business-level, joined/aggregated, consumed directly by BI.
-- BI tools are granted read-only access to `marts` only -- never `raw` or
-- `staging` -- which keeps the warehouse's access model simple to reason
-- about (one grant per layer, not per table).

with orders as (

    select * from {{ ref('stg_orders') }}

),

customer_summary as (

    select
        customer_id,
        count(*)                                   as total_orders,
        sum(total_amount)                          as lifetime_value,
        min(placed_at)                              as first_order_at,
        max(placed_at)                              as most_recent_order_at
    from orders
    where order_status != 'cancelled'
    group by customer_id

)

select * from customer_summary
