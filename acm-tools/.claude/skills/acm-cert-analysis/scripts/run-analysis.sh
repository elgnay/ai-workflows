#!/bin/bash

# ACM Certificate Analysis - Combined Workflow
# Usage: ./run-analysis.sh [--kubeconfig <path>]
#        If --kubeconfig is not specified, uses KUBECONFIG environment variable

# Get script directory
SCRIPT_DIR=`dirname "$0"`
SKILL_BASE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$SKILL_BASE_DIR/../../.." && pwd )"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_header() {
    echo -e "${CYAN}━━━${NC} $1"
}

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
    if [ -n "$KUBECONFIG" ]; then
        KUBECONFIG_PATH="$KUBECONFIG"
    else
        print_error "No kubeconfig specified"
        echo ""
        echo "Please provide kubeconfig in one of the following ways:"
        echo "  1. Use --kubeconfig parameter: $0 --kubeconfig <path>"
        echo "  2. Set KUBECONFIG environment variable: export KUBECONFIG=<path>"
        exit 1
    fi
fi

# Validate kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    print_error "Kubeconfig file not found: $KUBECONFIG_PATH"
    exit 1
fi

echo "ACM Hub Cluster Certificate Analysis"
echo ""

# Get cluster information
export KUBECONFIG="$KUBECONFIG_PATH"

CURRENT_USER=`oc whoami 2>/dev/null`
if [ -z "$CURRENT_USER" ]; then
    CURRENT_USER="Unknown"
fi

OCP_ENDPOINT=`oc get infrastructure cluster -o jsonpath='{.status.apiServerURL}' 2>/dev/null`
if [ -z "$OCP_ENDPOINT" ]; then
    OCP_ENDPOINT="Unknown"
fi

OCP_VERSION=`oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null`
if [ -z "$OCP_VERSION" ]; then
    OCP_VERSION="Unknown"
fi

# Step 1: Display cluster information
print_header "Step 1: Cluster Information"
echo ""
echo "Kubeconfig:    $KUBECONFIG_PATH"
echo "API Endpoint:  $OCP_ENDPOINT"
echo "OCP Version:   $OCP_VERSION"
echo "Current User:  $CURRENT_USER"
echo ""

# Step 2: Cluster Kube APIServer Certificates
print_header "Step 2: Cluster Kube APIServer Certificates"
echo ""

CERT_ANALYSIS_OUTPUT=`bash "$PROJECT_ROOT/.claude/skills/ocp-cert-analysis/scripts/run-all.sh" --kubeconfig "$KUBECONFIG_PATH" 2>&1`
CERT_ANALYSIS_EXIT=$?

if [ $CERT_ANALYSIS_EXIT -ne 0 ]; then
    print_error "Certificate detection failed"
    echo "$CERT_ANALYSIS_OUTPUT"
    exit 1
fi

# Extract certificate type from the analysis
if echo "$CERT_ANALYSIS_OUTPUT" | grep -q "Certificate Type: OpenShift-Managed Certificate"; then
    CERT_TYPE="OpenShift-Managed"
    CERT_TYPE_DISPLAY="OpenShift-Managed Certificate"
elif echo "$CERT_ANALYSIS_OUTPUT" | grep -q "Certificate Type: RedHat-Managed Certificate"; then
    CERT_TYPE="RedHat-Managed"
    CERT_TYPE_DISPLAY="RedHat-Managed Certificate"
elif echo "$CERT_ANALYSIS_OUTPUT" | grep -q "Certificate Type: Custom Certificate (Well-Known CA)"; then
    CERT_TYPE="Custom-WellKnown"
    CERT_TYPE_DISPLAY="Custom Certificate (Well-Known CA)"
elif echo "$CERT_ANALYSIS_OUTPUT" | grep -q "Certificate Type: Custom Certificate (Private CA)"; then
    CERT_TYPE="Custom-SelfSigned"
    CERT_TYPE_DISPLAY="Custom Certificate (Private CA)"
else
    CERT_TYPE="Unknown"
    CERT_TYPE_DISPLAY="Unknown"
fi

