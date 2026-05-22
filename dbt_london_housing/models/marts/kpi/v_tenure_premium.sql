{{ config(materialized='view') }}

-- View 7: Freehold vs leasehold price premium per borough
-- Answers: "What's the freehold premium in this area?"

WITH price_by_tenure AS (
    SELECT
        l.borough,
        f.tenure_label,
        COUNT(*)                          AS transactions,
        ROUND(MEDIAN(f.sale_price), 0)    AS median_price
    FROM {{ ref('fact_transactions') }} f
    JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
    WHERE l.borough != 'Unmatched'
      AND f.tenure_label IN ('Freehold', 'Leasehold')
    GROUP BY l.borough, f.tenure_label
),

pivoted AS (
    SELECT
        borough,
        SUM(CASE WHEN tenure_label = 'Freehold'  THEN transactions ELSE 0 END) AS freehold_txns,
        SUM(CASE WHEN tenure_label = 'Leasehold' THEN transactions ELSE 0 END) AS leasehold_txns,
        SUM(CASE WHEN tenure_label = 'Freehold'  THEN median_price ELSE 0 END) AS freehold_median,
        SUM(CASE WHEN tenure_label = 'Leasehold' THEN median_price ELSE 0 END) AS leasehold_median
    FROM price_by_tenure
    GROUP BY borough
)

SELECT
    borough,
    freehold_txns,
    leasehold_txns,
    freehold_median,
    leasehold_median,
    freehold_median - leasehold_median                                                AS freehold_premium_gbp,
    ROUND((freehold_median - leasehold_median) * 100.0 / NULLIF(leasehold_median, 0), 1) AS freehold_premium_pct
FROM pivoted
WHERE freehold_txns >= 50
  AND leasehold_txns >= 50
ORDER BY freehold_premium_pct DESC