"""Export Tableau-ready CSVs (ISO dates) from claims.duckdb to data/tableau/."""
import duckdb, os
c = duckdb.connect(os.path.join(os.path.dirname(__file__), '..', 'claims.duckdb'), read_only=True)
out = os.path.join(os.path.dirname(__file__), '..', 'data', 'tableau'); os.makedirs(out, exist_ok=True)
q = {
 'vw_kpi_summary': "SELECT * FROM vw_kpi_summary",
 'vw_monthly_volume': "SELECT * FROM vw_monthly_volume ORDER BY month_start, claim_type",
 'vw_quality_flags_monthly': """SELECT month_start, claim_year AS year, claim_type,
   COUNT(*) AS claim_count,
   SUM(flag_ip_30d_bounce::INT) AS ip_30d_bounce_claims,
   SUM(flag_high_op_density::INT) AS high_op_density_claims,
   SUM(flag_cost_outlier::INT) AS cost_outlier_claims,
   SUM(flag_missing_primary_dx::INT) AS missing_primary_dx_claims,
   SUM(any_flag::INT) AS any_flag_claims,
   ROUND(SUM(paid_amt),2) AS total_paid
   FROM vw_quality_flags WHERE month_start IS NOT NULL GROUP BY ALL ORDER BY 1,3""",
 'vw_high_utilizers': "SELECT * FROM vw_high_utilizers ORDER BY total_paid DESC",
 'dim_claim_type': "SELECT * FROM dim_claim_type",
 'dim_date': "SELECT * FROM dim_date",
 'dim_member': "SELECT * FROM dim_member",
 'fact_claim_slim': """SELECT f.claim_id, f.member_id, f.claim_type, f.claim_thru_dt, f.thru_date_key,
   f.claim_year, f.month_start, ROUND(f.paid_amt,2) AS paid_amt, f.los_days,
   q.flag_ip_30d_bounce::INT AS flag_ip_30d_bounce, q.flag_high_op_density::INT AS flag_high_op_density,
   q.flag_cost_outlier::INT AS flag_cost_outlier, q.flag_missing_primary_dx::INT AS flag_missing_primary_dx,
   q.any_flag::INT AS any_flag
   FROM fact_claim f JOIN vw_quality_flags q USING (claim_id, claim_type, member_id)""",
}
for n, s in q.items():
    c.execute(f"COPY ({s}) TO '{out}/{n}.csv' (HEADER, DELIMITER ',', DATEFORMAT '%Y-%m-%d', TIMESTAMPFORMAT '%Y-%m-%d %H:%M:%S')")
    rows = c.execute(f"SELECT COUNT(*) FROM read_csv_auto('{out}/{n}.csv')").fetchone()[0]
    print(f"{n}.csv rows={rows} size={os.path.getsize(f'{out}/{n}.csv')/1e6:.2f} MB")
