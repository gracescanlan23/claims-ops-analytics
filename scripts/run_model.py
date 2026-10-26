#!/usr/bin/env python3
"""Apply sql/02_model.sql to claims.duckdb and print object counts."""
from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "claims.duckdb"
SQL = ROOT / "sql" / "02_model.sql"


def main() -> None:
    try:
        import duckdb
    except ImportError:
        print("Use project venv: .venv/bin/python scripts/run_model.py", file=sys.stderr)
        raise SystemExit(1)

    if not DB.exists():
        raise SystemExit(f"Missing {DB}. Run scripts/run_ingest.py first.")
    if not SQL.exists():
        raise SystemExit(f"Missing {SQL}")

    os.chdir(ROOT)
    print(f"Opening {DB}")
    con = duckdb.connect(str(DB))

    # Require staging
    tables = {r[0] for r in con.execute("SHOW TABLES").fetchall()}
    for need in ("stg_beneficiary", "stg_inpatient", "stg_outpatient"):
        if need not in tables:
            raise SystemExit(f"Missing staging table {need}")

    print(f"Running {SQL.relative_to(ROOT)} ...")
    con.execute(SQL.read_text(encoding="utf-8"))

    objects = [
        "dim_member",
        "dim_date",
        "dim_claim_type",
        "fact_claim",
        "vw_monthly_volume",
        "vw_high_utilizers",
        "vw_quality_flags",
        "vw_kpi_summary",
    ]
    print("\nObject row counts:")
    for name in objects:
        n = con.execute(f"SELECT COUNT(*) FROM {name}").fetchone()[0]
        print(f"  {name:22s} {n:>12,}")

    print("\nKPI snapshot:")
    cols = [d[0] for d in con.execute("DESCRIBE vw_kpi_summary").fetchall()]
    # Cast timestamp to varchar to avoid optional pytz dependency
    sel = ", ".join(
        f"CAST({c} AS VARCHAR)" if c == "as_of_ts" else c for c in cols
    )
    vals = con.execute(f"SELECT {sel} FROM vw_kpi_summary").fetchone()
    for col, val in zip(cols, vals):
        print(f"  {col}: {val}")

    con.close()
    print("\nDone.")


if __name__ == "__main__":
    main()
