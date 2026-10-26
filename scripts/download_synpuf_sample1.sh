#!/usr/bin/env bash
# Reproducible download of CMS DE-SynPUF Sample 1 (beneficiary + IP + OP).
# Carrier/PDE skipped for laptop-demo size.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$ROOT/data/raw"
mkdir -p "$RAW"
cd "$RAW"

CMS="https://www.cms.gov/Research-Statistics-Data-and-Systems/Downloadable-Public-Use-Files/SynPUFs/Downloads"
# Official CMS Sample-1 page mis-links 2010 beneficiary to Sample 20;
# use community mirror from OHDSI ETL-CMS issue #62 for that file only.
OHDSI_2010="https://github.com/OHDSI/ETL-CMS/files/4932398/DE1_0_2010_Beneficiary_Summary_File_Sample_1.zip"

download() {
  local url="$1" out="$2"
  if [[ -f "$out" ]]; then
    echo "skip (exists): $out"
    return 0
  fi
  echo "GET $url"
  curl -fL --retry 3 --retry-delay 2 -A "Mozilla/5.0" -o "$out" "$url"
}

download "$CMS/DE1_0_2008_Beneficiary_Summary_File_Sample_1.zip" \
  "DE1_0_2008_Beneficiary_Summary_File_Sample_1.zip"
download "$CMS/DE1_0_2009_Beneficiary_Summary_File_Sample_1.zip" \
  "DE1_0_2009_Beneficiary_Summary_File_Sample_1.zip"
download "$OHDSI_2010" \
  "DE1_0_2010_Beneficiary_Summary_File_Sample_1.zip"
download "$CMS/DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.zip" \
  "DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.zip"
download "$CMS/DE1_0_2008_to_2010_Outpatient_Claims_Sample_1.zip" \
  "DE1_0_2008_to_2010_Outpatient_Claims_Sample_1.zip"

for z in \
  DE1_0_2008_Beneficiary_Summary_File_Sample_1.zip \
  DE1_0_2009_Beneficiary_Summary_File_Sample_1.zip \
  DE1_0_2010_Beneficiary_Summary_File_Sample_1.zip \
  DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.zip \
  DE1_0_2008_to_2010_Outpatient_Claims_Sample_1.zip
do
  echo "unzip $z"
  unzip -o -q "$z"
done

shopt -s nullglob
for f in *" - Copy.csv"; do
  mv "$f" "${f/ - Copy.csv/.csv}"
done

echo "Done. CSVs in $RAW:"
ls -lh *.csv
