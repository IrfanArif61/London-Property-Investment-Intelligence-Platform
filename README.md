# London Housing Market Analytics Platform

> **Business Question:** _Where in London should a property investor deploy £500K over the next 12 months for the best risk-adjusted returns?_

An end-to-end data analytics platform analysing **HM Land Registry property transactions (2021–2024)** to identify investment opportunities across London boroughs, property types, and postcodes — built with **Python, Snowflake, and Tableau**.

---

## Key Business Insights

_To be filled in after analysis._

- Borough-level price appreciation rankings (4-year CAGR)
- Transaction velocity and market liquidity by area
- Property type ROI breakdown per borough
- Identification of undervalued postcodes vs borough averages
- New build vs existing stock value retention
- Freehold vs leasehold premium quantified by area

---

## Architecture

HM Land Registry CSVs (2021–2024)
↓
Python ETL (pandas, chunked loading)
↓
Cleaned Parquet files
↓
Snowflake Data Warehouse (star schema)
↓
SQL KPI Views
↓
Power BI Dashboard (4 pages)

---

## Tech Stack

| Layer           | Tool                        |
| --------------- | --------------------------- |
| Ingestion       | Python, pandas              |
| Storage         | Snowflake (cloud warehouse) |
| Modelling       | SQL (star schema)           |
| Visualisation   | Power BI                    |
| Version Control | Git, GitHub                 |

---

## Project Structure

london-housing-analytics/
├── data/
│ ├── raw/ # Original CSV files (gitignored)
│ └── processed/ # Cleaned parquet files (gitignored)
├── notebooks/ # Jupyter notebooks (numbered in order)
├── sql/
│ ├── ddl/ # CREATE TABLE statements
│ └── views/ # KPI view definitions
├── scripts/ # Reusable Python scripts
├── docs/ # Methodology and data dictionary
├── screenshots/ # Dashboard images for README
├── .env # Snowflake credentials (gitignored)
├── .gitignore
├── README.md
└── requirements.txt

---

## Methodology

See [`docs/methodology.md`](docs/methodology.md) for cleaning decisions and analytical approach.

---

## Dashboard Preview

_Screenshots will be added here after the dashboard is built._

---

## Limitations

- Covers England & Wales only (filtered to London)
- Excludes property purchases via share transfers
- Prices are nominal (not inflation-adjusted)
- Recent months may have registration lag (~2 months)

---

## Data Source

[HM Land Registry Price Paid Data](https://www.gov.uk/government/statistical-data-sets/price-paid-data-downloads) — Open Government Licence v3.0.

## Pipeline Status

[DONE] **Phase 1** — Project foundation and documentation
[DONE] **Phase 2** — Data ingestion (285,791 London transactions, 2021-2024)
[DONE] **Phase 3** — Multi-layer S3 data lake + Snowflake RAW schema load
[DONE] **Phase 4** — dbt project setup + sources + data quality tests
[DONE] **Phase 5** — Staging layer: code mapping, postcode-borough seed
[DONE] **Phase 6** — Intermediate layer: borough enrichment, price bands, analytical flags
[DONE] **Phase 7** — Mart layer: star schema (1 fact + 3 dimensions, referential integrity tests)
[DONE] **Phase 8** — KPI layer: 8 business-question views (YoY growth, liquidity, undervalued postcodes, premiums)
[NEXT] **Phase 9** — Tableau dashboard
