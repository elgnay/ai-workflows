# ACM Tools

A collection of Claude Code skills for analyzing and managing Red Hat Advanced Cluster Management (ACM), OpenShift certificates, and audit logs.

## Overview

This toolkit provides automated analysis and assessment capabilities for OpenShift clusters, with a focus on certificate management, ACM integration, and audit log analysis. The skills can be used independently or in combination to provide comprehensive cluster analysis.

## Available Skills

### Certificate & ACM Management

#### 1. ocp-cert-analysis

Analyze OpenShift kube-apiserver certificates with comprehensive certificate chain verification.

**Purpose:**
- Determine certificate type (OpenShift-Managed, RedHat-Managed, Custom CA)
- Retrieve and analyze CA bundle
- Verify certificate chain integrity
- Test connectivity to the API server

**Usage:**
```bash
Skill(ocp-cert-analysis)
```

**Parameters:**
- `--kubeconfig` (optional) - Path to kubeconfig file. Defaults to `KUBECONFIG` environment variable
- `--output` (optional) - Output directory for analysis results. Defaults to current directory

**When to use:**
- Before making certificate changes
- Troubleshooting certificate issues
- Validating certificate configuration
- Understanding current certificate setup

---

#### 2. acm-status-detection

Detect and verify Red Hat Advanced Cluster Management (ACM) installation status.

**Purpose:**
- Check if ACM is installed on the cluster
- Verify MultiClusterHub resources
- Check operator deployment status
- Review ServerVerificationStrategy configuration

**Usage:**
```bash
Skill(acm-status-detection)
```

**Parameters:**
- `--kubeconfig` (optional) - Path to kubeconfig file. Defaults to `KUBECONFIG` environment variable

**When to use:**
- Before planning ACM installation
- Verifying ACM deployment status
- Troubleshooting ACM issues
- Planning certificate changes on ACM-enabled clusters

---

#### 3. acm-cert-analysis

Comprehensive ACM and certificate analysis combining detection and certificate analysis.

**Purpose:**
- Detect ACM installation status
- Analyze kube-apiserver certificates
- Provide scenario-specific recommendations
- Support both pre-installation and post-installation analysis

**Usage:**
```bash
Skill(acm-cert-analysis)
```

**Parameters:**
- `--kubeconfig` (optional) - Path to kubeconfig file. Defaults to `KUBECONFIG` environment variable

**When to use:**
- Full cluster analysis
- Pre-installation planning
- Post-installation verification
- Comprehensive certificate and ACM status review

---

#### 4. acm-cert-change-assessment

**Status: Not Implemented Yet**

Assess the risk and impact of changing kube-apiserver certificates on clusters with ACM.

**Planned Purpose:**
- Evaluate impact of certificate type changes
- Analyze certificate rotation scenarios
- Assess root CA change implications
- Review intermediate CA change impacts
- Provide risk analysis and mitigation guidance

**Planned Parameters:**
- `--kubeconfig` (optional) - Path to kubeconfig file

**Planned Use Cases:**
- Before making any certificate changes on ACM clusters
- Planning certificate rotation
- Migrating from one certificate type to another
- Understanding risks of CA changes

---

### Audit Log Management

#### 5. ocp-audit-dump

Dump OpenShift kube-apiserver audit logs from control plane nodes to local filesystem for faster querying.

**Purpose:**
- Extract all audit logs from control plane nodes
- Create organized local copy for fast querying
- Enable offline analysis (10-100x faster than cluster queries)

**Output Structure:**
```
audit-logs-YYYYMMDD-HHMMSS/
  ├── node1/
  │   ├── audit-2025-11-25T02-48-50.788.log
  │   └── audit-2025-11-25T01-47-13.490.log
  └── node2/
      └── ...
```

**Usage:**
```bash
Skill(ocp-audit-dump)
```

**Parameters:**
- `--kubeconfig` (optional) - Path to kubeconfig file. Defaults to `KUBECONFIG` environment variable

**When to use:**
- Before performing extensive audit log analysis
- When you need to query logs multiple times
- For offline audit log analysis
- To preserve audit logs for compliance or investigation

---

#### 6. ocp-audit-query

