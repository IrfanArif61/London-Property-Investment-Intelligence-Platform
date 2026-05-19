{{ config(materialized='view') }}

-- Staging model for raw_land_registry
-- Adds: typed dates, decoded property_type/new_build/tenure,
--       derived columns (year, month, quarter, postcode_area)
-- Filters: drop zero-price, null postcode, null date

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'raw_land_registry') }}
),

renamed AS (
    SELECT
        transaction_id,
        price,
        TRY_TO_DATE(LEFT(sale_date, 10))  AS sale_date,
        UPPER(TRIM(postcode))             AS postcode,
        property_type                     AS property_type_code,
        CASE property_type
            WHEN 'D' THEN 'Detached'
            WHEN 'S' THEN 'Semi-Detached'
            WHEN 'T' THEN 'Terraced'
            WHEN 'F' THEN 'Flat'
            WHEN 'O' THEN 'Other'
            ELSE 'Unknown'
        END                               AS property_type,
        new_build                         AS new_build_flag,
        CASE new_build
            WHEN 'Y' THEN TRUE
            WHEN 'N' THEN FALSE
            ELSE NULL
        END                               AS is_new_build,
        tenure                            AS tenure_code,
        CASE tenure
            WHEN 'F' THEN 'Freehold'
            WHEN 'L' THEN 'Leasehold'
            ELSE 'Unknown'
        END                               AS tenure,
        UPPER(TRIM(town))                 AS town,
        UPPER(TRIM(district))             AS district,
        UPPER(TRIM(county))               AS county,
        ppd_type                          AS ppd_type_code,
        CASE ppd_type
            WHEN 'A' THEN 'Standard'
            WHEN 'B' THEN 'Additional'
            ELSE 'Unknown'
        END                               AS ppd_type,
        source_year,
        loaded_at
    FROM source
    WHERE price > 0
      AND postcode IS NOT NULL
      AND sale_date IS NOT NULL
),

derived AS (
    SELECT
        *,
        YEAR(sale_date)                    AS sale_year,
        MONTH(sale_date)                   AS sale_month,
        QUARTER(sale_date)                 AS sale_quarter,
        DATE_TRUNC('MONTH', sale_date)     AS sale_month_start,
        DATE_TRUNC('QUARTER', sale_date)   AS sale_quarter_start,
        REGEXP_SUBSTR(postcode, '^[A-Z]+') AS postcode_area,
        SPLIT_PART(postcode, ' ', 1)       AS postcode_district
    FROM renamed
)

SELECT * FROM derived