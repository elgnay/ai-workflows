#!/bin/bash

# Common environment and functions for OCP certificate analysis
# This file should be sourced by all step scripts

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the absolute path to the skill base directory
SKILL_BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# State files
# Note: .current_workdir is saved in skill directory for persistence, all other state files go in WORKDIR
WORKDIR_FILE=".current_workdir"
WORKDIR_FILE_PATH="${SKILL_BASE_DIR}/${WORKDIR_FILE}"

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

# Function to load working directory
# This reads from skill directory and must be called before other load functions
load_workdir() {
    if [ -f "$WORKDIR_FILE_PATH" ]; then
        WORKDIR=`cat "$WORKDIR_FILE_PATH"`
    else
        print_error "Working directory not found. Run step 01 first."
        exit 1
    fi
}

# Function to load kubeconfig path
# Note: Requires load_workdir() to be called first
load_kubeconfig() {
    if [ -f "${WORKDIR}/.kubeconfig_path" ]; then
        export KUBECONFIG=`cat "${WORKDIR}/.kubeconfig_path"`
    else
        print_error "Kubeconfig path not found. Run step 01 first."
        exit 1
    fi
}

# Function to load API endpoint
# Note: Requires load_workdir() to be called first
load_api_endpoint() {
    if [ -f "${WORKDIR}/.api_endpoint" ]; then
        API_ENDPOINT=`cat "${WORKDIR}/.api_endpoint"`
    else
        print_error "API endpoint not found. Run step 02 first."
        exit 1
    fi
}

# Function to load certificate type
# Note: Requires load_workdir() to be called first
load_cert_type() {
    if [ -f "${WORKDIR}/.cert_type" ]; then
        CERT_TYPE=`cat "${WORKDIR}/.cert_type"`
    else
        print_error "Certificate type not determined. Run step 04 first."
        exit 1
    fi
}

# Function to load OpenShift version
# Note: Requires load_workdir() to be called first
load_ocp_version() {
    if [ -f "${WORKDIR}/.ocp_version" ]; then
        OCP_VERSION=`cat "${WORKDIR}/.ocp_version"`
    else
        OCP_VERSION="Unknown"
    fi
}

# Function to convert internal cert type to user-friendly display name
get_cert_type_display() {
    local cert_type="$1"
    case "$cert_type" in
        "Type1-OpenShift-Managed")
            echo "OpenShift-Managed Certificate"
            ;;
        "Type2-RedHat-Managed")
            echo "RedHat-Managed Certificate"
            ;;
        "Type3a-Custom-WellKnown")
            echo "Custom Certificate (Well-Known CA)"
            ;;
        "Type3b-Custom-SelfSigned")
            echo "Custom Certificate (Private CA)"
            ;;
        *)
            echo "$cert_type"
            ;;
    esac
}
