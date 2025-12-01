#!/bin/bash

# Simple script to dump all audit logs from OpenShift control plane nodes

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default values
KUBECONFIG_PATH=""

usage() {
    cat << 'EOF'
Usage: ./dump-logs.sh [OPTIONS]

Dump OpenShift kube-apiserver audit logs from control plane nodes.

Options:
    --kubeconfig PATH    Path to kubeconfig file (optional, uses KUBECONFIG env var if not specified)
    -h, --help           Show this help

Examples:
    # Dump logs using default kubeconfig
    ./dump-logs.sh

    # Dump logs using custom kubeconfig
    ./dump-logs.sh --kubeconfig /path/to/kubeconfig

    # Dump logs using KUBECONFIG env var
    KUBECONFIG=/path/to/kubeconfig ./dump-logs.sh
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Set kubeconfig if --kubeconfig argument is provided
# Otherwise, use KUBECONFIG env var or oc default (~/.kube/config)
if [ -n "$KUBECONFIG_PATH" ]; then
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        log_error "Kubeconfig file not found: ${KUBECONFIG_PATH}"
        exit 1
    fi
    export KUBECONFIG="$KUBECONFIG_PATH"
    log_info "Using kubeconfig from --kubeconfig: ${KUBECONFIG_PATH}"
elif [ -n "$KUBECONFIG" ]; then
    log_info "Using kubeconfig from KUBECONFIG env var: ${KUBECONFIG}"
else
    log_info "Using default kubeconfig"
fi

# Check prerequisites
if ! command -v oc &>/dev/null; then
    log_error "OpenShift CLI (oc) not found. Please install it first."
    exit 1
fi

if ! oc whoami &>/dev/null; then
    log_error "Not logged into OpenShift cluster. Run 'oc login' first."
    exit 1
fi

# Create timestamped directory
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_DIR="audit-logs-${TIMESTAMP}"

log_info "Creating output directory: ${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Get cluster info
CLUSTER=$(oc whoami --show-server 2>/dev/null)
log_success "Connected to: ${CLUSTER}"

# Get master nodes
log_info "Finding control plane nodes..."
MASTER_NODES=$(oc get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[*].metadata.name}')

if [ -z "$MASTER_NODES" ]; then
    log_error "No master nodes found"
    exit 1
fi

NODE_COUNT=$(echo "$MASTER_NODES" | wc -w | tr -d ' ')
log_success "Found ${NODE_COUNT} control plane node(s)"
echo

# Dump logs from each node
TOTAL_FILES=0

for NODE in $MASTER_NODES; do
    log_info "Processing node: ${NODE}"

    NODE_DIR="${OUTPUT_DIR}/${NODE}"
    mkdir -p "${NODE_DIR}"

    # Get list of audit logs
    LOG_FILES=$(oc adm node-logs "$NODE" --path=kube-apiserver/ 2>/dev/null | grep -E '^audit-.*\.log$')

    if [ -z "$LOG_FILES" ]; then
        log_error "  No audit logs found"
        continue
    fi

    FILE_COUNT=$(echo "$LOG_FILES" | wc -l | tr -d ' ')
    log_info "  Found ${FILE_COUNT} log file(s)"

    # Download each log file
    DOWNLOADED=0
    while read -r LOGFILE; do
        log_info "    Downloading: ${LOGFILE}"

        if oc adm node-logs "$NODE" --path="kube-apiserver/${LOGFILE}" > "${NODE_DIR}/${LOGFILE}" 2>/dev/null; then
            SIZE=$(du -h "${NODE_DIR}/${LOGFILE}" | cut -f1)
            log_success "    ✓ Downloaded (${SIZE})"
            DOWNLOADED=$((DOWNLOADED + 1))
        else
            log_error "    ✗ Failed"
            rm -f "${NODE_DIR}/${LOGFILE}"
        fi
    done <<< "$LOG_FILES"

    TOTAL_FILES=$((TOTAL_FILES + DOWNLOADED))
    echo
done

# Show summary
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/show-summary.sh" ]; then
    "${SCRIPT_DIR}/show-summary.sh" "${OUTPUT_DIR}"
else
    # Fallback if summary script not found
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Dump complete!"
    echo "  Total files: ${TOTAL_FILES}"
    echo "  Output directory: ${OUTPUT_DIR}/"
    TOTAL_SIZE=$(du -sh "${OUTPUT_DIR}" | cut -f1)
    echo "  Total size: ${TOTAL_SIZE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    log_info "You can now query these logs locally for much faster performance!"
fi
