-- This dimension describes WHERE transactions happen. One row per unique combination of postcode_district + borough + postcode_area. Tableau will join the fact table to this for geographic analysis.

{{ config(materialized='table') }}

-- Location dimension at the postcode_district grain.
-- One row per unique postcode_district with its borough and area attributes.
-- Includes a derived 'is_central_london' flag at the dimension level for BI convenience.

WITH unique_locations AS (
    SELECT DISTINCT
        postcode_district,
        postcode_area,
        borough
    FROM {{ ref('int_transactions__flagged') }}
),

with_attributes AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'postcode_district',
            'borough'
        ]) }}                                          AS location_key,
        postcode_district,
        postcode_area,
        borough,
        CASE
            WHEN borough IN (
                'City of London', 'Westminster', 'Kensington and Chelsea',
                'Camden', 'Islington', 'Southwark', 'Lambeth',
                'Hammersmith and Fulham'
            ) THEN TRUE
            ELSE FALSE
        END                                            AS is_central_london,
        CASE postcode_area
            WHEN 'E'  THEN 'East London'
            WHEN 'EC' THEN 'East Central London'
            WHEN 'N'  THEN 'North London'
            WHEN 'NW' THEN 'North West London'
            WHEN 'SE' THEN 'South East London'
            WHEN 'SW' THEN 'South West London'
            WHEN 'W'  THEN 'West London'
            WHEN 'WC' THEN 'West Central London'
            ELSE 'Other'
        END                                            AS london_region
    FROM unique_locations
)

SELECT * FROM with_attributes