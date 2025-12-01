#!/bin/bash

# Query local audit logs with powerful filtering and formatting

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Default values
VERBS=""
RESOURCES=""
RESOURCE_NAMES=""
NAMESPACES=""
USERS=""
START_TIME=""
END_TIME=""
STATUS_CODES=""
OUTPUT_FORMAT="table"
MAX_RESULTS=50
LOGS_DIR=""
KUBECONFIG_PATH=""

usage() {
    cat << 'EOF'
Usage: ./query-logs.sh [OPTIONS]

Query and filter OpenShift audit logs - online (from cluster) or offline (from local files).

Query Modes:
    Offline mode: Specify -d to query locally downloaded logs (fast, requires download first)
    Online mode:  Omit -d to query cluster directly (slower, always current data)

Options:
    -d, --dir DIR               Directory with downloaded logs (offline mode, mutually exclusive with --kubeconfig)
    --kubeconfig PATH           Path to kubeconfig file (online mode, mutually exclusive with -d)
    -v, --verbs VERBS           Filter by verbs (e.g., delete, create,update)
    -r, --resources RESOURCES   Filter by resources (e.g., pods, secrets)
    --name NAMES                Filter by resource names (e.g., my-pod, my-secret)
    -n, --namespaces NS         Filter by namespaces
    -u, --users USERS           Filter by users
    -s, --start-time TIME       Start time (ISO format or relative: 1h, 30m, 2d)
    -e, --end-time TIME         End time (ISO format)
    -c, --status-codes CODES    Filter by status codes (e.g., 200, 404,500) [default: 200]
    -o, --output FORMAT         Output format: table, json, csv, detail (default: table)
    -m, --max-results NUM       Maximum results (default: 50)
    -h, --help                  Show this help

Output Formats:
    table   - Compact table view (default)
    detail  - Detailed human-readable format
    json    - Raw JSON output
    csv     - CSV format for spreadsheets

Examples:
    # Online mode - query cluster directly for delete operations on pods
    ./query-logs.sh --verbs delete --resources pods

    # Online mode - query specific cluster using custom kubeconfig
    ./query-logs.sh --kubeconfig /path/to/kubeconfig --verbs delete --resources pods

    # Online mode - find failed requests in last hour
    ./query-logs.sh --status-codes 403,404,500 --start-time 1h

    # Offline mode - query local files for delete operations
    ./query-logs.sh -d audit-logs-20251125-143022 --verbs delete --resources pods

    # Offline mode - find operations on a specific pod by name
    ./query-logs.sh -d audit-logs-20251125-143022 --name my-pod

    # Offline mode - export to CSV
    ./query-logs.sh -d audit-logs-20251125-143022 --verbs create,update --output csv > results.csv
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir) LOGS_DIR="$2"; shift 2 ;;
        --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
        -v|--verbs) VERBS="$2"; shift 2 ;;
        -r|--resources) RESOURCES="$2"; shift 2 ;;
        --name) RESOURCE_NAMES="$2"; shift 2 ;;
        -n|--namespaces) NAMESPACES="$2"; shift 2 ;;
        -u|--users) USERS="$2"; shift 2 ;;
        -s|--start-time) START_TIME="$2"; shift 2 ;;
        -e|--end-time) END_TIME="$2"; shift 2 ;;
        -c|--status-codes) STATUS_CODES="$2"; shift 2 ;;
        -o|--output) OUTPUT_FORMAT="$2"; shift 2 ;;
        -m|--max-results) MAX_RESULTS="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Check prerequisites
if ! command -v jq &>/dev/null; then
    log_error "jq is required but not installed"
    exit 1
fi

# Validate mutual exclusivity of -d and --kubeconfig
if [ -n "$LOGS_DIR" ] && [ -n "$KUBECONFIG_PATH" ]; then
    log_error "Cannot specify both -d (offline mode) and --kubeconfig (online mode) at the same time"
    usage
    exit 1
fi

