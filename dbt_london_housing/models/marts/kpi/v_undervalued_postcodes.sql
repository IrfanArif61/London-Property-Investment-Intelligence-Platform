{{ config(materialized='view') }}

-- View 5: Undervalued postcode districts within their borough
-- Compares each postcode's median price to its borough's median.
-- Answers: "Which specific postcodes offer the best entry value?"
-- Used by: micro-targeting investment recommendations.

WITH postcode_stats AS (
    SELECT
        l.borough,
        l.postcode_district,
        COUNT(*)                                            AS postcode_transactions,
        ROUND(MEDIAN(f.sale_price), 0)                      AS postcode_median_price,
        ROUND(AVG(f.sale_price), 0)                         AS postcode_avg_price
    FROM {{ ref('fact_transactions') }} f
    JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
    JOIN {{ ref('dim_date') }} d     ON f.date_key     = d.date_key
    WHERE l.borough != 'Unmatched'
      AND d.year >= 2023  -- recent activity only, market has shifted post-COVID
    GROUP BY l.borough, l.postcode_district
    HAVING COUNT(*) >= 30   -- need enough sales to be meaningful
),

borough_stats AS (
    SELECT
        borough,
        ROUND(MEDIAN(postcode_median_price), 0) AS borough_median_price,
        COUNT(*) AS postcode_count
    FROM postcode_stats
    GROUP BY borough
)

SELECT
    p.borough,
    p.postcode_district,
    p.postcode_transactions,
    p.postcode_median_price,
    b.borough_median_price,
    p.postcode_median_price - b.borough_median_price                                                AS price_gap_gbp,
    ROUND((p.postcode_median_price - b.borough_median_price) * 100.0 / NULLIF(b.borough_median_price, 0), 1)  AS price_gap_pct,
    CASE
        WHEN p.postcode_median_price < b.borough_median_price * 0.75 THEN 'Significantly Undervalued (>25% below)'
        WHEN p.postcode_median_price < b.borough_median_price * 0.90 THEN 'Undervalued (10-25% below)'
        WHEN p.postcode_median_price < b.borough_median_price * 1.10 THEN 'In Line With Borough'
        WHEN p.postcode_median_price < b.borough_median_price * 1.25 THEN 'Premium (10-25% above)'
        ELSE 'Significant Premium (>25% above)'
    END AS value_position
FROM postcode_stats p
JOIN borough_stats b ON p.borough = b.borough
ORDER BY p.borough, price_gap_pct