#!/bin/bash

# ACM Installation Status Detection
# Usage: ./check-acm.sh [--kubeconfig <path>]
#        If --kubeconfig is not specified, uses KUBECONFIG environment variable

# Source common functions
SCRIPT_DIR=`dirname "$0"`
source "$SCRIPT_DIR/common.sh"

# Parse named arguments
KUBECONFIG_PATH=""

while [ $# -gt 0 ]; do
    case "$1" in
        --kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        *)
            print_error "Unknown argument: $1"
            echo ""
            echo "Usage: $0 [--kubeconfig <path>]"
            exit 1
            ;;
    esac
done

# Determine kubeconfig path
if [ -z "$KUBECONFIG_PATH" ]; then
    # Try to get from KUBECONFIG environment variable
    if [ -n "$KUBECONFIG" ]; then
        KUBECONFIG_PATH="$KUBECONFIG"
        print_info "Using kubeconfig from KUBECONFIG environment variable: $KUBECONFIG_PATH"
    else
        print_error "No kubeconfig specified"
        echo ""
        echo "Please provide kubeconfig in one of the following ways:"
        echo "  1. Use --kubeconfig parameter: $0 --kubeconfig <path>"
        echo "  2. Set KUBECONFIG environment variable: export KUBECONFIG=<path>"
        exit 1
    fi
fi

# Validate kubeconfig
if ! validate_kubeconfig "$KUBECONFIG_PATH"; then
    exit 1
fi

# Export kubeconfig for all subsequent commands
export KUBECONFIG="$KUBECONFIG_PATH"

# Variables to track status
MCH_FOUND=false
MCH_STATUS=""
MCH_NAMESPACE=""
MCH_NAME=""
MCH_VERSION=""
OPERATOR_FOUND=false

# Check for MultiClusterHub resources
MCH_OUTPUT=`oc get multiclusterhub -A 2>&1`
MCH_EXIT_CODE=$?

if echo "$MCH_OUTPUT" | grep -q "No resources found"; then
    MCH_FOUND=false
elif echo "$MCH_OUTPUT" | grep -q "doesn't have a resource type"; then
    # Resource type doesn't exist - ACM is not installed
    MCH_FOUND=false
elif [ $MCH_EXIT_CODE -eq 0 ] && echo "$MCH_OUTPUT" | grep -qv "^NAMESPACE"; then
    MCH_FOUND=true
    MCH_NAMESPACE=`echo "$MCH_OUTPUT" | grep -v "^NAMESPACE" | awk '{print $1}' | head -n 1`
    MCH_NAME=`echo "$MCH_OUTPUT" | grep -v "^NAMESPACE" | awk '{print $2}' | head -n 1`
    MCH_STATUS=`echo "$MCH_OUTPUT" | grep -v "^NAMESPACE" | awk '{print $3}' | head -n 1`

    # Get ACM version
    MCH_VERSION=`oc get multiclusterhub -A -o jsonpath='{.items[0].status.currentVersion}' 2>/dev/null`
    if [ -z "$MCH_VERSION" ]; then
        MCH_VERSION="Unknown"
    fi
else
    print_error "Failed to check for MultiClusterHub resources"
    echo "$MCH_OUTPUT"
    exit 1
fi

# Check for ACM Operator (only if no MultiClusterHub found)
if [ "$MCH_FOUND" = false ]; then
    OPERATOR_OUTPUT=`oc get pods -n open-cluster-management -l app=multiclusterhub-operator 2>&1`
    OPERATOR_EXIT_CODE=$?

    if echo "$OPERATOR_OUTPUT" | grep -q "No resources found"; then
        OPERATOR_FOUND=false
    elif [ $OPERATOR_EXIT_CODE -eq 0 ] && echo "$OPERATOR_OUTPUT" | grep -qv "^NAME"; then
        OPERATOR_FOUND=true
    else
        if echo "$OPERATOR_OUTPUT" | grep -q "NotFound"; then
            OPERATOR_FOUND=false
        fi
    fi
fi

# Get ServerVerificationStrategy if ACM is installed
SERVER_VERIFICATION_STRATEGY=""
if [ "$MCH_FOUND" = true ]; then
    # Check if global KlusterletConfig exists
    KLUSTERLET_CONFIG_OUTPUT=`oc get klusterletconfig global 2>&1`
    if [ $? -eq 0 ]; then
        # Extract serverVerificationStrategy from the resource
        SERVER_VERIFICATION_STRATEGY=`oc get klusterletconfig global -o jsonpath='{.spec.hubKubeAPIServerConfig.serverVerificationStrategy}' 2>/dev/null`
    fi

    # If not found or empty, use default value
    if [ -z "$SERVER_VERIFICATION_STRATEGY" ]; then
        SERVER_VERIFICATION_STRATEGY="UseAutoDetectedCABundle"
    fi
fi

# Output results
if [ "$MCH_FOUND" = true ]; then
    print_success "ACM Status: INSTALLED"
    echo "  Version:   $MCH_VERSION"
    echo "  Namespace: $MCH_NAMESPACE"
    echo "  Name:      $MCH_NAME"
    echo "  Status:    $MCH_STATUS"
    echo "  ServerVerificationStrategy: $SERVER_VERIFICATION_STRATEGY"
elif [ "$OPERATOR_FOUND" = true ]; then
    print_info "ACM Status: OPERATOR ONLY"
else
    print_success "ACM Status: NOT INSTALLED"
fi
echo ""
