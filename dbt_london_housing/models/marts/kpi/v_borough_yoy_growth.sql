{{ config(materialized='view') }}

-- View 2: Year-on-year price growth per borough
-- Uses LAG window function to compare each year's avg price to previous year.
-- Answers: "Which boroughs have grown fastest in capital value?"
-- Used by: borough ranking charts, investment opportunity table.

WITH yearly_prices AS (
    SELECT
        l.borough,
        l.is_central_london,
        l.london_region,
        d.year,
        COUNT(*)                          AS transactions,
        ROUND(AVG(f.sale_price), 0)       AS avg_price,
        ROUND(MEDIAN(f.sale_price), 0)    AS median_price
    FROM {{ ref('fact_transactions') }} f
    JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
    JOIN {{ ref('dim_date') }} d     ON f.date_key     = d.date_key
    WHERE l.borough != 'Unmatched'
    GROUP BY l.borough, l.is_central_london, l.london_region, d.year
),

with_lag AS (
    SELECT
        *,
        LAG(avg_price)    OVER (PARTITION BY borough ORDER BY year)  AS prev_avg_price,
        LAG(median_price) OVER (PARTITION BY borough ORDER BY year)  AS prev_median_price,
        LAG(transactions) OVER (PARTITION BY borough ORDER BY year)  AS prev_transactions
    FROM yearly_prices
)

SELECT
    borough,
    is_central_london,
    london_region,
    year,
    transactions,
    avg_price,
    median_price,
    prev_avg_price,
    prev_median_price,
    
    -- YoY change in £
    avg_price - prev_avg_price                                                    AS yoy_avg_change_gbp,
    median_price - prev_median_price                                              AS yoy_median_change_gbp,
    
    -- YoY change in %
    ROUND((avg_price - prev_avg_price) * 100.0 / NULLIF(prev_avg_price, 0), 2)        AS yoy_avg_change_pct,
    ROUND((median_price - prev_median_price) * 100.0 / NULLIF(prev_median_price, 0), 2) AS yoy_median_change_pct,
    
    -- Transaction volume YoY
    ROUND((transactions - prev_transactions) * 100.0 / NULLIF(prev_transactions, 0), 2) AS yoy_volume_change_pct

FROM with_lag
ORDER BY year DESC, yoy_median_change_pct DESC