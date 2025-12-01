---
name: ocp-cert-analysis
description: Analyze OpenShift kube-apiserver certificates. Determines certificate type (OpenShift-Managed, RedHat-Managed, Custom CA), retrieves CA bundle, verifies certificate chain, and tests connectivity. Use for certificate analysis, verification, and type determination. Accepts --kubeconfig (optional, defaults to KUBECONFIG env var) and --output (optional, defaults to current directory) parameters.
allowed-tools: [Bash, Read]
---

# OCP Certificate Analysis

This skill performs comprehensive OpenShift kube-apiserver certificate analysis. It identifies certificate types, retrieves CA bundles, verifies certificate chains, and validates API server connectivity.

## 🚀 Execution Instructions

**When this skill is invoked:**

1. **Check if kubeconfig argument was provided** in the user's invocation message
   - If provided (e.g., "run ocp-cert-analysis kubeconfig.c3"), extract it
   - If not provided, ask the user for the kubeconfig path

2. **Use the script-based workflow (Method 1 - Recommended)**
   - **IMPORTANT**: Do NOT change directory before executing the script
   - Execute from the current working directory:
     - With --kubeconfig: `bash .claude/skills/ocp-cert-analysis/scripts/run-all.sh --kubeconfig <path>`
     - With KUBECONFIG env var: `export KUBECONFIG=<path> && bash .claude/skills/ocp-cert-analysis/scripts/run-all.sh`
   - The working directory will be created in the current directory (where the command is invoked)
   - Optionally specify output directory: `bash .claude/skills/ocp-cert-analysis/scripts/run-all.sh --kubeconfig <path> --output <directory>`
   - The script will run all 8 steps automatically and display a summary

3. **Only use manual commands (Method 2)** if:
   - Scripts fail or are unavailable
   - User explicitly requests step-by-step manual execution
   - Debugging or troubleshooting specific steps

## Usage

**With kubeconfig argument:**
```
User: run ocp-cert-analysis kubeconfig.c3
```

**Without argument (will prompt for kubeconfig):**
```
User: run ocp-cert-analysis
```

## When to Use This Skill

Invoke this skill when you need to:
- **Analyze OpenShift cluster certificates**
- **Determine certificate type** (OpenShift-Managed, RedHat-Managed, Custom CA)
- **Retrieve and verify CA bundles**
- **Validate certificate chains**
- **Test API server connectivity with certificates**

## Trigger Keywords

- "analyze cluster certificates"
- "check certificate type"
- "verify kube-apiserver certificate"
- "certificate analysis"
- "OpenShift certificate verification"

## Prerequisites

- ✅ OpenShift cluster access with valid kubeconfig
- ✅ `oc` CLI installed
- ✅ `openssl` CLI available

---

## 🎯 Workflow Execution Methods

This skill supports two execution methods:

### Method 1: Automated Scripts (Recommended)

**All workflow steps have been converted to modular shell scripts** located in `scripts/` directory.

**Benefits:**
- ✅ API endpoint fetched once and reused across all steps
- ✅ State persisted between steps (kubeconfig, workdir, cert type)
- ✅ Cleaner output with colored status messages
- ✅ Error handling and validation built-in
- ✅ Can run individual steps or complete workflow

**Quick Start:**
```bash
# Run complete workflow (all 8 steps)
# Option 1: Specify kubeconfig with --kubeconfig parameter
bash .claude/skills/ocp-cert-analysis/scripts/run-all.sh --kubeconfig kubeconfig.c3

# Option 2: Use KUBECONFIG environment variable
export KUBECONFIG=kubeconfig.c3
bash .claude/skills/ocp-cert-analysis/scripts/run-all.sh

# Option 3: Specify custom output directory
bash .claude/skills/ocp-cert-analysis/scripts/run-all.sh --kubeconfig kubeconfig.c3 --output /path/to/output

# Or run individual steps (from project root)
bash .claude/skills/ocp-cert-analysis/scripts/01-setup-kubeconfig.sh --kubeconfig kubeconfig.c3
bash .claude/skills/ocp-cert-analysis/scripts/02-get-api-endpoint.sh
bash .claude/skills/ocp-cert-analysis/scripts/03-retrieve-cert-chain.sh
# ... continue with remaining steps

# Display summary
bash .claude/skills/ocp-cert-analysis/scripts/99-summary.sh
```

**Available Scripts:**
- `common.sh` - Shared functions and environment variables
- `01-setup-kubeconfig.sh` - Set up and verify kubeconfig
- `02-get-api-endpoint.sh` - Get API endpoint (saved for reuse)
- `03-retrieve-cert-chain.sh` - Retrieve certificate chain
- `04-determine-cert-type.sh` - Determine certificate type
- `05-get-ca-bundle.sh` - Get CA bundle based on type
- `06-verify-cert.sh` - Verify certificate
- `07-display-cert-chain.sh` - Display chain and check root CA
- `08-test-connectivity.sh` - Test API connectivity
- `99-summary.sh` - Display analysis summary
- `run-all.sh` - Execute complete workflow

