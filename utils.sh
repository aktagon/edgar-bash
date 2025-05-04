#!/usr/bin/env bash
# utils.sh – utility routines for EDGAR tooling
# shellcheck shell=bash

###############################################################################
# pad_cik <raw_cik_or_ciklike_string>
# Normalises the argument to a 10‑digit zero‑padded CIK.
#
# Accepts:
#   - "CIK##########", "##########", "0000########", etc.
# Returns (stdout):
#   - normalised 10‑character CIK, e.g. 0000320193
###############################################################################
pad_cik() {
    local raw="${1^^}"            # upper‑case copy for prefix test
    raw="${raw#CIK}"              # drop literal “CIK” if present
    raw="${raw#"${raw%%[1-9]*}"}" # strip all leading zeros
    printf "%010s\n" "$raw" | tr ' ' '0'
}

###############################################################################
# probe_cacheability <url>
# Tests whether the resource at <url> supports caching.
#
# Reads the User‑Agent string from environment variable EDGAR_UA.
# Prints one of:
#   CACHEABLE: <matching‑headers>
#   NOT CACHEABLE
#
# Exit status:
#   0 – cacheable headers found
#   1 – no cache headers
#   2 – usage error
#   3 – curl failure
###############################################################################
probe_cacheability() {
    # ---- Environment sanity ----
    : "${EDGAR_UA:?Set EDGAR_UA to a valid User‑Agent string}"

    # ---- Parameter check ----
    if [ "$#" -ne 1 ]; then
        echo "Usage: probe_cacheability <URL>" >&2
        return 2
    fi
    local url="$1"

    # ---- Fetch headers ----
    local headers matches
    if ! headers="$(curl -sI -H "User-Agent: ${EDGAR_UA}" -H "Range: bytes=0-0" "$url")"; then
        return 3
    fi

    # ---- Evaluate ----
    matches="$(printf '%s\n' "$headers" | grep -iE '^(ETag|Last-Modified|Cache-Control):')"

    if [ -n "$matches" ]; then
        printf 'Cache headers: %s\n' "$(printf '%s' "$matches" | tr '\n' ' ' | sed 's/[[:space:]]\+$//')"
        return 0
    else
        return 1
    fi
}

###############################################################################
# fetch_edgar_url <url> <output_file>
# Downloads a single EDGAR resource whose full URL is supplied by the caller.
#
# Accepts:
#   - Fully-qualified EDGAR URL (mandatory).
#   - Output filename (now mandatory).
# Uses:
#   - EDGAR_UA environment variable for the mandatory SEC-compliant User-Agent.
# Exit status:
#   0  – success
#   1  – EDGAR_UA not set
#   2  – usage error
#   3  – curl failure
###############################################################################
fetch_edgar_url() {
    # ---- Environment sanity ----
    : "${EDGAR_UA:?Set EDGAR_UA to a valid User-Agent string}"

    # ---- Parameter check ----
    if [ "$#" -ne 2 ]; then
        echo "Usage: fetch_edgar_url <URL> <output_file>" >&2
        return 2
    fi

    local url="$1"
    local out="$2"

    echo "Downloading EDGAR resource: ${url}"
    if ! curl -sSL -H "User-Agent: ${EDGAR_UA}" "${url}" -o "${out}"; then
        echo "Error: failed to download ${url}" >&2
        return 3
    fi

    echo "Saved to ${out}"
    return 0
}


###############################################################################
# run_query
# Executes SQL read from stdin against the local DuckDB database.
#
# Usage:
#   run_query <<SQL
#     CREATE TABLE IF NOT EXISTS company_facts AS
#       SELECT * FROM read_json_auto('${JSON}', map_inference_threshold=0) LIMIT 0;
#     INSERT INTO company_facts
#       SELECT * FROM read_json_auto('${JSON}', map_inference_threshold=0);
#   SQL
#
# Environment:
#   - EDGAR_DB: path to the DuckDB file (defaults to "edgar.db")
#
# Exit status:
#   0 – queries succeeded
#   2 – usage error (no SQL on stdin)
#   3 – duckdb CLI not found
###############################################################################
run_query() {
    # ---- Dependency check ----
    command -v duckdb >/dev/null 2>&1 || { echo "duckdb CLI not on PATH" >&2; return 3; }

    # ---- Ensure SQL on stdin ----
    if [ -t 0 ]; then
        echo "Usage: run_query <<SQL" >&2
        return 2
    fi

    local db="${EDGAR_DB:-edgar.db}"

    # ---- Execute SQL from stdin ----
    duckdb "$db"
}

###############################################################################
# export_schema <table_name> [output_dir]
# Writes the CREATE TABLE DDL for <table_name> into “db-schemas/<table_name>.sql”.
#
# Accepts:
#   - table_name      – required DuckDB table to be scripted
#   - output_dir      – optional target directory (default: db-schemas)
#
# Uses:
#   - EDGAR_DB        – path to DuckDB file (default: edgar.db)
#
# Exit status:
#   0  – schema written successfully
#   2  – usage error (missing argument)
#   3  – duckdb CLI not found
###############################################################################
export_schema() {
    # ---- Dependency check ----
    command -v duckdb >/dev/null 2>&1 || { echo "duckdb CLI not on PATH" >&2; return 3; }

    # ---- Parameter check ----
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "Usage: export_schema <table_name> [output_dir]" >&2
        return 2
    fi

    local table="$1"
    local outdir="${2:-db-schemas}"
    local db="${EDGAR_DB:-edgar.db}"
    local outfile="${outdir}/${table}.sql"

    mkdir -p "$outdir"

    # ---- Fetch DDL via PRAGMA and write to file ----
    duckdb "$db" -noheader -csv -c "SELECT sql FROM sqlite_master WHERE type='table' AND name='${table}';" > "$outfile"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo "Error: failed to export DDL for '${table}'" >&2
        return 4
    fi

    echo "DDL for '${table}' saved to ${outfile}"
    return 0
}
