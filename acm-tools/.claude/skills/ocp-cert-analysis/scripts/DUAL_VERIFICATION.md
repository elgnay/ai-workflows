# Dual Certificate Verification for Custom Well-Known CA

## Overview

For **Custom Certificate (Well-Known CA)** (Type 3a), the verification step performs **two independent verifications** to ensure the certificate is valid both according to the system trust store and the cluster's CA bundle configuration.

## Why Dual Verification?

For certificates issued by well-known CAs (Let's Encrypt, DigiCert, etc.) that are custom-configured in the cluster, we need to verify:

1. **System Trust Store Verification** - Ensures the certificate chain is valid according to the operating system's trusted CAs
2. **Cluster CA Bundle Verification** - Ensures the CA bundle extracted from the cluster's secret correctly validates the certificate

### Why This Matters

- ✅ **Detects incomplete CA bundles** - If the cluster's CA bundle is missing intermediate or root CAs
- ✅ **Detects trust store issues** - If the system is missing the well-known CA root
- ✅ **Validates cluster config** - Ensures what's configured in the cluster actually works
- ✅ **Identifies mismatches** - Catches discrepancies between system trust and cluster config

## Verification Flow

### Type 3a: Custom Certificate (Well-Known CA)

```
Step 6: Verify Serving Certificate
    ↓
1. Verify with System Trust Store
    ├─ macOS: openssl verify -untrusted intermediate-ca.pem serving-cert.pem
    ├─ RHEL: openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt -untrusted intermediate-ca.pem serving-cert.pem
    └─ Debian: openssl verify -CApath /etc/ssl/certs -untrusted intermediate-ca.pem serving-cert.pem
    ↓
    Result: PASSED / FAILED
    ↓
2. Verify with Extracted CA Bundle
    └─ openssl verify -CAfile ca-bundle.crt serving-cert.pem
    ↓
    Result: PASSED / FAILED
    ↓
Overall Result:
    ├─ Both PASSED → ✓ All certificate verifications successful (continue)
    ├─ System FAILED, Bundle PASSED → ⚠ Warning: Certificate valid per cluster (continue)
    ├─ System PASSED, Bundle FAILED → ⚠ Warning: Incomplete cluster config (continue)
    └─ Both FAILED → ✗ Error: Certificate chain invalid (abort)
```

## Example Output

### Scenario 1: Both Verifications Pass (Success)

```
=== Step 6: Verify Serving Certificate ===

Certificate Type: Custom Certificate (Well-Known CA)

Performing dual verification for custom certificate with well-known CA...

1. Verifying with system trust store...
   run-20251120-172238/serving-cert.pem: OK
✓    System trust store verification: PASSED

2. Verifying with extracted CA bundle from cluster...
   run-20251120-172238/serving-cert.pem: OK
✓    CA bundle verification: PASSED

✓ All certificate verifications successful

✓ Certificate verification complete. Ready to proceed to Step 7.
```

### Scenario 2: System Passes, Bundle Fails (Incomplete Cluster Config)

```
=== Step 6: Verify Serving Certificate ===

Certificate Type: Custom Certificate (Well-Known CA)

Performing dual verification for custom certificate with well-known CA...

1. Verifying with system trust store...
   run-20251120-172238/serving-cert.pem: OK
✓    System trust store verification: PASSED

2. Verifying with extracted CA bundle from cluster...
   C=US, O=Let's Encrypt, CN=R13
   error 2 at 1 depth lookup: unable to get issuer certificate
   error run-20251120-172238/serving-cert.pem: verification failed
✗    CA bundle verification: FAILED

ℹ Certificate verification: Mixed results

⚠ Warning: Certificate is valid according to system trust store but not cluster CA bundle.
This may indicate incomplete CA bundle in cluster configuration.

ℹ Continuing analysis (certificate is valid per system trust store)...

✓ Certificate verification complete. Ready to proceed to Step 7.
```

**What this means:** The certificate is valid (system trust store confirms it), but the CA bundle stored in the cluster's secret is missing intermediate or root CAs. The analysis continues since the certificate itself is valid.

**Action (Recommended):** Update the cluster's certificate secret to include the complete CA chain.

**Impact:** The warning will appear in the final summary with recommendations.

### Scenario 3: System Fails, Bundle Passes (Missing from System Trust)

```
=== Step 6: Verify Serving Certificate ===

Certificate Type: Custom Certificate (Well-Known CA)

Performing dual verification for custom certificate with well-known CA...

1. Verifying with system trust store...
   error 20 at 0 depth lookup: unable to get local issuer certificate
✗    System trust store verification: FAILED

2. Verifying with extracted CA bundle from cluster...
   run-20251120-172238/serving-cert.pem: OK
✓    CA bundle verification: PASSED

ℹ Certificate verification: Mixed results

⚠ Warning: Certificate is valid according to cluster CA bundle but not system trust store.
This may indicate the well-known CA root is missing from system trust store.

ℹ Continuing analysis (certificate is valid per cluster configuration)...

✓ Certificate verification complete. Ready to proceed to Step 7.
```

**What this means:** The cluster configuration is correct, but the system running the analysis doesn't trust the CA (unusual for well-known CAs like Let's Encrypt). The analysis continues since the certificate is valid per cluster configuration.

