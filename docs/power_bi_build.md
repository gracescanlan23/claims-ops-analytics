# Power BI build (on your machine)

Extracts are ready at `data/processed/` in the project repo.

## Copy files to your laptop

Ask Healthcare Claims to copy `/workspace/claims-ops-analytics/data/processed/` (and optionally `claims.duckdb`) to a folder on your computer, or zip the project.

## One-page dashboard

1. **Get data** → Folder (or individual Parquet/CSV) pointing at `data/processed/`.
2. Load at least:
   - `vw_kpi_summary.csv` (KPI cards)
   - `vw_monthly_volume.parquet` (trends)
   - `vw_quality_flags_monthly.parquet` (flag trends)
   - `vw_high_utilizers.parquet` (table)
   - `dim_claim_type.csv` / `dim_date.parquet` if you want slicer dims
3. **Visuals (one page):**
   - 4–5 card visuals from `vw_kpi_summary`
   - Line/column: monthly claim count by `claim_type`
   - Stacked bar or line: quality flag counts over month
   - Table: top high utilizers (`member_id`, `total_paid`, `claim_count`, `age_band`, `chronic_count`)
4. **Slicers:** year or month_start, claim_type
5. Screenshot → drop into `dashboard/` and README for applications

## Optional

- Connect to `claims.duckdb` with a DuckDB ODBC/connector if you prefer live SQL over parquet.
- Keep the methods note on the report page: synthetic SynPUF, not real PHI / not for inference.
