-- Phase 2: star schema + mart views on CMS DE-SynPUF Sample 1
-- Run from project root via scripts/run_model.py
-- Assumes staging tables from sql/01_ingest.sql already exist.

-- ---------------------------------------------------------------------------
-- Helpers: parse SynPUF YYYYMMDD integers to DATE
-- ---------------------------------------------------------------------------
CREATE OR REPLACE MACRO synpuf_date(d) AS
  CASE
    WHEN d IS NULL THEN NULL
    WHEN CAST(d AS BIGINT) < 19000101 OR CAST(d AS BIGINT) > 21001231 THEN NULL
    ELSE TRY_CAST(
      strptime(lpad(CAST(CAST(d AS BIGINT) AS VARCHAR), 8, '0'), '%Y%m%d') AS DATE
    )
  END;

-- ===========================================================================
-- DIMENSIONS
-- ===========================================================================

-- dim_member: ONE ROW PER MEMBER (latest bene_year for DESYNPUF_ID).
-- Rationale: BI member grain for unique_members / utilizer marts; chronic flags
-- and demographics from the most recent annual summary snapshot.
CREATE OR REPLACE TABLE dim_member AS
WITH ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY DESYNPUF_ID ORDER BY bene_year DESC) AS rn
  FROM stg_beneficiary
),
base AS (
  SELECT * FROM ranked WHERE rn = 1
)
SELECT
  DESYNPUF_ID AS member_id,
  bene_year AS snapshot_year,
  synpuf_date(BENE_BIRTH_DT) AS birth_dt,
  synpuf_date(BENE_DEATH_DT) AS death_dt,
  -- Age as of Dec 31 of snapshot year
  CASE
    WHEN synpuf_date(BENE_BIRTH_DT) IS NULL THEN NULL
    ELSE date_diff(
      'year',
      synpuf_date(BENE_BIRTH_DT),
      MAKE_DATE(bene_year, 12, 31)
    )
  END AS age_yrs,
  CASE
    WHEN synpuf_date(BENE_BIRTH_DT) IS NULL THEN 'Unknown'
    WHEN date_diff('year', synpuf_date(BENE_BIRTH_DT), MAKE_DATE(bene_year, 12, 31)) < 65
      THEN '<65'
    WHEN date_diff('year', synpuf_date(BENE_BIRTH_DT), MAKE_DATE(bene_year, 12, 31)) BETWEEN 65 AND 74
      THEN '65-74'
    WHEN date_diff('year', synpuf_date(BENE_BIRTH_DT), MAKE_DATE(bene_year, 12, 31)) BETWEEN 75 AND 84
      THEN '75-84'
    ELSE '85+'
  END AS age_band,
  CASE BENE_SEX_IDENT_CD
    WHEN 1 THEN 'Male'
    WHEN 2 THEN 'Female'
    ELSE 'Unknown'
  END AS sex,
  SP_STATE_CODE AS state_code,
  BENE_COUNTY_CD AS county_code,
  BENE_ESRD_IND AS esrd_ind,
  -- Dual proxy: Part D plan months present (not true dual-eligible flag in SynPUF)
  TRY_CAST(PLAN_CVRG_MOS_NUM AS INTEGER) AS plan_coverage_months,
  BENE_HI_CVRAGE_TOT_MONS AS part_a_months,
  BENE_SMI_CVRAGE_TOT_MONS AS part_b_months,
  BENE_HMO_CVRAGE_TOT_MONS AS hmo_months,
  -- SP_* : 1 = condition present, 2 = absent (CMS SynPUF codebook)
  (SP_ALZHDMTA = 1) AS has_alzheimers,
  (SP_CHF = 1) AS has_chf,
  (SP_CHRNKIDN = 1) AS has_ckd,
  (SP_CNCR = 1) AS has_cancer,
  (SP_COPD = 1) AS has_copd,
  (SP_DEPRESSN = 1) AS has_depression,
  (SP_DIABETES = 1) AS has_diabetes,
  (SP_ISCHMCHT = 1) AS has_ischemic_heart,
  (SP_OSTEOPRS = 1) AS has_osteoporosis,
  (SP_RA_OA = 1) AS has_ra_oa,
  (SP_STRKETIA = 1) AS has_stroke,
  (
    (SP_ALZHDMTA = 1)::INT + (SP_CHF = 1)::INT + (SP_CHRNKIDN = 1)::INT
    + (SP_CNCR = 1)::INT + (SP_COPD = 1)::INT + (SP_DEPRESSN = 1)::INT
    + (SP_DIABETES = 1)::INT + (SP_ISCHMCHT = 1)::INT + (SP_OSTEOPRS = 1)::INT
    + (SP_RA_OA = 1)::INT + (SP_STRKETIA = 1)::INT
  ) AS chronic_count
