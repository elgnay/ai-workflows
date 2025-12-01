#!/bin/bash

# Step 5: Retrieve CA Bundle Based on Certificate Type
# Usage: ./05-get-ca-bundle.sh

# Source common functions
SCRIPT_DIR=`dirname "$0"`
source "$SCRIPT_DIR/common.sh"

# Load dependencies
load_workdir
load_kubeconfig
load_cert_type

echo "=== Step 5: Retrieve CA Bundle ==="
echo ""
echo "Certificate Type: `get_cert_type_display "$CERT_TYPE"`"
echo ""

case "$CERT_TYPE" in
    "Type1-OpenShift-Managed")
        echo "Retrieving CA bundle from OpenShift configmap..."
        echo ""

        # Verify no custom certificates
        NAMED_CERTS=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'`
        if [ -z "$NAMED_CERTS" ] || [ "$NAMED_CERTS" = "null" ]; then
            print_success "Verified: No custom certificates configured"
        else
            print_error "Warning: Custom certificates found, but cert type is OpenShift-Managed"
        fi
        echo ""

        # Retrieve CA bundle from configmap
        CA_BUNDLE_OUTPUT=`oc get configmap kube-apiserver-server-ca -n openshift-kube-apiserver -o jsonpath='{.data.ca-bundle\.crt}' 2>&1`
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            echo "$CA_BUNDLE_OUTPUT" > "${WORKDIR}/ca-bundle.crt"
            print_success "CA bundle retrieved from kube-apiserver-server-ca configmap"
        else
            print_error "Failed to retrieve CA bundle"
            echo "$CA_BUNDLE_OUTPUT"
            if echo "$CA_BUNDLE_OUTPUT" | grep -qi "timeout\|timed out"; then
                echo ""
                print_error "Connection timed out - cluster is unavailable"
            fi
            exit 1
        fi
        ;;

    "Type2-RedHat-Managed")
        print_info "Certificate is signed by a well-known CA (already in system trust store)"
        print_info "No CA bundle extraction needed - verification will use system trust store"
        ;;

    "Type3a-Custom-WellKnown"|"Type3b-Custom-SelfSigned")
        echo "Retrieving CA bundle from custom certificate secret..."
        echo ""

        # Verify custom certificates configured
        NAMED_CERTS=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}'`
        if [ -n "$NAMED_CERTS" ] && [ "$NAMED_CERTS" != "null" ]; then
            print_success "Verified: Custom certificates configured"
        else
            print_error "No custom certificates found"
            exit 1
        fi
        echo ""

        # Get secret name
        SECRET_NAME=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}'`
        echo "Secret name: $SECRET_NAME"
        echo ""

        # Extract CA bundle from secret
        SECRET_OUTPUT=`oc extract secret/${SECRET_NAME} -n openshift-config --keys=tls.crt --to=- 2>&1`
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            echo "$SECRET_OUTPUT" > "${WORKDIR}/ca-bundle.crt"
            print_success "CA bundle retrieved from secret: $SECRET_NAME"
        else
            print_error "Failed to extract CA bundle from secret"
            echo "$SECRET_OUTPUT"
            if echo "$SECRET_OUTPUT" | grep -qi "timeout\|timed out"; then
                echo ""
                print_error "Connection timed out - cluster is unavailable"
            fi
            exit 1
        fi
        ;;

    *)
        print_error "Unknown certificate type: $CERT_TYPE"
        exit 1
        ;;
esac

# Count certificates in CA bundle (if file exists)
if [ -f "${WORKDIR}/ca-bundle.crt" ]; then
    CERT_COUNT=`grep -c "BEGIN CERTIFICATE" "${WORKDIR}/ca-bundle.crt"`
    echo ""
    print_success "Number of certificates in CA bundle: $CERT_COUNT"
fi

echo ""
print_success "CA bundle retrieval complete. Ready to proceed to Step 6."
