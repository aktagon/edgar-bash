#!/usr/bin/env bash
set -euo pipefail

# Check if required parameters were provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <CIK> <taxonomy> <concept>"
    echo "Example: $0 320193 us-gaap AccountsPayableCurrent"
    exit 1
fi

# Get parameters from command line arguments
CIK=$(printf "${1#CIK}")
TAXONOMY="$2"
CONCEPT="$3"

# Setup variables
JSON="json/${TAXONOMY}_${CONCEPT}_CIK${CIK}.json"
URL="https://data.sec.gov/api/xbrl/companyconcept/CIK${CIK}/${TAXONOMY}/${CONCEPT}.json"

echo "1) Downloading XBRL Company Concept JSON for CIK: ${CIK}, Taxonomy: ${TAXONOMY}, Concept: ${CONCEPT}..."
curl -sSL \
     -H "User-Agent: Your Name (your.email@example.com)" \
     "$URL" -o "$JSON"

echo "2) Querying the concept data..."
duckdb edgar.db <<SQL
-- Concept metadata
CREATE TABLE IF NOT EXISTS company_concept AS
SELECT *
FROM read_json_auto('$JSON', map_inference_threshold=0) LIMIT 0;
INSERT INTO company_concept
SELECT *
FROM read_json_auto('$JSON', map_inference_threshold=0);
SQL

echo "3) Dumping schema table..."
# Export the schema to a file in the schema directory
duckdb edgar.db <<SQL
DESCRIBE company_concept;
.mode list
.separator |
.headers off
.once schema/company_concept
DESCRIBE company_concept;
SQL

echo "Done! Company concept data for CIK${CIK} ${TAXONOMY}/${CONCEPT} has been processed"
