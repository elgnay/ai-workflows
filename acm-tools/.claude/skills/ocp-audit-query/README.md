# OCP Audit Log Query Skill

Query OpenShift audit logs with powerful filtering and beautiful formatted output - supports both **online** (direct cluster query) and **offline** (local files) modes.

## Quick Start

### Online Mode (Query Cluster Directly)

```bash
cd .claude/skills/ocp-audit-query/scripts

# Find all delete operations on pods - queries cluster directly (uses default kubeconfig)
./query-logs.sh --verbs delete --resources pods

# Query specific cluster using custom kubeconfig
./query-logs.sh --kubeconfig /path/to/kubeconfig --verbs delete --resources pods

# Find failed requests in last hour
./query-logs.sh --status-codes 403,404,500 --start-time 1h
```

### Offline Mode (Query Local Files)

```bash
cd .claude/skills/ocp-audit-query/scripts

# Find all delete operations on pods from local files
./query-logs.sh -d audit-logs-20251125-143022 --verbs delete --resources pods
```

## Prerequisites

### Online Mode
- **OpenShift CLI (oc)** installed and logged into cluster: `oc login`
- **jq** installed: `brew install jq` (macOS) or `apt-get install jq` (Linux)

### Offline Mode
1. **Dump logs first** using the `ocp-audit-dump` skill
2. **jq** installed: `brew install jq` (macOS) or `apt-get install jq` (Linux)

## Query Modes

The script automatically determines the query mode based on whether the `-d` flag is specified:

- **Online Mode**: Omit `-d` to query the cluster directly (requires `oc` CLI and active login)
- **Offline Mode**: Specify `-d <directory>` to query locally downloaded logs (requires prior download)

### When to Use Each Mode

**Use Online Mode when:**
- You need the absolute latest data
- You're doing a quick spot check
- You don't want to download large log files

**Use Offline Mode when:**
- You need to run multiple queries
- You want maximum query performance (10-100x faster)
- You're analyzing historical data
- You need to work offline

## Usage

```bash
./query-logs.sh [OPTIONS]
```

### Mode Selection
- Omit `-d` for **online mode** (queries cluster directly)
  - Optional: Use `--kubeconfig PATH` to specify a custom kubeconfig file
- Specify `-d DIR` for **offline mode** (queries local files)
- **Note**: `--kubeconfig` and `-d` are mutually exclusive (cannot be used together)

### Filters
- `-v, --verbs VERBS` - Filter by API verbs (e.g., `delete`, `create,update`)
- `-r, --resources RESOURCES` - Filter by resources (e.g., `pods`, `secrets,configmaps`)
- `-n, --namespaces NS` - Filter by namespaces
- `-u, --users USERS` - Filter by users
- `-s, --start-time TIME` - Start time (relative: `1h`, `30m`, or ISO: `2025-11-25T10:00:00`)
- `-e, --end-time TIME` - End time (ISO format)
- `-c, --status-codes CODES` - Filter by HTTP status (e.g., `200`, `404,500`)

### Output
- `-o, --output FORMAT` - Output format: `table`, `detail`, `json`, `csv` (default: `table`)
- `-m, --max-results NUM` - Maximum results (default: 50)

## Output Formats

### Table (Default)
Compact, color-coded table view:
```
TIMESTAMP                 USER                 VERB       RESOURCE        NAMESPACE            NAME                      STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2025-11-25T10:30:45   system:admin         delete     pods            default              my-pod                    200
2025-11-25T10:31:22   john@example.com     create     secrets         production           db-password               201
```

### Detail
Detailed human-readable format with all fields:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Timestamp:  2025-11-25T10:30:45.123456Z
User:       system:admin
Verb:       delete
Resource:   pods
Namespace:  default
Name:       my-pod
Status:     200
URI:        /api/v1/namespaces/default/pods/my-pod
Source IP:  10.0.0.1
User Agent: oc/4.10.0
```

### JSON
Raw JSON for programmatic processing:
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","verb":"delete",...}
```

### CSV
CSV format for spreadsheets:
```csv
Timestamp,User,Verb,Resource,Namespace,Name,Status,URI
2025-11-25T10:30:45.123456Z,system:admin,delete,pods,default,my-pod,200,/api/v1/namespaces/default/pods/my-pod
```

## Examples

### Online Mode Examples

#### Security Auditing

```bash
# Find all secret access (live from cluster)
./query-logs.sh --resources secrets

# Find all failed authentication/authorization
./query-logs.sh --status-codes 401,403

# Find privilege escalation attempts
./query-logs.sh --verbs create,update --resources roles,rolebindings
```

#### Troubleshooting

```bash
# Find all errors in last hour
./query-logs.sh --status-codes 500 --start-time 1h

# Find recent delete operations
./query-logs.sh --verbs delete --start-time 30m

# Find pod operations in specific namespace
./query-logs.sh --resources pods --namespaces my-app --start-time 2h
```

#### Quick Spot Checks

```bash
# Check who recently deleted pods
./query-logs.sh --verbs delete --resources pods --start-time 1h

# Monitor secret access in real-time window
./query-logs.sh --resources secrets --start-time 5m

# Check failed API calls
./query-logs.sh --status-codes 403,404,500 --start-time 15m
```

