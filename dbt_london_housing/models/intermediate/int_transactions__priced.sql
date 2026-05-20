{{ config(materialized='view') }}

-- Adds price categorisation bands and price-per-property-type quintiles.
-- Built on top of int_transactions__enriched_with_borough.

WITH enriched AS (
    SELECT *
    FROM {{ ref('int_transactions__enriched_with_borough') }}
),

with_price_band AS (
    SELECT
        *,
        CASE
            WHEN price < 250000             THEN '1. Under £250K'
            WHEN price < 500000             THEN '2. £250K-£500K'
            WHEN price < 750000             THEN '3. £500K-£750K'
            WHEN price < 1000000            THEN '4. £750K-£1M'
            WHEN price < 2000000            THEN '5. £1M-£2M'
            WHEN price < 5000000            THEN '6. £2M-£5M'
            ELSE                                 '7. £5M+'
        END AS price_band,

        CASE
            WHEN price < 500000             THEN 'Affordable'
            WHEN price < 1500000            THEN 'Mid-Market'
            WHEN price < 5000000            THEN 'Premium'
            ELSE                                 'Super-Prime'
        END AS market_segment
    FROM enriched
)

SELECT * FROM with_price_band