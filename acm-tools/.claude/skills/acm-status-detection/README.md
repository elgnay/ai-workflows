# ACM Status Detection Skill

This skill provides automated detection of Red Hat Advanced Cluster Management (ACM) installation status on OpenShift clusters.

## Purpose

Determines whether ACM is installed on a cluster and recommends the appropriate analysis workflow:
- **Workflow A**: Pre-Installation Analysis (when ACM is not installed)
- **Workflow B**: Post-Installation Analysis (when ACM is installed)

## Detection States

The skill identifies three possible states:

### 1. ACM Not Installed
- No MultiClusterHub resources
- No ACM operator pods
- **Recommendation**: Use Workflow A (Pre-Installation Analysis)

### 2. ACM Operator Only
- No MultiClusterHub resources
- ACM operator pods exist
- **Recommendation**: Use Workflow A (Pre-Installation Analysis)

### 3. ACM Fully Installed
- MultiClusterHub resources exist
- Status reported (Running, Installing, etc.)
- **Recommendation**: Use Workflow B (Post-Installation Analysis)

## Usage

### Using the Skill

```bash
# With Claude Code
run acm-status-detection kubeconfig.yaml

# Or without kubeconfig argument (will prompt)
run acm-status-detection
```

### Direct Script Execution

```bash
# With --kubeconfig parameter
bash .claude/skills/acm-status-detection/scripts/check-acm.sh --kubeconfig kubeconfig.yaml

# Using KUBECONFIG environment variable
export KUBECONFIG=kubeconfig.yaml
bash .claude/skills/acm-status-detection/scripts/check-acm.sh
```

## Detection Logic

### Step 1: Check for MultiClusterHub

```bash
oc get multiclusterhub -A
```

If MultiClusterHub resources are found, ACM is fully installed.

### Step 2: Check for ACM Operator (if no MultiClusterHub)

```bash
oc get pods -n open-cluster-management -l app=multiclusterhub-operator
```

If operator pods exist but no MultiClusterHub, only the operator is installed.

## Output Format

The script provides:
- Clear status indicators (✓, ✗, ℹ)
- Color-coded output for easy reading
- Detailed resource information when found
- Workflow recommendation based on detection results

## Files

- `SKILL.md` - Skill definition and documentation
- `scripts/common.sh` - Shared functions and utilities
- `scripts/check-acm.sh` - Main detection script
- `README.md` - This file

## Prerequisites

- OpenShift CLI (`oc`) installed
- Valid kubeconfig with cluster access
- Read permissions for ACM resources

## Integration

This skill integrates with the ACM certificate analysis workflows:
- Used in Step 0 of the main workflow to determine which path to follow
- Results guide users to the appropriate analysis workflow
- Can be invoked standalone or as part of the larger workflow
