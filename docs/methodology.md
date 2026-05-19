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

## Phase 3 — Multi-Layer S3 Data Lake + Snowflake Ingestion

### Data Lake Architecture

The S3 bucket implements a Bronze/Silver lake pattern:

```
s3://london-housing-analytics-irfan/
├── raw/csv/                          ← Bronze: untouched Land Registry CSVs (600MB)
└── staging/parquet/                  ← Silver: London-filtered Parquet (5.7MB)
```

### Layer Definitions

- **Bronze (raw CSVs):** Full England & Wales source data, immutable, never modified
- **Silver (Parquet):** Pre-processed analytics-ready data — London-filtered, columnar, compressed
- **Gold (Snowflake MARTS):** Star schema for BI consumption (built in Phase 7 via dbt)

### Why Multi-Layer

- Auditability — any KPI can be traced back to the original CSV
- Re-processability — can rebuild from Bronze if logic changes
- Performance — Snowflake ingests Silver (5.7MB) not Bronze (600MB)
- Industry standard — mirrors Databricks/Snowflake medallion pattern

### Ingestion Flow

```
Local CSVs → Notebook 02 → S3 Bronze
       ↓
Local CSVs → Notebook 01 (Phase 2) → Local Parquet → Notebook 03 → S3 Silver
       ↓
S3 Silver → Snowflake External Stage → COPY INTO → RAW.RAW_LAND_REGISTRY
```

### Snowflake Configuration

- **Database:** `LONDON_HOUSING`
- **Schemas:** RAW (this phase), STAGING (dbt), MARTS (dbt)
- **External Stage:** `s3_silver_stage` → `s3://.../staging/parquet/`
- **File format:** Parquet with auto-detected compression
- **Records loaded:** 285,791

### Data Distribution Verified

| Year | Transactions |
| ---- | ------------ |
| 2021 | 85,051       |
| 2022 | 75,217       |
| 2023 | 59,559       |
| 2024 | 65,964       |

### Security

- AWS credentials stored in `.env` (gitignored)
- Dedicated IAM user with bucket-scoped IAM policy (read + write)
- For production: would split into separate read-only (Snowflake) and write-only (ingestion) IAM roles following least-privilege principles
- Snowflake uses key-based auth (production: STORAGE INTEGRATION + IAM role)

## Schema Design

_To be documented after dbt mart models are built (Phase 7)._

## Known Limitations

- 2024 data may be incomplete due to typical 2-month registration lag
- Some postcodes may be missing — handled by dropping rows with null postcodes

```

```

## Phase 4 — dbt Project Setup

### Project Structure

The dbt project lives at `dbt_london_housing/` inside the main repo for unified version control.
dbt_london_housing/
├── models/
│ ├── staging/ ← 1:1 clean of raw tables (views)
│ ├── intermediate/ ← business logic enrichment (views)
│ └── marts/ ← star schema for BI (tables)
├── macros/
│ └── generate_schema_name.sql ← override default schema naming
├── sources.yml ← source definitions + tests
├── dbt_project.yml ← project config
└── ~/.dbt/profiles.yml ← Snowflake connection

### Three-Layer Architecture

- **Staging** (views): minimal transformations — rename, retype, light filtering
- **Intermediate** (views): enrichment, joins, business logic
- **Marts** (tables): final analytics-ready facts and dimensions for BI

### Materialisation Strategy

- Staging + Intermediate = views (always fresh, no storage cost)
- Marts = tables (fast for repeated BI queries from Tableau)

### Source Definition

The raw table `LONDON_HOUSING.RAW.RAW_LAND_REGISTRY` is registered as a dbt source with column documentation and 6 data quality tests:

- Uniqueness on `transaction_id`
- Not-null on `transaction_id`, `price`, `sale_date`, `postcode`, `source_year`

All 6 tests pass on the 285,791-row source.

### First Staging Model: `stg_land_registry__transactions`

- Casts `sale_date` from string to proper DATE
- Standardises text columns (postcode, town, district, county) to uppercase
- Filters out £0 transactions and null dates/postcodes
- Materialised as view in `LONDON_HOUSING.STAGING`
- Final row count: 285,791 (no data loss vs source — confirms Phase 2 ingestion quality)

### Custom Schema Naming

Default dbt behaviour prepends the target schema to custom schema names (e.g. `STAGING_marts`). A custom `generate_schema_name` macro overrides this to use schema names directly as defined in `dbt_project.yml`.

## Phase 5 — Staging Layer

### Models Built

1. `stg_land_registry__transactions` — main transactions staging
2. `stg_postcode_boroughs` — postcode district to borough lookup

### Code Mapping

Raw Land Registry codes decoded to readable labels:

| Column        | Raw codes     | Decoded labels                                 |
| ------------- | ------------- | ---------------------------------------------- |
| property_type | D, S, T, F, O | Detached, Semi-Detached, Terraced, Flat, Other |
| tenure        | F, L          | Freehold, Leasehold                            |
| new_build     | Y, N          | TRUE / FALSE (is_new_build boolean)            |
| ppd_type      | A, B          | Standard, Additional                           |

Both raw codes and decoded labels are preserved in the staging model to support both technical filtering (codes) and BI display (labels).

### Derived Columns

Added to support time-based and geographic analysis:

- `sale_year`, `sale_month`, `sale_quarter`
- `sale_month_start`, `sale_quarter_start` (truncated dates for grouping)
- `postcode_area` (letters before first digit, e.g. SW, NW)
- `postcode_district` (first half of postcode, e.g. SW1A, NW3)

### Seed: London Postcode -> Borough Mapping

Manual curation of 140+ London postcode districts mapped to 32 boroughs + City of London. Loaded via dbt seed.

**Limitations:**

- Edge postcodes near the M25 boundary may map ambiguously (e.g. some E4 postcodes are technically Essex)
- Coverage: ~95% of central and inner London transactions
- For production-grade accuracy would use ONS Postcode Directory (full UK postcode -> LSOA mapping)

### Tests

- All staging models have not-null and uniqueness tests on key columns
- `accepted_values` tests on `property_type` and `tenure` ensure code mapping completeness
- Total tests in pipeline: 14 (all passing)

### dbt Lineage

dbt-generated lineage graph shows the data flow:
RAW.raw_land_registry → stg_land_registry\_\_transactions
seed.london_postcode_boroughs → stg_postcode_boroughs

See `screenshots/dbt_lineage_phase5.png` for the visual graph.
