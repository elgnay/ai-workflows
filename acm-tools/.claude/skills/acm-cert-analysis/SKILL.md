---
name: acm-cert-analysis
description: Comprehensive ACM and certificate analysis for OpenShift clusters. Detects ACM installation status, analyzes kube-apiserver certificates, and provides recommendations for both pre-installation and post-installation scenarios. Accepts --kubeconfig (optional, defaults to KUBECONFIG env var) parameter.
allowed-tools: [Bash, Read]
---

# ACM Certificate Analysis

This skill provides comprehensive analysis combining ACM installation detection and certificate analysis, providing tailored recommendations based on your cluster's current state.

## 🚀 Execution Instructions

**When this skill is invoked:**

1. **Check if kubeconfig argument was provided** in the user's invocation message
   - If provided (e.g., "run acm-cert-analysis kubeconfig.c3"), extract it
   - If not provided, ask the user for the kubeconfig path

2. **Use the automated workflow**
   - Execute: `bash .claude/skills/acm-cert-analysis/scripts/run-analysis.sh --kubeconfig <path>`
   - The script will:
     - Detect ACM installation status
     - Analyze certificate type and configuration
     - Provide appropriate recommendations

3. **Present results to the user**
   - The script will display the analysis in 5 steps:
     - **Step 1: Cluster Information** - API endpoint, OCP version, user
     - **Step 2: Cluster Kube APIServer Certificates** - Certificate type, details, root CA status, complete chain
     - **Step 3: ACM Status and Configuration** - ACM status, version, ServerVerificationStrategy configuration
       - Use ✅ for INSTALLED status
       - Use ℹ️  for NOT INSTALLED status (this is informational, not an error)
       - Use ⚠️  for OPERATOR ONLY status
     - **Step 4: ACM Certificate Management Analysis** - Recommended ServerVerificationStrategy, comparison with current
     - **Step 5: Analysis Summary** - Compatibility assessment and recommendations

## Usage

**With kubeconfig argument:**
```
User: run acm-cert-analysis kubeconfig.c3
```

**Without argument (will prompt for kubeconfig):**
```
User: run acm-cert-analysis
```

## When to Use This Skill

Invoke this skill when you need to:
- **Plan ACM installation** on a cluster
- **Verify ACM configuration** with certificates
- **Troubleshoot ACM/certificate issues**
- **Understand certificate compatibility** with ACM

## What This Skill Does

### Workflow Steps

**Step 1: Cluster Information**
- Displays kubeconfig path, API endpoint, OCP version, current user

**Step 2: Cluster Kube APIServer Certificates**
- Determines certificate type (OpenShift-Managed, RedHat-Managed, Custom CA)
- Extracts certificate details (subject, issuer, validity)
- Checks if root CA is included
- Displays complete certificate chain

**Step 3: ACM Status and Configuration**
- Checks if ACM is installed
- Detects MultiClusterHub status
- Reports ACM version (if installed)
- Shows ServerVerificationStrategy configuration (if ACM installed)

**Step 4: ACM Certificate Management Analysis**
- Recommends ServerVerificationStrategy based on certificate type
- Compares current configuration with recommendation (if ACM installed)

**Step 5: Analysis Summary**
- **Pre-Installation**: Safety evaluation and installation recommendations
- **Post-Installation**: Configuration verification and compatibility check

## Prerequisites

- ✅ OpenShift cluster access with valid kubeconfig
- ✅ `oc` CLI installed
- ✅ `openssl` CLI available

---

## Analysis Outputs

### For Clusters WITHOUT ACM (Pre-Installation)

**Certificate Type Assessment:**
- Safety evaluation for ACM installation
- Custom certificate configuration guidance
- ACM configuration recommendations

### For Clusters WITH ACM (Post-Installation)

**Configuration Verification:**
- Certificate type compatibility check
- ACM configuration validation
- Troubleshooting guidance if needed

---

## Certificate Types and ACM Compatibility

| Certificate Type | Pre-Installation | Post-Installation |
|------------------|------------------|-------------------|
| OpenShift-Managed | ✅ Safe (don't change cert type later) | ✅ Verify no cert changes planned |
| RedHat-Managed | ✅ Safe with UseSystemTruststore | ✅ Verify UseSystemTruststore |
| Custom - Well-Known CA | ✅ Safe with root CA included | ✅ Verify configuration |
| Custom - Private CA | ✅ Safe with root CA included | ✅ Verify CA bundle config |

---

## Troubleshooting

**KUBECONFIG not persisting:**
- ✅ Specify with --kubeconfig parameter

**oc command not found:**
- ✅ Ensure OpenShift CLI is installed

**Permission denied errors:**
- ✅ Verify kubeconfig has appropriate cluster permissions
