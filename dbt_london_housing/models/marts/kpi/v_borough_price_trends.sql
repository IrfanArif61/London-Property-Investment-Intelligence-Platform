{{ config(materialized='view') }}

-- View 1: Borough price trends over time
-- One row per (borough, year_quarter) showing average price, median price, transaction count.
-- Answers: "How have prices evolved per borough over time?"
-- Used by: time-series charts in dashboard, YoY calculations downstream.

SELECT
    l.borough,
    l.is_central_london,
    l.london_region,
    d.year,
    d.quarter,
    d.year_quarter,
    d.quarter_start_date,
    
    COUNT(*)                                            AS transactions,
    ROUND(AVG(f.sale_price), 0)                         AS avg_price,
    ROUND(MEDIAN(f.sale_price), 0)                      AS median_price,
    MIN(f.sale_price)                                   AS min_price,
    MAX(f.sale_price)                                   AS max_price,
    ROUND(STDDEV(f.sale_price), 0)                      AS price_stddev,
    
    -- Coefficient of variation: stddev / mean. Lower = more stable market.
    ROUND(STDDEV(f.sale_price) / AVG(f.sale_price), 3)  AS price_volatility_ratio
    
FROM {{ ref('fact_transactions') }} f
JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
JOIN {{ ref('dim_date') }} d     ON f.date_key     = d.date_key
WHERE l.borough != 'Unmatched'
GROUP BY 
    l.borough, l.is_central_london, l.london_region,
    d.year, d.quarter, d.year_quarter, d.quarter_start_date