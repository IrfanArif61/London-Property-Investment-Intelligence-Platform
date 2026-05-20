{{ config(materialized='view') }}

-- Adds boolean flags for common analytical filters.
-- This is the final intermediate model — feeds directly into marts.

WITH priced AS (
    SELECT *
    FROM {{ ref('int_transactions__priced') }}
)

SELECT
    *,

    -- Geographic flags
    CASE
        WHEN borough IN (
            'City of London', 'Westminster', 'Kensington and Chelsea',
            'Camden', 'Islington', 'Southwark', 'Lambeth', 'Hammersmith and Fulham'
        ) THEN TRUE
        ELSE FALSE
    END AS is_central_london,

    CASE
        WHEN postcode_area IN ('EC', 'WC', 'W1', 'SW1', 'SW3', 'SW7', 'NW1')
        THEN TRUE
        ELSE FALSE
    END AS is_prime_postcode_area,

    -- Value flags
    CASE WHEN price >= 1000000 THEN TRUE ELSE FALSE END AS is_million_plus,
    CASE WHEN price >= 5000000 THEN TRUE ELSE FALSE END AS is_super_prime,

    -- Time flags
    CASE WHEN sale_year = (SELECT MAX(sale_year) FROM priced)
         THEN TRUE ELSE FALSE
    END AS is_most_recent_year,

    -- Property characteristic flags
    CASE WHEN property_type = 'Flat' THEN TRUE ELSE FALSE END AS is_flat,
    CASE WHEN tenure = 'Leasehold' THEN TRUE ELSE FALSE END AS is_leasehold

FROM priced