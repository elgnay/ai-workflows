# OCP Certificate Analysis for ACM

This workflow analyzes kube-apiserver serving certificates and assesses readiness for Red Hat Advanced Cluster Management (ACM) operations.

---

## 🔴 MANDATORY: COMMAND EXECUTION PROTOCOL

**CRITICAL - READ THIS FIRST BEFORE EXECUTING ANY WORKFLOW STEP:**

When executing ANY step (Step 1, Step 2, Step 3, etc.) in this workflow, you MUST follow this protocol:

### Required Steps BEFORE Running ANY Command:

1. **READ DOCUMENTATION FIRST**:
   - ALWAYS read `docs/workflows/common-steps.md` for the specific step number FIRST
   - NEVER execute commands from memory or assumptions
   - The documentation contains the exact, tested, working commands

2. **COPY COMMANDS EXACTLY**:
   - Copy the EXACT command from the documentation
   - DO NOT modify, improve, simplify, or "optimize" it
   - DO NOT combine multiple commands with && unless the documentation shows it
   - DO NOT change the syntax or structure

3. **VERIFY COMMAND SYNTAX**:
   - Use backticks (`) for command substitution - NEVER use $() syntax
   - Compare your command character-by-character with the documentation
   - If it doesn't match exactly, DO NOT run it

4. **FORBIDDEN ACTIONS**:
   - ❌ DO NOT parse kubeconfig files manually - use `oc` commands as documented
   - ❌ DO NOT use `$(...)` syntax - use backticks (`)
   - ❌ DO NOT chain commands with && unless documented
   - ❌ DO NOT "improve" or "simplify" documented commands
   - ❌ DO NOT skip reading the documentation

### Execution Workflow:

```
User requests Step N
    ↓
YOU: Read docs/workflows/common-steps.md Step N
    ↓
YOU: Find the exact command in documentation
    ↓
YOU: Copy command exactly (no modifications)
    ↓
YOU: Verify syntax matches (backticks, no &&, etc.)
    ↓
YOU: Execute the exact command
```

### Why This Matters:

- All commands have been **tested and verified** to work
- Deviating from documented commands **WILL cause failures**
- "Improving" commands wastes user time when they fail
- The documentation uses **shell-agnostic patterns** that work everywhere

### Violation Consequences:

If you deviate from documented commands:
- ✗ Commands WILL fail
- ✗ You WILL waste the user's time
- ✗ The workflow WILL break
- ✗ You WILL need to re-read the documentation anyway

**THERE ARE NO EXCEPTIONS TO THIS PROTOCOL.**

---

## 🔴 MANDATORY WORKFLOW INITIALIZATION

**CRITICAL**: When a user asks to run this workflow, you MUST follow this sequence:

1. **STEP 0 (MANDATORY)**: Ask the user to select which sub-workflow they want to run
2. **STEPS 1-8**: Proceed with the common certificate analysis (Step 1: kubeconfig selection is MANDATORY)
3. **FINAL STEP**: Apply the specific workflow recommendations based on their selection

**DO NOT** proceed to the next step until the user has completed the current mandatory step.

**IMPORTANT**: Step 1 in the common certificate analysis requires the user to provide/select their kubeconfig file. This is MANDATORY before proceeding to Step 2.

---

## Step 0: Select Your Workflow (REQUIRED)

**Choose ONE of the following workflows:**

### Option 1: ACM Pre-Installation Analysis

**Use this workflow if:**
- ACM is **NOT** yet installed on this cluster
- You want to determine if it's safe to install ACM
- You need recommendations for ACM configuration based on certificate type

**Documentation**: [docs/workflows/workflow-a-pre-installation.md](docs/workflows/workflow-a-pre-installation.md)

---

### Option 2: ACM Post-Installation Analysis

**Use this workflow if:**
- ACM **IS** already installed on this cluster
- You want to verify ACM configuration is compatible with certificate type
- You need to troubleshoot existing ACM/certificate issues

