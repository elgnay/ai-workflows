# Connection Timeout Handling

This document describes how the OCP certificate analysis scripts handle connection timeouts and cluster unavailability.

## Overview

All scripts that interact with the OpenShift cluster have been enhanced with:
- ✅ **Timeout detection** - Recognize timeout errors
- ✅ **Graceful error messages** - Clear explanations of what went wrong
- ✅ **Troubleshooting guidance** - Actionable suggestions for resolution
- ✅ **Timeout limits** - Explicit timeouts to prevent hanging
- ✅ **Exit code handling** - Proper error propagation

## Scripts Enhanced

### 1. Step 01: Setup Kubeconfig (`01-setup-kubeconfig.sh`)

**Enhancements:**
- Captures exit code and error output from `oc whoami`
- Detects timeout, authentication, and certificate errors
- Provides context-specific troubleshooting suggestions

**Timeout Detection:**
```bash
if echo "$USER_IDENTITY" | grep -qi "timeout\|timed out"; then
    print_error "Connection timed out - cluster may be unavailable or unreachable"
    # ... troubleshooting suggestions ...
fi
```

**Error Types Handled:**
- ✅ Connection timeout (cluster unreachable)
- ✅ Authentication failures (invalid credentials)
- ✅ Certificate validation errors (x509 errors)
- ✅ Unknown errors (fallback handler)

**Troubleshooting Output:**
```
✗ Connection timed out - cluster may be unavailable or unreachable

Troubleshooting suggestions:
  1. Check if the cluster is running and accessible
  2. Verify network connectivity to the API server
  3. Check VPN connection if required
  4. Verify kubeconfig has correct API server URL

To check the API server URL in kubeconfig:
  grep 'server:' kubeconfig.c3
```

---

### 2. Step 02: Get API Endpoint (`02-get-api-endpoint.sh`)

**Enhancements:**
- Captures exit code from `oc get infrastructure` command
- Detects timeout and authentication errors
- Provides specific error context

**Timeout Detection:**
```bash
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    # Success
else
    if echo "$API_ENDPOINT" | grep -qi "timeout\|timed out"; then
        print_error "Connection timed out - cluster is unavailable"
    fi
fi
```

---

### 3. Step 03: Retrieve Certificate Chain (`03-retrieve-cert-chain.sh`)

**Enhancements:**
- Uses `timeout` command (if available) to limit connection time to 30 seconds
- Detects timeout exit code (124)
- Provides detailed troubleshooting for connection failures
- Tests direct connectivity with openssl

**Timeout Command:**
```bash
if command -v timeout > /dev/null 2>&1; then
    timeout 30 sh -c "echo | openssl s_client -connect ${API_HOSTNAME}:${API_PORT} -showcerts 2>/dev/null" > output
    EXIT_CODE=$?
else
    # Fallback without timeout command
fi
```

**Exit Code Handling:**
```bash
if [ $EXIT_CODE -eq 0 ]; then
    print_success "Certificate chain retrieved"
elif [ $EXIT_CODE -eq 124 ]; then
    print_error "Connection timed out after 30 seconds"
    # Troubleshooting suggestions
else
    print_error "Failed to retrieve certificate chain"
    # Possible reasons
fi
```

**Troubleshooting Output:**
```
✗ Connection timed out after 30 seconds

Troubleshooting suggestions:
  1. Verify the cluster is accessible
  2. Check network connectivity to api.example.com:6443
  3. Verify firewall/security group settings
  4. Test connectivity: telnet api.example.com 6443
```

---

### 4. Step 04: Determine Certificate Type (`04-determine-cert-type.sh`)

**Enhancements:**
- Captures exit code from `oc get apiserver` command
- Detects timeout errors when retrieving cluster configuration
- Fails fast with clear error message

**Error Handling:**
```bash
NAMED_CERTS=`oc get apiserver cluster -o jsonpath='{...}' 2>&1`
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    print_error "Failed to retrieve API server configuration"
    if echo "$NAMED_CERTS" | grep -qi "timeout\|timed out"; then
        print_error "Connection timed out - cluster is unavailable"
    fi
    exit 1
fi
```

---

### 5. Step 05: Get CA Bundle (`05-get-ca-bundle.sh`)

**Enhancements:**
- Captures output and exit codes from:
  - `oc get configmap` (Type 1: OpenShift-Managed)
  - `oc extract secret` (Type 3: Custom CA)
- Detects timeout errors for both operations
- Provides error context for each operation

**ConfigMap Retrieval:**
```bash
CA_BUNDLE_OUTPUT=`oc get configmap kube-apiserver-server-ca -n openshift-kube-apiserver -o jsonpath='{...}' 2>&1`
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "$CA_BUNDLE_OUTPUT" > "${WORKDIR}/ca-bundle.crt"
    print_success "CA bundle retrieved"
else
    print_error "Failed to retrieve CA bundle"
    if echo "$CA_BUNDLE_OUTPUT" | grep -qi "timeout\|timed out"; then
        print_error "Connection timed out - cluster is unavailable"
    fi
    exit 1
fi
```

**Secret Extraction:**
```bash
SECRET_OUTPUT=`oc extract secret/${SECRET_NAME} -n openshift-config --keys=tls.crt --to=- 2>&1`
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "$SECRET_OUTPUT" > "${WORKDIR}/ca-bundle.crt"
else
    print_error "Failed to extract CA bundle from secret"
    if echo "$SECRET_OUTPUT" | grep -qi "timeout\|timed out"; then
        print_error "Connection timed out - cluster is unavailable"
    fi
fi
```

