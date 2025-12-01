#!/bin/bash

# Step 4: Determine Certificate Type
# Usage: ./04-determine-cert-type.sh

# Source common functions
SCRIPT_DIR=`dirname "$0"`
source "$SCRIPT_DIR/common.sh"

# Load dependencies
load_workdir
load_kubeconfig

echo "=== Step 4: Determine Certificate Type ==="
echo ""

# Step 4.1: Check the Issuer
echo "Step 4.1: Checking certificate issuer..."
ISSUER=`openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -issuer`
echo "$ISSUER"
echo ""

# Check if issuer is kube-apiserver-lb-signer
if echo "$ISSUER" | grep -q "CN=kube-apiserver-lb-signer"; then
    IS_KUBE_SIGNER="true"
    print_info "Issuer is kube-apiserver-lb-signer"
else
    IS_KUBE_SIGNER="false"
    print_info "Issuer is NOT kube-apiserver-lb-signer"
fi
echo ""

# Step 4.2: Check for Custom Certificate Configuration
echo "Step 4.2: Checking for custom certificate configuration..."
NAMED_CERTS=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}' 2>&1`
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    print_error "Failed to retrieve API server configuration"
    echo "$NAMED_CERTS"
    if echo "$NAMED_CERTS" | grep -qi "timeout\|timed out"; then
        echo ""
        print_error "Connection timed out - cluster is unavailable"
    fi
    exit 1
fi

if [ -z "$NAMED_CERTS" ] || [ "$NAMED_CERTS" = "null" ]; then
    HAS_CUSTOM_CERT="false"
    print_info "No custom certificate configuration found"
else
    HAS_CUSTOM_CERT="true"
    print_info "Custom certificate configuration found:"
    echo "$NAMED_CERTS"
    echo ""

    # Step 4.3: Verify Secret Exists
    echo "Step 4.3: Verifying custom certificate secret..."
    SECRET_NAME=`oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}' 2>&1`
    echo "Secret name: $SECRET_NAME"

    SECRET_EXISTS=`oc get secret "$SECRET_NAME" -n openshift-config --ignore-not-found 2>&1`

    if [ -n "$SECRET_EXISTS" ]; then
        print_info "Secret exists in openshift-config namespace"
        echo "$SECRET_EXISTS"
    else
        HAS_CUSTOM_CERT="false"
        print_info "Secret does not exist"
    fi
fi
echo ""

# Determine certificate type
echo "=== Certificate Type Determination ==="
echo ""

if [ "$IS_KUBE_SIGNER" = "true" ]; then
    CERT_TYPE="Type1-OpenShift-Managed"
    print_success "Certificate Type: `get_cert_type_display "$CERT_TYPE"`"
    echo "  - Issuer: CN=kube-apiserver-lb-signer"
    echo "  - Self-managed cluster with default OpenShift certificates"
elif [ "$HAS_CUSTOM_CERT" = "false" ]; then
    CERT_TYPE="Type2-RedHat-Managed"

    # Identify the specific well-known CA
    if echo "$ISSUER" | grep -q "Let's Encrypt"; then
        CA_NAME="Let's Encrypt"
    elif echo "$ISSUER" | grep -q "DigiCert"; then
        CA_NAME="DigiCert"
    elif echo "$ISSUER" | grep -q "GlobalSign"; then
        CA_NAME="GlobalSign"
    elif echo "$ISSUER" | grep -q "GeoTrust"; then
        CA_NAME="GeoTrust"
    elif echo "$ISSUER" | grep -q "Sectigo"; then
        CA_NAME="Sectigo"
    elif echo "$ISSUER" | grep -q "Entrust"; then
        CA_NAME="Entrust"
    else
        CA_NAME="Well-known CA"
    fi

    print_success "Certificate Type: `get_cert_type_display "$CERT_TYPE"`"
    echo "  - Issuer: $CA_NAME (Well-Known CA)"
    echo "  - Managed cluster (ROSA, ARO, OSD)"
else
    # Determine if well-known or self-signed
    # Check if issuer contains well-known CAs
    if echo "$ISSUER" | grep -qE "Let's Encrypt|DigiCert|GlobalSign|GeoTrust|Sectigo|Entrust"; then
        CERT_TYPE="Type3a-Custom-WellKnown"

        # Identify the specific well-known CA
        if echo "$ISSUER" | grep -q "Let's Encrypt"; then
            CA_NAME="Let's Encrypt"
        elif echo "$ISSUER" | grep -q "DigiCert"; then
            CA_NAME="DigiCert"
        elif echo "$ISSUER" | grep -q "GlobalSign"; then
            CA_NAME="GlobalSign"
        elif echo "$ISSUER" | grep -q "GeoTrust"; then
            CA_NAME="GeoTrust"
        elif echo "$ISSUER" | grep -q "Sectigo"; then
            CA_NAME="Sectigo"
        elif echo "$ISSUER" | grep -q "Entrust"; then
            CA_NAME="Entrust"
        else
            CA_NAME="Well-known CA"
        fi

        print_success "Certificate Type: `get_cert_type_display "$CERT_TYPE"`"
        echo "  - Issuer: $CA_NAME (Well-known CA)"
        echo "  - Self-managed cluster with custom certificate"
    else
        CERT_TYPE="Type3b-Custom-SelfSigned"
        print_success "Certificate Type: `get_cert_type_display "$CERT_TYPE"`"
        echo "  - Issuer: Private/Custom CA"
        echo "  - Self-managed cluster with custom certificate"
    fi
fi

# Save certificate type to working directory
echo "$CERT_TYPE" > "${WORKDIR}/.cert_type"
echo ""
print_info "Certificate type saved"
echo ""
print_success "Certificate type determination complete. Ready to proceed to Step 5."
