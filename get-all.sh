#!/usr/bin/env bash
set -euo pipefail

# This script runs all data retrieval scripts for a specified CIK
# with common examples for various data types

# Check if CIK parameter was provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <CIK>"
    echo "Example: $0 320193"
    exit 1
fi

# Get CIK from command line argument and pad with zeros if needed
CIK=$(printf "%010d" "${1#CIK}")

# Create output directory for logs
mkdir -p logs

echo "=========================================================="
echo "Starting SEC EDGAR data import for CIK: ${CIK}"
echo "=========================================================="

# Run submissions import
echo "1. Running submissions import..."
./get-submissions.sh "$CIK" | tee logs/submissions_${CIK}.log

# Run common company concepts for the CIK
echo "2. Running company concepts imports..."
echo "   2.1. Importing Assets (us-gaap)..."
./get-company-concept.sh "$CIK" "us-gaap" "Assets" | tee logs/concept_assets_${CIK}.log

echo "   2.2. Importing Revenues (us-gaap)..."
./get-company-concept.sh "$CIK" "us-gaap" "Revenues" | tee logs/concept_revenues_${CIK}.log

echo "   2.3. Importing NetIncomeLoss (us-gaap)..."
./get-company-concept.sh "$CIK" "us-gaap" "NetIncomeLoss" | tee logs/concept_netincome_${CIK}.log

# Run company facts import
echo "3. Running company facts import..."
./get-company-facts.sh "$CIK" | tee logs/companyfacts_${CIK}.log

# Run frames imports for common financial metrics
echo "4. Running frames imports..."
echo "   4.1. Importing Assets frames (latest quarter)..."
./get-xbrl-frames.sh "us-gaap" "Assets" "USD" "CY2024Q1I" | tee logs/frames_assets_q1_2024.log

echo "   4.2. Importing Revenues frames (latest year)..."
./get-xbrl-frames.sh "us-gaap" "Revenues" "USD" "CY2023" | tee logs/frames_revenues_2023.log

echo "=========================================================="
echo "SEC EDGAR data import completed for CIK: ${CIK}"
echo "=========================================================="
echo "Logs are available in the logs directory"

# Get company name
COMPANY_NAME=$(duckdb edgar.db -csv -c "SELECT entityName FROM company_facts")
echo "Company: $COMPANY_NAME (CIK: $CIK)"
echo ""

echo "=========================================================="
echo "All data has been imported and sample report generated"
echo "To explore the data further, you can use DuckDB to directly query the JSON files"
echo "=========================================================="
