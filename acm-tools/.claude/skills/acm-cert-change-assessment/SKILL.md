---
name: acm-cert-change-assessment
description: Assess the risk of changing kube-apiserver certificates on clusters with ACM. Evaluates impact of certificate type changes, rotations, root CA changes, and intermediate CA changes. Provides risk analysis and mitigation guidance. Accepts --kubeconfig (optional, defaults to KUBECONFIG env var) parameter.
allowed-tools: [Bash, Read]
---

# ACM Certificate Change Risk Assessment

> ⚠️ **STATUS: NOT YET IMPLEMENTED**
> This skill is currently under development and not yet available for use.

This skill helps you assess the risk and impact of changing kube-apiserver certificates on OpenShift clusters with ACM installed or planned.

## 🚀 Execution Instructions

**When this skill is invoked:**

1. **Inform the user that this skill is not yet implemented**
   - Display a clear message that the skill is under development
   - Suggest alternative approaches if applicable

## Usage

**With kubeconfig argument:**
```
User: run acm-cert-change-assessment kubeconfig.c3
```

**Without argument (will prompt for kubeconfig):**
```
User: run acm-cert-change-assessment
```

## When to Use This Skill

Invoke this skill when you need to:
- **Plan certificate type changes** (e.g., OpenShift-Managed to Custom)
- **Assess certificate rotation impact** on managed clusters
- **Evaluate root CA changes** before implementation
- **Understand risks** of certificate modifications with ACM

## Change Scenarios Covered

### 1. Certificate Type Change
- OpenShift-Managed → Custom Certificate
- Custom Certificate → Different CA
- Impact on managed clusters

### 2. Certificate Rotation
- Same type, new certificate
- Intermediate CA changes
- Validity period updates

### 3. Root CA Changes
- Adding root CA to chain
- Replacing root CA
- Root CA rotation

### 4. Intermediate CA Changes
- Different intermediate CA
- Intermediate CA rotation
- Chain modifications

## Risk Levels

- 🔴 **HIGH**: Will cause managed clusters to enter unknown state
- 🟡 **MEDIUM**: May cause temporary issues, requires coordination
- 🟢 **LOW**: Safe with proper configuration

## Prerequisites

- ✅ OpenShift cluster access with valid kubeconfig
- ✅ `oc` CLI installed
- ✅ Understanding of planned certificate change

---

## Assessment Process

1. **Current State Analysis**
   - Detect current certificate type
   - Check ACM installation status
   - Analyze certificate chain

2. **Change Details Capture**
   - Prompt for change type
   - Understand new certificate details
   - Identify timeline

3. **Risk Assessment**
   - Evaluate impact on ACM
   - Assess managed cluster impact
   - Identify potential issues

4. **Mitigation Guidance**
   - Provide step-by-step mitigation
   - Recommend best practices
   - Suggest alternatives if needed

---

## Troubleshooting

**KUBECONFIG not persisting:**
- ✅ Specify with --kubeconfig parameter

**oc command not found:**
- ✅ Ensure OpenShift CLI is installed