FROM base;

CREATE OR REPLACE TABLE dim_claim_type AS
SELECT * FROM (VALUES
  ('IP', 'Inpatient', TRUE),
  ('OP', 'Outpatient', TRUE),
  ('CAR', 'Carrier (professional)', FALSE)
) AS t(claim_type_cd, claim_type_desc, in_scope);

-- dim_date: daily spine from min claim thru to max claim thru (IP+OP)
CREATE OR REPLACE TABLE dim_date AS
WITH bounds AS (
  SELECT
    MIN(d) AS d_min,
    MAX(d) AS d_max
  FROM (
    SELECT synpuf_date(CLM_THRU_DT) AS d FROM stg_inpatient WHERE CLM_THRU_DT IS NOT NULL
    UNION ALL
    SELECT synpuf_date(CLM_THRU_DT) AS d FROM stg_outpatient WHERE CLM_THRU_DT IS NOT NULL
  )
),
spine AS (
  SELECT UNNEST(generate_series(d_min, d_max, INTERVAL 1 DAY))::DATE AS dt
  FROM bounds
)
SELECT
  CAST(strftime(dt, '%Y%m%d') AS INTEGER) AS date_key,
  dt AS calendar_date,
  YEAR(dt) AS year,
  QUARTER(dt) AS quarter,
  MONTH(dt) AS month,
  DATE_TRUNC('month', dt)::DATE AS month_start,
  strftime(dt, '%Y-%m') AS year_month,
  DAYOFWEEK(dt) AS dow,          -- 0=Sun in DuckDB
  DAYNAME(dt) AS day_name,
  (MONTH(dt) IN (1, 2, 3) AND DAY(dt) = 1) AS is_qtr_start
FROM spine;

-- ===========================================================================
-- FACT
-- ===========================================================================

CREATE OR REPLACE TABLE fact_claim AS
WITH ip AS (
  SELECT
    CAST(CLM_ID AS VARCHAR) AS claim_id,
    DESYNPUF_ID AS member_id,
    'IP' AS claim_type,
    synpuf_date(CLM_FROM_DT) AS claim_from_dt,
    synpuf_date(CLM_THRU_DT) AS claim_thru_dt,
    synpuf_date(CLM_ADMSN_DT) AS admit_dt,
    synpuf_date(NCH_BENE_DSCHRG_DT) AS discharge_dt,
    CLM_PMT_AMT AS paid_amt,
    CLM_UTLZTN_DAY_CNT AS los_days,
    NULLIF(TRIM(ICD9_DGNS_CD_1), '') AS primary_dx,
    PRVDR_NUM AS provider_num,
    SEGMENT AS segment
  FROM stg_inpatient
),
op AS (
  SELECT
    CAST(CLM_ID AS VARCHAR) AS claim_id,
    DESYNPUF_ID AS member_id,
    'OP' AS claim_type,
    synpuf_date(CLM_FROM_DT) AS claim_from_dt,
    synpuf_date(CLM_THRU_DT) AS claim_thru_dt,
    CAST(NULL AS DATE) AS admit_dt,
    CAST(NULL AS DATE) AS discharge_dt,
    CLM_PMT_AMT AS paid_amt,
    CAST(NULL AS BIGINT) AS los_days,
    NULLIF(TRIM(ICD9_DGNS_CD_1), '') AS primary_dx,
    PRVDR_NUM AS provider_num,
    SEGMENT AS segment
  FROM stg_outpatient
),
u AS (
  SELECT * FROM ip
  UNION ALL BY NAME
  SELECT * FROM op
)
SELECT
  u.claim_id,
  u.member_id,
  u.claim_type,
  u.claim_from_dt,
  u.claim_thru_dt,
  u.admit_dt,
  u.discharge_dt,
  u.paid_amt,
  u.los_days,
  u.primary_dx,
  u.provider_num,
  u.segment,
  CAST(strftime(u.claim_thru_dt, '%Y%m%d') AS INTEGER) AS thru_date_key,
  YEAR(u.claim_thru_dt) AS claim_year,
  MONTH(u.claim_thru_dt) AS claim_month,
  DATE_TRUNC('month', u.claim_thru_dt)::DATE AS month_start
