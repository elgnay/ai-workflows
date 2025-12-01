# Quick Reference - OCP Certificate Analysis Skill

## Certificate Type Decision Tree

```
Check Issuer (Step 4.1)
├─ CN=kube-apiserver-lb-signer
│  └─ namedCertificates empty?
│     └─ YES → Type 1: OpenShift-Managed
│
└─ NOT kube-apiserver-lb-signer
   └─ namedCertificates exists AND secret exists?
      ├─ NO → Type 2: RedHat-Managed
      └─ YES → Type 3: Custom CA
         ├─ Well-known issuer → Type 3a: Custom - Well-Known CA
         └─ Custom issuer → Type 3b: Custom - Self-Signed CA
```

## Certificate Types Summary

| Type | Issuer | namedCertificates | Secret Exists | Cluster Type |
|------|--------|-------------------|---------------|--------------|
| **Type 1** | `CN=kube-apiserver-lb-signer` | Empty | N/A | Self-Managed |
| **Type 2** | NOT kube-apiserver-lb-signer | Not configured | No | Managed (ROSA/ARO/OSD) |
| **Type 3a** | Well-known CA | Configured | Yes | Self-Managed |
| **Type 3b** | Custom CA | Configured | Yes | Self-Managed |

## CA Bundle Locations by Type

| Type | CA Bundle Location | Command |
|------|-------------------|---------|
| **Type 1** | ConfigMap: `kube-apiserver-server-ca`<br>Namespace: `openshift-kube-apiserver` | `oc get configmap kube-apiserver-server-ca -n openshift-kube-apiserver -o jsonpath='{.data.ca-bundle\.crt}'` |
| **Type 2** | Service-specific ConfigMap | Check with service provider docs |
| **Type 3** | Secret in `openshift-config`<br>Key: `tls.crt` | `oc extract secret/${SECRET_NAME} -n openshift-config --keys=tls.crt` |

## Verification Methods by Type

| Type | Verification Command |
|------|---------------------|
| **Type 1** | `openssl verify -CAfile ca-bundle.crt serving-cert.pem` |
| **Type 2** | `openssl verify -untrusted intermediate-ca.pem serving-cert.pem` (macOS)<br>`openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt -untrusted intermediate-ca.pem serving-cert.pem` (RHEL) |
| **Type 3a** | Same as Type 2 (system trust store) |
| **Type 3b** | Same as Type 1 (CA bundle file) |

## Critical Command Patterns

### KUBECONFIG Pattern (Automation)
```bash
export KUBECONFIG="/path/to/your/kubeconfig" && oc <command>
```

### Variable Loading Pattern
```bash
WORKDIR=`cat .current_workdir`  # ✅ CORRECT - uses backticks
```

### DO NOT Use
```bash
WORKDIR=$(cat .current_workdir)  # ❌ WRONG - uses $()
```

## Step Checklist

- [ ] **Step 1**: KUBECONFIG set and verified
- [ ] **Step 2**: API endpoint retrieved
- [ ] **Step 3**: Working directory created, certificates extracted
- [ ] **Step 4**: Certificate type determined
- [ ] **Step 5**: CA bundle retrieved
- [ ] **Step 6**: Certificate verified
- [ ] **Step 7**: Certificate chain displayed
- [ ] **Step 8**: Connectivity tested

## Common File Locations

| File | Path | Purpose |
|------|------|---------|
| Working directory | `run-<timestamp>/` | All analysis files |
| Directory tracker | `.current_workdir` | Stores working directory path |
| Serving cert | `run-<timestamp>/serving-cert.pem` | API server certificate |
| CA bundle | `run-<timestamp>/ca-bundle.crt` | CA certificates |
| Intermediate CA | `run-<timestamp>/intermediate-ca.pem` | Intermediate CAs from chain |
| Full chain | `run-<timestamp>/fullchain.pem` | Complete certificate chain |

## Key Commands by Step

### Step 1: Verify Connection
```bash
oc whoami --show-server
```

### Step 3: Get API Details
```bash
API_ENDPOINT=`oc whoami --show-server`
API_HOSTNAME=`echo "$API_ENDPOINT" | sed 's|https://||' | sed 's|:.*||'`
API_PORT=`echo "$API_ENDPOINT" | sed 's|.*:||'`
```

### Step 3: Retrieve Certificates
```bash
echo | openssl s_client -connect ${API_HOSTNAME}:${API_PORT} -showcerts 2>/dev/null
```

### Step 4: Check Configuration
```bash
oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'
```

### Step 6: Verify Certificate
```bash
openssl verify -CAfile "${WORKDIR}/ca-bundle.crt" "${WORKDIR}/serving-cert.pem"
```

### Step 8: Test Connectivity
```bash
curl --cacert "${WORKDIR}/ca-bundle.crt" "${API_ENDPOINT}/healthz"
```

## Expected Outputs

### Successful Certificate Verification
```
serving-cert.pem: OK
```

### Successful Connectivity Test
```
ok
```

### Certificate Chain Display
```
=== Certificate Chain Analysis ===

1. Serving Certificate:
subject=CN = *.apps.cluster.example.com
issuer=CN = kube-apiserver-lb-signer

2. CA Bundle Analysis:
Number of certificates in CA bundle: 1

--- Certificate 1 ---
subject=CN = kube-apiserver-lb-signer
issuer=CN = kube-apiserver-lb-signer
```

## Troubleshooting Quick Guide

| Issue | Solution |
|-------|----------|
| Command not found | Install `oc` and `openssl` |
| KUBECONFIG not persisting | Prepend `export KUBECONFIG=...` to each `oc` command |
| Syntax error | Use backticks (\`), not $() |
| Certificate verification fails | Check correct CA bundle for certificate type |
| API unreachable | Verify network access and kubeconfig |

## Well-Known Certificate Authorities

Common well-known CAs (Type 3a):
- Let's Encrypt
- DigiCert
- GlobalSign
- Sectigo
- GeoTrust
- Entrust
- Comodo
- Thawte

If issuer contains any of these, it's Type 3a.