# Extract certificate details
CERT_SUBJECT=`echo "$CERT_ANALYSIS_OUTPUT" | grep "^  Subject: CN=" | head -1 | sed 's/  Subject: //'`
CERT_ISSUER=`echo "$CERT_ANALYSIS_OUTPUT" | grep "^  Issuer: " | head -1 | sed 's/  Issuer: //'`
CERT_VALIDITY=`echo "$CERT_ANALYSIS_OUTPUT" | grep "Valid Until:" | head -1 | sed 's/.*Valid Until: //'`

# Save the intermediate CA (server cert's issuer) before it gets overwritten by chain display loop
INTERMEDIATE_CA="$CERT_ISSUER"

# Check if root CA is included
if echo "$CERT_ANALYSIS_OUTPUT" | grep -q "Root CA is INCLUDED"; then
    ROOT_CA_INCLUDED="Yes"
else
    ROOT_CA_INCLUDED="No"
fi

# Display certificate details
echo "Certificate Type: $CERT_TYPE_DISPLAY"
if [ -n "$CERT_SUBJECT" ]; then
    echo "Subject:          $CERT_SUBJECT"
fi
if [ -n "$CERT_ISSUER" ]; then
    echo "Issuer:           $CERT_ISSUER"
fi
if [ -n "$CERT_VALIDITY" ]; then
    echo "Valid Until:      $CERT_VALIDITY"
fi
echo "Root CA Included: $ROOT_CA_INCLUDED"

# Extract and display certificate chain
echo ""
echo "Certificate Chain:"

# Get serving certificate info
SERVING_SUBJECT=`echo "$CERT_ANALYSIS_OUTPUT" | grep "^subject=" | head -1 | sed 's/^subject=//'`
SERVING_ISSUER=`echo "$CERT_ANALYSIS_OUTPUT" | grep "^issuer=" | head -1 | sed 's/^issuer=//'`

# Extract all certificates from CA bundle
CHAIN_INFO=`echo "$CERT_ANALYSIS_OUTPUT" | sed -n '/^--- Certificate/,/^$/p'`

if [ -n "$SERVING_SUBJECT" ] && [ -n "$CHAIN_INFO" ]; then
    # Build the actual signing chain by following issuer links
    CHAIN_NUM=1
    CURRENT_ISSUER="$SERVING_ISSUER"

    # Display serving certificate first
    echo "  [$CHAIN_NUM] Subject: $SERVING_SUBJECT"
    echo "      Issuer:  $SERVING_ISSUER"

    # Follow the chain through CA bundle
    while [ -n "$CURRENT_ISSUER" ]; do
        CHAIN_NUM=$((CHAIN_NUM + 1))

        # Find certificate in CA bundle where subject matches current issuer
        CERT_FOUND=`echo "$CHAIN_INFO" | awk -v issuer="$CURRENT_ISSUER" '
        BEGIN { found = 0; subject = ""; cert_issuer = "" }
        /^subject=/ {
            sub(/^subject=/, "")
            if ($0 == issuer) {
                found = 1
                subject = $0
            }
        }
        /^issuer=/ {
            if (found == 1) {
                sub(/^issuer=/, "")
                cert_issuer = $0
                print subject "|" cert_issuer
                exit
            }
        }
        '`

        if [ -n "$CERT_FOUND" ]; then
            CERT_SUBJECT=`echo "$CERT_FOUND" | cut -d'|' -f1`
            CERT_ISSUER=`echo "$CERT_FOUND" | cut -d'|' -f2`

            echo ""
            echo "  [$CHAIN_NUM] Subject: $CERT_SUBJECT"
            echo "      Issuer:  $CERT_ISSUER"

            # Check if this is a self-signed root CA
            if [ "$CERT_SUBJECT" = "$CERT_ISSUER" ]; then
                break
            fi

            CURRENT_ISSUER="$CERT_ISSUER"
        else
            # Issuer not found in CA bundle - missing certificate
            echo ""
            echo "  [$CHAIN_NUM] Subject: $CURRENT_ISSUER (Not Included)"
            echo "      Issuer:  $CURRENT_ISSUER"
            break
        fi
    done
else
    echo "  Unable to extract certificate chain details"
fi

echo ""

# Step 3: ACM Status and Configuration
print_header "Step 3: ACM Status and Configuration"
echo ""

