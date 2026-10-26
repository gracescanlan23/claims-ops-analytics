#!/usr/bin/env python3
"""Create claims.duckdb and run sql/01_ingest.sql from the project root."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

try:
    import duckdb
except ImportError:
    print("duckdb not installed. Use project venv: .venv/bin/python scripts/run_ingest.py", file=sys.stderr)
    raise SystemExit(1)

DB = ROOT / "claims.duckdb"
SQL = ROOT / "sql" / "01_ingest.sql"


def main() -> None:
    if not SQL.exists():
        raise SystemExit(f"Missing {SQL}")
    required = [
        ROOT / "data/raw/DE1_0_2008_Beneficiary_Summary_File_Sample_1.csv",
        ROOT / "data/raw/DE1_0_2009_Beneficiary_Summary_File_Sample_1.csv",
        ROOT / "data/raw/DE1_0_2010_Beneficiary_Summary_File_Sample_1.csv",
        ROOT / "data/raw/DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.csv",
        ROOT / "data/raw/DE1_0_2008_to_2010_Outpatient_Claims_Sample_1.csv",
    ]
    missing = [str(p) for p in required if not p.exists()]
    if missing:
        raise SystemExit(
            "Missing raw CSVs. Run: bash scripts/download_synpuf_sample1.sh\n"
            + "\n".join(missing)
        )

    print(f"Opening {DB}")
    con = duckdb.connect(str(DB))
    # Ensure relative paths in SQL resolve from project root
    import os

    os.chdir(ROOT)
    sql_text = SQL.read_text(encoding="utf-8")
    print(f"Running {SQL.relative_to(ROOT)} ...")
    con.execute(sql_text)

    print("\nRow counts:")
    rows = con.execute(
        """
        SELECT 'stg_beneficiary' AS table_name, COUNT(*) AS n FROM stg_beneficiary
        UNION ALL SELECT 'stg_inpatient', COUNT(*) FROM stg_inpatient
        UNION ALL SELECT 'stg_outpatient', COUNT(*) FROM stg_outpatient
        ORDER BY 1
        """
    ).fetchall()
    for name, n in rows:
        print(f"  {name:20s} {n:>12,}")

    print("\nDate ranges (claim from/thru where present):")
    for tbl, col in [
        ("stg_inpatient", "CLM_FROM_DT"),
        ("stg_inpatient", "CLM_THRU_DT"),
        ("stg_outpatient", "CLM_FROM_DT"),
        ("stg_outpatient", "CLM_THRU_DT"),
    ]:
        mn, mx = con.execute(
            f"SELECT MIN({col}), MAX({col}) FROM {tbl} WHERE {col} IS NOT NULL"
        ).fetchone()
        print(f"  {tbl}.{col}: {mn} .. {mx}")

    bene_years = con.execute(
        "SELECT bene_year, COUNT(*) FROM stg_beneficiary GROUP BY 1 ORDER BY 1"
    ).fetchall()
    print("\nBeneficiary rows by year:")
    for y, n in bene_years:
        print(f"  {y}: {n:,}")

    con.close()
    print(f"\nDone. Database: {DB}")


if __name__ == "__main__":
    main()
