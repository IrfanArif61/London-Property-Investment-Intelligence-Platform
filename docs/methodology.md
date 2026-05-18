# Methodology

This document records all data cleaning, transformation, and analytical decisions.

## Data Source

HM Land Registry Price Paid Data — yearly CSV files for 2021–2024.

## Filtering Logic

- London-only transactions identified by postcode prefix: E, N, W, SW, SE, EC, WC
- All transactions outside London removed at the ingestion stage

## Cleaning Decisions

_To be documented as cleaning progresses._

## Schema Design

_To be documented after Snowflake load._

## Known Limitations

- 2024 data may be incomplete due to typical 2-month registration lag
- Some postcodes may be missing — handled by dropping rows with null postcodes
