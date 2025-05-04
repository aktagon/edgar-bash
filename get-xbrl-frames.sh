#!/usr/bin/env bash
set -euo pipefail

# Check if parameters were provided
if [ $# -lt 4 ]; then
    echo "Usage: $0 <taxonomy> <tag> <unit> <period>"
    echo "Example: $0 us-gaap AccountsPayableCurrent USD CY2023Q1I"
    echo "Periods: CY#### (annual), CY####Q# (quarterly), CY####Q#I (instantaneous)"
    exit 1
fi

# Get parameters from command line arguments
TAXONOMY="$1"
TAG="$2"
UNIT="$3"
PERIOD="$4"

# Setup variables
JSON="json/${TAXONOMY}_${TAG}_${UNIT}_${PERIOD}.json"
URL="https://data.sec.gov/api/xbrl/frames/${TAXONOMY}/${TAG}/${UNIT}/${PERIOD}.json"

echo "1) Downloading XBRL Frames JSON for Taxonomy: ${TAXONOMY}, Tag: ${TAG}, Unit: ${UNIT}, Period: ${PERIOD}..."
curl -sSL \
     -H "User-Agent: Your Name (your.email@example.com)" \
     "$URL" -o "$JSON"

echo "2) Querying the frames data..."
duckdb edgar.db <<SQL
-- Frame metadata
CREATE TABLE IF NOT EXISTS xbrl_frames AS
SELECT
*
FROM read_json_auto('$JSON', map_inference_threshold=0) LIMIT 0;
INSERT INTO xbrl_frames
SELECT
*
FROM read_json_auto('$JSON', map_inference_threshold=0);
SQL

echo "3) Dumping schema table..."
# Export the schema to a file in the schema directory
duckdb edgar.db <<SQL
DESCRIBE xbrl_frames;
.mode list
.separator |
.headers off
.once schema/xbrl_frames
DESCRIBE xbrl_frames;
SQL

echo "Done! XBRL frame data for ${TAXONOMY}/${TAG}/${UNIT}/${PERIOD} has been processed"
