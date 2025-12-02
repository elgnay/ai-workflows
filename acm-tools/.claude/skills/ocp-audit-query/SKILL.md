---
name: ocp-audit-query
description: Query OpenShift audit logs with powerful filtering and beautiful output formatting. Supports both online (direct cluster query) and offline (local files) modes. Accepts --kubeconfig, -d (directory), filter parameters (--verbs, --resources, --users, --namespaces, --status-codes, --start-time), and --output (format) parameters.
allowed-tools: [Bash, Read]
---

# OCP Audit Log Query Skill

## Description
Query OpenShift audit logs with powerful filtering and beautiful output formatting - supports both online (direct cluster query) and offline (local files) modes.

## Purpose
Query and analyze OpenShift audit logs with:
- **Online Mode**: Query cluster directly for latest data (no download needed)
- **Offline Mode**: Query locally downloaded logs for faster performance (10-100x faster)
- Multiple filter criteria (verbs, resources, users, namespaces, status codes, time windows)
- Beautiful output formats (table, detail, JSON, CSV)

## Query Modes

### Online Mode
Query cluster directly without downloading logs first:
- ✅ Always queries latest data
- ✅ No download required
- ✅ Good for quick spot checks
- ❌ Slower due to network latency
- **Usage**: Omit the `-d` flag

### Offline Mode
Query locally dumped logs (after using `ocp-audit-dump`):
- ✅ 10-100x faster queries
- ✅ Can query multiple times without hitting cluster
- ✅ Works offline
- ❌ Requires dumping logs first
- **Usage**: Specify `-d <directory>`

## Features
- **Dual Mode**: Online (cluster) or offline (local files) querying
- **Advanced Filtering**: Filter by verbs, resources, namespaces, users, time, status codes
- **Multiple Output Formats**: Table, detailed, JSON, CSV
- **Color-coded**: Status codes highlighted by success/warning/error
- **Smart Detection**: Automatically determines mode based on `-d` flag

## Usage

### Online Mode (Query Cluster Directly)

```bash
# Find all delete operations on pods (uses default kubeconfig)
./query-logs.sh --verbs delete --resources pods

# Query specific cluster using custom kubeconfig
./query-logs.sh --kubeconfig /path/to/kubeconfig --verbs delete --resources pods

# Find failed requests in last hour
./query-logs.sh --status-codes 403,404,500 --start-time 1h

# Find secret access by specific user
./query-logs.sh --resources secrets --users system:admin
```

### Offline Mode (Query Local Files)

```bash
# Find all delete operations on pods
./query-logs.sh -d audit-logs-20251125-143022 --verbs delete --resources pods

# Find failed requests
./query-logs.sh -d audit-logs-20251125-143022 --status-codes 403,404,500

# Export to CSV
./query-logs.sh -d audit-logs-20251125-143022 --output csv > results.csv
```

## Output Formats
- **table** - Compact color-coded table (default)
- **detail** - Detailed human-readable format
- **json** - Raw JSON for further processing
- **csv** - CSV for spreadsheets
