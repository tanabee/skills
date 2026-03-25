# Logging query language reference

## Basic syntax

```
FIELD_NAME OP VALUE
```

Multiple comparisons are joined with Boolean operators. AND can be omitted between comparisons.

## Boolean operators

| Operator | Description | Precedence |
|----------|-------------|------------|
| NOT (or `-`) | Negation | Highest |
| AND | Conjunction (can be omitted) | Middle |
| OR | Disjunction | Lowest |

**Boolean operators must always be capitalized.** Lowercase `and` / `or` are parsed as search terms.

## Comparison operators

| Operator | Description |
|----------|-------------|
| `=` | Equal |
| `!=` | Not equal |
| `>`, `<`, `>=`, `<=` | Numeric ordering |
| `:` | "Has" — substring match |
| `=~` | Regular expression match (RE2 syntax, case-sensitive) |
| `!~` | Regular expression non-match |

String equality (`=` / `!=`) comparisons are case-insensitive using NFKC_CF Unicode normalization. Regular expressions are case-sensitive.

## Field existence test

```
operation.id:*
```

Matches only log entries where the field is present.

## Indexed fields (fast)

- `resource.type`, `resource.labels.*`
- `logName`
- `severity`
- `timestamp`
- `insertId`, `operation.id`, `trace`
- `httpRequest.status`
- `labels.*`
- `split.uid`

## Common LogEntry fields

```
resource.type              # Monitored resource type
resource.labels.zone       # Resource labels
logName                    # Log name (URL-encoded)
severity                   # Log severity level
timestamp                  # Timestamp (RFC 3339)
textPayload                # Text payload
jsonPayload.FIELD          # JSON payload field
labels.KEY                 # User-defined labels
httpRequest.status         # HTTP status code
httpRequest.requestUrl     # Request URL
operation.id               # Operation ID
sourceLocation.file        # Source file
```

Field path components containing special characters must be double-quoted:
```
labels."compute.googleapis.com/resource_id"
```

## Value types

| Type | Examples |
|------|----------|
| bool | `true`, `false` (case-insensitive) |
| string | `"UTF-8 text"` |
| double | `-3.2e-8`, `NaN`, `Infinity` |
| intNN / uintNN | `-3`, `1234` |
| Timestamp | `"2024-08-02T15:01:23.045Z"` |
| Duration | `"3.2s"`, `"500ms"` (ns, us, ms, s, m, h) |
| enum (severity) | `ERROR`, `WARNING` |
| null | `NULL_VALUE` |

## Built-in functions

### log_id()
```
log_id("cloudaudit.googleapis.com/activity")
```
Matches by non-URL-encoded log ID.

### SEARCH()
```
SEARCH("keyword")                    # Searches the entire log entry
SEARCH(textPayload, "keyword")       # Searches a specific field
SEARCH("`exact phrase`")             # Backtick-quoted phrase match
```
Case-insensitive, token-based search. More efficient than global restrictions.

### sample()
```
sample(insertId, 0.25)    # Select 25% of log entries
```
Deterministic selection based on a hash of the specified field.

### ip_in_net()
```
ip_in_net(jsonPayload.realClientIP, "10.1.2.0/24")
```
Tests whether an IP address field falls within a subnet (IPv4/IPv6).

### cast()
```
cast(timestamp, STRING, TIME_ZONE("America/New_York"))
```
Converts a field to a specified type. Supported types: STRING, INT64, FLOAT64, BOOL, TIMESTAMP, DURATION.

### regexp_extract()
```
regexp_extract(textPayload, "error: (.*)")
```
Extracts the first substring matching a regex. Requires exactly one capture group.

### source()
```
source(projects/PROJECT_ID)
source(folders/FOLDER_ID)
source(organizations/ORG_ID)
```
Matches log entries from a specific resource in the hierarchy.

## Query examples

### Resource type + severity
```
resource.type = "cloud_run_revision" AND severity >= ERROR
```

### Time range
```
timestamp >= "2024-08-01T00:00:00Z" AND timestamp <= "2024-08-01T23:59:59Z"
```

### Text search
```
textPayload : "connection refused"
```

### JSON payload fields
```
jsonPayload.statusCode = 500
jsonPayload.message : "timeout"
```

### Regular expressions
```
textPayload =~ "error.*timeout|timeout.*error"
labels.pod_name =~ "api-server-.*"
```

### Excluding specific log entries
```
NOT log_id("cloudaudit.googleapis.com/activity")
severity >= WARNING AND NOT textPayload : "health check"
```

### Compound query
```
resource.type = "cloud_run_revision"
AND severity >= ERROR
AND timestamp >= "2024-08-01T09:00:00+09:00"
AND jsonPayload.message : "database"
```

## gcloud logging read flags

| Flag | Description | Example |
|------|-------------|---------|
| `--limit` | Maximum number of log entries to return | `--limit=100` |
| `--format` | Output format | `--format=json`, `--format="table(timestamp,severity,textPayload)"` |
| `--freshness` | Return log entries no older than this value | `--freshness=1h`, `--freshness=7d` |
| `--order` | Sort order | `--order=asc`, `--order=desc` |
| `--project` | Project ID | `--project=my-project` |
| `--folder` | Folder ID | `--folder=FOLDER_ID` |
| `--organization` | Organization ID | `--organization=ORG_ID` |
| `--billing-account` | Billing account ID | `--billing-account=ACCOUNT_ID` |

## Comments

`--` starts a comment that runs to the end of the line. Comments count toward the 20,000-character query length limit.
