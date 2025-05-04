#!/usr/bin/env bash
set -euo pipefail

# Check if CIK parameter was provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <CIK>"
    echo "Example: $0 320193"
    exit 1
fi

# Get CIK from command line argument and pad with zeros if needed
CIK=$(printf "${1#CIK}")

# Setup variables
JSON="json/facts_CIK${CIK}.json"
URL="https://data.sec.gov/api/xbrl/companyfacts/CIK${CIK}.json"

echo "1) Downloading XBRL Company Facts JSON for CIK: ${CIK}..."
curl -sSL \
     -H "User-Agent: Your Name (your.email@example.com)" \
     "$URL" -o "$JSON"

echo "2) Querying the company facts data..."
duckdb edgar.db <<SQL
-- Company metadata
CREATE TABLE IF NOT EXISTS company_facts AS
SELECT *
FROM read_json_auto('$JSON', map_inference_threshold=0) LIMIT 0;
INSERT INTO company_facts
SELECT *
FROM read_json_auto('$JSON', map_inference_threshold=0);
SQL

echo "3) Dumping schema table..."
# Export the schema to a file in the schema directory
duckdb edgar.db <<SQL
DESCRIBE company_facts;
.mode list
.separator |
.headers off
.once schema/company_facts
DESCRIBE company_facts;
SQL

echo "Done! Company facts data for CIK${CIK} has been processed"