### Method 2: Manual Commands (Fallback)

Individual commands are documented below for reference and troubleshooting.

---

## 🔴 CRITICAL: Command Execution Protocol (Manual Method)

**All commands have been tested and verified. You MUST:**

1. **Use EXACT commands** from this documentation - DO NOT modify
2. **Use backticks (\`) for command substitution** - NOT $()
3. **Prepend `export KUBECONFIG=...` to ALL `oc` commands** (automation context)
4. **DO NOT combine commands** unless shown in documentation

**CORRECT:**
```bash
WORKDIR=`cat .current_workdir`
```

**INCORRECT:**
```bash
WORKDIR=$(cat .current_workdir)  # ❌ WRONG
```

---

## Certificate Types

| Certificate Type | Issuer | Cluster Type |
|------------------|--------|--------------|
| **OpenShift-Managed Certificate** | `CN=kube-apiserver-lb-signer` | Self-Managed |
| **RedHat-Managed Certificate** | Well-known CA | Managed (ROSA, ARO, OSD) |
| **Custom CA - Well-Known CA** | Let's Encrypt, DigiCert, etc. | Self-Managed |
| **Custom CA - Self-Signed CA** | Private/Custom CA | Self-Managed |

---

## Workflow Steps

### Step 0: Parse Arguments (If Provided)

**When the skill is invoked, check if a kubeconfig path was provided as an argument:**

- If user ran: `run ocp-cert-analysis kubeconfig.c3` → Use `kubeconfig.c3` as the kubeconfig path
- If user ran: `run ocp-cert-analysis` → Ask the user to provide the kubeconfig file path

**Extract the argument from the user's invocation message and use it in Step 1.**

---

### Step 1: Set Up Kubeconfig (MANDATORY)

**CRITICAL**: Must complete before Step 2.

**If kubeconfig path was not provided as an argument in Step 0, ask the user to provide the kubeconfig file path.**

Once you have the kubeconfig path, verify the connection:

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc whoami
```

**Expected**: User identity (e.g., `system:admin`, `kube:admin`, or service account name)

**Verification checklist:**
- [ ] KUBECONFIG path obtained
- [ ] User identity displayed
- [ ] Successfully connected

**IMPORTANT**: All subsequent `oc` commands must use:
```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc <command>
```

**DO NOT proceed to Step 2 until verified.**

---

### Step 2: Get External API Server Endpoint

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}'
```

**Expected**: `https://api.<cluster-name>.<domain>.com:6443`

---

### Step 3: Create Working Directory and Retrieve Serving Certificate

**Create timestamped directory:**

```bash
TIMESTAMP=`date +%Y%m%d-%H%M%S` && WORKDIR="run-${TIMESTAMP}" && mkdir -p "${WORKDIR}" && echo "Working directory: ${WORKDIR}" && echo "${WORKDIR}" > .current_workdir
```

**Extract API hostname and port:**

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && API_ENDPOINT=`oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}'` && API_HOSTNAME=`echo "$API_ENDPOINT" | sed 's|https://||' | sed 's|:.*||'` && API_PORT=`echo "$API_ENDPOINT" | sed 's|.*:||'` && echo "API Hostname: ${API_HOSTNAME}" && echo "API Port: ${API_PORT}"
```

**Retrieve certificate chain:**

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && API_ENDPOINT=`oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}'` && API_HOSTNAME=`echo "$API_ENDPOINT" | sed 's|https://||' | sed 's|:.*||'` && API_PORT=`echo "$API_ENDPOINT" | sed 's|.*:||'` && WORKDIR=`cat .current_workdir` && echo | openssl s_client -connect ${API_HOSTNAME}:${API_PORT} -showcerts 2>/dev/null > "${WORKDIR}/openssl_output.txt" && echo "Certificate chain retrieved"
```

**Extract and separate certificates:**

```bash
WORKDIR=`cat .current_workdir` && sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "${WORKDIR}/openssl_output.txt" > "${WORKDIR}/fullchain.pem" && echo "Full chain extracted"
```

```bash
WORKDIR=`cat .current_workdir` && awk '/BEGIN CERTIFICATE/ {n++} n==1' "${WORKDIR}/fullchain.pem" > "${WORKDIR}/serving-cert.pem" && awk '/BEGIN CERTIFICATE/ {n++} n>=2' "${WORKDIR}/fullchain.pem" > "${WORKDIR}/intermediate-ca.pem" && ls -lh "${WORKDIR}/"
```

**Display certificate details:**

```bash
WORKDIR=`cat .current_workdir`
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -subject -issuer
```

```bash
WORKDIR=`cat .current_workdir`
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -dates
```

```bash
WORKDIR=`cat .current_workdir`
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -ext subjectAltName
```

---

### Step 4: Determine Certificate Type

**Step 4.1: Check the Issuer**

```bash
WORKDIR=`cat .current_workdir`
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -issuer
```

**Step 4.2: Check for Custom Certificate Configuration**

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

**Outcomes:**
- **Empty**: No custom certificate
- **Data returned**: Custom certificate exists → proceed to Step 4.3

**Step 4.3: If Custom Config Exists, Verify Secret**

Get secret name:

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate}'
```