ACM_DETECTION_OUTPUT=`bash "$PROJECT_ROOT/.claude/skills/acm-status-detection/scripts/check-acm.sh" --kubeconfig "$KUBECONFIG_PATH" 2>&1`
ACM_DETECTION_EXIT=$?

echo "$ACM_DETECTION_OUTPUT"

if [ $ACM_DETECTION_EXIT -ne 0 ]; then
    print_error "ACM detection failed"
    exit 1
fi

# Extract ACM status from output
if echo "$ACM_DETECTION_OUTPUT" | grep -q "ACM Status: INSTALLED"; then
    ACM_STATUS="INSTALLED"
    ACM_VERSION=`echo "$ACM_DETECTION_OUTPUT" | grep "Version:" | awk '{print $2}'`
    SERVER_VERIFICATION_STRATEGY=`echo "$ACM_DETECTION_OUTPUT" | grep "ServerVerificationStrategy:" | awk '{print $2}'`
elif echo "$ACM_DETECTION_OUTPUT" | grep -q "ACM Status: OPERATOR ONLY"; then
    ACM_STATUS="OPERATOR_ONLY"
else
    ACM_STATUS="NOT_INSTALLED"
fi

echo ""

# Step 4: ACM Certificate Management Analysis
print_header "Step 4: ACM Certificate Management Analysis"
echo ""
echo "Recommended ServerVerificationStrategy:"
echo ""

# Determine recommended strategy based on certificate type
RECOMMENDED_STRATEGY=""
STRATEGY_NOTE=""

case "$CERT_TYPE" in
    "OpenShift-Managed")
        RECOMMENDED_STRATEGY="UseAutoDetectedCABundle"
        STRATEGY_NOTE="OpenShift-managed certificates work best with auto-detection"
        ;;
    "RedHat-Managed")
        RECOMMENDED_STRATEGY="UseSystemTruststore"
        STRATEGY_NOTE="RedHat-managed certificates use well-known CAs trusted by system stores"
        ;;
    "Custom-WellKnown")
        if [ "$ROOT_CA_INCLUDED" = "Yes" ]; then
            RECOMMENDED_STRATEGY="UseAutoDetectedCABundle or UseSystemTruststore"
            STRATEGY_NOTE="Option 1: UseAutoDetectedCABundle (full CA chain is included)"
            STRATEGY_NOTE2="Option 2: UseSystemTruststore (well-known CA is trusted by system)"
        else
            RECOMMENDED_STRATEGY="UseSystemTruststore"
            STRATEGY_NOTE="UseSystemTruststore is recommended when root CA is not in the chain"
            STRATEGY_NOTE2="Alternative: Add root CA to chain, then use UseAutoDetectedCABundle"
        fi
        ;;
    "Custom-SelfSigned")
        if [ "$ROOT_CA_INCLUDED" = "Yes" ]; then
            RECOMMENDED_STRATEGY="UseAutoDetectedCABundle"
            STRATEGY_NOTE="Private CA certificates require auto-detection with full CA chain"
        else
            RECOMMENDED_STRATEGY="UseAutoDetectedCABundle (after adding root CA)"
            STRATEGY_NOTE="⚠️  ACM may work with current certificates but has rotation risks"
            STRATEGY_NOTE2="Certificate rotation with different intermediate CA will cause managed clusters to enter unknown state"
        fi
        ;;
    *)
        RECOMMENDED_STRATEGY="Unknown"
        STRATEGY_NOTE="Unable to determine recommended strategy"
        ;;
esac

echo "  Recommended: $RECOMMENDED_STRATEGY"
if [ -n "$STRATEGY_NOTE" ]; then
    echo "  • $STRATEGY_NOTE"
fi
if [ -n "$STRATEGY_NOTE2" ]; then
    echo "  • $STRATEGY_NOTE2"
fi

# Show current configuration if ACM is installed
if [ "$ACM_STATUS" = "INSTALLED" ] && [ -n "$SERVER_VERIFICATION_STRATEGY" ]; then
    echo ""
    echo "  Current: $SERVER_VERIFICATION_STRATEGY"

    # Check if current matches recommendation
    if echo "$RECOMMENDED_STRATEGY" | grep -q "$SERVER_VERIFICATION_STRATEGY"; then
        echo "  Status: ✓ Matches recommendation"
    else
        echo "  Status: ⚠️  Does not match recommendation"
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Step 5: Analysis Summary and Recommendations
print_header "Step 5: Analysis Summary"
echo ""

