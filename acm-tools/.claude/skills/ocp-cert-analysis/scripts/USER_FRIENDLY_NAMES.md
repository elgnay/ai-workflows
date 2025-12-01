# User-Friendly Certificate Type Names

## Overview

All scripts now display user-friendly certificate type names instead of technical codes (Type1, Type2, Type3a, Type3b).

## Certificate Type Display Names

| Internal Code | User-Friendly Display Name |
|---------------|----------------------------|
| `Type1-OpenShift-Managed` | **OpenShift-Managed Certificate** |
| `Type2-RedHat-Managed` | **RedHat-Managed Certificate** |
| `Type3a-Custom-WellKnown` | **Custom Certificate (Well-Known CA)** |
| `Type3b-Custom-SelfSigned` | **Custom Certificate (Private CA)** |

## Why This Change?

**Problem**: Users don't understand technical codes like "Type3a" or "Type1"

**Solution**: Display clear, descriptive names that immediately convey meaning:
- ✅ "OpenShift-Managed Certificate" - Users understand this is the default OpenShift cert
- ✅ "Custom Certificate (Well-Known CA)" - Users understand this is a custom cert from a trusted CA
- ✅ "Custom Certificate (Private CA)" - Users understand this is a custom cert from their own CA

## Implementation

### Helper Function

A centralized function in `common.sh` converts internal codes to display names:

```bash
# Function to convert internal cert type to user-friendly display name
get_cert_type_display() {
    local cert_type="$1"
    case "$cert_type" in
        "Type1-OpenShift-Managed")
            echo "OpenShift-Managed Certificate"
            ;;
        "Type2-RedHat-Managed")
            echo "RedHat-Managed Certificate"
            ;;
        "Type3a-Custom-WellKnown")
            echo "Custom Certificate (Well-Known CA)"
            ;;
        "Type3b-Custom-SelfSigned")
            echo "Custom Certificate (Private CA)"
            ;;
        *)
            echo "$cert_type"
            ;;
    esac
}
```

### Usage in Scripts

All scripts use the helper function for consistent display:

```bash
echo "Certificate Type: `get_cert_type_display "$CERT_TYPE"`"
```

### Internal vs Display

- **Internal storage**: Still uses technical codes (Type1, Type2, etc.) for:
  - File storage (`.cert_type`)
  - Case statements
  - Logic flow
  - Backward compatibility

- **User display**: Uses friendly names everywhere the user sees output:
  - Step 4 output (determination)
  - Step 5 output (CA bundle retrieval)
  - Step 6 output (verification)
  - Step 8 output (connectivity test)
  - Summary output (final report)

## Example Output

### Before (Technical Codes)

```
=== Certificate Type Determination ===

✓ Certificate Type: Type 3a - Custom with Well-Known CA
  - Issuer: Well-known CA (Let's Encrypt, DigiCert, etc.)
  - Self-managed cluster with custom certificate
```

### After (User-Friendly)

```
=== Certificate Type Determination ===

✓ Certificate Type: Custom Certificate (Well-Known CA)
  - Issuer: Well-known CA (Let's Encrypt, DigiCert, etc.)
  - Self-managed cluster with custom certificate
```

## Summary Output Comparison

### Before

```
╔═══════════════════════════════════════════════════════════════╗
║           OCP Certificate Analysis - Summary                  ║
╚═══════════════════════════════════════════════════════════════╝

Cluster: cluster.example.com
API Endpoint: https://api.cluster.example.com:6443

Certificate Type: Type3a-Custom-WellKnown

Certificate Type Details:
  • Custom certificate with well-known CA
  • Issuer: Let's Encrypt, DigiCert, etc.
  • Root CA typically in system trust store
```

### After

```
╔═══════════════════════════════════════════════════════════════╗
║           OCP Certificate Analysis - Summary                  ║
╚═══════════════════════════════════════════════════════════════╝

Cluster: cluster.example.com
API Endpoint: https://api.cluster.example.com:6443

Certificate Type: Custom Certificate (Well-Known CA)

About This Certificate Type:
  • Custom certificate from trusted Certificate Authority
  • Examples: Let's Encrypt, DigiCert, GlobalSign
  • Root CA typically in system trust store
```

## Benefits

✅ **Immediately understandable** - Users know what type of certificate they have
✅ **No learning curve** - No need to memorize technical codes
✅ **Context-rich** - Names provide information about the certificate
✅ **Professional** - Clear, business-friendly terminology
✅ **Consistent** - Same naming across all workflow steps

## Scripts Updated

| Script | Change |
|--------|--------|
| `common.sh` | Added `get_cert_type_display()` helper function |
| `04-determine-cert-type.sh` | Uses helper for display output |
| `05-get-ca-bundle.sh` | Uses helper for display output |
| `06-verify-cert.sh` | Uses helper for display output |
| `08-test-connectivity.sh` | Uses helper for display output |
| `99-summary.sh` | Uses helper for display output and "About This Certificate Type" section |

## Technical Details

### Backward Compatibility

Internal code format (`Type1-OpenShift-Managed`) is preserved for:
- State file storage (`.cert_type`)
- Case statement matching
- Script logic
- Integration with other tools

### Centralized Management

All display name mappings are in one place (`common.sh`), making it easy to:
- Update terminology
- Add new certificate types
- Maintain consistency
- Localize (if needed in future)

### No Breaking Changes

- File formats unchanged
- State files unchanged
- Logic unchanged
- Only display output improved

## User Experience

Users now see certificate types as clear, descriptive labels throughout the entire workflow, making the analysis results immediately understandable without technical knowledge.
