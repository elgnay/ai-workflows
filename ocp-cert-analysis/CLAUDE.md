# Workflow: Analyze and Verify OpenShift Kube-APIServer Certificate

This workflow helps you analyze the kube-apiserver serving certificate, determine its type, retrieve the appropriate CA bundle, and verify the certificate chain.

## Step 1: Get the External API Server Endpoint

First, retrieve the external API server URL:

```bash
oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}'
```

**Expected output:** `https://api.<cluster-name>.<domain>.com:6443`

Extract the hostname (without `https://` and port) for later use.

---

## Step 2: Create Working Directory and Retrieve Serving Certificate

Create a timestamped directory for this analysis run:

```bash
# Create working directory
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p "run-${TIMESTAMP}"
cd "run-${TIMESTAMP}"
```

Retrieve the certificate chain from the API server and separate the leaf certificate from intermediate CAs:

```bash
# Get the full chain from the server
echo | openssl s_client -connect <api-hostname>:6443 -showcerts 2>/dev/null | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > fullchain.pem

# Extract the leaf certificate (first certificate)
awk '/BEGIN CERTIFICATE/ { n++ } n == 1' fullchain.pem > kube-apiserver-serving-cert.pem

# Extract intermediate CA certificates (remaining certificates)
awk '/BEGIN CERTIFICATE/ { n++ } n >= 2' fullchain.pem > intermediate-ca.pem
```

Replace `<api-hostname>` with the hostname from Step 1.

**Note:** This separates the server's leaf certificate from the intermediate CA chain, which is needed for proper verification. All files will be saved in the `run-<timestamp>` directory.

### Display Certificate Details

View the certificate subject and issuer:

```bash
openssl x509 -in kube-apiserver-serving-cert.pem -noout -subject -issuer
```

View validity period:

```bash
openssl x509 -in kube-apiserver-serving-cert.pem -noout -dates
```

View Subject Alternative Names:

```bash
openssl x509 -in kube-apiserver-serving-cert.pem -noout -ext subjectAltName
```

---

## Step 3: Determine Certificate Type

Look at the **issuer** from Step 2 to determine the certificate type:

### If issuer contains `CN=kube-apiserver-lb-signer`
**Type:** OpenShift-Managed Certificate
**Next:** Go to Step 4A (OpenShift-Managed)

### If issuer contains well-known CA names
Examples: `Let's Encrypt`, `DigiCert`, `GlobalSign`, `Sectigo`, `GeoTrust`, `Entrust`
**Type:** Custom Certificate Signed by Well-Known CA
**Next:** Go to Step 4B (Well-Known CA)

### Otherwise
**Type:** Custom Certificate with Custom CA (self-signed or private CA)
**Next:** Go to Step 4C (Custom CA)

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
oc get configmap kube-apiserver-server-ca -n openshift-kube-apiserver -o jsonpath='{.data.ca-bundle\.crt}' > kube-apiserver-ca-bundle.crt
```

Count certificates in the bundle:

```bash
grep -c "BEGIN CERTIFICATE" kube-apiserver-ca-bundle.crt
```

**Expected:** 4 certificates (lb-signer, localhost-signer, service-network-signer, recovery-signer)

**Next:** Go to Step 5

---

## Step 4B: Well-Known CA Certificate

### Check Configuration

Check if custom certificates are configured:

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

If this returns data, custom serving certificates are configured (but signed by a well-known CA).

### No CA Bundle Needed

Since the certificate is signed by a well-known CA (like Let's Encrypt), it's already in your system trust store.

You can verify using the system trust store directly without retrieving a custom CA bundle.

**Next:** Go to Step 5 (use system trust store for verification)

---

## Step 4C: Custom CA Certificate

### Check Configuration

Check custom certificate configuration:

```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

Should return custom certificate configuration.

### Find Custom CA Bundle

Check for custom CA ConfigMap reference:

```bash
oc get apiserver cluster -o jsonpath='{.spec.clientCA.name}'
```

If this returns a ConfigMap name, retrieve it:

```bash
oc get configmap <configmap-name> -n openshift-config -o jsonpath='{.data.ca-bundle\.crt}' > custom-ca-bundle.crt
```

If empty, list available ConfigMaps in openshift-config:

```bash
oc get configmap -n openshift-config | grep -i ca
```

**Next:** Go to Step 5

---

