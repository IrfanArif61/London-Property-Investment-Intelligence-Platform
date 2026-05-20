{{ config(materialized='view') }}

-- Enriches each transaction with its London borough by joining on postcode_district.
-- Transactions where no borough match is found get 'Unmatched' so we never lose rows.
-- Downstream models can filter on borough = 'Unmatched' to investigate coverage gaps.

WITH transactions AS (
    SELECT *
    FROM {{ ref('stg_land_registry__transactions') }}
),

boroughs AS (
    SELECT *
    FROM {{ ref('stg_postcode_boroughs') }}
),

joined AS (
    SELECT
        t.transaction_id,
        t.price,
        t.sale_date,
        t.sale_year,
        t.sale_month,
        t.sale_quarter,
        t.sale_month_start,
        t.sale_quarter_start,
        t.postcode,
        t.postcode_area,
        t.postcode_district,
        COALESCE(b.borough, 'Unmatched') AS borough,
        t.town,
        t.district AS source_district,
        t.county,
        t.property_type,
        t.property_type_code,
        t.is_new_build,
        t.new_build_flag,
        t.tenure,
        t.tenure_code,
        t.ppd_type,
        t.ppd_type_code,
        t.source_year,
        t.loaded_at
    FROM transactions t
    LEFT JOIN boroughs b
        ON t.postcode_district = b.postcode_district
)

SELECT * FROM joined