#!/bin/bash

# Display Analysis Summary
# Usage: ./99-summary.sh

# Source common functions
SCRIPT_DIR=`dirname "$0"`
source "$SCRIPT_DIR/common.sh"

# Load dependencies
load_workdir
load_cert_type
load_api_endpoint
load_ocp_version

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           OCP Certificate Analysis - Summary                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Get cluster name from API endpoint
CLUSTER_NAME=`echo "$API_ENDPOINT" | sed 's|https://api.||' | sed 's|:6443||'`

# Get certificate details
SUBJECT=`openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -subject | sed 's/subject=//'`
ISSUER=`openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -issuer | sed 's/issuer=//'`
NOT_BEFORE=`openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -startdate | sed 's/notBefore=//'`
NOT_AFTER=`openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -enddate | sed 's/notAfter=//'`

# Get root CA inclusion status
if [ -f "${WORKDIR}/.root_ca_included" ]; then
    ROOT_CA_INCLUDED=`cat "${WORKDIR}/.root_ca_included"`
else
    ROOT_CA_INCLUDED="unknown"
fi

# Get certificate warning if exists
if [ -f "${WORKDIR}/.cert_warning" ]; then
    CERT_WARNING=`cat "${WORKDIR}/.cert_warning"`
else
    CERT_WARNING=""
fi

# Get connectivity warning if exists
if [ -f "${WORKDIR}/.connectivity_warning" ]; then
    CONNECTIVITY_WARNING=`cat "${WORKDIR}/.connectivity_warning"`
else
    CONNECTIVITY_WARNING=""
fi

# Display summary
echo "Cluster: $CLUSTER_NAME"
echo "API Endpoint: $API_ENDPOINT"
echo "OpenShift Version: $OCP_VERSION"
echo ""
echo "Certificate Type: `get_cert_type_display "$CERT_TYPE"`"
echo ""
echo "Certificate Details:"
echo "  Subject: $SUBJECT"
echo "  Issuer: $ISSUER"
echo ""
echo "Validity Period:"
echo "  Valid From: $NOT_BEFORE"
echo "  Valid Until: $NOT_AFTER"
echo ""

# Display root CA inclusion with context based on cert type
if [ "$ROOT_CA_INCLUDED" = "yes" ]; then
    echo "Root CA in Bundle: ✅ Yes"
elif [ "$ROOT_CA_INCLUDED" = "no" ]; then
    case "$CERT_TYPE" in
        "Type1-OpenShift-Managed")
            echo "Root CA in Bundle: ❌ No (unexpected - should always be included)"
            ;;
        "Type2-RedHat-Managed"|"Type3a-Custom-WellKnown")
            echo "Root CA in Bundle: ❌ No (incomplete - can work via system trust store)"
            ;;
        "Type3b-Custom-SelfSigned")
            echo "Root CA in Bundle: ❌ No (missing - will cause verification failure)"
            ;;
        *)
            echo "Root CA in Bundle: ❌ No"
            ;;
    esac
else
    echo "Root CA in Bundle: N/A (uses system trust store)"
fi

echo ""
echo "Analysis Files Location: $WORKDIR/"
echo ""
echo "Key Files:"
echo "  - serving-cert.pem      : API server leaf certificate"
echo "  - ca-bundle.crt         : CA certificate bundle"
echo "  - intermediate-ca.pem   : Intermediate CA certificates"
echo "  - fullchain.pem         : Complete certificate chain"
echo ""

# Certificate type explanation
echo "About This Certificate Type:"
case "$CERT_TYPE" in
    "Type1-OpenShift-Managed")
        echo "  • Default OpenShift certificate (self-signed)"
        echo "  • Signed by: kube-apiserver-lb-signer"
        echo "  • Root CA always included in bundle"
        ;;
    "Type2-RedHat-Managed")
        echo "  • Managed by RedHat (ROSA, ARO, or OSD cluster)"
        echo "  • Certificate from well-known Certificate Authority"
        echo "  • Root CA in system trust store"
        ;;
    "Type3a-Custom-WellKnown")
        echo "  • Custom certificate from trusted Certificate Authority"
        echo "  • Examples: Let's Encrypt, DigiCert, GlobalSign"
        echo "  • Root CA typically in system trust store"
        ;;
    "Type3b-Custom-SelfSigned")
        echo "  • Custom certificate from private Certificate Authority"
        echo "  • Self-managed or organizational CA"
        echo "  • Root CA should be included in bundle"
        ;;