**Action (Optional):** Update system trust store or verify the CA is actually well-known.

### Scenario 4: Both Fail (Invalid Certificate)

```
=== Step 6: Verify Serving Certificate ===

Certificate Type: Custom Certificate (Well-Known CA)

Performing dual verification for custom certificate with well-known CA...

1. Verifying with system trust store...
   error 20 at 0 depth lookup: unable to get local issuer certificate
✗    System trust store verification: FAILED

2. Verifying with extracted CA bundle from cluster...
   error 20 at 0 depth lookup: unable to get local issuer certificate
✗    CA bundle verification: FAILED

✗ Certificate verification failed

Both verification methods failed. Certificate chain may be incomplete or invalid.
```

**What this means:** The certificate cannot be verified by any method. The certificate chain is broken or invalid.

**Action:** Review the certificate configuration and ensure the complete chain is available.

## Comparison with Other Certificate Types

| Certificate Type | Verification Method(s) |
|------------------|------------------------|
| **OpenShift-Managed** | Single: CA bundle file only |
| **RedHat-Managed** | Single: System trust store only |
| **Custom (Well-Known CA)** | **Dual: System trust store + CA bundle** |
| **Custom (Private CA)** | Single: CA bundle file only |

## Benefits of Dual Verification

### For Type 3a Specifically

1. **Validates Cluster Configuration**
   - Ensures the CA bundle in the cluster secret is complete
   - Confirms cluster configuration matches the actual certificate

2. **Validates Certificate Authenticity**
   - Confirms the well-known CA is actually recognized
   - Verifies the certificate chain is valid

3. **Identifies Configuration Issues**
   - Detects incomplete CA bundles in cluster config
   - Catches misconfigurations early

4. **Provides Diagnostic Information**
   - Clear messaging about which verification failed
   - Actionable guidance for remediation

## Implementation Details

### Code Structure

```bash
case "$CERT_TYPE" in
    "Type3a-Custom-WellKnown")
        # Verification 1: System trust store
        VERIFY_SYSTEM=`openssl verify ...`

        if echo "$VERIFY_SYSTEM" | grep -q "OK"; then
            # System verification passed
        else
            SYSTEM_VERIFY_FAILED="true"
        fi

        # Verification 2: CA bundle
        VERIFY_BUNDLE=`openssl verify -CAfile "${WORKDIR}/ca-bundle.crt" ...`

        if echo "$VERIFY_BUNDLE" | grep -q "OK"; then
            # Bundle verification passed
        else
            BUNDLE_VERIFY_FAILED="true"
        fi

        # Overall result
        if [ "$SYSTEM_VERIFY_FAILED" = "true" ] || [ "$BUNDLE_VERIFY_FAILED" = "true" ]; then
            # Provide context-specific error message
            exit 1
        else
            # Success
        fi
        ;;
esac
```

