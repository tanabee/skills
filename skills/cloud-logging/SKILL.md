---
name: cloud-logging
description: Read and analyze log entries from Cloud Logging using the gcloud CLI.
allowed-tools: Bash, Read, Glob, Grep, Write, Task
---

Read and analyze log entries from Cloud Logging using the gcloud CLI. `$ARGUMENTS` is a natural-language description of the log query (e.g., `Cloud Run error logs from the last hour in production`). If `$ARGUMENTS` is empty, ask the user for the query criteria.

## Prerequisites

- `gcloud` CLI is installed and authenticated
- The user has the Logs Viewer role (or equivalent) on the target Google Cloud project

## Steps

1. Run `gcloud config get-value project` to confirm the current project ID. If the project is not set or may not match the user's intent, ask the user to confirm
2. Analyze `$ARGUMENTS` to identify the following query parameters:
   - Monitored resource type (`resource.type`): e.g., `cloud_run_revision`, `gce_instance`, `k8s_container`, `cloud_function`
   - Log severity (`severity`): DEFAULT, DEBUG, INFO, NOTICE, WARNING, ERROR, CRITICAL, ALERT, EMERGENCY
   - Time range (`timestamp`): Convert relative expressions (e.g., "last hour") to RFC 3339 timestamps based on the current time
   - Additional conditions: log name, labels, text search, JSON payload fields, etc.
3. Build a Logging query from the identified parameters (refer to [query-syntax.md](./references/query-syntax.md) for the query language specification)
4. Present the constructed query to the user and ask for confirmation before executing
5. Execute the query with `gcloud logging read`
   - Default flags: `--limit=50 --format=json`
   - Add `--freshness` or `--order=asc/desc` as needed
6. Analyze the results and report a summary to the user, including:
   - Total number of log entries returned
   - Trends and patterns in errors or warnings
   - Notable log entries highlighted
7. Handle follow-up requests from the user (e.g., narrowing filters, adjusting time range, inspecting specific log entries)

## Query construction guidelines

- Prefer indexed fields (`resource.type`, `logName`, `severity`, `timestamp`, `labels.*`) for faster queries
- Avoid global restrictions (`"keyword"`); instead, specify the field (e.g., `textPayload:`, `jsonPayload.message:`)
- Use the `:` (has) operator for substring matching and `=~` for regular expressions (RE2 syntax)
- Combine conditions with AND; use OR only when necessary, as it cannot leverage indexes
- Wrap the entire query filter in single quotes when passing it to the gcloud CLI

## Important

- Only use `gcloud logging read` (read-only). Never execute write or mutating commands such as `write`, `delete`, or `sinks create`
- When querying large volumes of log entries, use `--limit` to cap results and refine filters iteratively
- If log entries contain sensitive information (PII, auth tokens, etc.), alert the user before displaying them
- When no time range is specified, default to the last 1 hour