esac

echo ""

# Display warnings if any
if [ -n "$CERT_WARNING" ] || [ -n "$CONNECTIVITY_WARNING" ]; then
    echo "⚠ WARNINGS/ERRORS DETECTED:"
    echo ""

    # Display certificate warnings
    if [ "$CERT_WARNING" = "incomplete_bundle" ]; then
        echo "  • Incomplete CA Bundle in Cluster Configuration"
        echo "    The certificate is valid according to the system trust store,"
        echo "    but the CA bundle in the cluster secret is incomplete."
        echo ""
        echo "  Recommendation:"
        echo "    Update the cluster certificate secret to include the complete"
        echo "    CA chain (leaf, intermediate, and root certificates)."
        echo ""
        echo "  Impact:"
        echo "    - Certificate verification works (well-known CA is trusted)"
        echo "    - Cluster configuration should be updated for completeness"
        echo "    - This may affect applications relying on the cluster CA bundle"
    elif [ "$CERT_WARNING" = "verification_failed" ]; then
        echo "  • Certificate Verification Failed"
        echo "    The certificate could not be verified against the CA bundle."
        echo ""

        # Provide specific diagnosis based on gathered information
        if [ "$ROOT_CA_INCLUDED" = "no" ] && [ "$CERT_TYPE" = "Type3b-Custom-SelfSigned" ]; then
            echo "  Root Cause Identified:"
            echo "    ✗ Root CA is missing from the CA bundle"
            echo ""
            echo "  Analysis:"
            echo "    - Certificate Type: Custom Certificate (Private CA)"
            echo "    - Root CA Required: Yes (private CA must include root)"
            echo "    - Root CA Present: No (not found in CA bundle)"
            echo ""
            echo "  Recommendation:"
            echo "    Update the cluster certificate secret to include the complete"
            echo "    CA chain (leaf, intermediate, and root certificates)."
        elif [ "$ROOT_CA_INCLUDED" = "no" ]; then
            echo "  Root Cause Identified:"
            echo "    ✗ Root CA is missing from the CA bundle"
            echo ""
            echo "  Recommendation:"
            echo "    Update the cluster certificate secret to include the complete"
            echo "    CA chain (leaf, intermediate, and root certificates)."
        else
            echo "  Possible Causes:"
            echo "    1. CA bundle is incomplete (missing intermediate certificates)"
            echo "    2. Certificate chain is broken or invalid"
            echo "    3. CA bundle does not match the certificate"
            echo "    4. Certificate has expired or is not yet valid"
            echo ""
            echo "  Recommendation:"
            echo "    Review the certificate chain analysis (Step 7) to identify"
            echo "    missing certificates or chain issues."
        fi

        echo ""
        echo "  Impact:"
        echo "    - Certificate may not be trusted by applications"
        echo "    - SSL/TLS connections may fail"
        echo "    - Cluster services may experience connectivity issues"
    fi

    # Display connectivity warnings
    if [ -n "$CERT_WARNING" ] && [ -n "$CONNECTIVITY_WARNING" ]; then
        echo ""
    fi

    if [ "$CONNECTIVITY_WARNING" = "connectivity_failed" ]; then
        echo "  • API Server Connectivity Test Failed"
        echo "    Could not connect to the API server health endpoint."
        echo ""
        echo "  Possible Causes:"
        echo "    1. API server is not running or not accessible"
        echo "    2. Network connectivity issues"
        echo "    3. Firewall/security group blocking access"
        echo "    4. Certificate validation failed during connection"
        echo ""
        echo "  Recommendation:"
        echo "    Verify the API server is accessible and certificates are"
        echo "    properly configured. Review network and firewall settings."
        echo ""
        echo "  Impact:"
        echo "    - API server may not be accessible from this location"
        echo "    - This may be a network/connectivity issue, not a certificate issue"
    fi
    echo ""
fi

print_success "Analysis complete!"
echo ""
