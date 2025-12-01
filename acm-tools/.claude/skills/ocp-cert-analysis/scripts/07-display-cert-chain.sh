#!/bin/bash

# Step 7: Display the Certificate Chain
# Usage: ./07-display-cert-chain.sh

# Source common functions
SCRIPT_DIR=`dirname "$0"`
source "$SCRIPT_DIR/common.sh"

# Load dependencies
load_workdir

echo "=== Step 7: Certificate Chain Analysis ==="
echo ""

# Display serving certificate
echo "1. Serving Certificate:"
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -subject -issuer
echo ""

# Display CA Bundle Analysis (if file exists)
if [ -f "${WORKDIR}/ca-bundle.crt" ]; then
    echo "2. CA Bundle Analysis:"
    CERT_COUNT=`grep -c "BEGIN CERTIFICATE" "${WORKDIR}/ca-bundle.crt"`
    echo "Number of certificates in CA bundle: $CERT_COUNT"
    echo ""

    # Display each certificate in the bundle
    for i in `seq 1 ${CERT_COUNT}`; do
        echo "--- Certificate ${i} ---"
        CERT_SUBJECT_FULL=`awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -subject`
        CERT_ISSUER_FULL=`awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -issuer`
        echo "$CERT_SUBJECT_FULL"
        echo "$CERT_ISSUER_FULL"

        # Strip prefixes for comparison
        CERT_SUBJECT="${CERT_SUBJECT_FULL#subject=}"
        CERT_ISSUER="${CERT_ISSUER_FULL#issuer=}"

        # Check if this is a self-signed cert (root CA)
        if [ "$CERT_SUBJECT" = "$CERT_ISSUER" ]; then
            echo "(Self-signed - Root CA)"
        fi
        echo ""
    done

    # Check if Root CA is included by tracing the chain
    echo "3. Root CA Inclusion Check:"
    echo ""
    echo "Tracing certificate chain from serving certificate..."

    # Get the issuer of the serving certificate
    SERVING_ISSUER=`openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -issuer`
    echo "Serving certificate issued by: ${SERVING_ISSUER#issuer=}"
    echo ""

    # Look for root CA by finding a self-signed certificate in the chain
    ROOT_CA_FOUND="no"
    ROOT_CA_POSITION=0

    for i in `seq 1 ${CERT_COUNT}`; do
        CERT_SUBJECT_FULL=`awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -subject`
        CERT_ISSUER_FULL=`awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${WORKDIR}/ca-bundle.crt" | openssl x509 -noout -issuer`

        # Strip prefixes for comparison
        CERT_SUBJECT="${CERT_SUBJECT_FULL#subject=}"
        CERT_ISSUER="${CERT_ISSUER_FULL#issuer=}"

        # Check if this certificate is self-signed (root CA)
        if [ "$CERT_SUBJECT" = "$CERT_ISSUER" ]; then
            ROOT_CA_FOUND="yes"
            ROOT_CA_POSITION=$i
            echo "Found self-signed root CA at position ${i}:"
            echo "$CERT_SUBJECT"
            break
        fi
    done
    echo ""

    if [ "$ROOT_CA_FOUND" = "yes" ]; then
        print_success "Root CA is INCLUDED in CA bundle (found at position ${ROOT_CA_POSITION})"
        ROOT_CA_INCLUDED="yes"
    else
        print_info "Root CA is NOT included in CA bundle (no self-signed certificate found)"

        # Provide context-aware message based on certificate type
        case "$CERT_TYPE" in
            "Type1-OpenShift-Managed")
                print_info "Root CA should be included in bundle"
                ;;
            "Type2-RedHat-Managed")
                print_info "Root CA is expected to be in system trust store"
                ;;
            "Type3a-Custom-WellKnown")
                print_info "Root CA is expected to be in both system trust store and CA bundle"
                ;;
            "Type3b-Custom-SelfSigned")
                print_info "Root CA is missing - this will cause verification failure"
                ;;
        esac

        ROOT_CA_INCLUDED="no"
    fi

    # Save root CA inclusion status
    echo "$ROOT_CA_INCLUDED" > "${WORKDIR}/.root_ca_included"
else
    # For Type2, display the full certificate chain from fullchain.pem
    echo "2. Certificate Chain from Server:"

    if [ -f "${WORKDIR}/fullchain.pem" ]; then
        CERT_COUNT=`grep -c "BEGIN CERTIFICATE" "${WORKDIR}/fullchain.pem"`
        echo "Number of certificates in chain: $CERT_COUNT"
        echo ""

        # Display each certificate in the chain
        for i in `seq 1 ${CERT_COUNT}`; do
            echo "--- Certificate ${i} ---"
            CERT_SUBJECT_FULL=`awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${WORKDIR}/fullchain.pem" | openssl x509 -noout -subject`
            CERT_ISSUER_FULL=`awk "/BEGIN CERTIFICATE/ {n++} n==${i}" "${WORKDIR}/fullchain.pem" | openssl x509 -noout -issuer`
            echo "$CERT_SUBJECT_FULL"
            echo "$CERT_ISSUER_FULL"

            # Strip prefixes for comparison
            CERT_SUBJECT="${CERT_SUBJECT_FULL#subject=}"
            CERT_ISSUER="${CERT_ISSUER_FULL#issuer=}"

            # Check if this is a self-signed cert (root CA)
            if [ "$CERT_SUBJECT" = "$CERT_ISSUER" ]; then
                echo "(Self-signed - Root CA)"
            fi
            echo ""
        done

        echo ""
        print_info "Root CA is in system trust store (well-known CA)"

        # Set ROOT_CA_INCLUDED to n/a since we don't have a CA bundle to check
        ROOT_CA_INCLUDED="n/a"
    else
        print_info "No certificate chain file available"
        ROOT_CA_INCLUDED="n/a"
    fi

    echo "$ROOT_CA_INCLUDED" > "${WORKDIR}/.root_ca_included"
fi

echo ""
print_success "Certificate chain analysis complete. Ready to proceed to Step 8."
