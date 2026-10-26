# Ops insights (synthetic SynPUF Sample 1)

**Methods note:** All figures are from CMS DE-SynPUF Sample 1 (2008–2010), synthetic public data. Use for portfolio demo and process design only — not population inference about Medicare beneficiaries. 2010 volumes are lower than 2008–2009 in this sample (common SynPUF truncation); YoY comments focus on 2008→2009.

## Three insights for ops

1. **Volume — outpatient drove the ramp.** Outpatient claims rose **~14%** from 2008 (281,901) to 2009 (322,631), with OP paid rising from **$72.4M → $88.1M**. Inpatient volume was roughly flat-to-down over the same window. **Ops action:** staff and prior-auth capacity should track OP channel growth first; watch monthly OP mix on the dashboard before adding IP bed assumptions.

2. **Quality — ~1 in 11 IP stays has a 30-day bounce proxy.** Among 66,705 IP claims, **7,251 (10.9%)** had another IP admission within 1–30 days of the prior discharge date (`flag_ip_30d_bounce`). This is a SynPUF proxy, not CMS Hospital-Wide Readmission. **Ops / QI action:** pull the bounce cohort by primary Dx and age band from `vw_quality_flags` for pathway and post-discharge follow-up review.

3. **Cost / util — top ~5% of members ≈ 34% of paid.** **4,339** high-utilizer members (paid ≥ P95, ~$41.8k) are **5.0%** of members with claims but account for **~33.8%** of total paid ($847M warehouse total). **Ops action:** use `vw_high_utilizers` as a case-management triage list (sort by `total_paid`, chronic_count, IP share).

## Supporting KPIs (`vw_kpi_summary`)

| Metric | Value |
|--------|------:|
| Total claims | 846,242 |
| Unique members with claims | 86,705 |
| Total paid | $847.3M |
| IP share of claims | 7.88% |
| Avg IP LOS | 5.58 days |
| % claims with any quality flag | 20.33% |
| High utilizers | 4,339 |

## Flag hit counts

| Flag | Claims |
|------|-------:|
| IP 30d bounce | 7,251 |
| High OP density (year P95) | 135,263 |
| Cost outlier (type P95) | 43,970 |
| Missing primary Dx | 50 |