## Step 5: Verify the Serving Certificate

### For OpenShift-Managed or Custom CA

Verify the certificate with the CA bundle:

```bash
openssl verify -CAfile kube-apiserver-ca-bundle.crt kube-apiserver-serving-cert.pem
```

Or for custom CA:

```bash
openssl verify -CAfile custom-ca-bundle.crt kube-apiserver-serving-cert.pem
```

**Expected output:** `kube-apiserver-serving-cert.pem: OK`

### For Well-Known CA

Verify with system trust store, providing intermediate CAs:

**On macOS:**
```bash
openssl verify -untrusted intermediate-ca.pem kube-apiserver-serving-cert.pem
```

**On Linux (RHEL/Fedora/CentOS):**
```bash
openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt -untrusted intermediate-ca.pem kube-apiserver-serving-cert.pem
```

**On Linux (Debian/Ubuntu):**
```bash
openssl verify -CApath /etc/ssl/certs -untrusted intermediate-ca.pem kube-apiserver-serving-cert.pem
```

**Expected output:** `kube-apiserver-serving-cert.pem: OK`

**Note:** The `-untrusted` parameter provides intermediate CA certificates for chain building, while the system trust store (or `-CAfile`/`-CApath`) provides trusted root CAs.

---

## Step 6: Display the Certificate Chain

### Display the Trust Chain

Show the complete trust path from server certificate to root CA:

```bash
echo "=== Certificate Chain (Trust Path) ==="
echo ""
echo "1. Leaf Certificate (Server):"
openssl x509 -in kube-apiserver-serving-cert.pem -noout -subject
echo ""
echo "2. Issuing CA:"
openssl x509 -in kube-apiserver-serving-cert.pem -noout -issuer

# Display intermediate CA if present
if [ -s intermediate-ca.pem ]; then
    echo ""
    echo "3. Intermediate CA:"
    openssl x509 -in intermediate-ca.pem -noout -subject -issuer
else
    echo ""
    echo "3. No intermediate CA (direct to root CA)"
fi
```

### Verify if the CA is Self-Signed (Root CA)

Check if the issuing CA is a self-signed root CA:

**For OpenShift-Managed certificates:**
```bash
awk '/BEGIN CERTIFICATE/ { n++ } n == 1' kube-apiserver-ca-bundle.crt | openssl x509 -noout -subject -issuer
```

**For Custom CA:**
```bash
awk '/BEGIN CERTIFICATE/ { n++ } n == 1' custom-ca-bundle.crt | openssl x509 -noout -subject -issuer
```

If **subject == issuer**, it's a self-signed root CA (typical for OpenShift-managed certs).

If **subject ≠ issuer**, there's an intermediate CA, and you should continue checking:

```bash
# Check second certificate in bundle
awk '/BEGIN CERTIFICATE/ { n++ } n == 2' kube-apiserver-ca-bundle.crt | openssl x509 -noout -subject -issuer
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

### For OpenShift-Managed or Custom CA

Test with the CA bundle:

```bash
curl --cacert kube-apiserver-ca-bundle.crt https://<api-url>/version
```

### For Well-Known CA

Test without specifying CA (uses system trust store):

```bash
curl https://<api-url>/version
```

**Expected:** JSON response with Kubernetes version information.

---

## Summary

This workflow:

1. ✅ Retrieves the external API server endpoint
2. ✅ Extracts the serving certificate details (subject, issuer, validity, SANs)
3. ✅ Determines the certificate type by analyzing the issuer
4. ✅ Retrieves the appropriate CA bundle based on certificate type
5. ✅ Verifies the serving certificate against the CA bundle
6. ✅ Displays the certificate chain and trust path
7. ✅ Tests connectivity using the appropriate CA bundle

## Quick Reference: Certificate Types

| Certificate Type | Issuer Pattern | CA Bundle Location | Verification Method |
|-----------------|----------------|-------------------|---------------------|
| **OpenShift-Managed** | `CN=kube-apiserver-lb-signer` | `kube-apiserver-server-ca` ConfigMap in `openshift-kube-apiserver` namespace | Use CA bundle file |
| **Custom CA** | Custom organization name | ConfigMap referenced in `apiserver cluster` resource in `openshift-config` namespace | Use CA bundle file |
| **Well-Known CA** | `Let's Encrypt`, `DigiCert`, etc. | System trust store | Use system trust store |
