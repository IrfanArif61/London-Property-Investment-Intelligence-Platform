{{ config(materialized='view') }}

-- View 6: New-build vs existing-stock price premium per borough
-- Answers: "Is the new-build premium worth paying in this area?"

WITH price_by_segment AS (
    SELECT
        l.borough,
        f.is_new_build,
        COUNT(*)                          AS transactions,
        ROUND(MEDIAN(f.sale_price), 0)    AS median_price,
        ROUND(AVG(f.sale_price), 0)       AS avg_price
    FROM {{ ref('fact_transactions') }} f
    JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
    WHERE l.borough != 'Unmatched'
      AND f.is_new_build IS NOT NULL
    GROUP BY l.borough, f.is_new_build
),

pivoted AS (
    SELECT
        borough,
        SUM(CASE WHEN is_new_build = TRUE  THEN transactions  ELSE 0 END) AS new_build_txns,
        SUM(CASE WHEN is_new_build = FALSE THEN transactions  ELSE 0 END) AS existing_txns,
        SUM(CASE WHEN is_new_build = TRUE  THEN median_price  ELSE 0 END) AS new_build_median,
        SUM(CASE WHEN is_new_build = FALSE THEN median_price  ELSE 0 END) AS existing_median
    FROM price_by_segment
    GROUP BY borough
)

SELECT
    borough,
    new_build_txns,
    existing_txns,
    new_build_median,
    existing_median,
    new_build_median - existing_median                                                AS premium_gbp,
    ROUND((new_build_median - existing_median) * 100.0 / NULLIF(existing_median, 0), 1)  AS premium_pct
FROM pivoted
WHERE new_build_txns >= 50   -- need real new-build activity to be meaningful
  AND existing_txns >= 50
ORDER BY premium_pct DESC