Check if secret exists (replace `<secret-name>` with name from above):

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get secret <secret-name> -n openshift-config --ignore-not-found
```

**Certificate Type Decision:**

**OpenShift-Managed Certificate**
- ✅ Issuer is `CN=kube-apiserver-lb-signer`
- ✅ AND namedCertificates is empty

**RedHat-Managed Certificate**
- ✅ Issuer is NOT `CN=kube-apiserver-lb-signer`
- ✅ AND (namedCertificates does not exist OR secret does not exist)

**Custom CA Certificate**
- ✅ Issuer is NOT `CN=kube-apiserver-lb-signer`
- ✅ AND namedCertificates exists
- ✅ AND referenced secret exists
- **Well-Known CA**: Issuer is well-known CA (Let's Encrypt, DigiCert, etc.)
- **Self-Signed CA**: Issuer is custom/private CA

---

### Step 5: Retrieve CA Bundle Based on Certificate Type

#### For OpenShift-Managed Certificate

Verify no custom certificates:

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

Retrieve CA bundle:

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && WORKDIR=`cat .current_workdir` && oc get configmap kube-apiserver-server-ca -n openshift-kube-apiserver -o jsonpath='{.data.ca-bundle\.crt}' > "${WORKDIR}/ca-bundle.crt" && echo "CA bundle retrieved: ${WORKDIR}/ca-bundle.crt"
```

Count certificates:

```bash
WORKDIR=`cat .current_workdir`
grep -c "BEGIN CERTIFICATE" "${WORKDIR}/ca-bundle.crt"
```

**Expected**: Typically 1 or more certificates containing kube-apiserver-lb-signer CA

#### For RedHat-Managed Certificate

Check for service-specific CA ConfigMap:

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get configmap -n openshift-config | grep -i ca
```

Retrieve appropriate CA bundle based on managed service documentation.

#### For Custom CA Certificate

Verify custom certificates configured:

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

Get secret name:

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}'
```

Extract CA bundle from secret:

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && WORKDIR=`cat .current_workdir` && SECRET_NAME=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}'` && oc extract secret/${SECRET_NAME} -n openshift-config --keys=tls.crt --to=- > "${WORKDIR}/ca-bundle.crt" 2>/dev/null && echo "CA bundle retrieved from secret: ${SECRET_NAME}"
```

Count certificates:

```bash
WORKDIR=`cat .current_workdir`
grep -c "BEGIN CERTIFICATE" "${WORKDIR}/ca-bundle.crt"
```

---

### Step 6: Verify the Serving Certificate

#### For OpenShift-Managed Certificate

```bash
WORKDIR=`cat .current_workdir`
openssl verify -CAfile "${WORKDIR}/ca-bundle.crt" "${WORKDIR}/serving-cert.pem"
```

**Expected**: `serving-cert.pem: OK`

#### For RedHat-Managed Certificate

**On macOS:**
```bash
WORKDIR=`cat .current_workdir`
openssl verify -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/serving-cert.pem"
```

**On Linux (RHEL/Fedora/CentOS):**
```bash
WORKDIR=`cat .current_workdir`
openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/serving-cert.pem"
```

**On Linux (Debian/Ubuntu):**
```bash
WORKDIR=`cat .current_workdir`
openssl verify -CApath /etc/ssl/certs -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/serving-cert.pem"
```

**Expected**: `serving-cert.pem: OK`

#### For Custom CA - Well-Known CA

Same as RedHat-Managed Certificate (uses system trust store)

#### For Custom CA - Self-Signed CA

```bash
WORKDIR=`cat .current_workdir`
openssl verify -CAfile "${WORKDIR}/ca-bundle.crt" "${WORKDIR}/serving-cert.pem"
```

**Expected**: `serving-cert.pem: OK`

---

### Step 7: Display the Certificate Chain

Show complete trust path:

```bash
WORKDIR=`cat .current_workdir`
echo "=== Certificate Chain Analysis ==="
echo ""
echo "1. Serving Certificate:"
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -subject -issuer
echo ""
echo "2. CA Bundle Analysis:"
if [ -f "${WORKDIR}/ca-bundle.crt" ]; then
    CERT_COUNT=`grep -c "BEGIN CERTIFICATE" "${WORKDIR}/ca-bundle.crt"`
    echo "Number of certificates in CA bundle: ${CERT_COUNT}"
    echo ""

    # Display each certificate in the bundle
    for i in `seq 1 ${CERT_COUNT}`; do
        echo "--- Certificate ${i} ---"
        awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -subject -issuer
        echo ""
    done