# Determine query mode based on whether -d is specified
if [ -z "$LOGS_DIR" ]; then
    # Online mode
    QUERY_MODE="online"

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

    # Check for oc CLI in online mode
    if ! command -v oc &>/dev/null; then
        log_error "Online mode requires OpenShift CLI (oc). Install it or use offline mode with -d"
        exit 1
    fi
    if ! oc whoami &>/dev/null; then
        log_error "Not logged into OpenShift cluster. Run 'oc login' first or use offline mode with -d"
        exit 1
    fi
else
    # Offline mode
    QUERY_MODE="offline"
    if [ ! -d "$LOGS_DIR" ]; then
        log_error "Directory not found: ${LOGS_DIR}"
        exit 1
    fi
fi

# Build jq filter
build_jq_filter() {
    local filters=("select(. != null)")

    # Verb filter
    if [ -n "$VERBS" ]; then
        local verb_list=$(echo "$VERBS" | sed 's/,/", "/g')
        filters+=("select(.verb as \$v | [\"$verb_list\"] | any(. == \$v))")
    fi

    # Resource filter
    if [ -n "$RESOURCES" ]; then
        local resource_list=$(echo "$RESOURCES" | sed 's/,/", "/g')
        filters+=("select(.objectRef.resource as \$r | [\"$resource_list\"] | any(. == \$r))")
    fi

    # Resource name filter
    if [ -n "$RESOURCE_NAMES" ]; then
        local name_list=$(echo "$RESOURCE_NAMES" | sed 's/,/", "/g')
        filters+=("select(.objectRef.name as \$n | [\"$name_list\"] | any(. == \$n))")
    fi

    # Namespace filter
    if [ -n "$NAMESPACES" ]; then
        local ns_list=$(echo "$NAMESPACES" | sed 's/,/", "/g')
        filters+=("select(.objectRef.namespace as \$n | [\"$ns_list\"] | any(. == \$n))")
    fi

    # User filter
    if [ -n "$USERS" ]; then
        local user_list=$(echo "$USERS" | sed 's/,/", "/g')
        filters+=("select(.user.username as \$u | [\"$user_list\"] | any(. == \$u))")
    fi

    # Status code filter (default to 200 if not specified)
    if [ -n "$STATUS_CODES" ]; then
        local code_list=$(echo "$STATUS_CODES" | sed 's/,/, /g')
        filters+=("select(.responseStatus.code as \$c | [$code_list] | any(. == \$c))")
    else
        # Default: only show successful requests (200)
        filters+=("select(.responseStatus.code == 200)")
    fi

    # Time filter - start time
    if [ -n "$START_TIME" ]; then
        local start_epoch
        if [[ "$START_TIME" =~ ^([0-9]+)([mhd])$ ]]; then
            local value="${BASH_REMATCH[1]}"
            local unit="${BASH_REMATCH[2]}"
            local current_epoch=$(date +%s)
            case "$unit" in
                m) start_epoch=$((current_epoch - value * 60)) ;;
                h) start_epoch=$((current_epoch - value * 3600)) ;;
                d) start_epoch=$((current_epoch - value * 86400)) ;;
            esac
        else
            start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$START_TIME" +%s 2>/dev/null || date -d "$START_TIME" +%s 2>/dev/null)
        fi
        if [ -n "$start_epoch" ]; then
            filters+=("select(.requestReceivedTimestamp | fromdateiso8601 >= $start_epoch)")
        fi
    fi

    # Time filter - end time
    if [ -n "$END_TIME" ]; then
        local end_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$END_TIME" +%s 2>/dev/null || date -d "$END_TIME" +%s 2>/dev/null)
        if [ -n "$end_epoch" ]; then
            filters+=("select(.requestReceivedTimestamp | fromdateiso8601 <= $end_epoch)")
        fi
    fi

    # Combine filters
    local jq_filter=$(IFS='|'; echo "${filters[*]}")
    echo "$jq_filter"
}

