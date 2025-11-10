#!/bin/bash

# OCP Certificate Analysis Workflow Script
# This script analyzes and verifies OpenShift Kube-APIServer certificates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to print warnings
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Step 0: Set Up Kubeconfig
print_header "Step 0: Set Up Kubeconfig"

if [ -z "$KUBECONFIG" ]; then
    read -p "Enter the path to your kubeconfig file (or press Enter to use default): " KUBECONFIG_PATH

    if [ -z "$KUBECONFIG_PATH" ]; then
        # Check for kubeconfig in current directory
        if [ -f "kubeconfig" ]; then
            KUBECONFIG_PATH="$(pwd)/kubeconfig"
            print_info "Using kubeconfig found in current directory: $KUBECONFIG_PATH"
        elif [ -f "$HOME/.kube/config" ]; then
            KUBECONFIG_PATH="$HOME/.kube/config"
            print_info "Using default kubeconfig: $KUBECONFIG_PATH"
        else
            print_error "No kubeconfig file found"
            exit 1
        fi
    fi

    export KUBECONFIG="${KUBECONFIG_PATH}"
else
    print_info "Using existing KUBECONFIG: $KUBECONFIG"
fi

# Verify authentication
print_info "Verifying authentication..."
USERNAME=$(oc whoami)
print_success "Authenticated as: $USERNAME"

# Step 1: Get External API Server Endpoint
print_header "Step 1: Get External API Server Endpoint"

API_SERVER_URL=$(oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}')
print_success "API Server URL: $API_SERVER_URL"

# Extract hostname and port
API_HOSTNAME=$(echo "$API_SERVER_URL" | sed 's|https://||' | sed 's|:.*||')
API_PORT=$(echo "$API_SERVER_URL" | sed 's|.*:||')
print_info "API Hostname: $API_HOSTNAME"
print_info "API Port: $API_PORT"

# Step 2: Create Working Directory and Retrieve Certificates
print_header "Step 2: Create Working Directory and Retrieve Certificates"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
WORKDIR="run-${TIMESTAMP}"
mkdir -p "${WORKDIR}"
print_success "Working directory created: ${WORKDIR}"
echo "${WORKDIR}" > .current_workdir

# Retrieve certificate chain
print_info "Retrieving certificate chain from API server..."
echo | openssl s_client -connect "${API_HOSTNAME}:${API_PORT}" -showcerts 2>/dev/null > "${WORKDIR}/openssl_output.txt"
print_success "Certificate chain retrieved"

# Extract certificates
sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "${WORKDIR}/openssl_output.txt" > "${WORKDIR}/fullchain.pem"
awk '/BEGIN CERTIFICATE/ {n++} n==1' "${WORKDIR}/fullchain.pem" > "${WORKDIR}/kube-apiserver-serving-cert.pem"
awk '/BEGIN CERTIFICATE/ {n++} n>=2' "${WORKDIR}/fullchain.pem" > "${WORKDIR}/intermediate-ca.pem"
print_success "Certificates extracted and separated"

# Display Certificate Details (part of Step 2)
echo -e "\n${YELLOW}=== Certificate Details ===${NC}"
echo -e "${YELLOW}Subject and Issuer:${NC}"
openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -subject -issuer

echo -e "\n${YELLOW}Validity Period:${NC}"
openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -dates

echo -e "\n${YELLOW}Subject Alternative Names:${NC}"
openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -ext subjectAltName

# Step 3: Determine Certificate Type
print_header "Step 3: Determine Certificate Type"

CERT_ISSUER=$(openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -issuer)
print_info "Certificate Issuer: $CERT_ISSUER"

NAMED_CERTS=$(oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates}' 2>/dev/null || echo "")

CERT_TYPE=""

if echo "$CERT_ISSUER" | grep -q "kube-apiserver-lb-signer"; then
    if [ -z "$NAMED_CERTS" ]; then
        CERT_TYPE="Type1-OpenShift-Managed"
        print_success "Certificate Type: Type 1 - OpenShift-Managed Certificate"
        print_info "This is a self-managed cluster using the default OpenShift-managed certificate"
    else
        print_warning "Unusual case: kube-apiserver-lb-signer with namedCertificates configured"
        CERT_TYPE="Type1-OpenShift-Managed"
    fi
