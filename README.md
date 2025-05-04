# SEC EDGAR Bash

Tiny collection of bash scripts for downloading and querying public filings
straight from the SEC Data API. The scripts writes raw JSON into **json/**
and/or imports it into **DuckDB** for further exploration.

---

## Prerequisites

- **bash+**, **curl**, **duckdb+**
- export **`EDGAR_UA`** to a descriptive User‑Agent string (SEC requirement)

```bash
export EDGAR_UA="ACME Corp research bot (contact: data‑team@acme.com)"
```

---

## Script overview

| Script                     | What it fetches                                                                                                        | Minimal usage                                              |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| **get-submissions.sh**     | Entire _submissions_ feed (company‑wide filing history).                                                               | `./get-submissions.sh <CIK>`                               |
| **get-company-concept.sh** | Time‑series for a single taxonomy **concept** (e.g. `Assets`).                                                         | `./get-company-concept.sh <CIK> <taxonomy> <concept>`      |
| **get-company-facts.sh**   | Full Company Facts bundle (all concepts for the filer).                                                                | `./get-company-facts.sh <CIK>`                             |
| **get-xbrl-frames.sh**     | XBRL **frame** (cross‑company slice for a concept/unit/period).                                                        | `./get-xbrl-frames.sh <taxonomy> <concept> <unit> <frame>` |
| **get-all.sh**             | Convenience wrapper that runs every above script for a demo set of concepts, logs output, and creates a DuckDB schema. | `./get-all.sh <CIK>`                                       |

---

## Quick start

```bash
# pull everything Apple Inc. has filed and a XBRL frames for all companies
EDGAR_UA="Aktagon Ltd. (contact@aktagon.com)" ./get-all.sh 320193

# inspect data
duckdb edgar.db
SELECT * FROM company_facts LIMIT 20;
```

Output is stored in:

- **json/** – raw API responses
- **json-schemas/** – JSON schemas
- **db-schemas/** – database schemas
- **logs/** – curl + DuckDB progress
- **edgar.db** – local DuckDB with imported tables

---

## File map

```
.
├── utils.sh               # shared helpers (CIK padding, cache probe)
├── get-all.sh             # orchestrator
├── get-company-concept.sh # concept time‑series
├── get-company-facts.sh   # full facts blob
├── get-submissions.sh     # filing history
├── get-xbrl-frames.sh     # peer frame slice
└── json/                  # API downloads
```

---

## Troubleshooting

- **403 Forbidden** → check that you have set the `EDGAR_UA` env variable and keep request rate within rate limit (≤10 req/s).

Happy parsing!