# Table separator line (matches table width)
TABLE_SEPARATOR="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Format output
format_output() {
    local format="$1"

    case "$format" in
        table)
            # Header - check if node info is present
            local has_node=$(echo "$1" | head -1 | jq -r 'has("node")' 2>/dev/null)
            if [ "$has_node" = "true" ]; then
                printf "${CYAN}%-20s %-35s %-10s %-15s %-20s %-25s %-20s${NC}\n" \
                    "TIMESTAMP" "USER" "VERB" "RESOURCE" "NAMESPACE" "NAME" "NODE"
            else
                printf "${CYAN}%-20s %-40s %-10s %-15s %-25s %-30s %-35s${NC}\n" \
                    "TIMESTAMP" "USER" "VERB" "RESOURCE" "NAMESPACE" "NAME" "LOG FILE"
            fi
            echo "$TABLE_SEPARATOR"

            # Data
            if [ "$has_node" = "true" ]; then
                jq -r '[
                    .requestReceivedTimestamp[0:19],
                    (.user.username // "N/A"),
                    (.verb // "N/A")[0:10],
                    (.objectRef.resource // "N/A")[0:15],
                    (.objectRef.namespace // "N/A")[0:20],
                    (.objectRef.name // "N/A")[0:25],
                    (.node // "N/A")[0:20]
                ] | @tsv' | while IFS=$'\t' read -r ts user verb resource ns name node; do
                    # Abbreviate common user prefixes
                    user="${user//system:serviceaccount:/sa:}"
                    user="${user//system:node:/node:}"
                    user="${user//system:admin/sys:admin}"

                    # For service accounts, truncate long namespace names
                    if [[ "$user" =~ ^sa:([^:]+):(.+)$ ]]; then
                        local sa_ns="${BASH_REMATCH[1]}"
                        local sa_name="${BASH_REMATCH[2]}"

                        # Truncate namespace if longer than 12 chars
                        if [ ${#sa_ns} -gt 12 ]; then
                            sa_ns="${sa_ns:0:9}..."
                        fi

                        user="sa:${sa_ns}:${sa_name}"
                    fi

                    # Truncate to fit column
                    user="${user:0:35}"

                    printf "%-20s %-35s %-10s %-15s %-20s %-25s %-20s\n" \
                        "$ts" "$user" "$verb" "$resource" "$ns" "$name" "$node"
                done
            else
                jq -r '[
                    .requestReceivedTimestamp[0:19],
                    (.user.username // "N/A"),
                    (.verb // "N/A")[0:10],
                    (.objectRef.resource // "N/A")[0:15],
                    (.objectRef.namespace // "N/A")[0:25],
                    (.objectRef.name // "N/A")[0:30],
                    (.logfile // "N/A")
                ] | @tsv' | while IFS=$'\t' read -r ts user verb resource ns name logfile; do
                # Abbreviate common user prefixes
                user="${user//system:serviceaccount:/sa:}"
                user="${user//system:node:/node:}"
                user="${user//system:admin/sys:admin}"

                # For service accounts, truncate long namespace names
                if [[ "$user" =~ ^sa:([^:]+):(.+)$ ]]; then
                    local sa_ns="${BASH_REMATCH[1]}"
                    local sa_name="${BASH_REMATCH[2]}"

                    # Truncate namespace if longer than 15 chars
                    if [ ${#sa_ns} -gt 15 ]; then
                        sa_ns="${sa_ns:0:12}..."
                    fi

                    user="sa:${sa_ns}:${sa_name}"
                fi

                # Truncate to fit column
                user="${user:0:40}"

                # Truncate logfile to fit (remove .log extension and truncate)
                logfile="${logfile%.log}"
                logfile="${logfile:0:35}"

                printf "%-20s %-40s %-10s %-15s %-25s %-30s %-35s\n" \
                    "$ts" "$user" "$verb" "$resource" "$ns" "$name" "$logfile"
                done
            fi
            ;;

        detail)
            jq -r '"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
\(if .node then "Node:       \(.node)\n" else "" end)\
\(if .logfile then "Log File:   \(.logfile)\n" else "" end)\
Timestamp:  \(.requestReceivedTimestamp)
User:       \(.user.username // "N/A")
Verb:       \(.verb // "N/A")
Resource:   \(.objectRef.resource // "N/A")
Namespace:  \(.objectRef.namespace // "N/A")
Name:       \(.objectRef.name // "N/A")
Status:     \(.responseStatus.code // "N/A")
URI:        \(.requestURI // "N/A")
Source IP:  \(.sourceIPs[0] // "N/A")
User Agent: \(.userAgent // "N/A")
"'
            ;;

        json)
            jq -c '.'
            ;;

        csv)
            # Check if node info is present
            local has_node=$(echo "$1" | head -1 | jq -r 'has("node")' 2>/dev/null)

            # CSV header
            if [ "$has_node" = "true" ]; then
                echo "Timestamp,User,Verb,Resource,Namespace,Name,Status,URI,Node"
                # CSV data with node
                jq -r '[
                    .requestReceivedTimestamp,
                    .user.username // "N/A",
                    .verb // "N/A",
                    .objectRef.resource // "N/A",
                    .objectRef.namespace // "N/A",
                    .objectRef.name // "N/A",
                    (.responseStatus.code // 0),
                    .requestURI // "N/A",
                    .node // "N/A"
                ] | @csv'
            else
                echo "Timestamp,User,Verb,Resource,Namespace,Name,Status,URI,LogFile"
                # CSV data with logfile
                jq -r '[
                    .requestReceivedTimestamp,
                    .user.username // "N/A",
                    .verb // "N/A",
                    .objectRef.resource // "N/A",
                    .objectRef.namespace // "N/A",
                    .objectRef.name // "N/A",
                    (.responseStatus.code // 0),
                    .requestURI // "N/A",
                    .logfile // "N/A"
                ] | @csv'
            fi
            ;;

        *)
            log_error "Unknown output format: $format"
            exit 1
            ;;
    esac
}

# Query online from cluster
query_online() {
    log_info "=== Querying Cluster (Online Mode) ==="
    echo

    # Get cluster info
    local cluster=$(oc whoami --show-server 2>/dev/null)
    log_success "Connected to: ${cluster}"

    # Get master nodes
    log_info "Finding control plane nodes..."
    local master_nodes=$(oc get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[*].metadata.name}')

    if [ -z "$master_nodes" ]; then
        log_error "No master nodes found"
        exit 1
    fi

    local node_count=$(echo "$master_nodes" | wc -w | tr -d ' ')
    log_success "Found ${node_count} control plane node(s)"
    echo

    # Build jq filter
    local jq_filter=$(build_jq_filter)

    # Query each node and collect results
    local all_results=""
    for node in $master_nodes; do
        log_info "Querying node: ${node}"

        # Get list of audit logs on this node
        local log_files=$(oc adm node-logs "$node" --path=kube-apiserver/ 2>/dev/null | grep -E '^audit-.*\.log$')

        if [ -z "$log_files" ]; then
            log_warning "  No audit logs found on ${node}"
            continue
        fi

        local file_count=$(echo "$log_files" | wc -l | tr -d ' ')
        log_info "  Processing ${file_count} log file(s) from ${node}"

        # Stream and filter each log file
        while read -r logfile; do
            local node_results=$(oc adm node-logs "$node" --path="kube-apiserver/${logfile}" 2>/dev/null | \
                jq -c --arg nodename "$node" --arg filename "$logfile" \
                "$jq_filter | . + {node: \$nodename, logfile: \$filename}" 2>/dev/null)

            if [ -n "$node_results" ]; then
                all_results="${all_results}${node_results}"$'\n'
            fi
        done <<< "$log_files"
    done

    # Limit results and display
    local results=$(echo "$all_results" | grep -v '^$' | head -n "$MAX_RESULTS")

    if [ -z "$results" ]; then
        log_warning "No results found matching your criteria"
        exit 0
    fi

    local result_count=$(echo "$results" | wc -l | tr -d ' ')
    log_success "Found ${result_count} matching event(s)"
    echo

    if [ "$OUTPUT_FORMAT" != "csv" ] && [ "$OUTPUT_FORMAT" != "json" ]; then
        echo "$TABLE_SEPARATOR"
    fi

    echo "$results" | format_output "$OUTPUT_FORMAT"

    if [ "$OUTPUT_FORMAT" = "table" ]; then
        echo "$TABLE_SEPARATOR"
    fi

    echo
    log_info "Showing ${result_count} of maximum ${MAX_RESULTS} results"

    if [ "$result_count" -eq "$MAX_RESULTS" ]; then
        log_warning "Results limited to ${MAX_RESULTS}. Use -m to increase limit."
    fi
}

# Query offline from local files
query_offline() {
    log_info "=== Querying Local Files (Offline Mode) ==="
    echo

    log_info "Query Parameters:"
    [ -n "$VERBS" ] && echo "  Verbs: $VERBS"
    [ -n "$RESOURCES" ] && echo "  Resources: $RESOURCES"
    [ -n "$RESOURCE_NAMES" ] && echo "  Resource Names: $RESOURCE_NAMES"
    [ -n "$NAMESPACES" ] && echo "  Namespaces: $NAMESPACES"
    [ -n "$USERS" ] && echo "  Users: $USERS"
    [ -n "$START_TIME" ] && echo "  Start Time: $START_TIME"
    [ -n "$END_TIME" ] && echo "  End Time: $END_TIME"
    if [ -n "$STATUS_CODES" ]; then
        echo "  Status Codes: $STATUS_CODES"
    else
        echo "  Status Codes: 200 (default)"
    fi
    echo "  Output Format: $OUTPUT_FORMAT"
    echo "  Max Results: $MAX_RESULTS"
    echo "  Logs Directory: $LOGS_DIR"
    echo

    # Build jq filter
    local jq_filter=$(build_jq_filter)

    # Find all log files
    local log_files=$(find "$LOGS_DIR" -name "audit-*.log" -type f)
    local file_count=$(echo "$log_files" | wc -l | tr -d ' ')

    log_info "Found ${file_count} log file(s) to search"
    echo

    # Query and format - add filename to each entry
    local results=$(while read -r logfile; do
        local filename=$(basename "$logfile")
        jq -c --arg filename "$filename" "$jq_filter | . + {logfile: \$filename}" "$logfile" 2>/dev/null
    done <<< "$log_files" | head -n "$MAX_RESULTS")

    if [ -z "$results" ]; then
        log_warning "No results found matching your criteria"
        exit 0
    fi

    local result_count=$(echo "$results" | wc -l | tr -d ' ')
    log_success "Found ${result_count} matching event(s)"
    echo

    if [ "$OUTPUT_FORMAT" != "csv" ] && [ "$OUTPUT_FORMAT" != "json" ]; then
        echo "$TABLE_SEPARATOR"
    fi

    echo "$results" | format_output "$OUTPUT_FORMAT"

    if [ "$OUTPUT_FORMAT" = "table" ]; then
        echo "$TABLE_SEPARATOR"
    fi

    echo
    log_info "Showing ${result_count} of maximum ${MAX_RESULTS} results"

    if [ "$result_count" -eq "$MAX_RESULTS" ]; then
        log_warning "Results limited to ${MAX_RESULTS}. Use -m to increase limit."
    fi
}

# Main execution
main() {
    # Display query parameters for both modes
    log_info "Query Parameters:"
    [ -n "$VERBS" ] && echo "  Verbs: $VERBS"
    [ -n "$RESOURCES" ] && echo "  Resources: $RESOURCES"
    [ -n "$RESOURCE_NAMES" ] && echo "  Resource Names: $RESOURCE_NAMES"
    [ -n "$NAMESPACES" ] && echo "  Namespaces: $NAMESPACES"
    [ -n "$USERS" ] && echo "  Users: $USERS"
    [ -n "$START_TIME" ] && echo "  Start Time: $START_TIME"
    [ -n "$END_TIME" ] && echo "  End Time: $END_TIME"
    if [ -n "$STATUS_CODES" ]; then
        echo "  Status Codes: $STATUS_CODES"
    else
        echo "  Status Codes: 200 (default)"
    fi
    echo "  Output Format: $OUTPUT_FORMAT"
    echo "  Max Results: $MAX_RESULTS"
    echo

    # Route to appropriate query mode
    if [ "$QUERY_MODE" = "online" ]; then
        query_online
    else
        query_offline
    fi
}

main "$@"
