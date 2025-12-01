---
name: acm-status-detection
description: Detect if Red Hat Advanced Cluster Management (ACM) is installed on an OpenShift cluster. Checks for MultiClusterHub resources, operator deployment status, and ServerVerificationStrategy configuration. Accepts --kubeconfig (optional, defaults to KUBECONFIG env var) parameter.
allowed-tools: [Bash, Read]
---

# ACM Installation Status Detection

This skill detects whether Red Hat Advanced Cluster Management (ACM) is installed on an OpenShift cluster by checking for MultiClusterHub resources, operator deployment status, and the configured ServerVerificationStrategy.

## 🚀 Execution Instructions

**When this skill is invoked:**

1. **Check if kubeconfig argument was provided** in the user's invocation message
   - If provided (e.g., "run acm-status-detection kubeconfig.c3"), extract it
   - If not provided, ask the user for the kubeconfig path

2. **Use the script-based workflow (Recommended)**
   - **IMPORTANT**: Do NOT change directory before executing the script
   - Execute from the current working directory:
     - With --kubeconfig: `bash .claude/skills/acm-status-detection/scripts/check-acm.sh --kubeconfig <path>`
     - With KUBECONFIG env var: `export KUBECONFIG=<path> && bash .claude/skills/acm-status-detection/scripts/check-acm.sh`
   - The script will check ACM installation status and provide detailed results

## Usage

**With kubeconfig argument:**
```
User: run acm-status-detection kubeconfig.c3
```

**Without argument (will prompt for kubeconfig):**
```
User: run acm-status-detection
```

## When to Use This Skill

Invoke this skill when you need to:
- **Determine if ACM is installed** on a cluster
- **Check ACM deployment status**
- **Verify ACM operator presence**
- **Decide which workflow to use** (Pre-Installation vs Post-Installation)

## Trigger Keywords

- "check if ACM is installed"
- "is ACM installed"
- "detect ACM"
- "verify ACM installation"
- "ACM status"

## Prerequisites

- ✅ OpenShift cluster access with valid kubeconfig
- ✅ `oc` CLI installed

---

## Detection Logic

This skill performs a two-step check:

### Step 1: Check for MultiClusterHub Resources

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get multiclusterhub -A
```

**Outcomes:**

**Scenario 1: No resources found**
```
No resources found
```
- ✅ ACM is **NOT** installed
- **Next Step**: Proceed to Step 2 to check for operator

**Scenario 2: Resources found**
```
NAMESPACE                       NAME              STATUS    AGE
open-cluster-management         multiclusterhub   Running   30d
```
- ❌ ACM **IS** already installed and running
- **Workflow**: Use **Workflow B: ACM Post-Installation Analysis**

### Step 2: Check for ACM Operator (if no MultiClusterHub found)

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get pods -n open-cluster-management -l app=multiclusterhub-operator
```

**Outcomes:**

**Scenario 1: No resources found**
```
No resources found in open-cluster-management namespace.
```
- ✅ ACM operator is **NOT** installed
- ✅ ACM is **NOT** installed
- **Workflow**: Use **Workflow A: ACM Pre-Installation Analysis**

**Scenario 2: Operator pods found**
```
NAME                                          READY   STATUS    RESTARTS   AGE
multiclusterhub-operator-123456-abcde         1/1     Running   0          5d
```
- ✅ ACM operator is installed but MultiClusterHub is **NOT** deployed
- **Workflow**: Use **Workflow A: ACM Pre-Installation Analysis**

---

## Detection Results

The skill returns one of three states:

### State 1: ACM NOT Installed
- No MultiClusterHub resources
- No ACM operator pods
- **Recommended Workflow**: Workflow A (Pre-Installation Analysis)

### State 2: ACM Operator Only
- No MultiClusterHub resources
- ACM operator pods exist
- **Recommended Workflow**: Workflow A (Pre-Installation Analysis)

### State 3: ACM Fully Installed
- MultiClusterHub resources exist
- Status shows "Running" or other states
- ServerVerificationStrategy is detected from global KlusterletConfig
- **Recommended Workflow**: Workflow B (Post-Installation Analysis)

---

## ServerVerificationStrategy Detection

When ACM is installed, the skill also detects the ServerVerificationStrategy from the global KlusterletConfig resource.

### How It Works

1. **Query global KlusterletConfig**:
   ```bash
   oc get klusterletconfig global -o jsonpath='{.spec.hubKubeAPIServerConfig.serverVerificationStrategy}'
   ```

2. **Possible Values**:
   - `UseSystemTruststore` - Uses system's built-in CA certificates (for well-known CAs)
   - `UseAutoDetectedCABundle` - Auto-detects CA bundle from the cluster (default)
   - `UseCustomCABundles` - Uses custom CA bundles specified in the config

3. **Default Behavior**:
   - If the global KlusterletConfig doesn't exist: `UseAutoDetectedCABundle`
   - If the resource exists but serverVerificationStrategy is not specified: `UseAutoDetectedCABundle`

---

## Summary Template

When presenting the detection results, include:

**ACM Installation Status:**
- MultiClusterHub Status: [Not Found / Found]
- ACM Operator Status: [Not Found / Found]
- Overall Status: [Not Installed / Operator Only / Fully Installed]
- ServerVerificationStrategy: [UseSystemTruststore / UseAutoDetectedCABundle / UseCustomCABundles] (only when ACM is installed)
- **Recommended Workflow**: [Workflow A / Workflow B]

---

## Troubleshooting

**KUBECONFIG not persisting:**
- ✅ Prepend `export KUBECONFIG=...` to each `oc` command

**oc command not found:**
- ✅ Ensure OpenShift CLI is installed

**Permission denied errors:**
- ✅ Verify kubeconfig has appropriate cluster permissions
