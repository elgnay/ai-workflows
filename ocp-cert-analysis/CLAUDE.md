# Workflow: Analyze and Verify OpenShift Kube-APIServer Certificate

This workflow helps you analyze the kube-apiserver serving certificate, determine its type, retrieve the appropriate CA bundle, and verify the certificate chain.

## Step 0: Set Up Kubeconfig

First, provide the path to your kubeconfig file and set it for all subsequent commands:

```bash
# Prompt for kubeconfig path
read -p "Enter the path to your kubeconfig file: " KUBECONFIG_PATH

# Export the kubeconfig for all subsequent oc commands
export KUBECONFIG="${KUBECONFIG_PATH}"

# Verify the kubeconfig is valid
oc whoami
```

**Expected output:** Your OpenShift username (confirms successful authentication)

**Note:** All subsequent `oc` commands in this workflow will use this kubeconfig file. The `KUBECONFIG` environment variable will remain set for your current shell session.

---

## Step 1: Get the External API Server Endpoint

Retrieve the external API server URL:

```bash
oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}'
```

**Expected output:** `https://api.<cluster-name>.<domain>.com:6443`

Extract the hostname (without `https://` and port) for later use.

---

## Step 2: Create Working Directory and Retrieve Serving Certificate

Create a timestamped directory for this analysis run:

```bash
# Create working directory and store the path
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
WORKDIR="run-${TIMESTAMP}"
mkdir -p "${WORKDIR}"
echo "Working directory: ${WORKDIR}"
```

Retrieve the certificate chain from the API server and separate the leaf certificate from intermediate CAs:

```bash
# Get the full chain from the server
echo | openssl s_client -connect <api-hostname>:6443 -showcerts 2>/dev/null | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > "${WORKDIR}/fullchain.pem"

# Extract the leaf certificate (first certificate)
awk '/BEGIN CERTIFICATE/ { n++ } n == 1' "${WORKDIR}/fullchain.pem" > "${WORKDIR}/kube-apiserver-serving-cert.pem"

# Extract intermediate CA certificates (remaining certificates)
awk '/BEGIN CERTIFICATE/ { n++ } n >= 2' "${WORKDIR}/fullchain.pem" > "${WORKDIR}/intermediate-ca.pem"
```

Replace `<api-hostname>` with the hostname from Step 1.

**Note:** This separates the server's leaf certificate from the intermediate CA chain, which is needed for proper verification. All files will be saved in the `run-<timestamp>` directory.

### Display Certificate Details

View the certificate subject and issuer:

```bash
openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -subject -issuer
```

View validity period:

```bash
openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -dates
```

View Subject Alternative Names:

```bash
openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -ext subjectAltName
```

---

## Step 3: Determine Certificate Type

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

#### Step 3.1: Check the Issuer

From Step 2, check if the issuer contains `CN=kube-apiserver-lb-signer`:

```bash
# Review the issuer from Step 2
openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -issuer
```

---

#### Step 3.2: Check for Custom Certificate Configuration

Check if custom certificates are configured in the apiserver resource:

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

**Possible outcomes:**
- **Empty/Nothing returned**: No custom certificate configuration exists
- **Data returned**: Custom certificate configuration exists (proceed to verify the referenced secret)

---

#### Step 3.3: If Custom Certificate Configuration Exists, Verify the Secret

If Step 3.2 returned data, extract the secret name and namespace:

```bash
# Get the secret reference
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate}'
```

Example output: `{"name":"custom-cert-secret"}`

Check if the secret exists:

```bash
# Replace <secret-name> with the name from above
oc get secret <secret-name> -n openshift-config
```

**Outcomes:**
- **Secret exists**: Custom certificate is actually configured
- **Secret does NOT exist**: Custom certificate configuration exists but secret is missing

---

### Determine Certificate Type Based on Checks

#### Type 2: RedHat-Managed Certificate (Managed OpenShift Clusters)

**All conditions must be met:**
1. ✅ Issuer is **NOT** `CN=kube-apiserver-lb-signer` (from Step 3.1)
2. ✅ **AND** one of the following:
   - `.spec.servingCerts.namedCertificates` does **NOT** exist (Step 3.2 returns empty)
   - **OR** `.spec.servingCerts.namedCertificates` exists but referenced secret does **NOT** exist (Step 3.3 fails)

**This indicates:** Managed cluster (ROSA, ARO, OpenShift Dedicated) where certificates are managed by Red Hat

**Next:** Go to Step 4B (RedHat-Managed)

