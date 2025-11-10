# OCP Certificate Analysis Tool

A comprehensive shell script to analyze and verify OpenShift Kube-APIServer certificates.

## Features

✅ Automatic certificate type detection (OpenShift-Managed, RedHat-Managed, Custom CA)
✅ Certificate chain extraction and verification
✅ CA bundle retrieval based on certificate type
✅ Trust path validation
✅ API connectivity testing
✅ Color-coded output for easy reading
✅ Error handling and validation

## Prerequisites

- `oc` CLI tool (OpenShift CLI)
- `openssl` command-line tool
- `curl` for connectivity testing
- `jq` (optional, for pretty JSON output)
- Valid kubeconfig file with cluster access

## Usage

### Basic Usage

```bash
./ocp-cert-analysis.sh
```

The script will prompt you for the kubeconfig file path. If you press Enter without specifying a path, it will:
1. Look for `kubeconfig` in the current directory
2. Fall back to `~/.kube/config` if not found

### Pre-set Kubeconfig

You can also set the KUBECONFIG environment variable before running:

```bash
export KUBECONFIG=/path/to/your/kubeconfig
./ocp-cert-analysis.sh
```

## What It Does

The script performs the following steps:

### Step 0: Set Up Kubeconfig
- Prompts for kubeconfig path or uses default/existing
- Verifies authentication with the cluster

### Step 1: Get External API Server Endpoint
- Retrieves the external API server URL
- Extracts the hostname for certificate retrieval

### Step 2: Create Working Directory and Retrieve Certificates
- Creates a timestamped working directory (`run-YYYYMMDD-HHMMSS`)
- Retrieves the certificate chain from the API server
- Separates leaf certificate from intermediate CA

### Step 3: Display Certificate Details
- Shows certificate subject and issuer
- Displays validity period (notBefore, notAfter)
- Lists Subject Alternative Names (SANs)

### Step 4: Determine Certificate Type
- Analyzes the certificate issuer
- Checks for custom certificate configuration
- Identifies one of three types:
  - **Type 1**: OpenShift-Managed Certificate (default for self-managed clusters)
  - **Type 2**: RedHat-Managed Certificate (ROSA, ARO, OpenShift Dedicated)
  - **Type 3a**: Custom CA - Well-Known (Let's Encrypt, DigiCert, etc.)
  - **Type 3b**: Custom CA - Self-Signed

### Step 5: Retrieve CA Bundle
- Retrieves appropriate CA bundle based on certificate type
- Uses system trust store for well-known CAs
- Fetches OpenShift or custom CA bundles as needed

### Step 6: Verify Certificate
- Verifies the certificate against the CA bundle
- Uses appropriate verification method based on certificate type
- Reports verification success or failure

### Step 7: Display Certificate Chain and Trust Path
- Shows the complete trust chain from server to root CA
- Identifies intermediate CAs
- Verifies if root CA is self-signed

### Step 8: Test Connectivity
- Tests HTTPS connectivity to the API server
- Uses appropriate CA bundle for verification
- Displays Kubernetes version information

## Output

The script creates a timestamped working directory with the following files:

```
run-YYYYMMDD-HHMMSS/
├── kube-apiserver-serving-cert.pem  # Server leaf certificate
├── intermediate-ca.pem              # Intermediate CA (if present)
├── kube-apiserver-ca-bundle.crt     # CA bundle (if applicable)
├── fullchain.pem                    # Full certificate chain
└── openssl_output.txt               # Raw openssl s_client output
```

## Certificate Types

### Type 1: OpenShift-Managed Certificate
- **Cluster Type**: Self-Managed OpenShift
- **Issuer**: `CN=kube-apiserver-lb-signer`
- **CA Bundle**: Retrieved from `kube-apiserver-server-ca` ConfigMap
- **Custom Config**: No custom certificates configured

### Type 2: RedHat-Managed Certificate
- **Cluster Type**: Managed OpenShift (ROSA, ARO, OSD)
- **Issuer**: Well-known CA (not kube-apiserver-lb-signer)
- **CA Bundle**: System trust store
- **Custom Config**: Not available to users

### Type 3a: Custom CA - Well-Known
- **Cluster Type**: Self-Managed OpenShift
- **Issuer**: Let's Encrypt, DigiCert, GlobalSign, etc.
- **CA Bundle**: System trust store
- **Custom Config**: Custom certificate configured by customer

### Type 3b: Custom CA - Self-Signed
- **Cluster Type**: Self-Managed OpenShift
- **Issuer**: Custom/Private CA
- **CA Bundle**: Custom certificate Secret's `tls.crt` field in openshift-config
- **Custom Config**: Custom certificate configured by customer

## Example Output

```
========================================
Step 0: Set Up Kubeconfig
========================================

ℹ Using kubeconfig found in current directory: /path/to/kubeconfig
ℹ Verifying authentication...
✓ Authenticated as: system:admin

========================================
Step 1: Get External API Server Endpoint
========================================

✓ API Server URL: https://api.cluster-name.example.com:6443
ℹ API Hostname: api.cluster-name.example.com

...

========================================
Step 6: Verify Certificate
========================================

ℹ Verifying certificate with CA bundle...
✓ Certificate verification successful!
run-20251107-150535/kube-apiserver-serving-cert.pem: OK

...

========================================
Summary
========================================

✓ All workflow steps completed!

Certificate Type: Type 1 - OpenShift-Managed Certificate
Working Directory: run-20251107-150535

Files created:
  - run-20251107-150535/kube-apiserver-serving-cert.pem (server certificate)
  - run-20251107-150535/intermediate-ca.pem (intermediate CA, if present)
  - run-20251107-150535/kube-apiserver-ca-bundle.crt (CA bundle)
  - run-20251107-150535/fullchain.pem (full certificate chain)
  - run-20251107-150535/openssl_output.txt (raw openssl output)

✓ Certificate analysis complete!
```

## Troubleshooting

### Proxy Issues

If you encounter proxy-related errors during the connectivity test, the script automatically bypasses proxy settings. If issues persist:

```bash
# Manually unset proxy variables
unset https_proxy http_proxy HTTPS_PROXY HTTP_PROXY
./ocp-cert-analysis.sh
```

### Authentication Failures

Ensure your kubeconfig is valid and has proper permissions:

```bash
oc whoami
oc get infrastructure cluster
```

### Permission Errors

Make sure the script is executable:

```bash
chmod +x ocp-cert-analysis.sh
```

## Advanced Usage

### Analyze Multiple Clusters

```bash
# Cluster 1
KUBECONFIG=/path/to/cluster1/kubeconfig ./ocp-cert-analysis.sh

# Cluster 2
KUBECONFIG=/path/to/cluster2/kubeconfig ./ocp-cert-analysis.sh
```

### Compare Results

```bash
# Run analysis for different clusters and compare
ls -la run-*/kube-apiserver-serving-cert.pem
```

## Requirements

- OpenShift 4.x cluster
- Bash 4.0 or later
- Network access to the API server
- Cluster admin or appropriate permissions to read ConfigMaps

## References

- [OpenShift Documentation](https://docs.openshift.com/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
- Full workflow guide in `CLAUDE.md`

## License

This tool is provided as-is for OpenShift certificate analysis and verification.
