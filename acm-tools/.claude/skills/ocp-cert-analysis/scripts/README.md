# OCP Certificate Analysis Scripts

This directory contains modular shell scripts for analyzing OpenShift kube-apiserver certificates.

## Quick Start

```bash
# Run complete analysis (recommended)
bash run-all.sh kubeconfig.c3

# Display summary after analysis
bash 99-summary.sh
```

## Script Overview

### Core Workflow Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `01-setup-kubeconfig.sh` | Set up and verify kubeconfig connection | `bash 01-setup-kubeconfig.sh <kubeconfig-path>` |
| `02-get-api-endpoint.sh` | Get API endpoint and save for reuse | `bash 02-get-api-endpoint.sh` |
| `03-retrieve-cert-chain.sh` | Retrieve certificate chain from API server | `bash 03-retrieve-cert-chain.sh` |
| `04-determine-cert-type.sh` | Determine certificate type (Type 1/2/3a/3b) | `bash 04-determine-cert-type.sh` |
| `05-get-ca-bundle.sh` | Retrieve CA bundle based on cert type | `bash 05-get-ca-bundle.sh` |
| `06-verify-cert.sh` | Verify certificate chain | `bash 06-verify-cert.sh` |
| `07-display-cert-chain.sh` | Display chain and check root CA inclusion | `bash 07-display-cert-chain.sh` |
| `08-test-connectivity.sh` | Test API server connectivity | `bash 08-test-connectivity.sh` |

### Utility Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `common.sh` | Shared functions and environment variables | Sourced by all scripts |
| `run-all.sh` | Execute complete workflow (steps 1-8) | `bash run-all.sh <kubeconfig-path>` |
| `99-summary.sh` | Display analysis summary | `bash 99-summary.sh` |

## State Management

Scripts use state files to persist data between steps:

| File | Contains | Created By |
|------|----------|------------|
| `.kubeconfig_path` | Kubeconfig file path | Step 01 |
| `.api_endpoint` | API server endpoint URL | Step 02 |
| `.current_workdir` | Working directory path | Step 03 |
| `.cert_type` | Certificate type (Type1/2/3a/3b) | Step 04 |
| `run-<timestamp>/` | Analysis output directory | Step 03 |
| `run-<timestamp>/.root_ca_included` | Root CA inclusion status | Step 07 |

## Key Features

### 1. API Endpoint Reuse
- API endpoint fetched **once** in Step 02
- Saved to `.api_endpoint` file
- Reused in Steps 03 and 08
- **Eliminates redundant API calls**

### 2. State Persistence
- Each step saves its results for subsequent steps
- Scripts validate dependencies before execution
- Can resume workflow from any step

### 3. Error Handling
- Each script validates prerequisites
- Clear error messages with exit codes
- Colored output (✓ success, ✗ error, ℹ info)

### 4. Modular Design
- Run complete workflow with `run-all.sh`
- Or run individual steps independently
- Common functions in `common.sh`

## Certificate Types

The workflow identifies four certificate types:

| Type | Description | CA Bundle Source |
|------|-------------|------------------|
| **Type1-OpenShift-Managed** | Default OpenShift certificates | `kube-apiserver-server-ca` configmap |
| **Type2-RedHat-Managed** | Managed service (ROSA/ARO/OSD) | System trust store |
| **Type3a-Custom-WellKnown** | Custom cert with well-known CA | Custom secret + system trust |
| **Type3b-Custom-SelfSigned** | Custom cert with private CA | Custom secret |

## Example Workflow

```bash
# Complete analysis
bash run-all.sh kubeconfig.c3

# Output:
# ▶ Step 1/8: Setting up kubeconfig...
# ✓ Successfully connected as: system:admin
#
# ▶ Step 2/8: Getting API endpoint...
# ✓ API Server Endpoint: https://api.cluster.example.com:6443
# ℹ API endpoint saved for reuse in subsequent steps
#
# ... (steps 3-8) ...
#
# ╔═══════════════════════════════════════════════════════════════╗
# ║           OCP Certificate Analysis - Summary                  ║
# ╚═══════════════════════════════════════════════════════════════╝
#
# Cluster: cluster.example.com
# Certificate Type: Type3a-Custom-WellKnown
# Root CA in Bundle: ❌ No (root CA in system trust store)
# ✓ Analysis complete!
```

## Running Individual Steps

```bash
# Step 1: Set up kubeconfig
bash 01-setup-kubeconfig.sh kubeconfig.c3

# Step 2: Get API endpoint (saved for reuse!)
bash 02-get-api-endpoint.sh

# Step 3: Retrieve certificates
bash 03-retrieve-cert-chain.sh

# ... continue with remaining steps ...

# View summary
bash 99-summary.sh
```

## Output Files

All analysis files are stored in `run-<timestamp>/` directory:

- `serving-cert.pem` - Kube-apiserver leaf certificate
- `ca-bundle.crt` - CA certificate bundle
- `intermediate-ca.pem` - Intermediate CA certificates
- `fullchain.pem` - Complete certificate chain
- `openssl_output.txt` - Raw OpenSSL output
- `.root_ca_included` - Root CA inclusion status

## Troubleshooting

**Script fails with "not found" error:**
```bash
# Ensure scripts are executable
chmod +x scripts/*.sh
```

**State file missing:**
```bash
# Run earlier steps first
# Scripts validate dependencies and show clear error messages
```

**API endpoint reused incorrectly:**
```bash
# Clear state and restart
rm .api_endpoint .kubeconfig_path .current_workdir .cert_type
bash run-all.sh kubeconfig.c3
```

## Benefits Over Manual Commands

✅ **API endpoint fetched once** - Reused across steps 03 and 08
✅ **Cleaner output** - Colored status messages and formatted display
✅ **Error handling** - Validates prerequisites before execution
✅ **State management** - Persistent data between steps
✅ **Modular execution** - Run all steps or individual steps
✅ **Better UX** - Progress indicators and summary report