---

#### Type 1: OpenShift-Managed Certificate (Default for Self-Managed Clusters)

**Conditions:**
1. ✅ Issuer is `CN=kube-apiserver-lb-signer` (from Step 3.1)
2. ✅ **AND** `.spec.servingCerts.namedCertificates` is empty or does not exist (Step 3.2)

**This indicates:** Self-managed cluster using the default OpenShift-managed certificate

**Next:** Go to Step 4A (OpenShift-Managed)

---

#### Type 3: Custom CA Certificate (Self-Managed Clusters Only)

**Conditions:**
1. ✅ Issuer is **NOT** `CN=kube-apiserver-lb-signer` (from Step 3.1)
2. ✅ **AND** `.spec.servingCerts.namedCertificates` exists (Step 3.2 returns data)
3. ✅ **AND** referenced secret exists in the cluster (Step 3.3 succeeds)

**This indicates:** Self-managed cluster with custom certificate configured by the customer

**Proceed to determine the sub-type:**

##### Sub-type 3a: Custom Certificate Signed by Well-Known CA
**Condition:** Issuer contains well-known CA names
**Examples:** `Let's Encrypt`, `DigiCert`, `GlobalSign`, `Sectigo`, `GeoTrust`, `Entrust`
**Next:** Go to Step 4C-1 (Custom CA - Well-Known)

##### Sub-type 3b: Custom Certificate Signed by Self-Signed CA
**Condition:** Issuer is a custom/private CA (not well-known)
**Examples:** `CN=My Company Root CA`, `CN=Internal PKI CA`
**Next:** Go to Step 4C-2 (Custom CA - Self-Signed)

---

## Step 4A: OpenShift-Managed Certificate

### Check Configuration

Verify no custom certificates are configured:

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

If this returns empty or nothing, you're using OpenShift-managed certificates.

### Retrieve CA Bundle

Get the OpenShift-managed CA bundle:

```bash
oc get configmap kube-apiserver-server-ca -n openshift-kube-apiserver -o jsonpath='{.data.ca-bundle\.crt}' > "${WORKDIR}/kube-apiserver-ca-bundle.crt"
```

Count certificates in the bundle:

```bash
grep -c "BEGIN CERTIFICATE" "${WORKDIR}/kube-apiserver-ca-bundle.crt"
```

**Expected:** 4 certificates (lb-signer, localhost-signer, service-network-signer, recovery-signer)

**Next:** Go to Step 5

---

## Step 4B: RedHat-Managed Certificate

### Check Configuration

Verify certificate is managed by Red Hat (used in ROSA, ARO, or other managed services):

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

**Note:** RedHat-managed certificates are typically handled by the managed service provider.

### Retrieve CA Bundle

For RedHat-managed certificates, check for the CA bundle location (specific to the managed service):

```bash
# Check for service-specific CA ConfigMap
oc get configmap -n openshift-config | grep -i ca
```

Retrieve the appropriate CA bundle based on the managed service documentation.

**Next:** Go to Step 5

---

## Step 4C: Custom CA Certificate

Custom certificates are configured by the customer. There are two sub-types:

### Step 4C-1: Custom Certificate Signed by Well-Known CA

#### Check Configuration

Verify custom certificates are configured:

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

Should return custom certificate configuration with well-known CA as issuer.

#### No Custom CA Bundle Needed