fi
```

**Check if Root CA is included in CA bundle:**

Get the last certificate in the bundle and check if it's self-signed:

```bash
WORKDIR=`cat .current_workdir`
CERT_COUNT=`grep -c "BEGIN CERTIFICATE" "${WORKDIR}/ca-bundle.crt"`
echo "Checking last certificate in CA bundle (certificate ${CERT_COUNT}):"
awk "/BEGIN CERTIFICATE/ { n++ } n == ${CERT_COUNT}" "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -subject -issuer
```

Determine if root CA is included:

```bash
WORKDIR=`cat .current_workdir`
CERT_COUNT=`grep -c "BEGIN CERTIFICATE" "${WORKDIR}/ca-bundle.crt"`
LAST_CERT_SUBJECT=`awk "/BEGIN CERTIFICATE/ { n++ } n == ${CERT_COUNT}" "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -subject`
LAST_CERT_ISSUER=`awk "/BEGIN CERTIFICATE/ { n++ } n == ${CERT_COUNT}" "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -issuer`
if [ "$LAST_CERT_SUBJECT" = "$LAST_CERT_ISSUER" ]; then
    echo "✅ Root CA is INCLUDED in CA bundle (last certificate is self-signed)"
else
    echo "❌ Root CA is NOT included in CA bundle (last certificate is not self-signed)"
    echo "   Root CA is expected to be in system trust store or provided separately"
fi
```

**Root CA Inclusion Guide:**

- **OpenShift-Managed Certificate**: Root CA is always included (self-signed kube-apiserver-lb-signer)
- **RedHat-Managed Certificate**: Root CA typically NOT included (trusted by system)
- **Custom CA - Well-Known CA**: Root CA typically NOT included (trusted by system)
- **Custom CA - Self-Signed CA**: Root CA SHOULD be included (required for trust)

---

### Step 8: Test Connectivity

#### For OpenShift-Managed Certificate

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && WORKDIR=`cat .current_workdir` && API_ENDPOINT=`oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}'` && curl --cacert "${WORKDIR}/ca-bundle.crt" "${API_ENDPOINT}/healthz"
```

**Expected**: `ok` response with HTTP 200

#### For RedHat-Managed Certificate

```bash
export KUBECONFIG="/path/to/your/kubeconfig" && API_ENDPOINT=`oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}'` && curl "${API_ENDPOINT}/healthz"
```

**Expected**: `ok` response

#### For Custom CA - Well-Known CA

Same as RedHat-Managed Certificate (uses system trust store)

#### For Custom CA - Self-Signed CA

Same as OpenShift-Managed Certificate (uses CA bundle file)

---

## Analysis Complete

After completing Steps 1-8, you will have:

✅ **Identified certificate type** (OpenShift-Managed, RedHat-Managed, or Custom CA)
✅ **Retrieved CA bundle** for the certificate type
✅ **Determined root CA inclusion** in CA bundle
✅ **Verified certificate chain** is valid
✅ **Tested connectivity** to API server

## Summary Template

When presenting the final analysis summary, include:

**Certificate Analysis Summary:**
- Certificate Type
- CA Provider/Issuer
- Certificate Status (Valid/Expired)
- Valid Period
- **Root CA in Bundle**: Yes/No (✅/❌)
- Chain Verification Status
- API Connectivity Status

## Files Created

All analysis files are stored in `run-<timestamp>/` directory (created in current working directory or specified output directory):

- `serving-cert.pem` - Kube-apiserver leaf certificate
- `ca-bundle.crt` - CA certificate bundle
- `intermediate-ca.pem` - Intermediate CA certificates
- `fullchain.pem` - Complete certificate chain
- `openssl_output.txt` - Raw OpenSSL output

The working directory path is saved in `.claude/skills/ocp-cert-analysis/.current_workdir` file for script persistence.

---

## Troubleshooting

**Command fails with syntax error:**
- ✅ Verify using backticks (\`), not $()

**KUBECONFIG not persisting:**
- ✅ Prepend `export KUBECONFIG=...` to each `oc` command

**Certificate verification fails:**
- ✅ Verify correct CA bundle for certificate type

**oc command not found:**
- ✅ Ensure OpenShift CLI is installed
