# OCP Audit Log Dump Skill

Simple skill to dump all OpenShift kube-apiserver audit logs to local filesystem.

## Problem

Querying audit logs directly from the cluster is **very slow** (30-60 seconds per query).

## Solution

Dump all audit logs once, then query them locally (2-5 seconds per query).

**Speed improvement: 10-100x faster!**

## Usage

### Basic Usage

```bash
cd .claude/skills/ocp-audit-dump/scripts

# Dump logs using default kubeconfig
./dump-logs.sh

# Dump logs using custom kubeconfig
./dump-logs.sh --kubeconfig /path/to/kubeconfig

# Dump logs using KUBECONFIG env var
KUBECONFIG=/path/to/kubeconfig ./dump-logs.sh
```

All logs will be dumped to a timestamped directory:

```
audit-logs-20251125-143022/
  ├── ip-10-0-13-162.ec2.internal/
  │   ├── audit-2025-11-25T02-48-50.788.log
  │   ├── audit-2025-11-25T01-47-13.490.log
  │   └── ...
  ├── ip-10-0-13-163.ec2.internal/
  │   └── ...
  └── ip-10-0-13-164.ec2.internal/
      └── ...
```

## What It Does

1. Connects to your OpenShift cluster
2. Finds all control plane (master) nodes
3. Dumps ALL audit logs from each node
4. Saves them in `audit-logs-YYYYMMDD-HHMMSS/` directory

## Prerequisites

- OpenShift CLI (`oc`) installed
- Cluster access via one of:
  - Already logged in: `oc login <cluster>`
  - Custom kubeconfig: `--kubeconfig /path/to/kubeconfig`
  - KUBECONFIG env var: `export KUBECONFIG=/path/to/kubeconfig`
- Permissions to access node logs

## Multi-Cluster Support

You can dump logs from different clusters using the `--kubeconfig` argument:

```bash
# Dump logs from production cluster
./dump-logs.sh --kubeconfig ~/.kube/prod-config

# Dump logs from staging cluster
./dump-logs.sh --kubeconfig ~/.kube/staging-config

# Dump logs from development cluster
./dump-logs.sh --kubeconfig ~/.kube/dev-config
```

Each dump creates a separate timestamped directory, so you can keep logs from different clusters organized.

## After Dumping

Use the dumped logs with:
- `grep` commands for quick searches
- `jq` for JSON parsing and filtering
- The `ocp-audit-query` skill for powerful filtering and analysis

## Example Queries on Dumped Logs

```bash
# Find all delete operations
grep '"verb":"delete"' audit-logs-*/*/audit-*.log

# Find all pod operations
grep '"resource":"pods"' audit-logs-*/*/audit-*.log | jq .

# Find operations by specific user
grep '"username":"system:admin"' audit-logs-*/*/audit-*.log
```

## Tips

- Run this script once when you need to analyze logs
- Each run creates a new timestamped directory
- Delete old directories when you're done: `rm -rf audit-logs-*`

## Troubleshooting

**"Not logged into OpenShift cluster"**
```bash
oc login https://api.your-cluster.com:6443
```

**"No master nodes found"**
- Check permissions: `oc get nodes`

**Script runs slow**
- Yes, dumping takes time (first time only)
- But subsequent queries on local logs will be very fast!

## Storage

Typical size: 50-300MB total depending on number of nodes and logs.

## License

Part of the OCP audit logs AI workflow project.
