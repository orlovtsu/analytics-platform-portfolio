-- Minimal companion staging model to stg_orders, included so the
-- `relationships` test on stg_orders.customer_id has a real target.

with source as (

    select * from {{ source('raw', 'source_customers') }}

),

renamed as (

    select
        customer_id::bigint as customer_id,
        signup_at::timestamptz as signup_at

    from source

)

select * from renamed
