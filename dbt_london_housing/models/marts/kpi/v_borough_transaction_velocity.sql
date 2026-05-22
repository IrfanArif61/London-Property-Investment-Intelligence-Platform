{{ config(materialized='view') }}

-- View 3: Borough transaction velocity (market liquidity)
-- Measures how active each borough's market is.
-- Answers: "Where can I exit quickly if needed?"
-- Used by: risk overlay on investment recommendations.

WITH borough_activity AS (
    SELECT
        l.borough,
        l.is_central_london,
        l.london_region,
        d.year,
        COUNT(*) AS transactions
    FROM {{ ref('fact_transactions') }} f
    JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
    JOIN {{ ref('dim_date') }} d     ON f.date_key     = d.date_key
    WHERE l.borough != 'Unmatched'
    GROUP BY l.borough, l.is_central_london, l.london_region, d.year
),

with_rankings AS (
    SELECT
        *,
        ROUND(transactions / 12.0, 0)                                     AS avg_monthly_transactions,
        RANK() OVER (PARTITION BY year ORDER BY transactions DESC)        AS volume_rank,
        NTILE(4) OVER (PARTITION BY year ORDER BY transactions DESC)      AS liquidity_quartile
    FROM borough_activity
)

SELECT
    borough,
    is_central_london,
    london_region,
    year,
    transactions,
    avg_monthly_transactions,
    volume_rank,
    CASE liquidity_quartile
        WHEN 1 THEN 'High Liquidity'
        WHEN 2 THEN 'Moderate Liquidity'
        WHEN 3 THEN 'Lower Liquidity'
        WHEN 4 THEN 'Thin Market'
    END AS liquidity_tier
FROM with_rankings
ORDER BY year DESC, volume_rank