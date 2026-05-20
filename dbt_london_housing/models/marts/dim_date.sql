-- A proper date dimension is a star schema staple. It lets you do things like "sales by quarter" or "weekend vs weekday volume" without writing date functions in every query.

{{ config(materialized='table') }}

-- Date dimension covering 2021-01-01 to 2024-12-31
-- One row per date with all common time hierarchies pre-computed.
-- Generated using dbt_utils.date_spine which produces a clean continuous date series.

WITH date_spine AS (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2021-01-01' as date)",
        end_date="cast('2025-01-01' as date)"
    ) }}
),

date_attributes AS (
    SELECT
        date_day                                       AS date_key,
        date_day                                       AS full_date,
        YEAR(date_day)                                 AS year,
        QUARTER(date_day)                              AS quarter,
        MONTH(date_day)                                AS month_number,
        TO_CHAR(date_day, 'MMMM')                      AS month_name,
        TO_CHAR(date_day, 'Mon')                       AS month_short,
        DAY(date_day)                                  AS day_of_month,
        DAYOFWEEK(date_day)                            AS day_of_week_number,
        TO_CHAR(date_day, 'DAY')                       AS day_of_week_name,
        WEEK(date_day)                                 AS week_of_year,
        DATE_TRUNC('MONTH', date_day)                  AS month_start_date,
        LAST_DAY(date_day, 'MONTH')                    AS month_end_date,
        DATE_TRUNC('QUARTER', date_day)                AS quarter_start_date,
        LAST_DAY(date_day, 'QUARTER')                  AS quarter_end_date,
        DATE_TRUNC('YEAR', date_day)                   AS year_start_date,
        LAST_DAY(date_day, 'YEAR')                     AS year_end_date,
        CASE
            WHEN DAYOFWEEK(date_day) IN (0, 6) THEN TRUE
            ELSE FALSE
        END                                            AS is_weekend,
        YEAR(date_day) || '-Q' || QUARTER(date_day)    AS year_quarter,
        YEAR(date_day) || '-' || LPAD(MONTH(date_day), 2, '0')  AS year_month
    FROM date_spine
)

SELECT * FROM date_attributes