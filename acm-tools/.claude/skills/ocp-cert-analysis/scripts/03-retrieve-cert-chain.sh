#!/bin/bash

# Step 3: Retrieve Certificate Chain
# Usage: ./03-retrieve-cert-chain.sh

# Source common functions
SCRIPT_DIR=`dirname "$0"`
source "$SCRIPT_DIR/common.sh"

# Load dependencies
load_workdir
load_kubeconfig
load_api_endpoint

echo "=== Step 3: Retrieve Certificate Chain ==="
echo ""

# Extract API hostname and port from saved endpoint
API_HOSTNAME=`echo "$API_ENDPOINT" | sed 's|https://||' | sed 's|:.*||'`
API_PORT=`echo "$API_ENDPOINT" | sed 's|.*:||'`

echo "API Hostname: $API_HOSTNAME"
echo "API Port: $API_PORT"
echo ""

# Retrieve certificate chain
echo "Retrieving certificate chain from API server..."
echo "Connecting to ${API_HOSTNAME}:${API_PORT}..."

# Retrieve certificate chain (openssl has built-in connection timeout)
echo | openssl s_client -connect ${API_HOSTNAME}:${API_PORT} -showcerts 2>/dev/null > "${WORKDIR}/openssl_output.txt"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    print_success "Certificate chain retrieved"
else
    print_error "Failed to retrieve certificate chain"
    echo ""
    echo "Possible reasons:"
    echo "  1. API server is not reachable"
    echo "  2. Network connectivity issues"
    echo "  3. Incorrect hostname or port"
    exit 1
fi

# Extract full chain
sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "${WORKDIR}/openssl_output.txt" > "${WORKDIR}/fullchain.pem"
print_success "Full chain extracted"

# Separate serving certificate and intermediate CAs
awk '/BEGIN CERTIFICATE/ {n++} n==1' "${WORKDIR}/fullchain.pem" > "${WORKDIR}/serving-cert.pem"
awk '/BEGIN CERTIFICATE/ {n++} n>=2' "${WORKDIR}/fullchain.pem" > "${WORKDIR}/intermediate-ca.pem"
print_success "Certificates separated"
echo ""

# Display files created
echo "Files created in ${WORKDIR}/:"
ls -lh "${WORKDIR}/" | grep -v total
echo ""

# Display certificate details
echo "=== Serving Certificate Details ==="
echo ""
echo "Subject and Issuer:"
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -subject -issuer
echo ""
echo "Validity Period:"
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -dates
echo ""
echo "Subject Alternative Names:"
openssl x509 -in "${WORKDIR}/serving-cert.pem" -noout -ext subjectAltName
echo ""

print_success "Certificate retrieval complete. Ready to proceed to Step 4."