Query and analyze OpenShift audit logs with powerful filtering and beautiful output formatting.

**Purpose:**
- Query audit logs in online (cluster) or offline (local) mode
- Filter by verbs, resources, users, namespaces, status codes, time windows
- Export results in multiple formats (table, detail, JSON, CSV)

**Modes:**

**Online Mode** - Query cluster directly:
- Always queries latest data
- No download required
- Good for quick spot checks
- Slower due to network latency

**Offline Mode** - Query locally dumped logs:
- 10-100x faster queries
- Can query multiple times without hitting cluster
- Works offline
- Requires dumping logs first with `ocp-audit-dump`

**Usage:**

Online mode:
```bash
# Find all delete operations on pods
Skill(ocp-audit-query --verbs delete --resources pods)

# Find failed requests in last hour
Skill(ocp-audit-query --status-codes 403,404,500 --start-time 1h)
```

Offline mode:
```bash
# Query local audit logs
Skill(ocp-audit-query -d audit-logs-20251125-143022 --verbs delete --resources pods)

# Export to CSV
Skill(ocp-audit-query -d audit-logs-20251125-143022 --output csv)
```

**Parameters:**
- `--kubeconfig` (optional) - Path to kubeconfig file
- `-d <directory>` - Directory containing dumped audit logs (enables offline mode)
- `--verbs` - Filter by Kubernetes verbs (get, list, create, update, delete, patch, etc.)
- `--resources` - Filter by resource types (pods, secrets, configmaps, etc.)
- `--users` - Filter by username
- `--namespaces` - Filter by namespace
- `--status-codes` - Filter by HTTP status codes
- `--start-time` - Filter by start time
- `--output` - Output format: table (default), detail, json, csv

**When to use:**
- Investigating security incidents
- Auditing user actions
- Tracking resource changes
- Compliance reporting
- Troubleshooting permission issues

---

## Common Workflows

### Workflow 1: ACM and Certificate Assessment
For a complete cluster assessment:

1. Run `acm-cert-analysis` for combined ACM and certificate analysis
2. Review all recommendations and findings
3. Plan any necessary changes based on the analysis

### Workflow 2: Audit Log Investigation
For security investigation or compliance auditing:

**Quick Investigation (Online)**
```bash
# Query cluster directly for recent delete operations
Skill(ocp-audit-query --verbs delete --start-time 1h)
```

**Deep Investigation (Offline)**
```bash
# Step 1: Dump all audit logs
Skill(ocp-audit-dump)

# Step 2: Query local logs multiple times
Skill(ocp-audit-query -d audit-logs-20251201-093000 --verbs delete --resources secrets)
Skill(ocp-audit-query -d audit-logs-20251201-093000 --users system:admin --output csv)
```

---

## Prerequisites

- OpenShift cluster access
- Valid kubeconfig file
- Appropriate cluster permissions (cluster-admin or equivalent)
- `oc` CLI tool installed
- `openssl` command-line tool
- `jq` for JSON processing (recommended for audit queries)

---

## Environment Setup

Set your kubeconfig file:

```bash
export KUBECONFIG=/path/to/your/kubeconfig
```

Or pass it as a parameter when invoking skills:

```bash
Skill(ocp-cert-analysis --kubeconfig /path/to/kubeconfig)
```

---

## Output

All skills generate detailed analysis output including:

- Current configuration status
- Certificate details and chain information (cert skills)
- Audit log entries with filtering (audit skills)
- Risk assessments (where applicable)
- Recommendations and next steps
- Relevant troubleshooting information

---

## Support

For issues or questions about these skills, refer to the individual skill documentation in `.claude/skills/[skill-name]/SKILL.md`.

---

## Project Structure

```
acm-tools/
├── .claude/
│   └── skills/
│       ├── ocp-cert-analysis/          # Certificate analysis
│       ├── acm-status-detection/       # ACM installation detection
│       ├── acm-cert-analysis/          # Comprehensive ACM + cert analysis
│       ├── acm-cert-change-assessment/ # Risk assessment (not implemented)
│       ├── ocp-audit-dump/             # Dump audit logs
│       └── ocp-audit-query/            # Query audit logs
├── docs/
│   └── (additional documentation)
└── README.md
```
