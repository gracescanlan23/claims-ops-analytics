# Claims Ops Analytics Mini-Case

Portfolio mini-case for healthcare **claims / ops analytics** (Royal / HSAG / CareSource–adjacent): public CMS synthetic claims → SQL warehouse-style tables (DuckDB) → Tableau Public dashboard with volume trends, quality flags, KPIs, and three ops insights.

## Stack

| Layer | Choice |
|-------|--------|
| Data | CMS DE-SynPUF Sample 1 (beneficiary + inpatient + outpatient) |
| SQL | DuckDB (`claims.duckdb`) |
| BI | Tableau Public (free, Mac-friendly); Power BI steps kept as a Windows alternative |

## Status

**Phase 2 — star schema + marts done.** Staging (Phase 1) + model objects:

| Object | Rows |
|--------|------|
| `stg_beneficiary` | 343,644 |
| `stg_inpatient` | 66,773 |
| `stg_outpatient` | 790,790 |
| `dim_member` | 116,352 |
| `dim_date` | 1,096 |
| `fact_claim` | 846,242 |
| `vw_monthly_volume` | 72 |
| `vw_high_utilizers` | ~4,339 |
| `vw_quality_flags` | 846,242 |
| `vw_kpi_summary` | 1 |

BI-ready extracts: `data/processed/*.parquet` (and KPI CSV).  
Next (**Phase 3**): Tableau Public dashboard (see `docs/tableau_build.md`) + 3 ops insights.

See [docs/model_notes.md](docs/model_notes.md) for flag/KPI definitions.

## Layout

```
claims-ops-analytics/
  claims.duckdb          # local warehouse (gitignored)
  data/raw/              # SynPUF zips/CSVs (gitignored; re-download)
  data/processed/        # optional parquet later
  sql/01_ingest.sql      # staging load
  sql/02_model.sql       # dims, facts, mart views
  scripts/download_synpuf_sample1.sh
  scripts/run_ingest.py
  scripts/run_model.py
  scripts/export_processed.py   # Parquet extracts (Power BI alternative)
  scripts/export_tableau.py     # Tableau-ready CSVs -> data/tableau/
  data/processed/        # Parquet extracts (Power BI alternative)
  data/tableau/          # Tableau-ready CSVs (ISO dates)
  dashboard/             # dashboard screenshot (dashboard.png)
  docs/ingest_notes.md
```

## Setup / reproduce

```bash
cd /workspace/claims-ops-analytics
python3 -m venv .venv
.venv/bin/pip install duckdb
bash scripts/download_synpuf_sample1.sh
.venv/bin/python scripts/run_ingest.py
.venv/bin/python scripts/run_model.py
.venv/bin/python scripts/export_processed.py   # optional, Power BI
.venv/bin/python scripts/export_tableau.py     # Tableau CSVs
```

## Open the DuckDB file

**CLI (if installed):**

```bash
duckdb /workspace/claims-ops-analytics/claims.duckdb
```

**Python (project venv):**

```bash
cd /workspace/claims-ops-analytics
.venv/bin/python -c "
import duckdb
con = duckdb.connect('claims.duckdb')
print(con.execute('SHOW TABLES').fetchall())
print(con.execute('SELECT COUNT(*) FROM stg_inpatient').fetchone())
"
```

**Quick explore (next command):**

```bash
cd /workspace/claims-ops-analytics && .venv/bin/python -c "
import duckdb
c = duckdb.connect('claims.duckdb')
print(c.execute('''
  SELECT YEAR(strptime(CAST(CLM_THRU_DT AS VARCHAR), '%Y%m%d')) AS yr,
         COUNT(*) AS ip_claims,
         ROUND(SUM(CLM_PMT_AMT),0) AS paid
  FROM stg_inpatient
  WHERE CLM_THRU_DT IS NOT NULL
  GROUP BY 1 ORDER BY 1
''').fetchdf())
"
```

## Docs

See [docs/ingest_notes.md](docs/ingest_notes.md) for exact URLs, row counts, date ranges, and synthetic-data caveats.


## Current status

- Phase 1 ingest: done (SynPUF Sample 1 → staging)
- Phase 2 model: done (star schema + marts + `data/processed/` extracts)
- Phase 3: ops insights drafted in `docs/ops_insights.md`; dashboard build steps in `docs/tableau_build.md` (Tableau Public, primary) or `docs/power_bi_build.md` (Windows alternative)
