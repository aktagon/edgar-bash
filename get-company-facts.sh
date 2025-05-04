#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

# Check if CIK parameter was provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <CIK>"
    echo "Example: $0 320193    or   $0 0000320193   or   $0 CIK320193"
    exit 1
fi

CIK="$(pad_cik "$1")"
JSON="json/facts_CIK${CIK}.json"
URL="https://data.sec.gov/api/xbrl/companyfacts/CIK${CIK}.json"
UA="Your Name (your.email@example.com)"

probe_cacheability $URL

echo "1) Downloading XBRL Company Facts JSON for CIK: ${CIK}..."
fetch_edgar_url $URL

###############################################################################
# Query the company facts data with DuckDB
###############################################################################
echo "2) Querying the company facts data..."
run_query <<SQL
CREATE TABLE IF NOT EXISTS company_facts AS
SELECT *
FROM read_json_auto('${JSON}', map_inference_threshold=0) LIMIT 0;
INSERT INTO company_facts
SELECT *
FROM read_json_auto('${JSON}', map_inference_threshold=0);
SQL

###############################################################################
# 3) Dump the schema table
###############################################################################
echo "3) Dumping schema table..."
export_schema "company_facts"

echo "Done! Company facts data for CIK${CIK} has been processed"
