{{ config(materialized='view') }}

-- View 8: Executive summary of London market health
-- One row per year with top-line market indicators.
-- Used by: KPI cards on the executive dashboard page.

WITH yearly_summary AS (
    SELECT
        d.year,
        COUNT(*)                                            AS total_transactions,
        ROUND(AVG(f.sale_price), 0)                         AS avg_price,
        ROUND(MEDIAN(f.sale_price), 0)                      AS median_price,
        SUM(f.sale_price)                                   AS total_volume_gbp,
        SUM(CASE WHEN f.is_million_plus  THEN 1 ELSE 0 END) AS million_plus_transactions,
        SUM(CASE WHEN f.is_super_prime   THEN 1 ELSE 0 END) AS super_prime_transactions,
        SUM(CASE WHEN f.is_central_london THEN 1 ELSE 0 END) AS central_london_transactions,
        COUNT(DISTINCT l.borough)                           AS active_boroughs,
        COUNT(DISTINCT l.postcode_district)                 AS active_postcodes
    FROM {{ ref('fact_transactions') }} f
    JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
    JOIN {{ ref('dim_date') }} d     ON f.date_key     = d.date_key
    WHERE l.borough != 'Unmatched'
    GROUP BY d.year
)

SELECT
    *,
    LAG(total_transactions)                                              OVER (ORDER BY year)  AS prev_year_transactions,
    LAG(median_price)                                                    OVER (ORDER BY year)  AS prev_year_median,
    ROUND((total_transactions - LAG(total_transactions) OVER (ORDER BY year)) * 100.0
        / NULLIF(LAG(total_transactions) OVER (ORDER BY year), 0), 2)                          AS volume_yoy_change_pct,
    ROUND((median_price - LAG(median_price) OVER (ORDER BY year)) * 100.0
        / NULLIF(LAG(median_price) OVER (ORDER BY year), 0), 2)                                AS median_price_yoy_change_pct
FROM yearly_summary
ORDER BY year