echo "OCP API Endpoint: $OCP_ENDPOINT"
echo "OCP Version: $OCP_VERSION"
echo "Certificate Type: $CERT_TYPE"
echo "Root CA Included: $ROOT_CA_INCLUDED"

if [ "$ACM_STATUS" = "INSTALLED" ]; then
    echo "ACM: Installed (Version $ACM_VERSION)"
    if [ -n "$SERVER_VERIFICATION_STRATEGY" ]; then
        echo "ServerVerificationStrategy: $SERVER_VERIFICATION_STRATEGY"
    fi
else
    if [ "$ACM_STATUS" = "OPERATOR_ONLY" ]; then
        echo "ACM: Operator installed, MultiClusterHub not deployed"
    else
        echo "ACM: Not installed"
    fi
fi
echo ""

# Provide recommendations based on ACM status and cert type
if [ "$ACM_STATUS" = "INSTALLED" ]; then
    case "$CERT_TYPE" in
        "OpenShift-Managed")
            print_success "Configuration: Compatible"
            echo ""
            # Root CA info only matters when UseAutoDetectedCABundle is used
            if [ "$SERVER_VERIFICATION_STRATEGY" = "UseAutoDetectedCABundle" ]; then
                echo "Root CA is included in certificate chain"
                echo "  • ACM will automatically detect and distribute the CA bundle to managed clusters"
                echo "  • No additional configuration required"
            else
                echo "  • No additional configuration required"
            fi
            echo ""
            echo "Important considerations:"
            echo "  • ⚠️  Do NOT replace OpenShift-Managed certificates with Custom certificates"
            echo "  • Replacing the kube-apiserver certificate with a Custom certificate will cause managed clusters to enter unknown state"
            echo "  • If you need Custom certificates, run skill acm-cert-change-assessment for impact and mitigation guidance"
            ;;
        "RedHat-Managed")
            if [ "$SERVER_VERIFICATION_STRATEGY" = "UseSystemTruststore" ]; then
                print_success "Configuration: Compatible"
                echo ""
                echo "UseSystemTruststore is already configured"
                echo "  • RedHat-managed certificates use well-known CAs (like Let's Encrypt)"
                echo "  • Well-known CAs are already trusted by the system trust store"
                echo "  • No manual CA bundle management required"
            else
                print_info "Configuration Issue"
                echo ""
                echo "⚠️  Current configuration will cause cluster import failures"
                echo ""
                echo "Problem:"
                echo "  • UseAutoDetectedCABundle cannot detect well-known CA roots"
                echo "  • Cluster import will fail with certificate validation errors"
                echo ""
                echo "Required action:"
                echo "  • Configure UseSystemTruststore as the KubeAPIServer verification strategy"
                echo ""
                echo "Why this works:"
                echo "  • RedHat-managed certificates use well-known CAs (like Let's Encrypt)"
                echo "  • Well-known CAs are already trusted by the system trust store"
                echo "  • After switching, cluster import will succeed and no manual CA bundle management required"
            fi
            ;;
        "Custom-WellKnown")
            # For UseAutoDetectedCABundle, root CA inclusion matters
            if [ "$SERVER_VERIFICATION_STRATEGY" = "UseAutoDetectedCABundle" ]; then
                if [ "$ROOT_CA_INCLUDED" != "Yes" ]; then
                    print_info "ACM Configuration Notes"
                    echo ""
                    echo "Current status:"
                    echo "  • ACM may work with current certificates"
                    echo ""
                    echo "Limitation:"
                    echo "  • ⚠️  Certificate rotation MUST use the same intermediate CA ($INTERMEDIATE_CA)"
                    echo "  • Without root CA, managed clusters cannot verify certificates signed by different intermediates"
                    echo "  • Changing intermediate CA or root CA will cause managed clusters to enter unknown state"
                    echo ""
                    echo "Recommended actions:"
                    echo "  • Option 1: Add root CA to the certificate chain (enable flexible rotation, continue using UseAutoDetectedCABundle)"
                    echo "    - After adding, re-run this skill to verify the configuration"
                    echo "  • Option 2: Configure UseSystemTruststore (well-known CAs are already in system trust store)"
                    echo ""
                    echo "Note:"
                    echo "  • If you need to change intermediate CA or root CA, run skill acm-cert-change-assessment for impact and mitigation guidance"
                else
                    print_success "Configuration: Compatible"
                    echo ""
                    echo "Root CA is included in certificate chain"
                    echo "  • ACM will automatically detect and distribute the CA bundle to managed clusters"
                    echo "  • No additional configuration required"
                    echo ""
                    echo "Optional simplification:"
                    echo "  • You can configure UseSystemTruststore as the KubeAPIServer verification strategy"
                    echo "    in the global KlusterletConfig to simplify certificate management"
                    echo "  • Well-known CAs (like Let's Encrypt) are already trusted by system trust stores"
                    echo ""
                    echo "Important considerations:"
                    echo "  • Certificate rotation and intermediate CA changes are safe (as long as full chain is included)"
                    echo "  • ⚠️  Do NOT change the root CA - this may cause managed clusters to enter unknown state"
                    echo "  • If you need to change the root CA, run skill acm-cert-change-assessment for impact and mitigation guidance"
                fi
            else
                # For UseSystemTruststore or UseCustomCABundles, root CA in chain doesn't matter
                print_success "Configuration: Compatible"
                echo ""
                echo "  • No additional configuration required"
                echo ""
                echo "Important considerations:"
                if [ "$SERVER_VERIFICATION_STRATEGY" = "UseSystemTruststore" ]; then
                    echo "  • Certificate rotation is safe as long as signed by the same well-known CA"
                fi
                echo "  • ⚠️  Do NOT change the root CA - this may cause managed clusters to enter unknown state"
                echo "  • If you need to change the root CA, run skill acm-cert-change-assessment for impact and mitigation guidance"
            fi
            ;;
        "Custom-SelfSigned")
            # For UseAutoDetectedCABundle, root CA inclusion matters
            if [ "$SERVER_VERIFICATION_STRATEGY" = "UseAutoDetectedCABundle" ]; then
                if [ "$ROOT_CA_INCLUDED" != "Yes" ]; then
                    print_info "ACM Configuration Notes"
                    echo ""
                    echo "Current status:"
                    echo "  • ACM may work with current certificates"
                    echo ""
                    echo "Limitation:"
                    echo "  • ⚠️  Certificate rotation MUST use the same intermediate CA ($INTERMEDIATE_CA)"
                    echo "  • Without root CA, managed clusters cannot verify certificates signed by different intermediates"
                    echo "  • Changing intermediate CA or root CA will cause managed clusters to enter unknown state"
                    echo ""
                    echo "Recommended actions:"
                    echo "  1. Add root CA to the certificate chain to enable flexible certificate rotation"
                    echo "  2. Re-run this skill to verify the configuration after adding root CA"
                    echo ""
                    echo "Note:"
                    echo "  • If you need to change intermediate CA or root CA, run skill acm-cert-change-assessment for impact and mitigation guidance"
                else
                    print_success "Configuration: Compatible"
                    echo ""
                    echo "Root CA is included in certificate chain"
                    echo "  • ACM will automatically detect and distribute the CA bundle to managed clusters"
                    echo "  • No additional configuration required"
                    echo ""
                    echo "Important considerations:"
                    echo "  • Certificate rotation and intermediate CA changes are safe (as long as full chain is included)"
                    echo "  • ⚠️  Do NOT change the root CA - this may cause managed clusters to enter unknown state"
                    echo "  • If you need to change the root CA, run skill acm-cert-change-assessment for impact and mitigation guidance"
                fi
            else
                # For UseCustomCABundles, root CA in chain doesn't matter
                print_success "Configuration: Compatible"
                echo ""
                echo "  • No additional configuration required"
                echo ""
                echo "Important considerations:"
                echo "  • Certificate rotation depends on your custom CA bundle configuration"
                echo "  • ⚠️  Do NOT change the root CA - this may cause managed clusters to enter unknown state"
                echo "  • If you need to change the root CA, run skill acm-cert-change-assessment for impact and mitigation guidance"
            fi
            ;;
        *)
            print_error "Unknown certificate type - manual verification required"
            ;;
    esac
