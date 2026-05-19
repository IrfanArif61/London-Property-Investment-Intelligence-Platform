{{ config(materialized='view') }}

-- Staging view over the London postcode -> borough seed
-- Standardises casing and trims whitespace

SELECT
    UPPER(TRIM(postcode_district)) AS postcode_district,
    TRIM(borough)                  AS borough
FROM {{ ref('london_postcode_boroughs') }}