else
    if [ -z "$NAMED_CERTS" ]; then
        CERT_TYPE="Type2-RedHat-Managed"
        print_success "Certificate Type: Type 2 - RedHat-Managed Certificate"
        print_info "This is a managed cluster (ROSA, ARO, OpenShift Dedicated)"
    else
        # Check if secret exists
        SECRET_NAME=$(oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}' 2>/dev/null || echo "")
        if [ -n "$SECRET_NAME" ]; then
            if oc get secret "$SECRET_NAME" -n openshift-config &>/dev/null; then
                # Determine if it's a well-known CA or self-signed
                if echo "$CERT_ISSUER" | grep -qE "Let's Encrypt|DigiCert|GlobalSign|Sectigo|GeoTrust|Entrust"; then
                    CERT_TYPE="Type3a-Custom-WellKnown"
                    print_success "Certificate Type: Type 3a - Custom Certificate Signed by Well-Known CA"
                else
                    CERT_TYPE="Type3b-Custom-SelfSigned"
                    print_success "Certificate Type: Type 3b - Custom Certificate Signed by Self-Signed CA"
                fi
            else
                CERT_TYPE="Type2-RedHat-Managed"
                print_success "Certificate Type: Type 2 - RedHat-Managed Certificate"
                print_info "namedCertificates configured but secret not found"
            fi
        else
            CERT_TYPE="Type2-RedHat-Managed"
            print_success "Certificate Type: Type 2 - RedHat-Managed Certificate"
        fi
    fi
fi

# Step 4: Retrieve CA Bundle
print_header "Step 4: Retrieve CA Bundle"

case "$CERT_TYPE" in
    "Type1-OpenShift-Managed")
        print_info "Retrieving OpenShift-managed CA bundle..."
        echo -e "${BLUE}Command: oc get configmap kube-apiserver-server-ca -n openshift-kube-apiserver -o jsonpath='{.data.ca-bundle\.crt}' > \"${WORKDIR}/kube-apiserver-ca-bundle.crt\"${NC}\n"
        oc get configmap kube-apiserver-server-ca -n openshift-kube-apiserver -o jsonpath='{.data.ca-bundle\.crt}' > "${WORKDIR}/kube-apiserver-ca-bundle.crt"
        CA_BUNDLE="${WORKDIR}/kube-apiserver-ca-bundle.crt"
        CERT_COUNT=$(grep -c "BEGIN CERTIFICATE" "${CA_BUNDLE}")
        print_success "CA bundle retrieved: $CERT_COUNT certificates"
        ;;

    "Type2-RedHat-Managed")
        print_info "RedHat-managed certificate (uses well-known CA)"
        print_info "Will use system trust store for verification"
        echo -e "${BLUE}Command: N/A (using system trust store)${NC}\n"
        CA_BUNDLE="system"
        ;;

    "Type3a-Custom-WellKnown")
        print_info "Custom certificate signed by well-known CA"
        print_info "Will use system trust store for verification"
        echo -e "${BLUE}Command: N/A (using system trust store)${NC}\n"
        CA_BUNDLE="system"
        ;;

    "Type3b-Custom-SelfSigned")
        print_info "Retrieving custom CA bundle from certificate secret..."
        SECRET_NAME=$(oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[0].servingCertificate.name}' 2>/dev/null || echo "")
        if [ -n "$SECRET_NAME" ]; then
            echo -e "${BLUE}Command: oc get secret ${SECRET_NAME} -n openshift-config -o jsonpath='{.data.tls\.crt}' | base64 -d > \"${WORKDIR}/custom-ca-bundle.crt\"${NC}\n"
            oc get secret "$SECRET_NAME" -n openshift-config -o jsonpath='{.data.tls\.crt}' | base64 -d > "${WORKDIR}/custom-ca-bundle.crt"
            CA_BUNDLE="${WORKDIR}/custom-ca-bundle.crt"
            CERT_COUNT=$(grep -c "BEGIN CERTIFICATE" "${CA_BUNDLE}")
            print_success "Custom CA bundle retrieved from secret: $SECRET_NAME ($CERT_COUNT certificates)"
        else
            print_error "Unable to retrieve certificate secret name"
            exit 1
        fi
        ;;