#### Multi-Cluster Queries

```bash
# Query production cluster
./query-logs.sh --kubeconfig ~/.kube/prod-config --verbs delete --start-time 1h

# Query staging cluster
./query-logs.sh --kubeconfig ~/.kube/staging-config --resources secrets

# Query development cluster
./query-logs.sh --kubeconfig ~/.kube/dev-config --status-codes 403,404,500
```

### Offline Mode Examples

#### Security Auditing

```bash
# Find all secret access from downloaded logs
./query-logs.sh -d audit-logs-20251125-143022 --resources secrets

# Find all failed authentication/authorization
./query-logs.sh -d audit-logs-20251125-143022 --status-codes 401,403

# Find privilege escalation attempts
./query-logs.sh -d audit-logs-20251125-143022 \
  --verbs create,update --resources roles,rolebindings
```

#### Compliance & Reporting

```bash
# Track admin actions
./query-logs.sh -d audit-logs-20251125-143022 \
  --users system:admin --output detail

# Export all create/update operations to CSV
./query-logs.sh -d audit-logs-20251125-143022 \
  --verbs create,update --output csv > report.csv

# Generate compliance report for time period
./query-logs.sh -d audit-logs-20251125-143022 \
  --start-time "2025-11-01T00:00:00" \
  --end-time "2025-11-30T23:59:59" \
  --output csv > november-audit.csv
```

#### Complex Queries

```bash
# Failed delete attempts in production
./query-logs.sh -d audit-logs-20251125-143022 \
  --verbs delete \
  --namespaces production \
  --status-codes 403,404,500

# Service account activity
./query-logs.sh -d audit-logs-20251125-143022 \
  --users "system:serviceaccount" \
  --resources secrets \
  --output detail

# Multiple resources
./query-logs.sh -d audit-logs-20251125-143022 \
  --resources pods,deployments,services \
  --verbs create,delete \
  --max-results 100
```

## Common Verbs

- `get` - Retrieve a resource
- `list` - List resources
- `create` - Create a new resource
- `update` - Update a resource
- `patch` - Partially update a resource
- `delete` - Delete a resource
- `watch` - Watch for changes

## Common Resources

- `pods`, `deployments`, `replicasets`, `statefulsets`, `daemonsets`
- `services`, `endpoints`, `ingresses`, `routes`
- `configmaps`, `secrets`, `serviceaccounts`
- `roles`, `rolebindings`, `clusterroles`, `clusterrolebindings`
- `namespaces`, `nodes`, `persistentvolumes`

## Tips

1. **Mode selection**: Omit `-d` for online mode (cluster), specify `-d` for offline mode (local files)
2. **Time filters**: Use relative time (`1h`, `30m`, `2d`) for recent events - especially useful in online mode
3. **Combine filters**: All filters work together (AND logic)
4. **CSV export**: Redirect CSV output to a file for analysis in Excel/Google Sheets
5. **Color output**: Table format uses colors - green (2xx), yellow (4xx), red (5xx)
6. **Performance**: Use offline mode for repeated queries - 10-100x faster than online mode

## Troubleshooting

### Online Mode Issues

**"oc: command not found"**
- Install OpenShift CLI: Download from [OpenShift Downloads](https://console.redhat.com/openshift/downloads)
- Or use offline mode with `-d` if you have downloaded logs

**"Not logged into OpenShift cluster"**
- Run `oc login` to authenticate
- Or use offline mode with `-d` if you have downloaded logs

### Offline Mode Issues

**"Directory not found"**
- Dump logs first: `cd ../ocp-audit-dump/scripts && ./dump-logs.sh`
- Or use online mode (omit `-d` flag) to query cluster directly

### General Issues

**"jq: command not found"**
- Install jq: `brew install jq` (macOS) or `apt-get install jq` (Linux)

**No results found**
- Check your filter criteria - they might be too restrictive
- Verify logs contain the data you're looking for
- Try without filters first to see all events

## Performance Comparison

| Mode | Query Speed | Use Case |
|------|-------------|----------|
| **Online** | 30-120 seconds | Latest data, quick spot checks |
| **Offline** | 2-5 seconds | Repeated queries, historical analysis |

**Offline mode is 10-100x faster** than online mode!

## Workflow Recommendations

### One-time Quick Check
Use **online mode** for immediate results:
```bash
./query-logs.sh --verbs delete --resources pods --start-time 1h
```

### Multiple Queries / Analysis
Use **offline mode** for better performance:
```bash
# 1. Dump logs once
cd ../ocp-audit-dump/scripts && ./dump-logs.sh

# 2. Run multiple queries quickly
cd ../../ocp-audit-query/scripts
./query-logs.sh -d audit-logs-* --verbs delete
./query-logs.sh -d audit-logs-* --resources secrets
./query-logs.sh -d audit-logs-* --status-codes 403,404
```

## Integration

This skill provides two complementary workflows:

1. **Quick checks**: Use online mode when you need immediate answers
2. **Deep analysis**: Dump with `ocp-audit-dump`, then query multiple times with offline mode

## License

Part of the OCP audit logs AI workflow project.