else
    case "$CERT_TYPE" in
        "OpenShift-Managed")
            print_success "Safe to install ACM"
            echo ""
            echo "You have two options:"
            echo ""
            echo "Option 1: Install ACM with current certificates"
            echo "  • Safe to proceed with installation"
            echo "  • ⚠️  Do NOT replace kube-apiserver certificate with Custom certificate after ACM installation"
            echo "  • Replacing with Custom certificate will cause managed clusters to enter unknown state"
            echo "  • If you plan to change certificates later, run skill acm-cert-change-assessment for impact and mitigation guidance"
            echo ""
            echo "Option 2: Configure Custom certificates BEFORE installing ACM"
            echo "  • Configure Custom kube-apiserver certificates first"
            echo "  • Then install ACM with Custom certificate configuration"
            echo "  • This avoids the risk of certificate type change after installation"
            ;;
        "RedHat-Managed")
            print_success "Safe to install ACM"
            echo ""
            echo "Next steps:"
            echo "  1. Proceed with ACM installation"
            echo "  2. (Required) Configure UseSystemTruststore strategy as the KubeAPIServer verification strategy in the global KlusterletConfig after installation"
            echo ""
            echo "Note: Well-known CAs are automatically trusted by system trust stores"
            ;;
        "Custom-WellKnown")
            if echo "$CERT_ANALYSIS_OUTPUT" | grep -q "Root CA is INCLUDED"; then
                print_success "Safe to install ACM"
                echo ""
                echo "Root CA is included in certificate chain"
                echo ""
                echo "Next steps:"
                echo "  1. Proceed with ACM installation"
                echo "  2. (Optional) Configure UseSystemTruststore strategy as the KubeAPIServer verification strategy in the global KlusterletConfig"
                echo ""
                echo "Note: Well-known CAs are already trusted by system trust stores"
            else
                print_info "ACM may work initially but has certificate rotation risk"
                echo ""
                echo "Root CA is NOT included in certificate chain"
                echo ""
                echo "You have two options:"
                echo ""
                echo "Option 1: Add root CA to certificate chain (Simpler)"
                echo "  • Add the root CA certificate to the certificate chain"
                echo "  • Then proceed with ACM installation"
                echo "  • No additional ACM configuration needed"
                echo ""
                echo "Option 2: Use system trust store (No cert chain changes)"
                echo "  • Proceed with ACM installation as-is"
                echo "  • Configure UseSystemTruststore strategy as the KubeAPIServer verification strategy in the global KlusterletConfig after installation"
                echo "  • Note: System trust store already contains well-known CA root certificates"
                echo ""
                echo "Risk if neither option is implemented:"
                echo "  • ACM may work initially with the current intermediate certificate"
                echo "  • If Let's Encrypt rotates to a different intermediate CA, managed clusters will enter unknown state"
                echo "  • Without root CA in chain, managed clusters cannot verify certificates signed by different intermediates"
            fi
            ;;
        "Custom-SelfSigned")
            if echo "$CERT_ANALYSIS_OUTPUT" | grep -q "Root CA is INCLUDED"; then
                print_success "Safe to install ACM"
                echo ""
                echo "Root CA is included in certificate chain"
                echo ""
                echo "Next steps:"
                echo "  1. Proceed with ACM installation"
                echo ""
                echo "Note: ACM will automatically detect the CA bundle and distribute it to managed clusters, which will be used to connect to the hub Kube APIServer."
            else
                print_info "ACM may work initially but has certificate rotation risk"
                echo ""
                echo "Root CA is NOT included in certificate chain"
                echo ""
                echo "Recommended action:"
                echo "  • Add the root CA certificate to the certificate chain before installing ACM"
                echo "  • Verify certificate configuration includes complete chain"
                echo "  • Re-run this analysis to confirm"
                echo ""
                echo "Risk if not implemented:"
                echo "  • ACM may work initially with the current intermediate certificate"
                echo "  • Certificate rotation with different intermediate CA will cause managed clusters to enter unknown state"
                echo "  • Without root CA in chain, managed clusters cannot verify certificates signed by different intermediates"
            fi
            ;;
        *)
            print_error "Unknown certificate type - manual verification required"
            ;;
    esac
fi

echo ""
