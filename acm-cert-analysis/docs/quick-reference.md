# Quick Reference: Certificate Types

## How to Identify Cluster Type

A cluster is a **Managed OpenShift Cluster** if **ALL** conditions are met:
1. Issuer is **NOT** `CN=kube-apiserver-lb-signer`
2. **AND** one of the following:
   - `.spec.servingCerts.namedCertificates` does **NOT** exist
   - **OR** `.spec.servingCerts.namedCertificates` exists but referenced secret does **NOT** exist

Otherwise, it's a **Self-Managed OpenShift Cluster**.

---

## Certificate Types by Cluster Type

| Cluster Type | Available Certificate Types | User Can Configure Custom? |
|-------------|----------------------------|---------------------------|
| **Managed OpenShift** (ROSA, ARO, OSD) | Type 2: RedHat-Managed only | ❌ No |
| **Self-Managed OpenShift** | Type 1: OpenShift-Managed (default)<br>Type 3a: Custom CA - Well-Known<br>Type 3b: Custom CA - Self-Signed | ✅ Yes |

---

## Certificate Type Identification Conditions

| Certificate Type | Issuer | namedCertificates Config | Secret Exists | Cluster Type |
|-----------------|--------|-------------------------|---------------|--------------|
| **Type 1: OpenShift-Managed** | `CN=kube-apiserver-lb-signer` | Empty/Does not exist | N/A | Self-Managed |
| **Type 2: RedHat-Managed** | NOT `kube-apiserver-lb-signer` | Does not exist OR exists | N/A OR No | Managed |
| **Type 3a: Custom - Well-Known** | Well-known CA (Let's Encrypt, etc.) | Exists | Yes | Self-Managed |
| **Type 3b: Custom - Self-Signed** | Custom CA | Exists | Yes | Self-Managed |

---

## Certificate Type Details

| Certificate Type | CA Bundle Location | Verification Method |
|-----------------|-------------------|---------------------|
| **Type 1: OpenShift-Managed**<br>(Default for Self-Managed) | `kube-apiserver-server-ca` ConfigMap<br>in `openshift-kube-apiserver` namespace | Use CA bundle file |
| **Type 2: RedHat-Managed**<br>(Managed Clusters Only) | Service-specific ConfigMap (ROSA, ARO, etc.) | Use CA bundle file |
| **Type 3a: Custom CA - Well-Known**<br>(Self-Managed Only) | System trust store | Use system trust store |
| **Type 3b: Custom CA - Self-Signed**<br>(Self-Managed Only) | Custom certificate secret's `tls.crt` field (referenced in `.spec.servingCerts.namedCertificates`) in `openshift-config` namespace | Use CA bundle file |

---

## ACM Pre-Installation Quick Reference

### Certificate Type and ACM Configuration

| Certificate Type | Safe to Install ACM? | Risk Level |
|-----------------|---------------------|------------|
| **Type 1: OpenShift-Managed** | ✅ Yes (but configure custom cert first if you plan to use one) | 🟢 LOW |
| **Type 2: RedHat-Managed** | ✅ Yes | 🟢 LOW |
| **Type 3a: Custom - Well-Known CA** | ✅ Yes (if root CA included) | 🟢 LOW |
| **Type 3b: Custom - Self-Signed CA** | ✅ Yes (if root CA included) | 🟢 LOW |

**Important Notes:**
- **Automatic CA Bundle Handling**: ACM automatically handles CA bundle distribution to managed clusters during import. Users do not need to manually provide CA bundles.
- **Type 1 Warning**: There is NO risk in using OpenShift-Managed certificates with ACM as long as you don't change certificate types later. The ONLY risk is changing certificate types (from OpenShift-Managed to Custom) AFTER ACM installation, which causes managed clusters to enter an unknown state. If you plan to use custom certificates, configure them BEFORE installing ACM.
