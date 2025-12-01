#!/bin/bash

# Step 6: Verify the Serving Certificate
# Usage: ./06-verify-cert.sh

# Source common functions
SCRIPT_DIR=`dirname "$0"`
source "$SCRIPT_DIR/common.sh"

# Load dependencies
load_workdir
load_cert_type

echo "=== Step 6: Verify Serving Certificate ==="
echo ""
echo "Certificate Type: `get_cert_type_display "$CERT_TYPE"`"
echo ""

case "$CERT_TYPE" in
    "Type1-OpenShift-Managed")
        echo "Verifying with CA bundle file..."
        VERIFY_OUTPUT=`openssl verify -CAfile "${WORKDIR}/ca-bundle.crt" "${WORKDIR}/serving-cert.pem" 2>&1`

        echo "$VERIFY_OUTPUT"
        echo ""

        if echo "$VERIFY_OUTPUT" | grep -q "OK"; then
            print_success "Certificate verification successful"
        else
            print_error "Certificate verification failed"
            echo ""
            echo "⚠ Verification failed, but continuing analysis to provide complete report..."
            echo "verification_failed" > "${WORKDIR}/.cert_warning"
        fi
        ;;

    "Type2-RedHat-Managed")
        echo "Verifying with system trust store..."
        # Detect OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            VERIFY_OUTPUT=`openssl verify -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/serving-cert.pem" 2>&1`
        elif [ -f "/etc/pki/tls/certs/ca-bundle.crt" ]; then
            # RHEL/Fedora/CentOS
            VERIFY_OUTPUT=`openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/serving-cert.pem" 2>&1`
        elif [ -d "/etc/ssl/certs" ]; then
            # Debian/Ubuntu
            VERIFY_OUTPUT=`openssl verify -CApath /etc/ssl/certs -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/serving-cert.pem" 2>&1`
        else
            print_error "Unsupported OS for system trust store verification"
            exit 1
        fi

        echo "$VERIFY_OUTPUT"
        echo ""

        if echo "$VERIFY_OUTPUT" | grep -q "OK"; then
            print_success "Certificate verification successful"
        else
            print_error "Certificate verification failed"
            echo ""
            echo "⚠ Verification failed, but continuing analysis to provide complete report..."
            echo "verification_failed" > "${WORKDIR}/.cert_warning"
        fi
        ;;

    "Type3a-Custom-WellKnown")
        echo "Performing dual verification for custom certificate with well-known CA..."
        echo ""

        # Verification 1: System trust store
        echo "1. Verifying with system trust store..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            VERIFY_SYSTEM=`openssl verify -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/serving-cert.pem" 2>&1`
        elif [ -f "/etc/pki/tls/certs/ca-bundle.crt" ]; then
            # RHEL/Fedora/CentOS
            VERIFY_SYSTEM=`openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/serving-cert.pem" 2>&1`
        elif [ -d "/etc/ssl/certs" ]; then
            # Debian/Ubuntu
            VERIFY_SYSTEM=`openssl verify -CApath /etc/ssl/certs -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/serving-cert.pem" 2>&1`
        else
            print_error "Unsupported OS for system trust store verification"
            exit 1
        fi

        echo "   $VERIFY_SYSTEM"

        if echo "$VERIFY_SYSTEM" | grep -q "OK"; then
            print_success "   System trust store verification: PASSED"
        else
            print_error "   System trust store verification: FAILED"
            SYSTEM_VERIFY_FAILED="true"
        fi
        echo ""

        # Verification 2: Extracted CA bundle
        echo "2. Verifying with extracted CA bundle from cluster..."
        VERIFY_BUNDLE=`openssl verify -CAfile "${WORKDIR}/ca-bundle.crt" "${WORKDIR}/serving-cert.pem" 2>&1`

        echo "   $VERIFY_BUNDLE"

        if echo "$VERIFY_BUNDLE" | grep -q "OK"; then
            print_success "   CA bundle verification: PASSED"
        else
            print_error "   CA bundle verification: FAILED"
            BUNDLE_VERIFY_FAILED="true"
        fi
        echo ""

        # Overall result
        if [ "$SYSTEM_VERIFY_FAILED" = "true" ] && [ "$BUNDLE_VERIFY_FAILED" = "true" ]; then
            # Both failed - this is a real error
            print_error "Certificate verification failed"
            echo ""
            echo "Both verification methods failed. Certificate chain may be incomplete or invalid."
            exit 1
        elif [ "$SYSTEM_VERIFY_FAILED" = "true" ] && [ "$BUNDLE_VERIFY_FAILED" != "true" ]; then
            # System failed but bundle passed - unusual, warn but continue
            print_info "Certificate verification: Mixed results"
            echo ""
            echo "⚠ Warning: Certificate is valid according to cluster CA bundle but not system trust store."
            echo "This may indicate the well-known CA root is missing from system trust store."
            echo ""
            print_info "Continuing analysis (certificate is valid per cluster configuration)..."
        elif [ "$SYSTEM_VERIFY_FAILED" != "true" ] && [ "$BUNDLE_VERIFY_FAILED" = "true" ]; then
            # System passed but bundle failed - warn but continue
            print_info "Certificate verification: Mixed results"
            echo ""
            echo "⚠ Warning: Certificate is valid according to system trust store but not cluster CA bundle."
            echo "This may indicate incomplete CA bundle in cluster configuration."
            echo ""
            print_info "Continuing analysis (certificate is valid per system trust store)..."

            # Save warning flag for summary
            echo "incomplete_bundle" > "${WORKDIR}/.cert_warning"
        else
            # Both passed - perfect
            print_success "All certificate verifications successful"
        fi
        ;;

    "Type3b-Custom-SelfSigned")
        echo "Verifying with CA bundle file..."
        VERIFY_OUTPUT=`openssl verify -CAfile "${WORKDIR}/ca-bundle.crt" "${WORKDIR}/serving-cert.pem" 2>&1`

        echo "$VERIFY_OUTPUT"
        echo ""

        if echo "$VERIFY_OUTPUT" | grep -q "OK"; then
            print_success "Certificate verification successful"
        else
            print_error "Certificate verification failed"
            echo ""
            echo "⚠ Verification failed, but continuing analysis to provide complete report..."
            echo ""
            echo "Possible causes:"
            echo "  1. CA bundle is incomplete (missing intermediate or root CA)"
            echo "  2. Certificate chain is broken or invalid"
            echo "  3. CA bundle does not match the certificate"
            echo ""
            echo "verification_failed" > "${WORKDIR}/.cert_warning"
        fi
        ;;

    *)
        print_error "Unknown certificate type: $CERT_TYPE"
        exit 1
        ;;
esac

echo ""
print_success "Certificate verification complete. Ready to proceed to Step 7."
