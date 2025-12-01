# ACM Certificate Analysis Skill

Comprehensive analysis skill that combines ACM installation detection and certificate analysis to provide tailored recommendations for both pre-installation and post-installation scenarios.

## Purpose

This skill orchestrates multiple analysis workflows to provide complete guidance for ACM and certificate management on OpenShift clusters.

## What It Does

### 1. ACM Status Detection
- Checks if ACM is installed on the cluster
- Detects ACM version if installed
- Identifies operator-only installations

### 2. Certificate Analysis
- Determines certificate type (OpenShift-Managed, RedHat-Managed, Custom CA)
- Retrieves and verifies CA bundles
- Validates certificate chains
- Checks for root CA inclusion
- Tests API connectivity

### 3. Tailored Recommendations
Based on the combination of ACM status and certificate type, provides specific guidance:

**Pre-Installation Scenarios:**
- Safety assessment for ACM installation
- Custom certificate configuration guidance
- Root CA verification requirements

**Post-Installation Scenarios:**
- Configuration verification
- Compatibility checks
- Troubleshooting guidance

## Usage

### Using the Skill

```bash
# With Claude Code
run acm-cert-analysis kubeconfig.yaml

# Or without kubeconfig argument (will prompt)
run acm-cert-analysis
```

### Direct Script Execution

```bash
# With --kubeconfig parameter
bash .claude/skills/acm-cert-analysis/scripts/run-analysis.sh --kubeconfig kubeconfig.yaml

# Using KUBECONFIG environment variable
export KUBECONFIG=kubeconfig.yaml
bash .claude/skills/acm-cert-analysis/scripts/run-analysis.sh
```

## Analysis Workflow

```
1. ACM Status Detection
   ├─ Check for MultiClusterHub
   ├─ Check for ACM operator
   └─ Determine ACM version

2. Certificate Analysis
   ├─ Retrieve kube-apiserver certificates
   ├─ Determine certificate type
   ├─ Verify certificate chain
   └─ Check root CA inclusion

3. Generate Recommendations
   ├─ Pre-Installation: Safety & configuration guidance
   └─ Post-Installation: Verification & troubleshooting
```

## Certificate Types and Recommendations

### OpenShift-Managed Certificates

**Pre-Installation:**
- ✅ Safe to install ACM
- ⚠️ Do NOT change cert type after ACM installation
- Option: Configure custom certs before ACM installation

**Post-Installation:**
- ✅ Compatible configuration
- ⚠️ Do NOT change to custom certificates

### RedHat-Managed Certificates

**Pre-Installation:**
- ✅ Safe to install ACM
- **(Required)** Configure UseSystemTruststore strategy as the KubeAPIServer verification strategy in the global KlusterletConfig after installation

**Post-Installation:**
- **(Required)** Verify UseSystemTruststore strategy is configured as the KubeAPIServer verification strategy in the global KlusterletConfig

### Custom Certificates (Well-Known CA)

**Pre-Installation:**
- ✅ Safe if root CA included
- (Optional) Configure UseSystemTruststore strategy as the KubeAPIServer verification strategy in the global KlusterletConfig

**Post-Installation:**
- (Optional) Verify UseSystemTruststore strategy is configured in the global KlusterletConfig for KubeAPIServer verification

### Custom Certificates (Private CA)

**Pre-Installation:**
- ✅ Safe if root CA included
- ❌ Requires root CA if not included
- ACM will automatically detect and distribute the CA bundle to managed clusters

**Post-Installation:**
- Verify ACM has detected and distributed the CA bundle
- Klusterlets on managed clusters will use the CA bundle to verify the hub Kube APIServer

## Dependencies

This skill uses two other skills:
- `acm-status-detection` - Detects ACM installation status
- `ocp-cert-analysis` - Analyzes OpenShift certificates

## Files

- `SKILL.md` - Skill definition and documentation
- `scripts/run-analysis.sh` - Main orchestration script
- `README.md` - This file

## Prerequisites

- OpenShift CLI (`oc`) installed
- OpenSSL CLI available
- Valid kubeconfig with cluster access
- Read permissions for ACM and certificate resources

## Output

The skill provides:
- Clear status indicators (✓, ✗, ℹ)
- Color-coded output for easy reading
- Detailed analysis results
- Specific, actionable recommendations
- Risk warnings where applicable

## Example Output

```
━━━ Step 1: ACM Installation Status Detection

✓ ACM Status: INSTALLED
  Version:   2.15.0
  Namespace: open-cluster-management
  Name:      multiclusterhub
  Status:    Running

━━━ Step 2: Certificate Analysis

[Certificate analysis details...]

━━━ Recommendations

Workflow: Post-Installation Analysis

ACM Status: Installed (Version 2.15.0)
Certificate Type: OpenShift-Managed

✓ Configuration: Compatible

Current configuration is compatible. Important considerations:
  • Do NOT change certificate type while ACM is installed
  • Changing cert type will cause managed clusters to enter unknown state
  • If you need custom certificates, plan for cluster reinstallation
```
