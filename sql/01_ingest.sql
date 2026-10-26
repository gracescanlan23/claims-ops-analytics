-- Phase 1: load CMS DE-SynPUF Sample 1 into staging tables.
-- Paths are relative to the project root (run via scripts/run_ingest.py).
-- Raw CSVs quote headers; DuckDB read_csv_auto handles that.

CREATE OR REPLACE TABLE stg_beneficiary AS
SELECT
  CAST(2008 AS INTEGER) AS bene_year,
  *
FROM read_csv_auto('data/raw/DE1_0_2008_Beneficiary_Summary_File_Sample_1.csv', header=true, sample_size=-1)
UNION ALL BY NAME
SELECT
  CAST(2009 AS INTEGER) AS bene_year,
  *
FROM read_csv_auto('data/raw/DE1_0_2009_Beneficiary_Summary_File_Sample_1.csv', header=true, sample_size=-1)
UNION ALL BY NAME
SELECT
  CAST(2010 AS INTEGER) AS bene_year,
  *
FROM read_csv_auto('data/raw/DE1_0_2010_Beneficiary_Summary_File_Sample_1.csv', header=true, sample_size=-1);

CREATE OR REPLACE TABLE stg_inpatient AS
SELECT *
FROM read_csv_auto('data/raw/DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.csv', header=true, sample_size=-1);

CREATE OR REPLACE TABLE stg_outpatient AS
SELECT *
FROM read_csv_auto('data/raw/DE1_0_2008_to_2010_Outpatient_Claims_Sample_1.csv', header=true, sample_size=-1);

-- Quick sanity checks (printed by run_ingest.py after this file runs)
