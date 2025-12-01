#!/bin/bash

# Show summary of downloaded audit logs

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get directory from argument or auto-detect
LOG_DIR="$1"

if [ -z "$LOG_DIR" ]; then
    # Auto-detect most recent audit-logs-* directory
    LOG_DIR=$(find . -maxdepth 1 -type d -name "audit-logs-*" | sort -r | head -1)

    if [ -z "$LOG_DIR" ]; then
        log_error "No audit logs directory found"
        echo "Usage: $0 [audit-logs-directory]"
        exit 1
    fi

    log_info "Auto-detected: ${LOG_DIR}"
fi

if [ ! -d "$LOG_DIR" ]; then
    log_error "Directory not found: ${LOG_DIR}"
    exit 1
fi

echo
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Audit Logs Summary                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo

# Count files and nodes
TOTAL_FILES=$(find "$LOG_DIR" -name "audit-*.log" -type f 2>/dev/null | wc -l | tr -d ' ')
NODE_COUNT=$(find "$LOG_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

# Get total size
TOTAL_SIZE=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)

# Get time window from log filenames
ALL_LOGS=$(find "$LOG_DIR" -name "audit-*.log" -type f 2>/dev/null | sort)

if [ -n "$ALL_LOGS" ]; then
    # Get earliest and latest log files
    EARLIEST_LOG_FILE=$(echo "$ALL_LOGS" | head -1)
    LATEST_LOG_FILE=$(echo "$ALL_LOGS" | tail -1)

    # Check if jq is available for accurate timestamp extraction
    if command -v jq &>/dev/null; then
        # Get actual event timestamps from log content
        EARLIEST_TIME=$(head -1 "$EARLIEST_LOG_FILE" 2>/dev/null | jq -r '.requestReceivedTimestamp // empty' 2>/dev/null | sed 's/\.[0-9]*Z$//' | tr 'T' ' ')
        LATEST_TIME=$(tail -1 "$LATEST_LOG_FILE" 2>/dev/null | jq -r '.requestReceivedTimestamp // empty' 2>/dev/null | sed 's/\.[0-9]*Z$//' | tr 'T' ' ')
    fi

    # Fallback to filename-based timestamps if jq failed or not available
    if [ -z "$EARLIEST_TIME" ] || [ -z "$LATEST_TIME" ]; then
        EARLIEST_LOG=$(basename "$EARLIEST_LOG_FILE")
        LATEST_LOG=$(basename "$LATEST_LOG_FILE")
        EARLIEST_TIME=$(echo "$EARLIEST_LOG" | sed 's/audit-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)T\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)\..*/\1 \2:\3:\4/')
        LATEST_TIME=$(echo "$LATEST_LOG" | sed 's/audit-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)T\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)\..*/\1 \2:\3:\4/')
        TIME_NOTE=" (from filenames)"
    else
        TIME_NOTE=" (actual events)"
    fi

    echo "📊 Summary:"
    echo "   ├─ Output Path:    $(cd "$LOG_DIR" && pwd)"
    echo "   ├─ Total Files:    ${TOTAL_FILES}"
    echo "   ├─ Total Size:     ${TOTAL_SIZE}"
    echo "   ├─ Nodes:          ${NODE_COUNT}"
    echo "   └─ Time Window${TIME_NOTE}:"
    echo "      ├─ Earliest:    ${EARLIEST_TIME}"
    echo "      └─ Latest:      ${LATEST_TIME}"
else
    echo "📊 Summary:"
    echo "   ├─ Output Path:    $(cd "$LOG_DIR" && pwd)"
    echo "   ├─ Total Files:    ${TOTAL_FILES}"
    echo "   ├─ Total Size:     ${TOTAL_SIZE}"
    echo "   └─ Nodes:          ${NODE_COUNT}"
fi

echo

# Show breakdown by node
if [ "$NODE_COUNT" -gt 0 ]; then
    echo "📦 Per-Node Breakdown:"
    for node_dir in "$LOG_DIR"/*; do
        if [ -d "$node_dir" ]; then
            NODE_NAME=$(basename "$node_dir")
            NODE_FILES=$(find "$node_dir" -name "audit-*.log" -type f 2>/dev/null | wc -l | tr -d ' ')
            NODE_SIZE=$(du -sh "$node_dir" 2>/dev/null | cut -f1)

            echo "   • ${NODE_NAME}"
            echo "     ├─ Files: ${NODE_FILES}"
            echo "     ├─ Size:  ${NODE_SIZE}"

            # Get time window for this node
            NODE_LOGS=$(find "$node_dir" -name "audit-*.log" -type f 2>/dev/null | sort)
            if [ -n "$NODE_LOGS" ]; then
                EARLIEST_NODE_FILE=$(echo "$NODE_LOGS" | head -1)
                LATEST_NODE_FILE=$(echo "$NODE_LOGS" | tail -1)

                # Try to get timestamps from log content using jq
                if command -v jq &>/dev/null; then
                    EARLIEST_NODE_TIME=$(head -1 "$EARLIEST_NODE_FILE" 2>/dev/null | jq -r '.requestReceivedTimestamp // empty' 2>/dev/null | sed 's/\.[0-9]*Z$//' | tr 'T' ' ')
                    LATEST_NODE_TIME=$(tail -1 "$LATEST_NODE_FILE" 2>/dev/null | jq -r '.requestReceivedTimestamp // empty' 2>/dev/null | sed 's/\.[0-9]*Z$//' | tr 'T' ' ')
                fi

                # Fallback to filename-based timestamps
                if [ -z "$EARLIEST_NODE_TIME" ] || [ -z "$LATEST_NODE_TIME" ]; then
                    EARLIEST_NODE_LOG=$(basename "$EARLIEST_NODE_FILE")
                    LATEST_NODE_LOG=$(basename "$LATEST_NODE_FILE")
                    EARLIEST_NODE_TIME=$(echo "$EARLIEST_NODE_LOG" | sed 's/audit-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)T\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)\..*/\1 \2:\3:\4/')
                    LATEST_NODE_TIME=$(echo "$LATEST_NODE_LOG" | sed 's/audit-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)T\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)\..*/\1 \2:\3:\4/')
                fi

                echo "     └─ Time Window:"
                echo "        ├─ Earliest: ${EARLIEST_NODE_TIME}"
                echo "        └─ Latest:   ${LATEST_NODE_TIME}"
            else
                echo "     └─ Time Window: No logs found"
            fi
        fi
    done
    echo
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
log_success "Ready for querying!"
echo
log_info "Query examples:"
echo "  ./query-logs.sh -d ${LOG_DIR} --verbs delete --resources pods"
echo "  ./query-logs.sh -d ${LOG_DIR} --resources secrets --users system:admin"
echo
