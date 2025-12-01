# ACM Certificate Change Risk Assessment Skill

> ⚠️ **STATUS: NOT YET IMPLEMENTED**
>
> This skill is currently under development and not yet available for use.

This skill helps assess the risk and impact of changing kube-apiserver certificates on OpenShift clusters with ACM.

## Purpose

Provides risk analysis and mitigation guidance for:
- Certificate type changes
- Certificate rotations
- Root CA modifications
- Intermediate CA changes

## Usage

```bash
# Via Claude Code (when implemented)
run acm-cert-change-assessment kubeconfig.yaml

# Direct execution (when implemented)
bash .claude/skills/acm-cert-change-assessment/scripts/assess-change.sh --kubeconfig kubeconfig.yaml
```

**Note**: This skill is not yet functional. The examples above show the intended usage once implementation is complete.

## Planned Change Scenarios

The following scenarios describe the intended functionality once this skill is implemented:

### 1. Certificate Type Change
**Example**: OpenShift-Managed → Custom Certificate

**With ACM Installed**: 🔴 HIGH RISK
- Causes managed clusters to enter unknown state
- Requires manual intervention on all managed clusters
- Recommendation: Avoid if possible, consider cluster reinstallation

**Without ACM**: 🟢 LOW RISK
- Complete before installing ACM
- No impact on managed clusters

### 2. Certificate Rotation (Same Type)
**Example**: Renewing expired certificate

**Same Intermediate CA**: 🟢 LOW RISK
- Standard maintenance operation
- No special ACM considerations

**Different Intermediate CA**:
- **Without Root CA**: 🔴 HIGH RISK - Add root CA first
- **With Root CA**: 🟡 MEDIUM RISK - Coordinate carefully

### 3. Root CA Changes

**Adding Root CA**: 🟢 LOW RISK
- Safe operation
- Improves future rotation safety
- No immediate impact

**Replacing Root CA**: 🔴 HIGH RISK
- Breaks trust for all managed clusters
- Requires manual intervention everywhere
- Avoid if possible

### 4. Intermediate CA Change

**Without Root CA**: 🔴 HIGH RISK
- Add root CA first, then change intermediate CA

**With Root CA**: 🟡 MEDIUM RISK
- Manageable with proper coordination
- Test with one cluster first

## Risk Levels

- 🔴 **HIGH**: Will cause managed clusters to enter unknown state
- 🟡 **MEDIUM**: Requires careful coordination, may cause temporary issues
- 🟢 **LOW**: Safe operation with standard procedures

## Assessment Process

1. **Analyzes Current State**
   - Certificate type
   - ACM installation status
   - Root CA inclusion

2. **Captures Change Intent**
   - Interactive prompts
   - Change type selection
   - Target configuration

3. **Assesses Risk**
   - Evaluates impact on ACM
   - Identifies managed cluster impact
   - Determines risk level

4. **Provides Mitigation**
   - Specific steps for the scenario
   - Best practices
   - Alternatives if risk is high

## Planned Example Output

When implemented, the output will look like:

```
━━━ Step 3: Risk Assessment

🔴 HIGH RISK: Changing certificate type with ACM installed will cause managed clusters to enter unknown state.

━━━ Step 4: Mitigation Guidance

• This change is NOT recommended with ACM already installed
• Managed clusters will lose connection and enter unknown state
• Manual intervention required for each managed cluster
• Consider cluster reinstallation if certificate type change is mandatory
• Alternative: Keep current certificate type and work with support if issues arise

━━━ Assessment Summary

Change Type:          Certificate Type Change
Current Cert Type:    OpenShift-Managed
Target Cert Type:     Custom-SelfSigned
ACM Installed:        true
Root CA Included:     Yes
Risk Level:           HIGH
```

## Integration

This skill leverages:
- `acm-status-detection` - Detects ACM installation
- `ocp-cert-analysis` - Analyzes current certificates

## Files

- `SKILL.md` - Skill definition
- `scripts/assess-change.sh` - Main assessment script
- `README.md` - This file

## Prerequisites

- OpenShift CLI (`oc`) installed
- Valid kubeconfig with cluster access
- Understanding of planned certificate change
