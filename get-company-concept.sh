#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

# Check if required parameters were provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <CIK> <taxonomy> <concept>"
    echo "Example: $0 320193 us-gaap AccountsPayableCurrent"
    exit 1
fi

CIK="$(pad_cik "$1")"
TAXONOMY="$2"
CONCEPT="$3"

# Setup variables
JSON="json/${TAXONOMY}_${CONCEPT}_CIK${CIK}.json"
URL="https://data.sec.gov/api/xbrl/companyconcept/CIK${CIK}/${TAXONOMY}/${CONCEPT}.json"

probe_cacheability $URL

echo "1) Downloading XBRL Company Concept JSON for CIK: ${CIK}, Taxonomy: ${TAXONOMY}, Concept: ${CONCEPT}..."
fetch_edgar_url $URL

echo "2) Querying the concept data..."
run_query <<SQL
-- Concept metadata
CREATE TABLE IF NOT EXISTS company_concept AS
SELECT *
FROM read_json_auto('$JSON', map_inference_threshold=0) LIMIT 0;
INSERT INTO company_concept
SELECT *
FROM read_json_auto('$JSON', map_inference_threshold=0);
SQL

echo "3) Dumping schema table..."
export_schema "company_concept"

echo "Done! Company concept data for CIK${CIK} ${TAXONOMY}/${CONCEPT} has been processed"