FROM u
WHERE u.claim_thru_dt IS NOT NULL;

-- ===========================================================================
-- MART VIEWS
-- ===========================================================================

CREATE OR REPLACE VIEW vw_monthly_volume AS
SELECT
  month_start,
  claim_year AS year,
  claim_month AS month,
  claim_type,
  COUNT(*) AS claim_count,
  COUNT(DISTINCT member_id) AS unique_members,
  ROUND(SUM(COALESCE(paid_amt, 0)), 2) AS total_paid
FROM fact_claim
GROUP BY 1, 2, 3, 4;

-- High utilizers: top ~5% of members by total paid across all claim types.
-- Threshold = 95th percentile of member-level total_paid (documented).
CREATE OR REPLACE VIEW vw_high_utilizers AS
WITH member_tot AS (
  SELECT
    member_id,
    COUNT(*) AS claim_count,
    ROUND(SUM(COALESCE(paid_amt, 0)), 2) AS total_paid,
    SUM(CASE WHEN claim_type = 'IP' THEN 1 ELSE 0 END) AS ip_claims,
    SUM(CASE WHEN claim_type = 'OP' THEN 1 ELSE 0 END) AS op_claims
  FROM fact_claim
  GROUP BY 1
),
thresh AS (
  SELECT QUANTILE_CONT(total_paid, 0.95) AS paid_p95
  FROM member_tot
)
SELECT
  m.member_id,
  m.claim_count,
  m.total_paid,
  m.ip_claims,
  m.op_claims,
  t.paid_p95 AS threshold_paid_p95,
  dm.age_band,
  dm.sex,
  dm.chronic_count,
  dm.state_code
FROM member_tot m
CROSS JOIN thresh t
LEFT JOIN dim_member dm ON dm.member_id = m.member_id
WHERE m.total_paid >= t.paid_p95;

