#!/usr/bin/env bash
set -euo pipefail

# Check if CIK parameter was provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <CIK>"
    echo "Example: $0 0000320193"
    exit 1
fi

# Get CIK from command line argument and pad with zeros if needed
CIK=$(printf "${1#CIK}")

# Setup variables
JSON="json/CIK${CIK}.json"
URL="https://data.sec.gov/submissions/CIK${CIK}.json"

echo "1) Downloading EDGAR Submissions JSON for CIK: ${CIK}..."
curl -sSL \
     -H "User-Agent: Your Name (your.email@example.com)" \
     "$URL" -o "$JSON"

echo "2) Querying the submissions data..."
duckdb edgar.db <<SQL
-- Basic entity information
CREATE TABLE IF NOT EXISTS submissions AS
SELECT *
FROM read_json_auto('$JSON', map_inference_threshold=0) LIMIT 0;
INSERT INTO submissions
SELECT *
FROM read_json_auto('$JSON', map_inference_threshold=0);
SQL

echo "3) Dumping schema table..."
# Export the schema to a file in the schema directory
duckdb edgar.db <<SQL
DESCRIBE submissions;
.mode list
.separator |
.headers off
.once schema/submissions
DESCRIBE submissions;
SQL

echo "Done! Submissions data for CIK${CIK} has been processed"
