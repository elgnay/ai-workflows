# Workflow A: ACM Pre-Installation Analysis

**Prerequisites:**
- Completed [Common Certificate Analysis Steps 1-8](common-steps.md)
- Certificate type determined (from Step 4)
- CA bundle retrieved (from Step 5)

This workflow analyzes whether it's safe to install Red Hat Advanced Cluster Management (ACM) on this cluster based on the certificate configuration.

---

## Step A1: Verify ACM is Not Installed

**🔴 CRITICAL**: If using automation/AI agents, prepend `export KUBECONFIG="/path/to/your/kubeconfig" &&` to all `oc` commands in this workflow. Refer to the KUBECONFIG persistence warning in [Common Certificate Analysis Step 1](common-steps.md#step-1-set-up-kubeconfig-mandatory).

First, confirm that ACM is not already installed on this cluster using a two-step check:

### Step A1.1: Check if ACM CRD Exists

```bash
oc get crd multiclusterhubs.operator.open-cluster-management.io --ignore-not-found
```

**Possible outcomes:**

**Outcome 1: No output (CRD does not exist)**
- ✅ ACM is **NOT** installed
- You can proceed with this pre-installation workflow

**Outcome 2: CRD exists**
```
NAME                                                  CREATED AT
multiclusterhubs.operator.open-cluster-management.io   2024-01-15T10:30:00Z
```
- The ACM operator may be installed
- Proceed to Step A1.2 to check if ACM is actually deployed

### Step A1.2: Check if MultiClusterHub Resource Exists

**Only run this if the CRD exists from Step A1.1:**

```bash
oc get multiclusterhubs -A
```

**Possible outcomes:**

**Outcome 1: No resources found**
- ✅ ACM operator is installed but MultiClusterHub is **NOT** deployed
- You can proceed with this pre-installation workflow

**Outcome 2: MultiClusterHub resource exists**
```
NAMESPACE                       NAME              STATUS    AGE
open-cluster-management         multiclusterhub   Running   30d
```
- ❌ ACM **IS** already installed and running
- You should use **Workflow B: ACM Post-Installation Analysis** instead
- If you still want to understand pre-installation considerations, you can continue with this workflow for reference

---

## Step A2: Pre-Installation Analysis Based on Certificate Type

Proceed to the appropriate subsection based on your certificate type from Step 4:

- **Type 1: OpenShift-Managed** → Go to Step A2-A
- **Type 2: RedHat-Managed** → Go to Step A2-B
- **Type 3a: Custom CA - Well-Known** → Go to Step A2-C
- **Type 3b: Custom CA - Self-Signed** → Go to Step A2-C

---

## Step A2-A: Pre-Installation Analysis - Type 1 (OpenShift-Managed Certificate)

**Certificate Type**: OpenShift-Managed (Self-Signed)
**Issuer**: `CN=kube-apiserver-lb-signer`

### Decision Point: Choose Your Path

You have two options for proceeding with ACM installation:

### Path 1: Install ACM with OpenShift-Managed Certificates ✅

**Risk Level**: 🟢 **LOW** (as long as you don't change cert type after ACM installation)

**This is safe IF:**
- You are comfortable continuing with OpenShift-managed certificates
- You do NOT plan to change to custom certificates in the future

**Important Considerations:**
- OpenShift-managed certificates are self-signed and rotate automatically (typically every 30 days)
- ACM automatically handles CA bundle distribution to managed clusters during import
- Certificate rotation (same type) is safe and does not affect managed clusters

**If you choose this path:**
- ✅ You can proceed directly with ACM installation
- ✅ ACM will automatically distribute the CA bundle to managed clusters
- ⚠️ **DO NOT** change to custom certificates after ACM installation (this will cause managed clusters to enter unknown state)

### Path 2: Configure Custom Certificates BEFORE ACM Installation ✅

**Choose this path IF:**
- You plan to use custom certificates (well-known CA or self-signed CA)
- You want longer certificate validity periods and controlled rotation

**Why Configure Custom Certificates Before ACM Installation?**

**The Risk**: Changing certificate types **from OpenShift-Managed to Custom AFTER ACM installation** will cause managed clusters to enter an **unknown state** and require manual intervention.

**Benefits of Custom Certificates:**
1. **Stability**: Custom certificates have longer validity periods and controlled rotation
2. **Predictability**: You control when certificates are rotated
3. **Managed Cluster Trust**: If you include the root CA in the certificate chain, intermediate CA rotation won't affect managed clusters
4. **Simplified Operations** (for well-known CAs): Can use `UseSystemTruststore` strategy

**Custom Certificate Options:**
- **Option 1**: Use a Well-Known CA (Type 3a)
- **Option 2**: Use a Self-Signed/Private CA (Type 3b)

**Next Steps:**
1. Configure custom certificates for the kube-apiserver
2. **Important**: For Type 3b, ensure the certificate secret includes the complete chain with root CA
3. After configuration, re-run this workflow to verify the certificate type (should be Type 3a or 3b)
4. Proceed with ACM installation based on the new certificate type recommendations

---

### Summary for Type 1

| Action | Status |
|--------|--------|
| **Path 1**: Install ACM with OpenShift-Managed Cert | ✅ **SAFE** (if you don't plan to change certs later) |
| **Path 2**: Configure Custom Certificate First | ✅ **RECOMMENDED** (if you plan to use custom certs) |
| Change cert type AFTER ACM installation | ❌ **NOT SAFE** (causes managed clusters to enter unknown state) |

**Choose your path:**
- **Path 1**: Proceed with ACM installation using OpenShift-Managed certificates
- **Path 2**: Configure custom certificate first, then re-run this workflow to verify Type 3a/3b configuration, then install ACM

---

## Step A2-B: Pre-Installation Analysis - Type 2 (RedHat-Managed Certificate)

**Certificate Type**: RedHat-Managed (Well-Known CA)
**Issuer**: Well-known CA (e.g., Let's Encrypt)
**Cluster Type**: Managed OpenShift (ROSA, ARO, OpenShift Dedicated)

### ✅ Safe to Install ACM

**Risk Level**: 🟢 **LOW**

### Summary

RedHat-managed certificates use well-known CAs and are automatically renewed by the managed service provider. This configuration is safe for ACM installation.

### Managed Cluster Import Considerations

- **No CA bundle required**: Managed clusters will trust the hub automatically (well-known CA)
- **Automatic renewal**: Certificate renewal is handled by Red Hat
- **Standard import process**: Use standard ACM import procedures

### Recommended Configuration: Use System Truststore

Since your hub cluster uses a certificate signed by a well-known CA, configure ACM to use the system truststore for validating the hub cluster's API server certificate. This simplifies managed cluster imports and reduces operational overhead.

#### Configure UseSystemTruststore Strategy

After installing ACM, configure the KubeAPIServer verify strategy:

```bash
# Create or patch the global
cat <<EOF | oc apply -f -
apiVersion: config.open-cluster-management.io/v1alpha1
kind: KlusterletConfig
metadata:
  name: global
spec:
  hubKubeAPIServerConfig:
    serverVerificationStrategy: UseSystemTruststore
EOF
```

#### Benefits of UseSystemTruststore

1. **No CA Bundle Distribution**: Managed clusters automatically trust the hub using their system CA store
2. **Simplified Import Process**: No need to extract and provide custom CA bundles during import
3. **Automatic Trust**: Works seamlessly with well-known CAs (Let's Encrypt, DigiCert, etc.)
4. **Reduced Operational Overhead**: Eliminates CA bundle management

#### Verification

After configuring, verify the setting:

```bash
oc get klusterletconfig global -o jsonpath='{.spec.hubKubeAPIServerConfig.serverVerificationStrategy}'
```

**Expected output**: `UseSystemTruststore`

### Next Steps

1. ✅ Proceed with ACM installation following Red Hat documentation
2. ✅ Configure `UseSystemTruststore` strategy after ACM installation
3. ✅ Use standard managed cluster import process (no custom CA bundle needed)

**Reference**: [ACM Documentation - Configure Hub Cluster KubeAPIServer Certificate Validation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.14/html/clusters/cluster_mce_overview#config-hub-kube-api-server)

---

## Step A2-C: Pre-Installation Analysis - Type 3 (Custom CA Certificate)

**Applies to:**
- **Type 3a**: Custom Certificate signed by Well-Known CA
- **Type 3b**: Custom Certificate signed by Self-Signed CA

**Certificate Type**: Custom CA
**Issuer**: Well-known CA or Custom/Private CA

### Check if Root CA is Included

**Critical Requirement**: The custom certificate secret must include the **complete certificate chain including the root CA**.

#### Why Root CA is Required

When you rotate certificates in the future:
- If the new certificate is signed by a **different intermediate CA** but the **same root CA**
- Managed clusters can still validate the chain if they trust the root CA
- Without the root CA, managed clusters will enter an **unknown state** after certificate rotation

#### Verify Root CA Inclusion

Check if the root CA is included in your custom certificate secret:

```bash
# Get the secret name from Step 4.3
SECRET_NAME=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}'`

echo "Checking certificate chain in secret: ${SECRET_NAME}"
echo ""

# Extract the certificate chain
oc get secret ${SECRET_NAME} -n openshift-config -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/custom-cert-chain.pem

# Count certificates in the chain
CERT_COUNT=`grep -c "BEGIN CERTIFICATE" /tmp/custom-cert-chain.pem`
echo "Number of certificates in chain: ${CERT_COUNT}"
echo ""

# Check each certificate
echo "=== Certificate Chain Analysis ==="
echo ""

for i in `seq 1 ${CERT_COUNT}`; do
  echo "Certificate ${i}:"
  awk "/BEGIN CERTIFICATE/ {n++} n==${i}" /tmp/custom-cert-chain.pem | openssl x509 -noout -subject -issuer

  # Check if this is a self-signed certificate (root CA)
  SUBJECT=`awk "/BEGIN CERTIFICATE/ {n++} n==${i}" /tmp/custom-cert-chain.pem | openssl x509 -noout -subject | sed 's/subject=//'`
  ISSUER=`awk "/BEGIN CERTIFICATE/ {n++} n==${i}" /tmp/custom-cert-chain.pem | openssl x509 -noout -issuer | sed 's/issuer=//'`

  if [ "${SUBJECT}" = "${ISSUER}" ]; then
    echo "  → This is a ROOT CA (self-signed) ✅"
  fi
  echo ""
done

# Check if the last certificate is the root CA
echo "=== Root CA Verification ==="
LAST_CERT_SUBJECT=`awk "/BEGIN CERTIFICATE/ {n++} n==${CERT_COUNT}" /tmp/custom-cert-chain.pem | openssl x509 -noout -subject | sed 's/subject=//'`
LAST_CERT_ISSUER=`awk "/BEGIN CERTIFICATE/ {n++} n==${CERT_COUNT}" /tmp/custom-cert-chain.pem | openssl x509 -noout -issuer | sed 's/issuer=//'`

if [ "${LAST_CERT_SUBJECT}" = "${LAST_CERT_ISSUER}" ]; then
  echo "✅ Root CA is included in the certificate chain"
  echo ""
  echo "Certificate chain structure:"
  echo "  1. Leaf certificate (API server)"
  if [ ${CERT_COUNT} -gt 2 ]; then
    echo "  2. Intermediate CA(s)"
    echo "  ${CERT_COUNT}. Root CA (self-signed)"
  else
    echo "  2. Root CA (self-signed)"
  fi
else
  echo "⚠️  WARNING: Root CA is NOT included in the certificate chain"
  echo ""
  echo "Current chain only contains:"
  echo "  1. Leaf certificate (API server)"
  if [ ${CERT_COUNT} -gt 1 ]; then
    echo "  2. Intermediate CA"
  fi
  echo ""
  echo "Missing: Root CA"
fi
```

#### Outcome 1: Root CA is Included ✅

**Expected output:**
```
✅ Root CA is included in the certificate chain

Certificate chain structure:
  1. Leaf certificate (API server)
  2. Intermediate CA(s)
  3. Root CA (self-signed)
```

**Result**: ✅ **Safe to install ACM**

---

### Determine Sub-Type: 3a or 3b

Now determine if your custom certificate is signed by a **well-known CA** (Type 3a) or a **self-signed/private CA** (Type 3b):

```bash
# Check the issuer from Step 3
WORKDIR=`cat .current_workdir`
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -issuer
```

**If the issuer contains well-known CA names** (Let's Encrypt, DigiCert, GlobalSign, Sectigo, GeoTrust, Entrust, etc.):
- **Sub-Type**: Type 3a (Custom CA - Well-Known)
- Go to **Step A2-C-1** below

**If the issuer is a custom/private CA** (e.g., "CN=My Company Root CA", "CN=Internal PKI CA"):
- **Sub-Type**: Type 3b (Custom CA - Self-Signed)
- Go to **Step A2-C-2** below

---

### Step A2-C-1: Type 3a - Custom Certificate Signed by Well-Known CA

**Certificate Issuer**: Well-known CA (Let's Encrypt, DigiCert, etc.)
**Root CA Status**: ✅ Included in certificate chain

#### ✅ Safe to Install ACM

**Risk Level**: 🟢 **LOW**

#### ACM Configuration: Two Options

Since your certificate is signed by a well-known CA **AND** the root CA is included in the chain, you have two options:

##### Option A: Standard ACM Configuration (Default)

**How it works:**
- ACM automatically distributes the complete CA bundle (leaf + intermediate + root CA) to managed clusters
- Managed clusters validate the hub using the distributed CA bundle
- Works perfectly because the root CA is included

**Next Steps:**
1. ✅ Proceed with ACM installation
2. ✅ Use standard managed cluster import process
3. ✅ No additional configuration needed
4. ✅ Monitor certificate expiration and ensure renewal automation is configured

**Benefits:**
- ✅ No additional configuration required
- ✅ Protected against intermediate CA rotation (root CA included)
- ✅ Standard ACM workflow

---

##### Option B: Use System Truststore (Recommended for Simplicity)

**How it works:**
- Managed clusters use their system trust store to validate the hub
- ACM doesn't distribute CA bundles
- Simpler operations

**Configuration:**

After installing ACM, configure the KubeAPIServer verify strategy:

```bash
# Create or patch the global KlusterletConfig
cat <<EOF | oc apply -f -
apiVersion: config.open-cluster-management.io/v1alpha1
kind: KlusterletConfig
metadata:
  name: global
spec:
  hubKubeAPIServerConfig:
    serverVerificationStrategy: UseSystemTruststore
EOF
```

Verify the configuration:

```bash
oc get klusterletconfig global -o jsonpath='{.spec.hubKubeAPIServerConfig.serverVerificationStrategy}'
```

**Expected output**: `UseSystemTruststore`

**Benefits:**
1. **No CA Bundle Distribution**: Managed clusters automatically trust the hub using their system CA store
2. **Simplified Import Process**: No need to extract and provide custom CA bundles during import
3. **Automatic Trust**: Works seamlessly with well-known CAs
4. **Reduced Operational Overhead**: Eliminates CA bundle management

**Next Steps:**
1. ✅ Proceed with ACM installation
2. ✅ Configure `UseSystemTruststore` strategy after ACM installation
3. ✅ Use standard managed cluster import process (no custom CA bundle needed)
4. ✅ Monitor certificate expiration and ensure renewal automation is configured

---

#### Summary for Type 3a with Root CA Included

**Both options work equally well. Choose based on your preference:**

| Aspect | Option A (Standard) | Option B (UseSystemTruststore) |
|--------|-------------------|-------------------------------|
| **Rotation Protected?** | ✅ Yes (root CA included) | ✅ Yes (system trust store) |
| **Configuration Needed?** | ❌ No | ✅ Yes (simple) |
| **Operational Complexity** | Standard | Simpler |
| **Recommendation** | Good default choice | Recommended for simplicity |

**Reference**: [ACM Documentation - Configure Hub Cluster KubeAPIServer Certificate Validation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.14/html/clusters/cluster_mce_overview#config-hub-kube-api-server)

---

### Step A2-C-2: Type 3b - Custom Certificate Signed by Self-Signed/Private CA

**Certificate Issuer**: Custom/Private CA
**Root CA Status**: ✅ Included in certificate chain

#### ✅ Safe to Install ACM (with CA Bundle Management)

**Risk Level**: 🟢 **LOW**

**Important**: ACM automatically handles CA bundle distribution to managed clusters during import. You do not need to manually provide the CA bundle.

#### Certificate Rotation Protection

✅ **Protected**: Since the root CA is included in the certificate chain:
- Future certificate rotations with different intermediate CAs will work seamlessly
- Managed clusters trust the root CA, so they can validate new certificates signed by different intermediates
- No manual CA bundle updates needed during routine certificate rotation

#### Operational Considerations

1. **PKI Infrastructure**: Ensure your PKI infrastructure is reliable and well-maintained
2. **CA Certificate Expiration**: Monitor root CA expiration (typically years in the future)
3. **Automatic CA Bundle**: ACM automatically distributes the CA bundle from the custom certificate secret to managed clusters

#### Next Steps

1. ✅ Proceed with ACM installation
2. ✅ Use standard managed cluster import process (ACM handles CA bundle automatically)
3. ✅ Ensure root CA is included in the custom certificate secret for rotation protection

**Reference**: [ACM Documentation - Configure Hub Cluster KubeAPIServer Certificate Validation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.14/html/clusters/cluster_mce_overview#config-hub-kube-api-server)

---

#### Outcome 2: Root CA is NOT Included ⚠️

**Expected output:**
```
⚠️  WARNING: Root CA is NOT included in the certificate chain

Current chain only contains:
  1. Leaf certificate (API server)
  2. Intermediate CA

Missing: Root CA
```

**Result**: ⚠️ **Requires Special Configuration**

**The Problem:**
- The certificate chain is missing the root CA
- ACM will distribute this incomplete chain to managed clusters
- When you rotate certificates in the future (especially if signed by a different intermediate CA), managed clusters will fail validation and enter **unknown state**

**Next Steps:** Determine if you have Type 3a or Type 3b, then follow the appropriate section below.

---

#### For Type 3a (Well-Known CA) with Missing Root CA

**Available Options:** You have two options to resolve this issue.

### Understanding the Situation (Type 3a Only)

**"Will ACM work now?"**
- **Yes** - ACM will work currently with the incomplete chain
- HTTP/HTTPS clients (including ACM components) can validate using system trust stores
- Managed cluster imports will succeed

**"Will it keep working?"**
- **Depends on your ACM configuration:**
  - **Without UseSystemTruststore**: ❌ Rotation risk exists
    - ACM distributes incomplete CA bundle to managed clusters
    - When intermediate CA changes → Managed clusters fail validation and enter "unknown" state
  - **With UseSystemTruststore**: ✅ No rotation risk
    - ACM doesn't distribute CA bundle
    - Managed clusters use system trust store (which has root CA)
    - Works seamlessly even when intermediate CA changes

**"Is this the right way?"**
- **Best practice**: Include the complete chain with root CA (Option 1)
- **Alternative for well-known CAs**: Use UseSystemTruststore strategy (Option 2)

---

### Choose Your Approach (Type 3a)

#### Option 1: Add Root CA to Certificate Secret (Best Practice)

**What needs to be done:**
1. Obtain the root CA certificate from your CA provider
   - For Let's Encrypt: Download ISRG Root X1 from https://letsencrypt.org/certificates/
   - For other CAs: Contact your CA provider or PKI administrator
2. Update the certificate secret to include the complete chain: leaf certificate + intermediate CA(s) + root CA
3. Wait for the API server to reload with the new certificate
4. Re-run this workflow to verify the root CA is included
5. Proceed with ACM installation

**Benefits:**
- ✅ Follows PKI best practices
- ✅ Works with or without UseSystemTruststore
- ✅ Protected against intermediate CA rotation
- ✅ Future-proof configuration

**ACM Configuration:**
- UseSystemTruststore is **optional** (recommended for simplicity)
- Works well even without UseSystemTruststore

---

#### Option 2: Use UseSystemTruststore Strategy (Well-Known CAs Only)

**Available for**: Type 3a only (well-known CAs like Let's Encrypt, DigiCert, etc.)

**Not available for**: Type 3b (self-signed/private CAs not in system trust store)

**What needs to be done:**
1. Proceed with ACM installation with the current certificate configuration
2. **REQUIRED**: Configure UseSystemTruststore after ACM installation (see configuration below)

**Benefits:**
- ✅ No certificate secret updates needed
- ✅ Solves rotation issue completely
- ✅ Simplified operations

**Limitation:**
- ⚠️ **UseSystemTruststore configuration is REQUIRED** - not optional
- ⚠️ Without it, managed clusters will fail after intermediate CA rotation

**ACM Configuration (REQUIRED for Option 2):**

After installing ACM, you **MUST** configure UseSystemTruststore:

```bash
# REQUIRED: Configure UseSystemTruststore strategy
cat <<EOF | oc apply -f -
apiVersion: config.open-cluster-management.io/v1alpha1
kind: KlusterletConfig
metadata:
  name: global
spec:
  hubKubeAPIServerConfig:
    serverVerificationStrategy: UseSystemTruststore
EOF
```

Verify the configuration:
```bash
oc get klusterletconfig global -o jsonpath='{.spec.hubKubeAPIServerConfig.serverVerificationStrategy}'
```

**Expected output**: `UseSystemTruststore`

**Why this works:**
- Managed clusters validate the hub using their system trust store (which includes the root CA)
- ACM doesn't distribute the incomplete CA bundle
- Intermediate CA rotation is handled transparently by the system trust store

---

#### For Type 3b (Self-Signed/Private CA) with Missing Root CA

**Required Action:** The root CA certificate **MUST** be added to the certificate secret before installing ACM.

**What needs to be done:**
1. Obtain the root CA certificate from your PKI administrator
2. Update the certificate secret to include the complete chain: leaf certificate + intermediate CA(s) + root CA
3. Wait for the API server to reload with the new certificate
4. Re-run this workflow to verify the root CA is included
5. Proceed with ACM installation

**Benefits of adding the root CA:**
- ✅ ACM installation will be safe
- ✅ Protected against intermediate CA rotation
- ✅ Managed clusters will trust the root CA
- ✅ Future certificate rotations will work seamlessly

---

### Summary: Root CA Not Included

**For Type 3a (Well-Known CA):**

| Approach | Best For | UseSystemTruststore | Rotation Protected |
|----------|----------|---------------------|-------------------|
| **Option 1**: Add Root CA | Best practice, future-proof | Optional | ✅ Yes |
| **Option 2**: Use UseSystemTruststore | Quick deployment, well-known CAs | **REQUIRED** | ✅ Yes |

**For Type 3b (Self-Signed/Private CA):**

| Approach | Status |
|----------|--------|
| **Option 1**: Add Root CA | ✅ **REQUIRED** - Only viable option |
| **Option 2**: Use UseSystemTruststore | ❌ Not available (root CA not in system trust store) |

**Important**: For Type 3b with missing root CA, you **MUST** add the root CA to the certificate secret before installing ACM. UseSystemTruststore is not an option because the private/self-signed root CA is not in the system trust store.

---

### Summary for Type 3

#### Root CA Included in Certificate Chain

| Sub-Type | UseSystemTruststore | Status |
|----------|---------------------|--------|
| **Type 3a** (Well-Known CA) | Optional (recommended for simplicity) | ✅ Safe to install - both options work |
| **Type 3b** (Self-Signed/Private CA) | ❌ Not available | ✅ Safe to install - ACM distributes CA bundle |

**For Type 3a with Root CA:**
- **Option A**: Standard ACM (no extra config) - Works well
- **Option B**: UseSystemTruststore - Also works well, simpler operations

**For Type 3b with Root CA:**
- **Only option**: Standard ACM - ACM distributes the complete CA bundle
- UseSystemTruststore doesn't work (private root CA not in system trust store)

---

#### Root CA NOT Included in Certificate Chain

| Sub-Type | Required Action | UseSystemTruststore |
|----------|----------------|---------------------|
| **Type 3a** (Well-Known CA) | Choose Option 1 or 2 below | **REQUIRED** for Option 2 |
| **Type 3b** (Self-Signed/Private CA) | **MUST** add root CA (Option 1 only) | ❌ Not available |

**For Type 3a without Root CA:**
- **Option 1**: Add root CA to cert secret (best practice) - UseSystemTruststore optional
- **Option 2**: Keep incomplete chain + UseSystemTruststore (REQUIRED) - Solves rotation issue

**For Type 3b without Root CA:**
- **Only option**: Add root CA to cert secret before installing ACM
- UseSystemTruststore doesn't work (private root CA not in system trust store)

---

**Key Insight**:

The **UseSystemTruststore strategy** serves different purposes depending on the situation:

| Scenario | Purpose of UseSystemTruststore |
|----------|-------------------------------|
| Root CA included | Optional - for operational simplicity |
| Root CA missing (Type 3a only) | **Required** - to solve rotation issue |

---

## Workflow A Summary: ACM Pre-Installation Recommendations

### Certificate Type and ACM Configuration Summary

| Certificate Type | Safe to Install ACM? | Risk Level |
|-----------------|---------------------|------------|
| **Type 1: OpenShift-Managed** | ✅ Yes (but configure custom cert first if you plan to use one) | 🟢 LOW |
| **Type 2: RedHat-Managed** | ✅ Yes | 🟢 LOW |
| **Type 3a: Custom - Well-Known CA** | ✅ Yes (if root CA included) | 🟢 LOW |
| **Type 3b: Custom - Self-Signed CA** | ✅ Yes (if root CA included) | 🟢 LOW |

**Important Notes:**
- **Automatic CA Bundle Handling**: ACM automatically handles CA bundle distribution to managed clusters during import. Users do not need to manually provide CA bundles.
- **Type 1 Warning**: There is NO risk in using OpenShift-Managed certificates with ACM as long as you don't change certificate types later. The ONLY risk is changing certificate types (from OpenShift-Managed to Custom) AFTER ACM installation, which causes managed clusters to enter an unknown state. If you plan to use custom certificates, configure them BEFORE installing ACM.
