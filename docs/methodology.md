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
