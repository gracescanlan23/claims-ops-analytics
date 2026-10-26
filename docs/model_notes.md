# Phase 2 model notes (star schema + marts)

Built on DE-SynPUF Sample 1 staging tables. Script: `sql/02_model.sql` via `scripts/run_model.py`.

## Grain choices

| Object | Grain | Choice |
|--------|-------|--------|
| `dim_member` | 1 row / `DESYNPUF_ID` | **Latest `bene_year`** snapshot (not member-year). Preferable for unique-member KPIs and high-utilizer joins. `snapshot_year` retained. |
| `dim_date` | 1 row / calendar day | Spine from min→max `claim_thru_dt` across IP+OP |
| `dim_claim_type` | IP / OP / CAR | CAR marked `in_scope=FALSE` (not loaded Phase 1) |
| `fact_claim` | 1 row / claim (CLM_ID) | Union IP+OP; drops rows with null `CLM_THRU_DT` |

## Date parsing

SynPUF dates are integers `YYYYMMDD`. Macro `synpuf_date(d)` → DuckDB `DATE` via `strptime`. Invalid/out-of-range → NULL.

## Flag / KPI definitions

| Flag / metric | Definition | Threshold |
|---------------|------------|-----------|
| `flag_ip_30d_bounce` | Subsequent **IP** claim whose event date (`discharge_dt`, else `claim_thru_dt`) falls **1–30 days** after the same member’s prior IP `discharge_dt` | Calendar days 1–30 |
| `flag_high_op_density` | OP claim for a member whose **OP claim count that calendar year** is ≥ year-specific **95th percentile** of member-year OP counts | P95 by year |
| `flag_cost_outlier` | Claim `paid_amt` ≥ **95th percentile** of paid within the same `claim_type` (IP or OP) | P95 by claim_type |
| `flag_missing_primary_dx` | `primary_dx` (`ICD9_DGNS_CD_1`) is null/blank | — |
| `any_flag` | OR of the four flags above | — |
| High utilizer (`vw_high_utilizers`) | Member total paid (all types) ≥ **95th percentile** of member-level total paid | ~top 5% by paid |
| `avg_ip_los` | Mean of `CLM_UTLZTN_DAY_CNT` on IP claims | — |
| `ip_share_pct` | 100 × IP claims / total claims | — |
| `pct_claims_flagged` | 100 × claims with `any_flag` / total claims | — |

### Chronic flags on `dim_member`

CMS SynPUF `SP_*` codes: **1 = condition present**, **2 = absent**. Booleans (`has_chf`, …) and `chronic_count` (0–11) roll up the eleven SP indicators.

### Dual / coverage

No true dual-eligible flag in DE-SynPUF. `plan_coverage_months` = Part D plan months (`PLAN_CVRG_MOS_NUM`); also Part A/B/HMO month counts for ops context.

## Readmit / bounce proxy caveats (SynPUF)

1. **Synthetic** — not a CMS official readmission measure (not HWR / CMS 30-day readmit).
2. Uses **`NCH_BENE_DSCHRG_DT`** for prior discharge when present (always populated on Sample 1 IP in this load); index event uses discharge else thru date.
3. Same-day repeats excluded (`BETWEEN 1 AND 30`).
4. No planned-readmit exclusion, no DRG/transfer logic, no death censoring.
5. Multiple segments / claim splits may create extra “stays”; SynPUF `SEGMENT` is retained on the fact for later cleanup if needed.
6. Dates can lag enrollment years; thru dates span late 2007 admissions discharging into 2008 through 2010-12-31.

## Object counts (after Phase 2 run)

| Object | Rows (approx.) |
|--------|----------------|
| `dim_member` | 116,352 |
| `dim_date` | 1,096 |
| `dim_claim_type` | 3 |
| `fact_claim` | 846,242 |
| `vw_monthly_volume` | 72 |
| `vw_high_utilizers` | ~4,339 |
| `vw_quality_flags` | 846,242 |
| `vw_kpi_summary` | 1 |

## BI exports

`scripts/export_processed.py` → `data/processed/`:

- `fact_claim.parquet` (full), `fact_claim_sample.parquet` (50k)
- `dim_member.parquet`, `dim_date.parquet`, `dim_claim_type.csv`
- `vw_monthly_volume.parquet`, `vw_high_utilizers.parquet`
- `vw_quality_flags_monthly.parquet` (rolled for size)
- `vw_kpi_summary.csv` / `.parquet`
