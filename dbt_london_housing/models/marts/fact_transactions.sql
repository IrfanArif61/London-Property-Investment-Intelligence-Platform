-- The centrepiece. Every property transaction with foreign keys to all three dimensions and the numeric measures.
{{ config(materialized='table') }}

-- Fact table for property transactions.
-- One row per transaction with surrogate keys to dim_date, dim_location, dim_property
-- plus all numeric measures and core attributes needed for BI.

WITH flagged AS (
    SELECT *
    FROM {{ ref('int_transactions__flagged') }}
)

SELECT
    -- Primary key
    transaction_id                                                       AS transaction_key,

    -- Foreign keys to dimensions
    sale_date                                                            AS date_key,
    {{ dbt_utils.generate_surrogate_key([
        'postcode_district',
        'borough'
    ]) }}                                                                AS location_key,
    {{ dbt_utils.generate_surrogate_key(['property_type_code']) }}       AS property_key,

    -- Measures (the things you aggregate)
    price                                                                AS sale_price,
    CASE WHEN price >= 1000000 THEN price ELSE 0 END                     AS sale_price_million_plus,
    1                                                                    AS transaction_count,

    -- Degenerate dimensions (attributes that don't need their own dim table)
    is_new_build,
    is_leasehold                                                         AS tenure_is_leasehold,
    tenure                                                               AS tenure_label,
    price_band,
    market_segment,
    is_central_london,
    is_million_plus,
    is_super_prime,
    is_most_recent_year,

    -- Metadata for traceability
    sale_date,
    sale_year,
    sale_quarter,
    sale_month,
    source_year,
    loaded_at

FROM flagged