esac

# Step 5: Verify Certificate
print_header "Step 5: Verify Certificate"

if [ "$CA_BUNDLE" = "system" ]; then
    # Use system trust store with intermediate CA
    print_info "Verifying certificate with system trust store..."

    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        VERIFY_CMD="openssl verify -untrusted \"${WORKDIR}/intermediate-ca.pem\" \"${WORKDIR}/kube-apiserver-serving-cert.pem\""
        echo -e "${BLUE}Command: ${VERIFY_CMD}${NC}\n"
        VERIFY_RESULT=$(openssl verify -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/kube-apiserver-serving-cert.pem" 2>&1)
    elif [ -f /etc/pki/tls/certs/ca-bundle.crt ]; then
        # RHEL/Fedora/CentOS
        VERIFY_CMD="openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt -untrusted \"${WORKDIR}/intermediate-ca.pem\" \"${WORKDIR}/kube-apiserver-serving-cert.pem\""
        echo -e "${BLUE}Command: ${VERIFY_CMD}${NC}\n"
        VERIFY_RESULT=$(openssl verify -CAfile /etc/pki/tls/certs/ca-bundle.crt -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/kube-apiserver-serving-cert.pem" 2>&1)
    elif [ -d /etc/ssl/certs ]; then
        # Debian/Ubuntu
        VERIFY_CMD="openssl verify -CApath /etc/ssl/certs -untrusted \"${WORKDIR}/intermediate-ca.pem\" \"${WORKDIR}/kube-apiserver-serving-cert.pem\""
        echo -e "${BLUE}Command: ${VERIFY_CMD}${NC}\n"
        VERIFY_RESULT=$(openssl verify -CApath /etc/ssl/certs -untrusted "${WORKDIR}/intermediate-ca.pem" "${WORKDIR}/kube-apiserver-serving-cert.pem" 2>&1)
    else
        print_error "Unable to locate system trust store"
        exit 1
    fi
else
    # Use specific CA bundle
    print_info "Verifying certificate with CA bundle..."
    VERIFY_CMD="openssl verify -CAfile \"${CA_BUNDLE}\" \"${WORKDIR}/kube-apiserver-serving-cert.pem\""
    echo -e "${BLUE}Command: ${VERIFY_CMD}${NC}\n"
    VERIFY_RESULT=$(openssl verify -CAfile "${CA_BUNDLE}" "${WORKDIR}/kube-apiserver-serving-cert.pem" 2>&1)
fi

if echo "$VERIFY_RESULT" | grep -q "OK"; then
    print_success "Certificate verification successful!"
    echo "$VERIFY_RESULT"
else
    print_error "Certificate verification failed!"
    echo "$VERIFY_RESULT"
    exit 1
fi

# Step 6: Display Certificate Chain
print_header "Step 6: Display Certificate Chain and Trust Path"

echo -e "${YELLOW}=== Certificate Chain (Trust Path) ===${NC}\n"

# Build the chain step by step
CHAIN_NUM=1
FOUND_ROOT=false

# 1. Show leaf certificate (server)
echo "${CHAIN_NUM}. Leaf Certificate (Server):"
openssl x509 -in "${WORKDIR}/kube-apiserver-serving-cert.pem" -noout -subject -issuer
CHAIN_NUM=$((CHAIN_NUM + 1))

# 2. Show intermediate CA(s) and check if any is the root CA
if [ -s "${WORKDIR}/intermediate-ca.pem" ]; then
    # Count total certificates in the chain
    TOTAL_CERTS=$(grep -c "BEGIN CERTIFICATE" "${WORKDIR}/intermediate-ca.pem" 2>/dev/null || echo 0)

    # First pass: count actual intermediate CAs (non-root)
    ACTUAL_INTERMEDIATE_COUNT=0
    for i in $(seq 1 $TOTAL_CERTS); do
        CERT_INFO=$(awk "/BEGIN CERTIFICATE/ { n++ } n == $i" "${WORKDIR}/intermediate-ca.pem" | openssl x509 -noout -subject -issuer 2>/dev/null)
        CERT_SUBJECT=$(echo "$CERT_INFO" | grep "subject" | sed 's/subject=//')
        CERT_ISSUER=$(echo "$CERT_INFO" | grep "issuer" | sed 's/issuer=//')

        if [ "$CERT_SUBJECT" != "$CERT_ISSUER" ]; then
            ACTUAL_INTERMEDIATE_COUNT=$((ACTUAL_INTERMEDIATE_COUNT + 1))
        fi
    done

    # Second pass: display certificates with proper labels
    INTERMEDIATE_NUM=1
    for i in $(seq 1 $TOTAL_CERTS); do
        CERT_INFO=$(awk "/BEGIN CERTIFICATE/ { n++ } n == $i" "${WORKDIR}/intermediate-ca.pem" | openssl x509 -noout -subject -issuer 2>/dev/null)
        CERT_SUBJECT=$(echo "$CERT_INFO" | grep "subject" | sed 's/subject=//')
        CERT_ISSUER=$(echo "$CERT_INFO" | grep "issuer" | sed 's/issuer=//')

        # Check if this certificate is self-signed (Root CA)
        if [ "$CERT_SUBJECT" = "$CERT_ISSUER" ]; then
            echo -e "\n${CHAIN_NUM}. Root CA (Self-Signed):"
            echo "$CERT_INFO"
            FOUND_ROOT=true
        else
            # It's an intermediate CA
            if [ "$ACTUAL_INTERMEDIATE_COUNT" -eq 1 ]; then
                echo -e "\n${CHAIN_NUM}. Intermediate CA:"
            else
                echo -e "\n${CHAIN_NUM}. Intermediate CA ${INTERMEDIATE_NUM}:"
                INTERMEDIATE_NUM=$((INTERMEDIATE_NUM + 1))
            fi
            echo "$CERT_INFO"
        fi
        CHAIN_NUM=$((CHAIN_NUM + 1))
    done
fi

# 3. If we haven't found the root CA yet, look in the CA bundle or system trust store
if [ "$FOUND_ROOT" = "false" ]; then
    if [ "$CA_BUNDLE" != "system" ] && [ -f "$CA_BUNDLE" ]; then
        echo -e "\n${YELLOW}=== Searching for Root CA in CA Bundle ===${NC}"

        # For Type 3b (custom self-signed), the CA bundle contains the full chain
        if [ "$CERT_TYPE" = "Type3b-Custom-SelfSigned" ]; then
            CA_COUNT=$(grep -c "BEGIN CERTIFICATE" "${CA_BUNDLE}")
            print_info "CA bundle contains $CA_COUNT certificate(s)"

            # Find the root CA (where subject == issuer)
            for i in $(seq 1 $CA_COUNT); do
                CERT_INFO=$(awk "/BEGIN CERTIFICATE/ { n++ } n == $i" "${CA_BUNDLE}" | openssl x509 -noout -subject -issuer 2>/dev/null)
                CERT_SUBJECT=$(echo "$CERT_INFO" | grep "subject" | sed 's/subject=//')
                CERT_ISSUER=$(echo "$CERT_INFO" | grep "issuer" | sed 's/issuer=//')

                if [ "$CERT_SUBJECT" = "$CERT_ISSUER" ]; then
                    echo -e "\n${CHAIN_NUM}. Root CA (Self-Signed):"
                    echo "$CERT_INFO"
                    print_success "Found self-signed root CA in CA bundle"
                    FOUND_ROOT=true
                    break
                fi
            done
        else
            # For Type 1 (OpenShift-managed), check the first cert
            ROOT_CA_INFO=$(awk '/BEGIN CERTIFICATE/ { n++ } n == 1' "${CA_BUNDLE}" | openssl x509 -noout -subject -issuer 2>/dev/null)
            ROOT_SUBJECT=$(echo "$ROOT_CA_INFO" | grep "subject" | sed 's/subject=//')
            ROOT_ISSUER=$(echo "$ROOT_CA_INFO" | grep "issuer" | sed 's/issuer=//')

            if [ "$ROOT_SUBJECT" = "$ROOT_ISSUER" ]; then
                echo -e "\n${CHAIN_NUM}. Root CA (Self-Signed):"
                echo "$ROOT_CA_INFO"
                print_success "Found self-signed root CA in CA bundle"
                FOUND_ROOT=true
            fi
        fi
    else
        # For system trust store (Type 2 and Type 3a), extract root CA info from intermediate issuer
        if [ -s "${WORKDIR}/intermediate-ca.pem" ]; then
            # Get the last certificate in the intermediate chain (closest to root)
            TOTAL_CERTS=$(grep -c "BEGIN CERTIFICATE" "${WORKDIR}/intermediate-ca.pem" 2>/dev/null || echo 0)
            if [ "$TOTAL_CERTS" -gt 0 ]; then
                LAST_CERT_INFO=$(awk "/BEGIN CERTIFICATE/ { n++ } n == $TOTAL_CERTS" "${WORKDIR}/intermediate-ca.pem" | openssl x509 -noout -issuer 2>/dev/null)
                ROOT_CA_NAME=$(echo "$LAST_CERT_INFO" | sed 's/issuer=//')

                echo -e "\n${CHAIN_NUM}. Root CA (System Trust Store):"
                echo "subject=${ROOT_CA_NAME}"
                echo "issuer=${ROOT_CA_NAME}"
                print_info "Root CA is trusted via system trust store"
                FOUND_ROOT=true
            fi
        fi
    fi
fi

if [ "$FOUND_ROOT" = "true" ]; then
    print_success "Complete certificate chain verified"
fi

# Step 7: Test Connectivity
print_header "Step 7: Test Connectivity"

print_info "Testing API server connectivity..."

# Remove proxy settings if they might interfere
CURL_BASE="env -u https_proxy -u http_proxy -u HTTPS_PROXY -u HTTP_PROXY curl -s"

if [ "$CA_BUNDLE" = "system" ]; then
    # Test without specifying CA (uses system trust store)
    CURL_CMD="${CURL_BASE} https://${API_HOSTNAME}:${API_PORT}/version"
    echo -e "${BLUE}Command: curl -s https://${API_HOSTNAME}:${API_PORT}/version${NC}\n"
    CONNECTIVITY_RESULT=$($CURL_BASE "https://${API_HOSTNAME}:${API_PORT}/version" 2>&1)
else
    # Test with specific CA bundle
    CURL_CMD="${CURL_BASE} --cacert \"${CA_BUNDLE}\" https://${API_HOSTNAME}:${API_PORT}/version"
    echo -e "${BLUE}Command: curl -s --cacert \"${CA_BUNDLE}\" https://${API_HOSTNAME}:${API_PORT}/version${NC}\n"
    CONNECTIVITY_RESULT=$($CURL_BASE --cacert "${CA_BUNDLE}" "https://${API_HOSTNAME}:${API_PORT}/version" 2>&1)
fi

if echo "$CONNECTIVITY_RESULT" | grep -q "major"; then
    print_success "Connectivity test successful!"
    echo "$CONNECTIVITY_RESULT" | jq . 2>/dev/null || echo "$CONNECTIVITY_RESULT"
else
    print_error "Connectivity test failed!"
    echo "$CONNECTIVITY_RESULT"
fi

# Summary
print_header "Summary"

echo -e "${GREEN}✓ All workflow steps completed!${NC}\n"

echo "Certificate Type: $(echo $CERT_TYPE | sed 's/-/ - /g')"
echo "Working Directory: ${WORKDIR}"
echo ""
echo "Files created:"
echo "  - ${WORKDIR}/kube-apiserver-serving-cert.pem (server certificate)"
echo "  - ${WORKDIR}/intermediate-ca.pem (intermediate CA, if present)"
if [ "$CA_BUNDLE" != "system" ]; then
    echo "  - ${CA_BUNDLE} (CA bundle)"
fi
echo "  - ${WORKDIR}/fullchain.pem (full certificate chain)"
echo "  - ${WORKDIR}/openssl_output.txt (raw openssl output)"

print_success "Certificate analysis complete!"