-- Quality / ops flags (claim-level with member context where needed)
CREATE OR REPLACE VIEW vw_quality_flags AS
WITH ip_ordered AS (
  SELECT
    claim_id,
    member_id,
    claim_thru_dt,
    discharge_dt,
    LAG(discharge_dt) OVER (
      PARTITION BY member_id
      ORDER BY COALESCE(discharge_dt, claim_thru_dt), claim_id
    ) AS prev_discharge_dt
  FROM fact_claim
  WHERE claim_type = 'IP'
),
ip_bounce AS (
  SELECT
    claim_id,
    member_id,
    prev_discharge_dt,
    COALESCE(discharge_dt, claim_thru_dt) AS this_event_dt,
    date_diff(
      'day',
      prev_discharge_dt,
      COALESCE(discharge_dt, claim_thru_dt)
    ) AS days_since_prior_discharge
  FROM ip_ordered
  WHERE prev_discharge_dt IS NOT NULL
    AND date_diff(
          'day',
          prev_discharge_dt,
          COALESCE(discharge_dt, claim_thru_dt)
        ) BETWEEN 1 AND 30
),
op_year AS (
  SELECT
    member_id,
    claim_year,
    COUNT(*) AS op_claims_yr
  FROM fact_claim
  WHERE claim_type = 'OP'
  GROUP BY 1, 2
),
op_thresh AS (
  SELECT
    claim_year,
    QUANTILE_CONT(op_claims_yr, 0.95) AS op_p95
  FROM op_year
  GROUP BY 1
),
high_op_members AS (
  SELECT o.member_id, o.claim_year, o.op_claims_yr, t.op_p95
  FROM op_year o
  JOIN op_thresh t USING (claim_year)
  WHERE o.op_claims_yr >= t.op_p95
),
paid_thresh AS (
  SELECT
    claim_type,
    QUANTILE_CONT(paid_amt, 0.95) AS paid_p95
  FROM fact_claim
  WHERE paid_amt IS NOT NULL
  GROUP BY 1
)
SELECT
  f.claim_id,
  f.member_id,
  f.claim_type,
  f.claim_thru_dt,
  f.month_start,
  f.claim_year,
  f.paid_amt,
  f.primary_dx,
  -- 1) IP short-stay bounce proxy: subsequent IP within 1–30 days of prior IP discharge
  COALESCE(b.claim_id IS NOT NULL, FALSE) AS flag_ip_30d_bounce,
  b.days_since_prior_discharge,
  b.prev_discharge_dt,
  -- 2) High OP density: member's OP claim count in that year >= year-specific 95th pct
  COALESCE(h.member_id IS NOT NULL, FALSE) AS flag_high_op_density,
  h.op_claims_yr,
  h.op_p95 AS op_density_threshold,
  -- 3) Cost outlier within claim_type (>= 95th pct paid)
  COALESCE(f.paid_amt >= p.paid_p95, FALSE) AS flag_cost_outlier,
  p.paid_p95 AS cost_outlier_threshold,
  -- 4) Missing primary Dx
  (f.primary_dx IS NULL) AS flag_missing_primary_dx,
  (
    COALESCE(b.claim_id IS NOT NULL, FALSE)
    OR COALESCE(h.member_id IS NOT NULL, FALSE)
    OR COALESCE(f.paid_amt >= p.paid_p95, FALSE)
    OR (f.primary_dx IS NULL)
  ) AS any_flag
FROM fact_claim f
LEFT JOIN ip_bounce b ON f.claim_id = b.claim_id AND f.claim_type = 'IP'
LEFT JOIN high_op_members h
  ON f.member_id = h.member_id
 AND f.claim_year = h.claim_year
 AND f.claim_type = 'OP'
LEFT JOIN paid_thresh p ON f.claim_type = p.claim_type;

CREATE OR REPLACE VIEW vw_kpi_summary AS
WITH base AS (
  SELECT
    COUNT(*) AS total_claims,
    COUNT(DISTINCT member_id) AS unique_members,
    ROUND(SUM(COALESCE(paid_amt, 0)), 2) AS total_paid,
    SUM(CASE WHEN claim_type = 'IP' THEN 1 ELSE 0 END) AS ip_claims,
    SUM(CASE WHEN claim_type = 'OP' THEN 1 ELSE 0 END) AS op_claims,
    ROUND(AVG(CASE WHEN claim_type = 'IP' THEN los_days END), 2) AS avg_ip_los
  FROM fact_claim
),
flags AS (
  SELECT
    COUNT(*) AS flagged_claims,
    COUNT(*) * 1.0 / NULLIF((SELECT COUNT(*) FROM fact_claim), 0) AS pct_claims_flagged
  FROM vw_quality_flags
  WHERE any_flag
),
hu AS (
  SELECT COUNT(*) AS high_utilizer_members
  FROM vw_high_utilizers
)
SELECT
  b.total_claims,
  b.unique_members,
  b.total_paid,
  b.ip_claims,
  b.op_claims,
  ROUND(100.0 * b.ip_claims / NULLIF(b.total_claims, 0), 2) AS ip_share_pct,
  b.avg_ip_los,
  f.flagged_claims,
  ROUND(100.0 * f.pct_claims_flagged, 2) AS pct_claims_flagged,
  h.high_utilizer_members,
  CAST(now() AS TIMESTAMP) AS as_of_ts
FROM base b
CROSS JOIN flags f
CROSS JOIN hu h;