Since the certificate is signed by a well-known CA (like Let's Encrypt, DigiCert), it's already in your system trust store.

You can verify using the system trust store directly without retrieving a custom CA bundle.

**Next:** Go to Step 5 (use system trust store for verification)

---

### Step 4C-2: Custom Certificate Signed by Self-Signed CA

#### Check Configuration

Verify custom certificates are configured:

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

Should return custom certificate configuration.

#### Find Custom CA Bundle

Check for custom CA ConfigMap reference:

```bash
oc get apiserver cluster -o jsonpath='{.spec.clientCA.name}'
```

If this returns a ConfigMap name, retrieve it:

```bash
oc get configmap <configmap-name> -n openshift-config -o jsonpath='{.data.ca-bundle\.crt}' > "${WORKDIR}/custom-ca-bundle.crt"
```

If empty, list available ConfigMaps in openshift-config:

```bash
oc get configmap -n openshift-config | grep -i ca
```

**Next:** Go to Step 5

---

## Step 5: Verify the Serving Certificate

### For Type 1: OpenShift-Managed Certificate

Verify the certificate with the OpenShift CA bundle:

```bash
openssl verify -CAfile "${WORKDIR}/kube-apiserver-ca-bundle.crt" "${WORKDIR}/kube-apiserver-serving-cert.pem"
```

**Expected output:** `<workdir>/kube-apiserver-serving-cert.pem: OK`

---

### For Type 2: RedHat-Managed Certificate

For RedHat-managed certificates signed by well-known CAs (like Let's Encrypt), verify with system trust store and intermediate CA:

**On macOS:**
```bash
openssl verify -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/kube-apiserver-serving-cert.pem"
```

**On Linux (RHEL/Fedora/CentOS):**
```bash
openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/kube-apiserver-serving-cert.pem"
```

**On Linux (Debian/Ubuntu):**
```bash
openssl verify -CApath /etc/ssl/certs -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/kube-apiserver-serving-cert.pem"
```

**Expected output:** `<workdir>/kube-apiserver-serving-cert.pem: OK`

---

### For Type 3a: Custom Certificate Signed by Well-Known CA

Verify with system trust store, providing intermediate CAs:

**On macOS:**
```bash
openssl verify -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/kube-apiserver-serving-cert.pem"
```

**On Linux (RHEL/Fedora/CentOS):**
```bash
openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/kube-apiserver-serving-cert.pem"
```

**On Linux (Debian/Ubuntu):**
```bash
openssl verify -CApath /etc/ssl/certs -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/kube-apiserver-serving-cert.pem"
```

**Expected output:** `<workdir>/kube-apiserver-serving-cert.pem: OK`

**Note:** The `-untrusted` parameter provides intermediate CA certificates for chain building, while the system trust store (or `-CAfile`/`-CApath`) provides trusted root CAs.

---

### For Type 3b: Custom Certificate Signed by Self-Signed CA

Verify the certificate with the custom CA bundle:

```bash
openssl verify -CAfile "${WORKDIR}/custom-ca-bundle.crt" "${WORKDIR}/kube-apiserver-serving-cert.pem"
```

**Expected output:** `<workdir>/kube-apiserver-serving-cert.pem: OK`

---

## Step 6: Display the Certificate Chain

### Display the Trust Chain

Show the complete trust path from server certificate to root CA:

```bash
echo "=== Certificate Chain (Trust Path) ==="
echo ""
echo "1. Leaf Certificate (Server):"
openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -subject
echo ""
echo "2. Issuing CA:"
openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -issuer

# Display intermediate CA if present
if [ -s "${WORKDIR}/intermediate-ca.pem" ]; then
    echo ""
    echo "3. Intermediate CA:"
    openssl x509 -in "${WORKDIR}/intermediate-ca.pem" -noout -subject -issuer
else
    echo ""
    echo "3. No intermediate CA (direct to root CA)"
fi
```

### Verify if the CA is Self-Signed (Root CA)

Check if the issuing CA is a self-signed root CA:

**For OpenShift-Managed certificates:**
```bash
awk '/BEGIN CERTIFICATE/ { n++ } n == 1' "${WORKDIR}/kube-apiserver-ca-bundle.crt" | openssl x509 -noout -subject -issuer
```

**For Custom CA:**
```bash
awk '/BEGIN CERTIFICATE/ { n++ } n == 1' "${WORKDIR}/custom-ca-bundle.crt" | openssl x509 -noout -subject -issuer
```

If **subject == issuer**, it's a self-signed root CA (typical for OpenShift-managed certs).

If **subject ≠ issuer**, there's an intermediate CA, and you should continue checking:

```bash
# Check second certificate in bundle
awk '/BEGIN CERTIFICATE/ { n++ } n == 2' "${WORKDIR}/kube-apiserver-ca-bundle.crt" | openssl x509 -noout -subject -issuer
```

Continue until you find the root CA where subject == issuer.

### Example Trust Chain Output

**For OpenShift-Managed (typical):**
```
1. Leaf Certificate (Server):
   subject=CN=api.cluster-name.domain.com

2. Issuing/Root CA (Self-Signed):
   subject=OU=openshift, CN=kube-apiserver-lb-signer
   issuer=OU=openshift, CN=kube-apiserver-lb-signer

Trust Chain: Server Cert → kube-apiserver-lb-signer (Root CA)
```

**For Custom CA with Intermediate:**
```
1. Leaf Certificate (Server):
   subject=CN=api.cluster-name.domain.com

2. Intermediate CA:
   subject=CN=Intermediate CA
   issuer=CN=Root CA

3. Root CA (Self-Signed):
   subject=CN=Root CA
   issuer=CN=Root CA

Trust Chain: Server Cert → Intermediate CA → Root CA
```

**Note:** Only display certificates that are part of the actual trust chain. The CA bundle may contain additional certificates (like localhost-signer, service-network-signer) that are not involved in verifying the external API server certificate.

---

## Step 7: Test Connectivity

### For Type 1: OpenShift-Managed Certificate

Test with the OpenShift CA bundle:

```bash
curl --cacert "${WORKDIR}/kube-apiserver-ca-bundle.crt" https://<api-url>/version
```

**Expected:** JSON response with Kubernetes version information.

---

### For Type 2: RedHat-Managed Certificate

For RedHat-managed certificates signed by well-known CAs (like Let's Encrypt), test without specifying CA (uses system trust store):

```bash
curl https://<api-url>/version
```

**Expected:** JSON response with Kubernetes version information.

---

### For Type 3a: Custom Certificate Signed by Well-Known CA

Test without specifying CA (uses system trust store):

```bash
curl https://<api-url>/version
```

**Expected:** JSON response with Kubernetes version information.

---

### For Type 3b: Custom Certificate Signed by Self-Signed CA

Test with the custom CA bundle:

```bash
curl --cacert "${WORKDIR}/custom-ca-bundle.crt" https://<api-url>/version
```

**Expected:** JSON response with Kubernetes version information.

---

## Summary

This workflow:

1. ✅ Sets up kubeconfig for cluster access
2. ✅ Retrieves the external API server endpoint
3. ✅ Extracts the serving certificate details (subject, issuer, validity, SANs)
4. ✅ Determines the certificate type by analyzing the issuer
5. ✅ Retrieves the appropriate CA bundle based on certificate type
6. ✅ Verifies the serving certificate against the CA bundle
7. ✅ Displays the certificate chain and trust path
8. ✅ Tests connectivity using the appropriate CA bundle

## Quick Reference: Certificate Types

### How to Identify Cluster Type

A cluster is a **Managed OpenShift Cluster** if **ALL** conditions are met:
1. Issuer is **NOT** `CN=kube-apiserver-lb-signer`
2. **AND** one of the following:
   - `.spec.servingCerts.namedCertificates` does **NOT** exist
   - **OR** `.spec.servingCerts.namedCertificates` exists but referenced secret does **NOT** exist

Otherwise, it's a **Self-Managed OpenShift Cluster**.

---

### Certificate Types by Cluster Type

| Cluster Type | Available Certificate Types | User Can Configure Custom? |
|-------------|----------------------------|---------------------------|
| **Managed OpenShift** (ROSA, ARO, OSD) | Type 2: RedHat-Managed only | ❌ No |
| **Self-Managed OpenShift** | Type 1: OpenShift-Managed (default)<br>Type 3a: Custom CA - Well-Known<br>Type 3b: Custom CA - Self-Signed | ✅ Yes |

---

### Certificate Type Identification Conditions

| Certificate Type | Issuer | namedCertificates Config | Secret Exists | Cluster Type |
|-----------------|--------|-------------------------|---------------|--------------|
| **Type 1: OpenShift-Managed** | `CN=kube-apiserver-lb-signer` | Empty/Does not exist | N/A | Self-Managed |
| **Type 2: RedHat-Managed** | NOT `kube-apiserver-lb-signer` | Does not exist OR exists | N/A OR No | Managed |
| **Type 3a: Custom - Well-Known** | Well-known CA (Let's Encrypt, etc.) | Exists | Yes | Self-Managed |
| **Type 3b: Custom - Self-Signed** | Custom CA | Exists | Yes | Self-Managed |

---

### Certificate Type Details

| Certificate Type | CA Bundle Location | Verification Method |
|-----------------|-------------------|---------------------|
| **Type 1: OpenShift-Managed**<br>(Default for Self-Managed) | `kube-apiserver-server-ca` ConfigMap in `openshift-kube-apiserver` namespace | Use CA bundle file |
| **Type 2: RedHat-Managed**<br>(Managed Clusters Only) | Service-specific ConfigMap (ROSA, ARO, etc.) | Use CA bundle file |
| **Type 3a: Custom CA - Well-Known**<br>(Self-Managed Only) | System trust store | Use system trust store |
| **Type 3b: Custom CA - Self-Signed**<br>(Self-Managed Only) | ConfigMap referenced in `apiserver cluster` resource in `openshift-config` namespace | Use CA bundle file |