**Status**: Coming soon

---

### Option 3: Certificate Change Evaluation

**Use this workflow if:**
- You're planning to change the cluster's certificate type
- You want to understand the impact on ACM and managed clusters
- You need migration steps for certificate changes

**Status**: Coming soon

---

## Common Certificate Analysis (Steps 1-8)

**Prerequisites:** You MUST have selected a workflow in Step 0 before proceeding.

All workflows require certificate analysis. Complete Steps 1-8, then proceed to your selected workflow.

**Documentation**: [docs/workflows/common-steps.md](docs/workflows/common-steps.md)

**Steps covered:**
1. Set Up Kubeconfig
2. Get the External API Server Endpoint
3. Create Working Directory and Retrieve Serving Certificate
4. Determine Certificate Type
5. Retrieve CA Bundle Based on Certificate Type
6. Verify the Serving Certificate
7. Display the Certificate Chain
8. Test Connectivity

---

## Quick Reference

For quick lookup of certificate types, cluster identification, and ACM configuration guidelines:

**Documentation**: [docs/quick-reference.md](docs/quick-reference.md)

---

## Available Workflows

- **[Workflow A: ACM Pre-Installation Analysis](docs/workflows/workflow-a-pre-installation.md)** ✅ Available
- **Workflow B: ACM Post-Installation Analysis** 🚧 Coming soon
- **Workflow C: Certificate Change Evaluation** 🚧 Coming soon

---

## Workflow File Naming Standards

All workflow commands use standardized filenames for consistency and reliability:

| File Type | Filename | Description |
|-----------|----------|-------------|
| Serving Certificate | `serving-cert.pem` | The kube-apiserver leaf certificate |
| CA Bundle | `ca-bundle.crt` | The CA certificate bundle (all types) |
| Intermediate CA | `intermediate-ca.pem` | Intermediate CA certificates from chain |
| Working Directory | `run-<timestamp>` | Timestamped directory for analysis output |
| Directory Tracker | `.current_workdir` | File storing current working directory path |

**Command Pattern:**
```bash
# All commands follow this pattern - NOTE: Uses backticks, NOT $()
WORKDIR=`cat .current_workdir`
command "${WORKDIR}/filename"
```

---

## Workflow Overview

### Workflow A: Pre-Installation Analysis

Analyzes whether it's safe to install ACM based on certificate configuration. Provides:
- Safety assessment for each certificate type
- Recommendations for custom certificate configuration
- ACM configuration guidance (UseSystemTruststore vs CA Bundle)

### Certificate Type Decision Tree

```
Check Issuer
├─ CN=kube-apiserver-lb-signer → Type 1: OpenShift-Managed
└─ NOT kube-apiserver-lb-signer
   ├─ No custom cert config → Type 2: RedHat-Managed
   └─ Custom cert configured
      ├─ Well-known CA → Type 3a: Custom - Well-Known
      └─ Private CA → Type 3b: Custom - Self-Signed
```

### ACM Safety Summary

| Certificate Type | Safe to Install? | Risk Level |
|-----------------|------------------|------------|
| Type 1: OpenShift-Managed | ✅ Yes (but configure custom cert first if you plan to use one) | 🟢 LOW |
| Type 2: RedHat-Managed | ✅ Yes | 🟢 LOW |
| Type 3a: Custom - Well-Known | ✅ Yes (if root CA included) | 🟢 LOW |
| Type 3b: Custom - Self-Signed | ✅ Yes (if root CA included) | 🟢 LOW |

**Important Note for Type 1**: There is NO risk in using OpenShift-Managed certificates with ACM as long as you don't change certificate types later. The ONLY risk is **changing certificate types (from OpenShift-Managed to Custom) AFTER ACM installation**, which causes managed clusters to enter an unknown state. If you plan to use custom certificates, configure them BEFORE installing ACM.
