# OCP Audit Log Dump Skill

## Description
Dump OpenShift kube-apiserver audit logs from control plane nodes to local filesystem for faster querying.

## Purpose
Querying audit logs directly from the cluster is slow. This skill dumps all audit logs once so you can query them locally much faster.

## What It Does
Dumps all audit logs from all control plane nodes into a timestamped directory:
```
audit-logs-YYYYMMDD-HHMMSS/
  ├── node1/
  │   ├── audit-2025-11-25T02-48-50.788.log
  │   └── audit-2025-11-25T01-47-13.490.log
  └── node2/
      └── ...
```

## Usage

### Basic Usage
```bash
# Dump logs using default kubeconfig
./dump-logs.sh

# Dump logs using custom kubeconfig
./dump-logs.sh --kubeconfig /path/to/kubeconfig

# Dump logs using KUBECONFIG env var
KUBECONFIG=/path/to/kubeconfig ./dump-logs.sh
```

All logs will be dumped to a new timestamped directory.
