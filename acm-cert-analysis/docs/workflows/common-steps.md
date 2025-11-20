# Common Certificate Analysis (Steps 1-8)

**Prerequisites:** You MUST have selected a workflow before proceeding.

All workflows require certificate analysis. After selecting your workflow, complete Steps 1-8 below, then proceed to your selected workflow for specific recommendations.

---

## ⚠️ CRITICAL: Command Syntax Requirements

**IMPORTANT**: All commands in this workflow have been tested and verified to work correctly. You MUST:

1. **Follow the exact command syntax shown** - Do NOT modify or "improve" the commands
2. **Use backticks (`` ` ``) for command substitution** - NOT `$(...)` syntax
3. **Do NOT combine multiple commands unnecessarily** - Run commands as shown
4. **Copy commands exactly as written** - These patterns are shell-agnostic and proven to work

**Example of CORRECT syntax:**
```bash
WORKDIR=`cat .current_workdir`
```

**Example of INCORRECT syntax (will FAIL):**
```bash
WORKDIR=$(cat .current_workdir)  # ❌ WRONG - will fail in some shells
```

**If you deviate from these patterns, commands WILL fail.**

---

## Step 1: Set Up Kubeconfig (MANDATORY)

**CRITICAL**: You MUST complete this step before proceeding to Step 2.

You must provide your kubeconfig file using ONE of these methods:

### Option A: Provide Kubeconfig Path

If you know the path to your kubeconfig file, provide it directly:

```bash
# Set your kubeconfig path (replace with your actual path)
export KUBECONFIG="/path/to/your/kubeconfig"

# Verify the kubeconfig is valid
oc whoami --show-server
```

**Common kubeconfig locations:**
- `~/.kube/config` (default location)
- `~/kubeconfig` (common custom location)
- Custom paths provided during cluster creation

### Option B: Search and Choose from Available Kubeconfig Files

If you're unsure of the path, search for available kubeconfig files:

**Search in common locations:**
```bash
# Search for kubeconfig files
echo "Searching for kubeconfig files..."
echo ""
echo "=== Default location ==="
ls -lh ~/.kube/config 2>/dev/null || echo "Not found"
echo ""
echo "=== Home directory ==="
ls -lh ~/kubeconfig 2>/dev/null || echo "Not found"
echo ""
echo "=== Current directory ==="
find . -maxdepth 2 -name "*kubeconfig*" -type f 2>/dev/null || echo "Not found"
```

**Select and verify your kubeconfig:**
```bash
# After identifying your kubeconfig file, set it
export KUBECONFIG="/path/to/selected/kubeconfig"

# Verify the connection
oc whoami --show-server
```

**Expected output:** The API server URL (e.g., `https://api.cluster-name.domain.com:6443`)

**Verification checklist:**
- [ ] `KUBECONFIG` environment variable is set
- [ ] `oc whoami --show-server` returns a valid API server URL
- [ ] You can successfully connect to the cluster

**Note:** All subsequent `oc` commands in this workflow will use this kubeconfig file.

**🔴 CRITICAL - KUBECONFIG PERSISTENCE:**

If you are running commands manually in a shell, the `KUBECONFIG` environment variable will persist for your current shell session.

**However**, if you are using an automation tool or AI agent that executes each command in a separate shell session, you MUST include the `export KUBECONFIG=...` statement in EVERY command that uses `oc`.

For automation/AI agents, all `oc` commands must follow this pattern:
```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc <command>
```

**DO NOT proceed to Step 2 until this verification is complete.**

---

## Step 2: Get the External API Server Endpoint

**⚠️ IMPORTANT**: Use the EXACT command below. Do NOT try to combine this with other commands or use `$(...)` syntax.

**🔴 CRITICAL**: If using automation/AI agents, you MUST include the `export KUBECONFIG=...` statement in this command.

Retrieve the external API server URL:

**For manual shell execution:**
```bash
oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}'
```

**For automation/AI agents:**
```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}'
```

**Expected output:** `https://api.<cluster-name>.<domain>.com:6443`

**Note:** This command retrieves the API server URL from the cluster's infrastructure resource. The hostname and port will be extracted in Step 3 using the verified command patterns.

---

## Step 3: Create Working Directory and Retrieve Serving Certificate

**Important for manual shell execution:** Ensure you run all commands in this workflow in the same shell session to maintain environment variables like `WORKDIR`, `API_HOSTNAME`, `API_PORT`, and `KUBECONFIG`.

**Important for automation/AI agents:** Since each command may run in a separate shell session, you must either chain commands together with `&&` or re-set variables in every command that uses them. See the specific "For automation/AI agents" commands below.

**⚠️ REMINDER**: All commands below use backticks (`` ` ``) for command substitution. Do NOT change to `$(...)` syntax.

Create a timestamped directory for this analysis run:

```bash
# Create working directory and store the path
# NOTE: Uses backticks for command substitution - DO NOT change this!
TIMESTAMP=`date +%Y%m%d-%H%M%S` && WORKDIR="run-${TIMESTAMP}" && mkdir -p "${WORKDIR}" && echo "Working directory: ${WORKDIR}" && echo "${WORKDIR}" > .current_workdir
```

Extract the API hostname and port, then retrieve the certificate chain:

**🔴 CRITICAL**: If using automation/AI agents, prepend `export KUBECONFIG="/path/to/your/kubeconfig" &&` to this command.

**For manual shell execution:**
```bash
# Extract API hostname and port using sed (shell-agnostic approach)
API_ENDPOINT=`oc whoami --show-server`
API_HOSTNAME=`echo "$API_ENDPOINT" | sed 's|https://||' | sed 's|:.*||'`
API_PORT=`echo "$API_ENDPOINT" | sed 's|.*:||'`
echo "API Hostname: ${API_HOSTNAME}"
echo "API Port: ${API_PORT}"
```

**For automation/AI agents (each command runs in separate shell):**
```bash
# Must set KUBECONFIG and extract variables in the same command
export KUBECONFIG="/path/to/your/kubeconfig" && API_ENDPOINT=`oc whoami --show-server` && API_HOSTNAME=`echo "$API_ENDPOINT" | sed 's|https://||' | sed 's|:.*||'` && API_PORT=`echo "$API_ENDPOINT" | sed 's|.*:||'` && echo "API Hostname: ${API_HOSTNAME}" && echo "API Port: ${API_PORT}"
```

---

Retrieve the certificate chain from the API server and separate the leaf certificate from intermediate CAs:

**🔴 CRITICAL - Variable Persistence for Automation/AI Agents:**

The commands below use `API_HOSTNAME` and `API_PORT` variables. If using automation/AI agents that execute each command in separate shell sessions, you **MUST** re-set these variables in the same command, or chain all variable-setting and usage together with `&&`.

**For manual shell execution:**
```bash
# Get the full chain from the server
WORKDIR=`cat .current_workdir` && echo | openssl s_client -connect ${API_HOSTNAME}:${API_PORT} -showcerts 2>/dev/null > "${WORKDIR}/openssl_output.txt" && echo "Certificate chain retrieved"
```

**For automation/AI agents:**
```bash
# Must re-set variables in the same command
export KUBECONFIG="/path/to/your/kubeconfig" && API_ENDPOINT=`oc whoami --show-server` && API_HOSTNAME=`echo "$API_ENDPOINT" | sed 's|https://||' | sed 's|:.*||'` && API_PORT=`echo "$API_ENDPOINT" | sed 's|.*:||'` && WORKDIR=`cat .current_workdir` && echo | openssl s_client -connect ${API_HOSTNAME}:${API_PORT} -showcerts 2>/dev/null > "${WORKDIR}/openssl_output.txt" && echo "Certificate chain retrieved"

# Extract and separate certificates
WORKDIR=`cat .current_workdir` && sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "${WORKDIR}/openssl_output.txt" > "${WORKDIR}/fullchain.pem" && echo "Full chain extracted"

# Separate leaf certificate from intermediate CA
WORKDIR=`cat .current_workdir` && awk '/BEGIN CERTIFICATE/ {n++} n==1' "${WORKDIR}/fullchain.pem" > "${WORKDIR}/serving-cert.pem" && awk '/BEGIN CERTIFICATE/ {n++} n>=2' "${WORKDIR}/fullchain.pem" > "${WORKDIR}/intermediate-ca.pem" && ls -lh "${WORKDIR}/"
```

**Note:**
- The working directory path is saved to `.current_workdir` for reference in subsequent commands
- This separates the server's leaf certificate from the intermediate CA chain, which is needed for proper verification
- All files will be saved in the `run-<timestamp>` directory

### Display Certificate Details

View the certificate subject and issuer:

```bash
WORKDIR=`cat .current_workdir`
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -subject -issuer
```

View validity period:

```bash
WORKDIR=`cat .current_workdir`
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -dates
```

View Subject Alternative Names:

```bash
WORKDIR=`cat .current_workdir`
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -ext subjectAltName
```

---

## Step 4: Determine Certificate Type

### Understanding OpenShift Cluster Types

There are **two types of OpenShift clusters**:

1. **Managed OpenShift Clusters** (ROSA, ARO, OpenShift Dedicated, etc.)
   - Kube-apiserver serving certificate is **managed by Red Hat**
   - Users **cannot** configure custom certificates
   - Certificate type: **RedHat-Managed Certificate**

2. **Self-Managed OpenShift Clusters**
   - Users **can** configure custom certificates
   - If no custom certificate is configured, uses **OpenShift-Managed Certificate** (default)
   - Certificate types: **OpenShift-Managed** or **Custom CA Certificate**

### Certificate Type Decision Tree

```
Start: Check Certificate Issuer
│
├─── Issuer is "CN=kube-apiserver-lb-signer"
│    │
│    └─── Check .spec.servingCerts.namedCertificates
│         │
│         ├─── Empty/Does not exist
│         │    └─── Type 1: OpenShift-Managed Certificate
│         │         (Self-Managed Cluster, default config)
│         │
│         └─── Exists with data
│              └─── [Unusual case - investigate further]
│
└─── Issuer is NOT "CN=kube-apiserver-lb-signer"
     │
     └─── Check .spec.servingCerts.namedCertificates
          │
          ├─── Does NOT exist OR exists but secret missing
          │    └─── Type 2: RedHat-Managed Certificate
          │         (Managed Cluster: ROSA, ARO, OSD)
          │
          └─── Exists AND secret exists in cluster
               │
               └─── Type 3: Custom CA Certificate
                    (Self-Managed Cluster)
                    │
                    ├─── Issuer: Let's Encrypt, DigiCert, etc.
                    │    └─── Type 3a: Custom CA - Well-Known CA
                    │
                    └─── Issuer: Custom organization CA
                         └─── Type 3b: Custom CA - Self-Signed CA
```

---

### Determine Your Certificate Type

Follow these steps in order to determine your certificate type:

#### Step 4.1: Check the Issuer

From Step 3, check if the issuer contains `CN=kube-apiserver-lb-signer`:

```bash
# Review the issuer from Step 3
WORKDIR=`cat .current_workdir`
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -issuer
```

---

#### Step 4.2: Check for Custom Certificate Configuration

**🔴 CRITICAL**: If using automation/AI agents, prepend `export KUBECONFIG="/path/to/your/kubeconfig" &&` to all `oc` commands in Steps 4.2 and 4.3.

Check if custom certificates are configured in the apiserver resource:

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

**Possible outcomes:**
- **Empty/Nothing returned**: No custom certificate configuration exists
- **Data returned**: Custom certificate configuration exists (proceed to verify the referenced secret)

---

#### Step 4.3: If Custom Certificate Configuration Exists, Verify the Secret

If Step 4.2 returned data, extract the secret name and namespace:

```bash
# Get the secret reference
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate}'
```

Example output: `{"name":"custom-cert-secret"}`

Check if the secret exists:

```bash
# Replace <secret-name> with the name from above
oc get secret <secret-name> -n openshift-config --ignore-not-found
```

**Outcomes:**
- **Secret exists**: Returns secret details - Custom certificate is actually configured
- **Secret does NOT exist**: Returns empty output (no error) - Custom certificate configuration exists but secret is missing

---

### Determine Certificate Type Based on Checks

#### Type 2: RedHat-Managed Certificate (Managed OpenShift Clusters)

**All conditions must be met:**
1. ✅ Issuer is **NOT** `CN=kube-apiserver-lb-signer` (from Step 4.1)
2. ✅ **AND** one of the following:
   - `.spec.servingCerts.namedCertificates` does **NOT** exist (Step 4.2 returns empty)
   - **OR** `.spec.servingCerts.namedCertificates` exists but referenced secret does **NOT** exist (Step 4.3 fails)

**This indicates:** Managed cluster (ROSA, ARO, OpenShift Dedicated) where certificates are managed by Red Hat

**Next:** Go to Step 5B (RedHat-Managed)

---

#### Type 1: OpenShift-Managed Certificate (Default for Self-Managed Clusters)

**Conditions:**
1. ✅ Issuer is `CN=kube-apiserver-lb-signer` (from Step 4.1)
2. ✅ **AND** `.spec.servingCerts.namedCertificates` is empty or does not exist (Step 4.2)

**This indicates:** Self-managed cluster using the default OpenShift-managed certificate

**Next:** Go to Step 5A (OpenShift-Managed)

---

#### Type 3: Custom CA Certificate (Self-Managed Clusters Only)

**Conditions:**
1. ✅ Issuer is **NOT** `CN=kube-apiserver-lb-signer` (from Step 4.1)
2. ✅ **AND** `.spec.servingCerts.namedCertificates` exists (Step 4.2 returns data)
3. ✅ **AND** referenced secret exists in the cluster (Step 4.3 succeeds)

**This indicates:** Self-managed cluster with custom certificate configured by the customer

**Proceed to determine the sub-type:**

##### Sub-type 3a: Custom Certificate Signed by Well-Known CA
**Condition:** Issuer contains well-known CA names
**Examples:** `Let's Encrypt`, `DigiCert`, `GlobalSign`, `Sectigo`, `GeoTrust`, `Entrust`
**Next:** Go to Step 5C (Custom CA)

##### Sub-type 3b: Custom Certificate Signed by Self-Signed CA
**Condition:** Issuer is a custom/private CA (not well-known)
**Examples:** `CN=My Company Root CA`, `CN=Internal PKI CA`
**Next:** Go to Step 5C (Custom CA)

---

## Step 5: Retrieve CA Bundle Based on Certificate Type

**🔴 CRITICAL**: If using automation/AI agents, prepend `export KUBECONFIG="/path/to/your/kubeconfig" &&` to all `oc` commands in Step 5.

### Step 5A: OpenShift-Managed Certificate

#### Check Configuration

Verify no custom certificates are configured:

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

If this returns empty or nothing, you're using OpenShift-managed certificates.

#### Retrieve CA Bundle

Get the OpenShift-managed CA bundle from the `kube-apiserver-server-ca` configmap in the `openshift-kube-apiserver` namespace:

```bash
WORKDIR=`cat .current_workdir`
oc get configmap kube-apiserver-server-ca -n openshift-kube-apiserver -o jsonpath='{.data.ca-bundle\.crt}' > "${WORKDIR}/ca-bundle.crt"
echo "CA bundle retrieved: ${WORKDIR}/ca-bundle.crt"
```

**Note:** The CA bundle for OpenShift-Managed certificates contains the `CN=kube-apiserver-lb-signer` CA certificate. This configmap is in the `openshift-kube-apiserver` namespace, which is more stable than operator namespaces.

Count certificates in the bundle:

```bash
WORKDIR=`cat .current_workdir`
grep -c "BEGIN CERTIFICATE" "${WORKDIR}/ca-bundle.crt"
```

**Expected:** 1 certificate (the kube-apiserver-lb-signer CA)

**Next:** Go to Step 6

---

### Step 5B: RedHat-Managed Certificate

#### Check Configuration

Verify certificate is managed by Red Hat (used in ROSA, ARO, or other managed services):

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

**Note:** RedHat-managed certificates are typically handled by the managed service provider.

#### Retrieve CA Bundle

For RedHat-managed certificates, check for the CA bundle location (specific to the managed service):

```bash
# Check for service-specific CA ConfigMap
oc get configmap -n openshift-config | grep -i ca
```

Retrieve the appropriate CA bundle based on the managed service documentation.

**Next:** Go to Step 6

---

### Step 5C: Custom CA Certificate

Custom certificates are configured by the customer. There are two sub-types:

#### Check Configuration

Verify custom certificates are configured:

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

Should return custom certificate configuration.

#### Retrieve Custom CA Bundle from Certificate Secret

For custom certificates, the CA bundle is stored in the custom certificate secret itself (the same secret referenced in `.spec.servingCerts.namedCertificates`).

First, get the secret name (from Step 4.3):

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}'
```

Example output: `server-cert-s1`

Extract the CA bundle from the secret's `tls.crt` field:

```bash
WORKDIR=`cat .current_workdir`
SECRET_NAME=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}'`
oc extract secret/${SECRET_NAME} -n openshift-config --keys=tls.crt --to=- > "${WORKDIR}/ca-bundle.crt" 2>/dev/null
echo "CA bundle retrieved from secret: ${SECRET_NAME}"
```

Count certificates in the bundle:

```bash
WORKDIR=`cat .current_workdir`
grep -c "BEGIN CERTIFICATE" "${WORKDIR}/ca-bundle.crt"
```

**Note:** The `tls.crt` field in a custom certificate secret typically contains the full certificate chain (leaf certificate + intermediate CA(s) + root CA). This complete chain is what we use as the CA bundle for verification.

**Next:** Go to Step 6

---

## Step 6: Verify the Serving Certificate

### For Type 1: OpenShift-Managed Certificate

Verify the certificate with the OpenShift CA bundle:

```bash
WORKDIR=`cat .current_workdir`
openssl verify -CAfile "${WORKDIR}/ca-bundle.crt" "${WORKDIR}/serving-cert.pem"
```

**Expected output:** `serving-cert.pem: OK`

---

### For Type 2: RedHat-Managed Certificate

For RedHat-managed certificates signed by well-known CAs (like Let's Encrypt), verify with system trust store and intermediate CA:

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

**Expected output:** `serving-cert.pem: OK`

---

### For Type 3a: Custom Certificate Signed by Well-Known CA

Verify with system trust store, providing intermediate CAs:

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

**Expected output:** `serving-cert.pem: OK`

**Note:** The `-untrusted` parameter provides intermediate CA certificates for chain building, while the system trust store (or `-CAfile`/`-CApath`) provides trusted root CAs.

---

### For Type 3b: Custom Certificate Signed by Self-Signed CA

Verify the certificate with the custom CA bundle:

```bash
WORKDIR=`cat .current_workdir`
openssl verify -CAfile "${WORKDIR}/ca-bundle.crt" "${WORKDIR}/serving-cert.pem"
```

**Expected output:** `serving-cert.pem: OK`

---

## Step 7: Display the Certificate Chain

### Display the Trust Chain

Show the complete trust path from server certificate to root CA:

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

### Verify if the CA is Self-Signed (Root CA)

Check if the issuing CA is a self-signed root CA:

**For OpenShift-Managed certificates:**
```bash
WORKDIR=`cat .current_workdir`
awk '/BEGIN CERTIFICATE/ { n++ } n == 1' "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -subject -issuer
```

**For Custom CA:**
```bash
WORKDIR=`cat .current_workdir`
awk '/BEGIN CERTIFICATE/ { n++ } n == 1' "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -subject -issuer
```

If **subject == issuer**, it's a self-signed root CA (typical for OpenShift-managed certs).

If **subject ≠ issuer**, there's an intermediate CA, and you should continue checking:

```bash
# Check second certificate in bundle
WORKDIR=`cat .current_workdir`
awk '/BEGIN CERTIFICATE/ { n++ } n == 2' "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -subject -issuer
```

Continue until you find the root CA where subject == issuer.

**Note:** Only display certificates that are part of the actual trust chain. The CA bundle may contain additional certificates (like localhost-signer, service-network-signer) that are not involved in verifying the external API server certificate.

---

## Step 8: Test Connectivity

**🔴 CRITICAL**: If using automation/AI agents, prepend `export KUBECONFIG="/path/to/your/kubeconfig" &&` to all commands in Step 8 that use `oc`.

### For Type 1: OpenShift-Managed Certificate

Test with the OpenShift CA bundle:

```bash
WORKDIR=`cat .current_workdir`
API_ENDPOINT=`oc whoami --show-server`
curl --cacert "${WORKDIR}/ca-bundle.crt" "${API_ENDPOINT}/healthz"
```

**Expected:** `ok` response with HTTP 200 status.

---

### For Type 2: RedHat-Managed Certificate

For RedHat-managed certificates signed by well-known CAs (like Let's Encrypt), test without specifying CA (uses system trust store):

```bash
API_ENDPOINT=`oc whoami --show-server`
curl "${API_ENDPOINT}/healthz"
```

**Expected:** `ok` response with HTTP 200 status.

---

### For Type 3a: Custom Certificate Signed by Well-Known CA

Test without specifying CA (uses system trust store):

```bash
API_ENDPOINT=`oc whoami --show-server`
curl "${API_ENDPOINT}/healthz"
```

**Expected:** `ok` response with HTTP 200 status.

---

### For Type 3b: Custom Certificate Signed by Self-Signed CA

Test with the custom CA bundle:

```bash
WORKDIR=`cat .current_workdir`
API_ENDPOINT=`oc whoami --show-server`
curl --cacert "${WORKDIR}/ca-bundle.crt" "${API_ENDPOINT}/healthz"
```

**Expected:** `ok` response with HTTP 200 status.

---

## Next Steps

You have completed the common certificate analysis (Steps 1-8). Now proceed to your selected workflow:

- [Workflow A: ACM Pre-Installation Analysis](workflow-a-pre-installation.md)
- Workflow B: ACM Post-Installation Analysis *(Coming soon)*
- Workflow C: Certificate Change Evaluation *(Coming soon)*
