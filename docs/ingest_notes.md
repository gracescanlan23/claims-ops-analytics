# Phase 1 ingest notes

## Data source

**Primary:** CMS 2008–2010 Data Entrepreneurs’ Synthetic Public Use File (DE-SynPUF), **Sample 1**.

- Collection overview: https://www.cms.gov/data-research/statistics-trends-and-reports/medicare-claims-synthetic-public-use-files/cms-2008-2010-data-entrepreneurs-synthetic-public-use-file-de-synpuf
- Sample 1 download page: https://www.cms.gov/data-research/statistics-trends-and-reports/medicare-claims-synthetic-public-use-files/cms-2008-2010-data-entrepreneurs-synthetic-public-use-file-de-synpuf/de10-sample-1
- Direct CMS Downloads base: `https://www.cms.gov/Research-Statistics-Data-and-Systems/Downloadable-Public-Use-Files/SynPUFs/Downloads/`

**Not used (yet):** newer Synthetic Medicare Enrollment / FFS claims collection on data.cms.gov — classic DE-SynPUF Sample 1 was available and is the better fit for a claims/ops demo (beneficiary + IP + OP with familiar SynPUF field names).

## Files loaded (Sample 1)

| File | Source URL |
|------|------------|
| 2008 Beneficiary Summary | CMS Downloads / `DE1_0_2008_Beneficiary_Summary_File_Sample_1.zip` |
| 2009 Beneficiary Summary | CMS Downloads / `DE1_0_2009_Beneficiary_Summary_File_Sample_1.zip` |
| 2010 Beneficiary Summary | **OHDSI mirror** (see caveat) — https://github.com/OHDSI/ETL-CMS/files/4932398/DE1_0_2010_Beneficiary_Summary_File_Sample_1.zip |
| 2008–2010 Inpatient Claims | CMS Downloads / `DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.zip` |
| 2008–2010 Outpatient Claims | CMS Downloads / `DE1_0_2008_to_2010_Outpatient_Claims_Sample_1.zip` |

**Skipped (size / Phase 1 scope):** Carrier Claims A/B, Prescription Drug Events (PDE).

Re-download script: `scripts/download_synpuf_sample1.sh`

## Staging tables (DuckDB: `claims.duckdb`)

| Table | Rows | Notes |
|-------|------|--------|
| `stg_beneficiary` | 343,644 | Union of 2008 + 2009 + 2010 summary files with added `bene_year` |
| `stg_inpatient` | 66,773 | Claim-level IP |
| `stg_outpatient` | 790,790 | Claim-level OP |

Beneficiary by year: 2008 = 116,352; 2009 = 114,538; 2010 = 112,754.

## Date range (ascertainable from claims)

| Column | Min | Max |
|--------|-----|-----|
| `stg_inpatient.CLM_FROM_DT` | 2007-11-27 | 2010-12-30 |
| `stg_inpatient.CLM_THRU_DT` | 2008-01-01 | 2010-12-31 |
| `stg_outpatient.CLM_FROM_DT` | 2007-12-12 | 2010-12-31 |
| `stg_outpatient.CLM_THRU_DT` | 2008-01-01 | 2010-12-31 |

Dates are stored as integers `YYYYMMDD` in the raw SynPUF CSVs (DuckDB may cast depending on sniffing). Beneficiary files are annual snapshots for calendar years **2008–2010**.

## Caveats

1. **Synthetic data** — DE-SynPUF is for software/training demos, **not** for population inference or publishing “real” Medicare rates.
2. **CMS Sample 1 2010 beneficiary link is broken** — the official Sample 1 page points the 2010 beneficiary ZIP at Sample 20. Community copy used: OHDSI ETL-CMS [issue #62](https://github.com/OHDSI/ETL-CMS/issues/62) attachment (original CMS file content from their ETL archive).
3. **Sample ≈ 0.25%** of the full SynPUF population; 20 samples exist. All claims for a given synthetic beneficiary stay in the same sample number.
4. **Link key:** `DESYNPUF_ID` across beneficiary and claims files.
5. Carrier omitted in Phase 1 — volume KPIs will be IP/OP-centric until Phase 2 optionally adds carrier.

## How ingest was run

```bash
cd /workspace/claims-ops-analytics
# (data already present) bash scripts/download_synpuf_sample1.sh
.venv/bin/python scripts/run_ingest.py
```

SQL: `sql/01_ingest.sql`
