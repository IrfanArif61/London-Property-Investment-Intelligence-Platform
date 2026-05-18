# Methodology

This document records all data cleaning, transformation, and analytical decisions.

## Data Source

HM Land Registry Price Paid Data — yearly CSV files for 2021–2024.

## Filtering Logic

- London-only transactions identified by postcode prefix: E, N, W, SW, SE, EC, WC
- All transactions outside London removed at the ingestion stage

## Cleaning Decisions

## Ingestion Decisions (Notebook 01)

### London Filtering

- Filtered using postcode area prefixes: E, EC, N, NW, SE, SW, W, WC
- Used regex `^([A-Z]+)` to extract postcode area (letters before first digit) for accurate matching
- This avoids false positives (e.g. avoiding matching "SWA" outside London)

### Null Handling

- Dropped rows with null postcodes at ingestion stage (~0.1% of records)
- All other nulls preserved for handling in cleaning notebook

### Memory Optimisation

- Used chunked CSV loading (200K rows per chunk) to handle large files efficiently
- Filtered to London inside the chunk loop to reduce memory footprint by ~85%
- Final output stored as Parquet (Snappy compression) for fast downstream reads

### Output

- Single file: `data/processed/london_transactions_raw.parquet`
- Schema preserved from raw, plus added `source_year` column for traceability

## Schema Design

_To be documented after Snowflake load._

## Known Limitations

- 2024 data may be incomplete due to typical 2-month registration lag
- Some postcodes may be missing — handled by dropping rows with null postcodes
