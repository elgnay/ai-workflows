#!/bin/bash

# Step 2: Get External API Server Endpoint
# Usage: ./02-get-api-endpoint.sh

# Source common functions
SCRIPT_DIR=`dirname "$0"`
source "$SCRIPT_DIR/common.sh"

# Load dependencies
load_workdir
load_kubeconfig

echo "Retrieving external API server endpoint..."

# Get API endpoint
API_ENDPOINT=`oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}' 2>&1`
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    # Save API endpoint to working directory for reuse
    echo "$API_ENDPOINT" > "${WORKDIR}/.api_endpoint"

    print_success "API Server Endpoint: $API_ENDPOINT"
    print_info "API endpoint saved for reuse in subsequent steps"
    echo ""
    echo "Ready to proceed to Step 3."
else
    print_error "Failed to retrieve API endpoint"
    echo ""
    echo "Error details:"
    echo "$API_ENDPOINT"
    echo ""

    if echo "$API_ENDPOINT" | grep -qi "timeout\|timed out"; then
        print_error "Connection timed out - cluster is unavailable"
        echo "The cluster must be accessible to retrieve the API endpoint."
    elif echo "$API_ENDPOINT" | grep -qi "unauthorized\|forbidden"; then
        print_error "Authentication failed - insufficient permissions"
    fi

    exit 1
fi
