#!/bin/bash

# Step 1: Set Up Kubeconfig and Create Working Directory
# Usage: ./01-setup-kubeconfig.sh [--kubeconfig <path>] [--output <directory>]
#        If --kubeconfig is not specified, uses KUBECONFIG environment variable
#        If --output is not specified, uses the current working directory (PWD)

# Source common functions
SCRIPT_DIR=`dirname "$0"`
source "$SCRIPT_DIR/common.sh"

# Parse named arguments
KUBECONFIG_PATH=""
OUTPUT_DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            print_error "Unknown argument: $1"
            echo ""
            echo "Usage: $0 [--kubeconfig <path>] [--output <directory>]"
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

# Check if kubeconfig file exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    print_error "Kubeconfig file not found: $KUBECONFIG_PATH"
    exit 1
fi

# Convert kubeconfig path to absolute path
KUBECONFIG_PATH=`cd "\`dirname \"$KUBECONFIG_PATH\"\`" && pwd`/`basename "$KUBECONFIG_PATH"`

# Determine output directory
if [ -z "$OUTPUT_DIR" ]; then
    # Default to the current working directory where the command was invoked
    OUTPUT_DIR=`pwd`
    print_info "Output directory not specified, using current directory: $OUTPUT_DIR"
else
    # Convert to absolute path if relative
    if [ -d "$OUTPUT_DIR" ]; then
        OUTPUT_DIR=`cd "$OUTPUT_DIR" && pwd`
    fi
    print_info "Using specified output directory: $OUTPUT_DIR"
fi

echo ""
echo "=== Step 1: Set Up Kubeconfig and Create Working Directory ==="
echo ""

# Create working directory with timestamp in the output directory
TIMESTAMP=`date +%Y%m%d-%H%M%S`
WORKDIR="${OUTPUT_DIR}/run-${TIMESTAMP}"
mkdir -p "$WORKDIR"

print_success "Working directory created: $WORKDIR"

# Save working directory path to .current_workdir (in skill directory for persistence)
echo "$WORKDIR" > "$WORKDIR_FILE_PATH"
print_success "Working directory path saved to $WORKDIR_FILE_PATH"

# Save kubeconfig path to working directory
echo "$KUBECONFIG_PATH" > "${WORKDIR}/.kubeconfig_path"
print_success "Kubeconfig path saved: $KUBECONFIG_PATH"

# Verify connection
export KUBECONFIG="$KUBECONFIG_PATH"
echo ""
echo "Verifying connection to cluster..."
echo "(This may take up to 30 seconds if cluster is slow to respond)"

USER_IDENTITY=`oc whoami 2>&1`
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    print_success "Successfully connected as: $USER_IDENTITY"

    # Get OpenShift version to verify this is an OpenShift cluster
    OCP_VERSION=`oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>&1`
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ] && [ -n "$OCP_VERSION" ]; then
        echo "OpenShift Version: $OCP_VERSION"

        # Save version to state file in working directory for reuse
        echo "$OCP_VERSION" > "${WORKDIR}/.ocp_version"

        echo ""
        echo "Connection verified. Ready to proceed to Step 2."
    else
        echo ""
        print_error "This does not appear to be an OpenShift cluster"
        echo ""
        echo "Error details:"
        echo "$OCP_VERSION"
        echo ""
        echo "This tool is designed specifically for OpenShift clusters and requires:"
        echo "  - OpenShift-specific resources (clusterversion, infrastructure, apiserver)"
        echo "  - OpenShift ConfigMaps and Secrets structure"
        echo ""
        echo "If this is a standard Kubernetes cluster, this tool will not work."
        exit 1
    fi
else
    print_error "Failed to connect with kubeconfig: $KUBECONFIG_PATH"
    echo ""
    echo "Error details:"
    echo "$USER_IDENTITY"
    echo ""

    # Check if it's a timeout error
    if echo "$USER_IDENTITY" | grep -qi "timeout\|timed out"; then
        print_error "Connection timed out - cluster may be unavailable or unreachable"
        echo ""
        echo "Troubleshooting suggestions:"
        echo "  1. Check if the cluster is running and accessible"
        echo "  2. Verify network connectivity to the API server"
        echo "  3. Check VPN connection if required"
        echo "  4. Verify kubeconfig has correct API server URL"
        echo ""
        echo "To check the API server URL in kubeconfig:"
        echo "  grep 'server:' $KUBECONFIG_PATH"
    elif echo "$USER_IDENTITY" | grep -qi "unauthorized\|forbidden"; then
        print_error "Authentication failed - invalid credentials"
        echo ""
        echo "Troubleshooting suggestions:"
        echo "  1. Check if the kubeconfig token/certificate is valid"
        echo "  2. Verify user has proper permissions"
        echo "  3. Token may have expired - re-authenticate if needed"
    elif echo "$USER_IDENTITY" | grep -qi "certificate\|x509"; then
        print_error "Certificate validation failed"
        echo ""
        echo "Troubleshooting suggestions:"
        echo "  1. Cluster certificate may have changed"
        echo "  2. Try with --insecure-skip-tls-verify flag if testing"
    else
        print_error "Unknown connection error"
    fi

    exit 1
fi