---

### 6. Step 08: Test Connectivity (`08-test-connectivity.sh`)

**Enhancements:**
- Uses curl with explicit timeouts:
  - `--connect-timeout 30` (30 seconds to establish connection)
  - `--max-time 60` (60 seconds total)
- Detects curl exit code 28 (timeout)
- Detects timeout in error output
- Provides specific troubleshooting for connectivity issues

**Curl with Timeout:**
```bash
CURL_OUTPUT=`curl -s --connect-timeout 30 --max-time 60 --cacert "${WORKDIR}/ca-bundle.crt" "${API_ENDPOINT}/healthz" 2>&1`
EXIT_CODE=$?
```

**Timeout Detection:**
```bash
if [ "$CURL_OUTPUT" = "ok" ]; then
    print_success "API server responded: ok"
elif [ $EXIT_CODE -eq 28 ] || echo "$CURL_OUTPUT" | grep -qi "timeout\|timed out"; then
    print_error "Connection timed out"
    # Troubleshooting suggestions
else
    print_error "API server connectivity test failed"
    # Other error handling
fi
```

**Troubleshooting Output:**
```
✗ Connection timed out

Troubleshooting suggestions:
  1. Verify the API server is running and accessible
  2. Check network connectivity to https://api.example.com:6443
  3. Verify firewall/security group allows access
  4. Test basic connectivity: curl -k https://api.example.com:6443/healthz
```

---

## Timeout Values

| Operation | Timeout | Rationale |
|-----------|---------|-----------|
| `oc whoami` | Default (client timeout) | Quick auth check |
| `oc get infrastructure` | Default (client timeout) | Cluster metadata query |
| `openssl s_client` | 30 seconds | Certificate retrieval |
| `oc get apiserver` | Default (client timeout) | Cluster config query |
| `oc get configmap` | Default (client timeout) | ConfigMap retrieval |
| `oc extract secret` | Default (client timeout) | Secret extraction |
| `curl /healthz` | 30s connect, 60s total | API health check |

---

## Error Message Patterns

All scripts detect these patterns in error output:

| Pattern | Error Type |
|---------|------------|
| `timeout` | Connection timeout |
| `timed out` | Connection timeout |
| `i/o timeout` | Connection timeout |
| `unauthorized` | Authentication failure |
| `forbidden` | Authorization failure |
| `certificate` | Certificate validation error |
| `x509` | Certificate validation error |

---

## Best Practices

### For Script Users

1. **Check cluster accessibility before running**
   ```bash
   # Quick connectivity test
   oc whoami --show-server
   ```

2. **Review error messages carefully**
   - Scripts provide specific troubleshooting steps
   - Follow suggestions in order

3. **Test network connectivity**
   ```bash
   # Test DNS resolution
   nslookup api.cluster.example.com

   # Test port connectivity
   telnet api.cluster.example.com 6443

   # Test TLS connection
   openssl s_client -connect api.cluster.example.com:6443
   ```

### For Script Developers

1. **Always capture exit codes**
   ```bash
   COMMAND_OUTPUT=`command 2>&1`
   EXIT_CODE=$?
   ```

2. **Check exit code before processing output**
   ```bash
   if [ $EXIT_CODE -eq 0 ]; then
       # Success path
   else
       # Error handling
   fi
   ```

3. **Provide context-specific error messages**
   - Explain what failed
   - Why it might have failed
   - How to troubleshoot

4. **Use explicit timeouts when possible**
   ```bash
   timeout 30 command
   curl --connect-timeout 30 --max-time 60 URL
   ```

---

## Example: Complete Error Flow

### User runs script on unavailable cluster:

```bash
$ bash scripts/run-all.sh kubeconfig.c3
```

### Output:

```
╔═══════════════════════════════════════════════════════════════╗
║     OCP Certificate Analysis - Complete Workflow              ║
╚═══════════════════════════════════════════════════════════════╝

Starting certificate analysis workflow...

▶ Step 1/8: Setting up kubeconfig...
✓ Kubeconfig path saved: kubeconfig.c3

Verifying connection to cluster...
(This may take up to 30 seconds if cluster is slow to respond)

✗ Failed to connect with kubeconfig: kubeconfig.c3

Error details:
Unable to connect to the server: dial tcp 100.30.50.68:6443: i/o timeout

✗ Connection timed out - cluster may be unavailable or unreachable

Troubleshooting suggestions:
  1. Check if the cluster is running and accessible
  2. Verify network connectivity to the API server
  3. Check VPN connection if required
  4. Verify kubeconfig has correct API server URL

To check the API server URL in kubeconfig:
  grep 'server:' kubeconfig.c3

✗ Step 1 failed. Aborting.
```

### User follows troubleshooting steps:

```bash
# Check API server in kubeconfig
$ grep 'server:' kubeconfig.c3
    server: https://api.cluster.example.com:6443

# Test connectivity
$ telnet api.cluster.example.com 6443
Trying 100.30.50.68...
^C

# Cluster is unreachable - user needs to fix network/VPN
```

---

## Summary

All scripts now handle connection timeouts gracefully with:
- ✅ Clear error detection
- ✅ Helpful error messages
- ✅ Actionable troubleshooting steps
- ✅ Proper exit codes
- ✅ Explicit timeout limits
- ✅ Context-specific guidance

This ensures users can quickly identify and resolve connectivity issues without confusion.
