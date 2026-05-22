{{ config(materialized='view') }}

-- View 4: Property type performance per borough
-- For each (borough, property_type) combination: avg price, 4-year growth, transaction count.
-- Answers: "What type of property delivers best returns in this borough?"
-- Used by: property type selection in investment recommendations.

WITH first_year AS (
    SELECT
        l.borough,
        p.property_type_name,
        AVG(f.sale_price) AS avg_price_2021,
        COUNT(*)          AS transactions_2021
    FROM {{ ref('fact_transactions') }} f
    JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
    JOIN {{ ref('dim_property') }} p ON f.property_key = p.property_key
    JOIN {{ ref('dim_date') }} d     ON f.date_key     = d.date_key
    WHERE d.year = 2021
      AND l.borough != 'Unmatched'
    GROUP BY l.borough, p.property_type_name
),

last_year AS (
    SELECT
        l.borough,
        p.property_type_name,
        AVG(f.sale_price) AS avg_price_2024,
        COUNT(*)          AS transactions_2024
    FROM {{ ref('fact_transactions') }} f
    JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
    JOIN {{ ref('dim_property') }} p ON f.property_key = p.property_key
    JOIN {{ ref('dim_date') }} d     ON f.date_key     = d.date_key
    WHERE d.year = 2024
      AND l.borough != 'Unmatched'
    GROUP BY l.borough, p.property_type_name
),

overall AS (
    SELECT
        l.borough,
        p.property_type_name,
        p.property_category,
        COUNT(*)                        AS total_transactions,
        ROUND(AVG(f.sale_price), 0)     AS avg_price_overall,
        ROUND(MEDIAN(f.sale_price), 0)  AS median_price_overall
    FROM {{ ref('fact_transactions') }} f
    JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
    JOIN {{ ref('dim_property') }} p ON f.property_key = p.property_key
    WHERE l.borough != 'Unmatched'
    GROUP BY l.borough, p.property_type_name, p.property_category
)

SELECT
    o.borough,
    o.property_type_name,
    o.property_category,
    o.total_transactions,
    o.avg_price_overall,
    o.median_price_overall,
    ROUND(f.avg_price_2021, 0)                                                 AS avg_price_2021,
    ROUND(l.avg_price_2024, 0)                                                 AS avg_price_2024,
    ROUND((l.avg_price_2024 - f.avg_price_2021) * 100.0 / NULLIF(f.avg_price_2021, 0), 2) AS four_year_growth_pct,
    f.transactions_2021,
    l.transactions_2024
FROM overall o
LEFT JOIN first_year f
    ON o.borough = f.borough AND o.property_type_name = f.property_type_name
LEFT JOIN last_year l
    ON o.borough = l.borough AND o.property_type_name = l.property_type_name
WHERE o.total_transactions >= 50  -- exclude rare combinations (statistical noise)
ORDER BY o.borough, four_year_growth_pct DESC