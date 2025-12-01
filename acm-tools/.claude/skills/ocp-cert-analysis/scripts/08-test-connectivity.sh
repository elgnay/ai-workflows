#!/bin/bash

# Step 8: Test Connectivity to API Server
# Usage: ./08-test-connectivity.sh

# Source common functions
SCRIPT_DIR=`dirname "$0"`
source "$SCRIPT_DIR/common.sh"

# Load dependencies
load_workdir
load_kubeconfig
load_api_endpoint
load_cert_type

echo "=== Step 8: Test API Server Connectivity ==="
echo ""
echo "Certificate Type: `get_cert_type_display "$CERT_TYPE"`"
echo "API Endpoint: $API_ENDPOINT"
echo ""

case "$CERT_TYPE" in
    "Type1-OpenShift-Managed"|"Type3b-Custom-SelfSigned")
        echo "Testing connectivity with CA bundle file..."
        CURL_OUTPUT=`curl -s --connect-timeout 30 --max-time 60 --cacert "${WORKDIR}/ca-bundle.crt" "${API_ENDPOINT}/healthz" 2>&1`
        EXIT_CODE=$?
        ;;

    "Type2-RedHat-Managed"|"Type3a-Custom-WellKnown")
        echo "Testing connectivity with system trust store..."
        CURL_OUTPUT=`curl -s --connect-timeout 30 --max-time 60 "${API_ENDPOINT}/healthz" 2>&1`
        EXIT_CODE=$?
        ;;

    *)
        print_error "Unknown certificate type: $CERT_TYPE"
        exit 1
        ;;
esac

# Check connectivity result
if [ "$CURL_OUTPUT" = "ok" ]; then
    print_success "API server responded: $CURL_OUTPUT"
    print_success "Connectivity test passed"
elif [ $EXIT_CODE -eq 28 ] || echo "$CURL_OUTPUT" | grep -qi "timeout\|timed out"; then
    print_error "Connection timed out"
    echo ""
    echo "Response: $CURL_OUTPUT"
    echo ""
    echo "Troubleshooting suggestions:"
    echo "  1. Verify the API server is running and accessible"
    echo "  2. Check network connectivity to ${API_ENDPOINT}"
    echo "  3. Verify firewall/security group allows access"
    echo "  4. Test basic connectivity: curl -k ${API_ENDPOINT}/healthz"
    echo ""
    echo "⚠ Connectivity test failed, but analysis is complete."
    echo "connectivity_failed" > "${WORKDIR}/.connectivity_warning"
else
    print_error "API server connectivity test failed"
    echo ""
    echo "Response: $CURL_OUTPUT"
    echo ""
    if echo "$CURL_OUTPUT" | grep -qi "certificate"; then
        echo "Certificate validation may have failed."
        echo "This could indicate a mismatch between the CA bundle and server certificate."
    fi
    echo ""
    echo "⚠ Connectivity test failed, but analysis is complete."
    echo "connectivity_failed" > "${WORKDIR}/.connectivity_warning"
fi

echo ""
print_success "All 8 steps completed successfully!"