### Error Context

The script provides specific guidance based on which verification failed:

| Scenario | System | Bundle | Outcome | Action |
|----------|--------|--------|---------|--------|
| Success | PASS | PASS | Continue | None |
| Incomplete cluster config | PASS | FAIL | **Continue with warning** | Update cluster secret (recommended) |
| Missing from system trust | FAIL | PASS | **Continue with warning** | Update system trust store (optional) |
| Invalid certificate | FAIL | FAIL | **Abort** | Fix certificate chain |

## When to Use Each Verification

### System Trust Store (Always for Type 3a)
- Validates the certificate against well-known CAs
- Confirms the CA is actually trusted
- Uses OS-native trust anchors

### CA Bundle (Always for Type 3a)
- Validates the cluster configuration
- Confirms the secret contains correct CA chain
- Ensures cluster can validate its own certificates

## Troubleshooting

### If System Trust Store Verification Fails

1. **Check if CA is well-known**
   ```bash
   openssl x509 -in serving-cert.pem -noout -issuer
   ```

2. **Verify system trust store has CA**
   - macOS: Check Keychain Access
   - Linux: Check `/etc/pki/tls/certs/` or `/etc/ssl/certs/`

3. **Update system trust store if needed**

### If CA Bundle Verification Fails

1. **Check CA bundle completeness**
   ```bash
   grep -c "BEGIN CERTIFICATE" ca-bundle.crt
   ```

2. **Compare with certificate chain**
   ```bash
   openssl x509 -in serving-cert.pem -noout -issuer
   openssl x509 -in ca-bundle.crt -noout -subject
   ```

3. **Update cluster secret with complete chain**
   ```bash
   oc create secret tls cert-secret \
     --cert=fullchain.pem \
     --key=private-key.pem \
     -n openshift-config \
     --dry-run=client -o yaml | oc replace -f -
   ```

## Warning Display in Summary

If a verification warning is detected, it will be displayed in the final summary:

```
╔═══════════════════════════════════════════════════════════════╗
║           OCP Certificate Analysis - Summary                  ║
╚═══════════════════════════════════════════════════════════════╝

Cluster: cluster.example.com
API Endpoint: https://api.cluster.example.com:6443

Certificate Type: Custom Certificate (Well-Known CA)

...

⚠ WARNINGS DETECTED:

  • Incomplete CA Bundle in Cluster Configuration
    The certificate is valid according to the system trust store,
    but the CA bundle in the cluster secret is incomplete.

  Recommendation:
    Update the cluster certificate secret to include the complete
    CA chain (leaf, intermediate, and root certificates).

  Impact:
    - Certificate verification works (well-known CA is trusted)
    - Cluster configuration should be updated for completeness
    - This may affect applications relying on the cluster CA bundle

✓ Analysis complete!
```

## Summary

Dual verification for Custom Certificate (Well-Known CA) provides:
- ✅ Comprehensive validation
- ✅ Early detection of configuration issues
- ✅ Clear diagnostic information
- ✅ Actionable remediation guidance
- ✅ Non-blocking warnings for incomplete configurations
- ✅ Only aborts on truly invalid certificates

**Key Design Decision:** The script continues the analysis even if one verification method fails (as long as at least one passes), because:
- If system trust passes: The certificate is valid, cluster config is the issue
- If bundle passes: The cluster config is valid, system trust store is the issue
- Only if both fail: The certificate is actually invalid and analysis should stop

This ensures certificates are valid both from a trust perspective (system) and from a configuration perspective (cluster), while not blocking analysis on configuration issues.
