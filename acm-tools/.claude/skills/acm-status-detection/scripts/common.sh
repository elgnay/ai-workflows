#!/bin/bash

# Common environment and functions for ACM status detection
# This file should be sourced by all scripts

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the absolute path to the skill base directory
SKILL_BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print info messages
print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Function to print header messages
print_header() {
    echo -e "${BLUE}▶${NC} $1"
}

# Function to validate kubeconfig
validate_kubeconfig() {
    local kube_path="$1"

    if [ -z "$kube_path" ]; then
        print_error "Kubeconfig path is empty"
        return 1
    fi

    if [ ! -f "$kube_path" ]; then
        print_error "Kubeconfig file not found: $kube_path"
        return 1
    fi

    # Test connection
    if ! export KUBECONFIG="$kube_path" && oc whoami &>/dev/null; then
        print_error "Cannot connect to cluster using kubeconfig: $kube_path"
        return 1
    fi

    return 0
}
