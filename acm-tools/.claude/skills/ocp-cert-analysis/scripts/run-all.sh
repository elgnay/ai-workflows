#!/bin/bash

# Run All Steps - Complete Certificate Analysis
# Usage: ./run-all.sh [--kubeconfig <path>] [--output <directory>]
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

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     OCP Certificate Analysis - Complete Workflow              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Execute all steps in sequence
echo "Starting certificate analysis workflow..."
echo ""

# Step 1
echo "▶ Step 1/8: Setting up kubeconfig..."
if [ -n "$OUTPUT_DIR" ]; then
    bash "$SCRIPT_DIR/01-setup-kubeconfig.sh" --kubeconfig "$KUBECONFIG_PATH" --output "$OUTPUT_DIR"
else
    bash "$SCRIPT_DIR/01-setup-kubeconfig.sh" --kubeconfig "$KUBECONFIG_PATH"
fi
if [ $? -ne 0 ]; then
    print_error "Step 1 failed. Aborting."
    exit 1
fi
echo ""

# Step 2
echo "▶ Step 2/8: Getting API endpoint..."
bash "$SCRIPT_DIR/02-get-api-endpoint.sh"
if [ $? -ne 0 ]; then
    print_error "Step 2 failed. Aborting."
    exit 1
fi
echo ""

# Step 3
echo "▶ Step 3/8: Retrieving certificate chain..."
bash "$SCRIPT_DIR/03-retrieve-cert-chain.sh"
if [ $? -ne 0 ]; then
    print_error "Step 3 failed. Aborting."
    exit 1
fi
echo ""

# Step 4
echo "▶ Step 4/8: Determining certificate type..."
bash "$SCRIPT_DIR/04-determine-cert-type.sh"
if [ $? -ne 0 ]; then
    print_error "Step 4 failed. Aborting."
    exit 1
fi
echo ""

# Step 5
echo "▶ Step 5/8: Retrieving CA bundle..."
bash "$SCRIPT_DIR/05-get-ca-bundle.sh"
if [ $? -ne 0 ]; then
    print_error "Step 5 failed. Aborting."
    exit 1
fi
echo ""

# Step 6
echo "▶ Step 6/8: Verifying certificate..."
bash "$SCRIPT_DIR/06-verify-cert.sh"
if [ $? -ne 0 ]; then
    print_error "Step 6 failed. Aborting."
    exit 1
fi
echo ""

# Step 7
echo "▶ Step 7/8: Displaying certificate chain..."
bash "$SCRIPT_DIR/07-display-cert-chain.sh"
if [ $? -ne 0 ]; then
    print_error "Step 7 failed. Aborting."
    exit 1
fi
echo ""

# Step 8
echo "▶ Step 8/8: Testing connectivity..."
bash "$SCRIPT_DIR/08-test-connectivity.sh"
if [ $? -ne 0 ]; then
    print_error "Step 8 failed. Aborting."
    exit 1
fi
echo ""

# Display summary
echo "═══════════════════════════════════════════════════════════════"
echo ""
bash "$SCRIPT_DIR/99-summary.sh"
