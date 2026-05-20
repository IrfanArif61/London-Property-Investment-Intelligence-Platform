-- The smallest but still useful dimension. One row per property type.
{{ config(materialized='table') }}

-- Property dimension.
-- One row per property type with code, label, and category description.

WITH unique_types AS (
    SELECT DISTINCT
        property_type_code,
        property_type
    FROM {{ ref('int_transactions__flagged') }}
),

with_attributes AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['property_type_code']) }}  AS property_key,
        property_type_code,
        property_type                                                    AS property_type_name,
        CASE property_type
            WHEN 'Detached'      THEN 'Standalone house'
            WHEN 'Semi-Detached' THEN 'House sharing one wall'
            WHEN 'Terraced'      THEN 'House in a row sharing both walls'
            WHEN 'Flat'          THEN 'Apartment within a larger building'
            WHEN 'Other'         THEN 'Non-standard property type'
            ELSE 'Unknown property type'
        END                                                              AS property_description,
        CASE
            WHEN property_type IN ('Detached', 'Semi-Detached', 'Terraced') THEN 'House'
            WHEN property_type = 'Flat'                                     THEN 'Apartment'
            ELSE 'Other'
        END                                                              AS property_category
    FROM unique_types
)

SELECT * FROM with_attributes