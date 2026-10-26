# Tableau Public build — one-page Claims Ops dashboard

**Suggested title:** *Medicare Claims Ops Monitor — Volume, Quality Flags & High Utilizers (CMS SynPUF 2008–2010)*

Time: ~1.5–2 h. Tool: [Tableau Public](https://public.tableau.com/app/discover) (free, Mac/Windows).
Inputs: `data/tableau/*.csv` (rebuild with `.venv/bin/python scripts/export_tableau.py`). All dates are ISO `YYYY-MM-DD`.

| File | Rows | Grain | Use |
|---|---|---|---|
| `vw_kpi_summary.csv` | 1 | whole dataset | KPI BANs |
| `vw_monthly_volume.csv` | 72 | month × claim_type | volume line |
| `vw_quality_flags_monthly.csv` | 72 | month × claim_type | flag trend |
| `vw_high_utilizers.csv` | 4,339 | member (≥ p95 paid) | table |
| `dim_claim_type.csv` | 3 | claim type | friendly labels |
| `dim_date.csv` | 1,096 | day | optional |
| `dim_member.csv` | 116,352 | member | optional drill |
| `fact_claim_slim.csv` | 846,242 | claim | optional drill / custom calcs |

## 1. Connect
1. Open Tableau Public → **Connect → To a File → Text file** → pick `data/tableau/vw_kpi_summary.csv`.
2. On the Data Source page, check types: `month_start` / `claim_thru_dt` = Date; `year`, `claim_year` = whole number — right-click `year` → *Convert to Dimension* later in sheets if needed.
3. Add the other files as **separate data sources** (Data → New Data Source → Text file) rather than one big model — the aggregates are already at different grains:
   - `vw_monthly_volume.csv`; then drag `dim_claim_type.csv` onto the canvas → **Relationship** `claim_type` = `claim_type_cd`.
   - `vw_quality_flags_monthly.csv` (also relate `dim_claim_type` the same way, optional).
   - `vw_high_utilizers.csv`.
   - Optional: `fact_claim_slim.csv` related to `dim_member.csv` on `member_id` and `dim_date.csv` on `thru_date_key` = `date_key`. Note `dim_member` has one row per member (latest snapshot).
4. Use **Extract** (top right of Data Source page). Tableau Public requires extracts anyway.

## 2. Calculated fields (exact syntax)
In `vw_kpi_summary`:
```
// Paid per Member
SUM([total_paid]) / SUM([unique_members])

// Flagged Rate   (format as Percentage, 1 decimal)
SUM([flagged_claims]) / SUM([total_claims])

// IP Share       (format as Percentage)
SUM([ip_claims]) / SUM([total_claims])
```
(`ip_share_pct` and `pct_claims_flagged` already exist as numbers like 7.88 / 20.33 — fine for BANs with a "%" suffix; the calcs above are the "proper" ratio versions.)

In `vw_quality_flags_monthly`:
```
// Flag Rate (monthly)
SUM([any_flag_claims]) / SUM([claim_count])

// IP 30d Bounce Rate (IP claims only)
SUM(IF [claim_type] = "IP" THEN [ip_30d_bounce_claims] END)
  / SUM(IF [claim_type] = "IP" THEN [claim_count] END)
```
In `vw_monthly_volume`:
```
// Paid per Claim
SUM([total_paid]) / SUM([claim_count])
```
In `fact_claim_slim` (optional):
```
// Paid per Member
SUM([paid_amt]) / COUNTD([member_id])
```

## 3. Sheets
**KPI BANs (5 sheets, source `vw_kpi_summary`)** — one each: `unique_members` (Members, 86,705), `total_paid` (Total Paid, format Currency, Units = Millions → $847.3M), `IP Share` (7.9%), `avg_ip_los` (Avg IP LOS, 5.58 days), `Flagged Rate` (20.3%). Drag measure to **Text** on the Marks card, set font ~28 pt, put the label in the sheet title. Optional 6th: `Paid per Member`.

**Monthly claim volume (`vw_monthly_volume`)** — Columns: `month_start` → right-click → *Month* (continuous, green). Rows: `SUM(claim_count)`. Color: `claim_type_desc` (or `claim_type`). Mark: Line. Tip: IP is ~10× smaller than OP — use *Dual Axis* or put `claim_type` on Rows for two panes with independent axes (right-click axis → *Edit Axis → Independent*).

**Quality-flag trend (`vw_quality_flags_monthly`)** — Columns: continuous Month of `month_start`. Rows: `Flag Rate (monthly)`. Color: `claim_type`. Alternative: Measure Names/Values with `ip_30d_bounce_claims`, `high_op_density_claims`, `cost_outlier_claims`, `missing_primary_dx_claims` as stacked bars.

**High-utilizer table (`vw_high_utilizers`)** — Rows: `member_id`, `age_band`, `sex`, `state_code`. Text: `total_paid`, `claim_count`, `ip_claims`, `chronic_count`. Sort by `total_paid` descending; drag `total_paid` to Filters → *Top* → Top 25 by SUM(total_paid). Title it "Top 25 High Utilizers (≥ p95 paid)".

## 4. Filters
- **Year**: on the volume sheet drag `year` to Filters → *Show Filter*; dropdown → *Apply to Worksheets → All Using Related Data Sources* (or *Selected Worksheets* → pick the flag sheet; if prompted, map `year` across sources via Data → Edit Blend Relationships).
- **Claim type**: same with `claim_type`, applied to volume + flag sheets.
- KPI BANs and the high-utilizer table are whole-period; note this in subtitles ("All years, 2008–2010").

## 5. Dashboard
1. New Dashboard, Size → *Fixed* 1366 × 900 (or Automatic).
2. Layout: Title text object (suggested title above) → row of 5 BANs (horizontal container) → volume line + flag trend side by side → high-utilizer table at bottom. Filters at top-right.
3. Footnote text object: *"Data: CMS 2008–2010 DE-SynPUF Sample 1 — synthetic Medicare claims, not real patients. Flags are analytical proxies (30-day IP bounce, high OP density, cost outlier, missing primary dx). Built by Grace Scanlan."*

## 6. Publish + screenshot
1. **File → Save to Tableau Public As…** → sign in (free account) → name `Claims Ops Monitor`. It opens in your browser; copy the URL.
2. Screenshot (Mac: `Cmd+Shift+4`, drag) → save as `dashboard/dashboard.png` in the project folder.
3. Add the public URL + screenshot to `README.md`, then commit.

## Ops insights to echo on the dashboard (optional caption)
- 4,339 high utilizers (~5% of members) drive ~33.8% of paid.
- IP 30-day bounce proxy ≈ 10.9%.
- OP volume +14% (2008→2009), OP paid +22%.
