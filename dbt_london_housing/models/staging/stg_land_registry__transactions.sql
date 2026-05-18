{{ config(materialized='view') }}

SELECT
    transaction_id,
    price,
    TRY_TO_DATE(LEFT(sale_date, 10)) AS sale_date,
    UPPER(TRIM(postcode))            AS postcode,
    property_type,
    new_build,
    tenure,
    UPPER(TRIM(town))                AS town,
    UPPER(TRIM(district))            AS district,
    UPPER(TRIM(county))              AS county,
    source_year,
    loaded_at
FROM {{ source('raw', 'raw_land_registry') }}
WHERE price > 0
  AND postcode IS NOT NULL
  AND sale_date IS NOT NULL