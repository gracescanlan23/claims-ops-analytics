#!/usr/bin/env python3
"""Export BI-ready parquet/CSV extracts under data/processed/."""
from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "claims.duckdb"
OUT = ROOT / "data" / "processed"


def main() -> None:
    import duckdb

    os.chdir(ROOT)
    OUT.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB), read_only=True)

    # Full marts (small)
    exports = [
        ("vw_monthly_volume", "vw_monthly_volume.parquet"),
        ("vw_kpi_summary", "vw_kpi_summary.parquet"),
        ("vw_kpi_summary", "vw_kpi_summary.csv"),
        ("dim_claim_type", "dim_claim_type.csv"),
        ("dim_member", "dim_member.parquet"),
        ("vw_high_utilizers", "vw_high_utilizers.parquet"),
    ]
    for src, fname in exports:
        path = OUT / fname
        if fname.endswith(".csv"):
            con.execute(f"COPY (SELECT * FROM {src}) TO '{path.as_posix()}' (HEADER, DELIMITER ',')")
        else:
            con.execute(f"COPY (SELECT * FROM {src}) TO '{path.as_posix()}' (FORMAT PARQUET)")
        print(f"wrote {path} ({path.stat().st_size:,} bytes)")

    # Quality flags: aggregate for BI size (claim-level full set is large)
    path = OUT / "vw_quality_flags_monthly.parquet"
    con.execute(
        f"""
        COPY (
          SELECT
            month_start,
            claim_type,
            COUNT(*) AS claims,
            SUM(flag_ip_30d_bounce::INT) AS ip_30d_bounce,
            SUM(flag_high_op_density::INT) AS high_op_density,
            SUM(flag_cost_outlier::INT) AS cost_outlier,
            SUM(flag_missing_primary_dx::INT) AS missing_primary_dx,
            SUM(any_flag::INT) AS any_flag
          FROM vw_quality_flags
          GROUP BY 1, 2
        ) TO '{path.as_posix()}' (FORMAT PARQUET)
        """
    )
    print(f"wrote {path} ({path.stat().st_size:,} bytes)")

    # fact_claim sample for dashboard prototyping (~50k rows) + monthly rollup already above
    path = OUT / "fact_claim_sample.parquet"
    con.execute(
        f"""
        COPY (
          SELECT * FROM fact_claim
          USING SAMPLE 50000
        ) TO '{path.as_posix()}' (FORMAT PARQUET)
        """
    )
    print(f"wrote {path} ({path.stat().st_size:,} bytes)")

    # Also full fact as parquet if under ~80MB compressed; SynPUF IP+OP ~857k rows — try it
    path = OUT / "fact_claim.parquet"
    con.execute(f"COPY (SELECT * FROM fact_claim) TO '{path.as_posix()}' (FORMAT PARQUET)")
    print(f"wrote {path} ({path.stat().st_size:,} bytes)")

    # dim_date
    path = OUT / "dim_date.parquet"
    con.execute(f"COPY (SELECT * FROM dim_date) TO '{path.as_posix()}' (FORMAT PARQUET)")
    print(f"wrote {path} ({path.stat().st_size:,} bytes)")

    con.close()
    print("Export done.")


if __name__ == "__main__":
    main()
