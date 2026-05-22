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

## Phase 6 — Intermediate Layer

### Purpose

The intermediate layer sits between staging and marts. Each model does one focused transformation, making the pipeline modular, testable, and easy to debug.

### Models Built (in dependency order)

1. **`int_transactions__enriched_with_borough`** — joins transactions with the postcode-borough seed
2. **`int_transactions__priced`** — adds price bands and market segments
3. **`int_transactions__flagged`** — adds boolean flags for common analytical filters

### Key Design Decisions

**LEFT JOIN, not INNER JOIN, for borough enrichment**
Preserves all transactions even when postcode doesn't match the seed. Unmatched rows get a 'Unmatched' label rather than NULL, making coverage gaps trivially queryable.

**Numbered price bands**
Bands are prefixed with sort keys (`1. Under £250K`, `2. £250K-£500K`) to ensure BI tools display them in correct numeric order without custom sort logic.

**Boolean flags for common filters**
Pre-computed flags like `is_central_london`, `is_million_plus`, `is_flat` centralise business logic in one place rather than duplicating it across BI tools.

### Price Bands

| Band | Range         |
| ---- | ------------- |
| 1    | Under £250K   |
| 2    | £250K - £500K |
| 3    | £500K - £750K |
| 4    | £750K - £1M   |
| 5    | £1M - £2M     |
| 6    | £2M - £5M     |
| 7    | £5M+          |

### Market Segments

- **Affordable**: under £500K
- **Mid-Market**: £500K - £1.5M
- **Premium**: £1.5M - £5M
- **Super-Prime**: £5M+

### Central London Definition

Defined as the following boroughs: City of London, Westminster, Kensington and Chelsea, Camden, Islington, Southwark, Lambeth, Hammersmith and Fulham.

This is a slightly broader definition than the official "Inner London" classification but reflects how the property market is commonly segmented by investors and agents.

### Tests

All intermediate models tested for:

- `transaction_id` uniqueness preservation through joins
- Not-null on key columns
- `accepted_values` on `price_band` and `market_segment` (ensures categorisation logic is complete)

### Lineage

See `screenshots/dbt_lineage_phase6.png` for the full data flow visualisation.

## Phase 7 — Mart Layer (Star Schema)

### Star Schema Design

The final analytics layer follows Kimball-style dimensional modelling with one fact table and three dimensions:

```
                     dim_date
                        |
                        |
   dim_location ---  fact_transactions  ---  dim_property
                        |
                        |
                  (numeric measures)
```

### Tables

**`fact_transactions`** (285,791 rows)

- Grain: one row per property transaction
- Foreign keys: date_key, location_key, property_key
- Measures: sale_price, sale_price_million_plus, transaction_count
- Degenerate dimensions: price_band, market_segment, is_central_london, etc.

**`dim_date`** (1,461 rows)

- Grain: one row per calendar date (2021-01-01 to 2024-12-31)
- Attributes: year, quarter, month, day-of-week, week-of-year, is_weekend, year_quarter, year_month
- Generated using `dbt_utils.date_spine`

**`dim_location`** (~150 rows)

- Grain: one row per (postcode_district, borough) combination
- Attributes: postcode_district, postcode_area, borough, is_central_london, london_region
- Surrogate key: hash of postcode_district + borough

**`dim_property`** (5 rows)

- Grain: one row per property type
- Attributes: property_type_name, property_description, property_category
- Surrogate key: hash of property_type_code

### Surrogate Keys

All dimension joins use hash-based surrogate keys generated via `dbt_utils.generate_surrogate_key`. Benefits over natural keys:

- Deterministic — same inputs always produce the same hash
- Collision-free in practice (MD5 hash)
- Fast joins in Snowflake's columnar engine
- Decoupled from source system codes that may change

### Referential Integrity

dbt `relationships` tests enforce that every foreign key in `fact_transactions` matches a row in the referenced dimension. Acts as database-level referential integrity without needing actual FK constraints (which Snowflake doesn't enforce by default).

### Why Tables, Not Views, in the Mart Layer

Mart models are materialised as **tables** rather than views because:

- Tableau queries them repeatedly — tables are faster than views by orders of magnitude on aggregations
- Storage cost is negligible (285K rows ≈ a few MB in Snowflake)
- Pre-computed once per dbt run, reused across thousands of dashboard interactions

## Phase 8 — KPI Views (Business Logic Layer)

### Purpose

This layer translates the generic star schema into opinionated views that directly answer the investor's strategic questions. Each view is purpose-built for a specific decision — eliminating ambiguity in BI dashboards.

### Views Built

| View                             | Business Question Answered                            |
| -------------------------------- | ----------------------------------------------------- |
| `v_borough_price_trends`         | How are prices evolving per borough over time?        |
| `v_borough_yoy_growth`           | Which boroughs grew fastest YoY?                      |
| `v_borough_transaction_velocity` | Where is market liquidity highest?                    |
| `v_property_type_roi_by_borough` | What property type delivers best returns per borough? |
| `v_undervalued_postcodes`        | Which specific postcodes are cheap vs their borough?  |
| `v_new_build_premium`            | What's the new-build price premium per borough?       |
| `v_tenure_premium`               | What's the freehold price premium per borough?        |
| `v_market_health_summary`        | Top-line market indicators for executive dashboard    |

### Key Analytical Techniques Used

- **`LAG` window function** — YoY calculations without self-joins
- **`RANK` and `NTILE`** — borough liquidity ranking and quartile classification
- **`MEDIAN` over `AVG`** — robust central tendency measures resistant to super-prime outliers
- **`HAVING COUNT(*) >= N`** — statistical relevance filters (excludes thin markets / rare property combinations)
- **CTEs for clarity** — every view structured as named query steps rather than nested subqueries
- **`NULLIF` defensive coding** — prevents divide-by-zero errors in growth calculations

### Why Views, Not Tables, for KPIs

- KPI definitions evolve frequently as business questions change
- Underlying fact table is already materialised (fast reads)
- No storage cost — views are query definitions, not stored data
- Logic changes reflect immediately, no rebuild required

### Tableau Integration

These views become the **primary data sources** for the Tableau dashboard in Phase 9. Tableau workbooks reference views directly:

- Page 1 (Executive Overview) → `v_market_health_summary`
- Page 2 (Borough Comparison) → `v_borough_yoy_growth` + `v_borough_transaction_velocity`
- Page 3 (Property Type Analysis) → `v_property_type_roi_by_borough`
- Page 4 (Postcode Heatmap) → `v_undervalued_postcodes`
