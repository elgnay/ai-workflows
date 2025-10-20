# Konflux Build Status Analysis Workflow

This document describes the workflow for analyzing Server Foundation components' Konflux build status across all ACM and MCE version pairs.

## Prerequisites

- `gdocs` tool available in the project directory (for downloading the spreadsheet)
- `xlsx` tool available in the project directory (for exporting sheets)
- Google Sheets URL or ID for the Konflux Image Promotion spreadsheet

## Workflow Steps

### 1. Download the Latest Spreadsheet

**IMPORTANT:** Before starting the analysis, ask the user to provide the Google Sheets URL or document ID for the Konflux Image Promotion spreadsheet.

Example prompt:
```
Please provide the Google Sheets URL for the Konflux Tracking spreadsheet.
```

Once received, download the latest version from Google Sheets:

```bash
./bin/gdocs -file "USER_PROVIDED_URL" -format xlsx -output "Konflux Tracking (ACM _ MCE).xlsx"
```

### 2. List Available Sheets

First, list all sheets in the Excel file to identify which versions are available:

```bash
./bin/xlsx list --file "Konflux Tracking (ACM _ MCE).xlsx"
```

This will show sheets like:
- ACM 2.15, MCE 2.10
- ACM 2.14, MCE 2.9
- ACM 2.13, MCE 2.8
- ACM 2.12, MCE 2.7
- ACM 2.11, MCE 2.6
- etc.

**Note:** Ignore sheets with names like "ACM 2.15 MCE 2.10 Release Cuto" (these are not data sheets).

### 3. Export Relevant Sheets to CSV

Export each ACM and MCE version pair sheet to CSV format:

```bash
# For ACM 2.15 & MCE 2.10
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "ACM 2.15" --output acm_2_15.csv --format csv
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "MCE 2.10" --output mce_2_10.csv --format csv

# For ACM 2.14 & MCE 2.9
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "ACM 2.14" --output acm_2_14.csv --format csv
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "MCE 2.9" --output mce_2_9.csv --format csv

# For ACM 2.13 & MCE 2.8
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "ACM 2.13" --output acm_2_13.csv --format csv
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "MCE 2.8" --output mce_2_8.csv --format csv

# For ACM 2.12 & MCE 2.7
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "ACM 2.12" --output acm_2_12.csv --format csv
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "MCE 2.7" --output mce_2_7.csv --format csv

# For ACM 2.11 & MCE 2.6
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "ACM 2.11" --output acm_2_11.csv --format csv
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "MCE 2.6" --output mce_2_6.csv --format csv
```

### 4. Read and Analyze CSV Files

Read each exported CSV file to extract Server Foundation component data:

**CRITICAL FILTERING RULE:**
- **ONLY** include rows where `Owning Squad` column **EXACTLY equals** "Server Foundation"
- **EXCLUDE** all other components, including:
  - Components with squads like "Hypershift / Observability"
  - Components with squads like "Observability"
  - Components with any squad value other than exactly "Server Foundation"

**Data to extract for Server Foundation components:**
  - Konflux Component
  - Last Image Promotion Time
  - Promotion Status
  - Hermetic Build Status
  - Enterprise Contract Status
  - Multi-Arch Status

**Validation Step:**
Before creating the analysis tables, verify that each component's `Owning Squad` is exactly "Server Foundation" by double-checking the CSV data.

### 5. Create Version Pair Analysis

For each ACM and MCE version pair, create a combined analysis table showing:

#### Table Format

| Component | Version | Last Promotion | Status | Hermetic | Enterprise Contract | Multi-Arch |
|-----------|---------|---------------|---------|----------|---------------------|------------|
| [component-name] | ACM X.XX or MCE X.XX | YYYY-MM-DD HH:MM:SS | ✅/❌ | ✅/❌ | ✅/⚠️ | ✅/❌ |

#### Summary Format

For each version pair, include a concise summary:

```
**Summary:**
✅ X% Promotion | ✅ X% Hermetic | ⚠️ X% EC (N failures) | ✅ X% Multi-Arch
```

**Notes:**
- Only show the number of failures in the summary (e.g., "4 failures", "1 failure")
- Do NOT include a separate "Issues" section listing individual component failures
- The table itself contains all the information needed to identify which components have issues

### 6. Version Pairing Strategy

Pair ACM and MCE versions as follows:

| ACM Version | MCE Version | Release Relationship |
|-------------|-------------|---------------------|
| ACM 2.15 | MCE 2.10 | Latest |
| ACM 2.14 | MCE 2.9 | Previous |
| ACM 2.13 | MCE 2.8 | - |
| ACM 2.12 | MCE 2.7 | - |
| ACM 2.11 | MCE 2.6 | - |

### 7. Status Indicators

Use the following emoji indicators for quick visual status:

- ✅ **Compliant/Successful/Enabled**: Green status, everything working
- ⚠️ **Push Failure**: Yellow warning, needs attention
- ❌ **Failed/Not Compliant**: Red status, critical issue

### 8. Output Format

The final output should contain:

1. **Individual Version Pair Sections** (5 sections total)
   - Version Pair 1: ACM 2.15 & MCE 2.10
   - Version Pair 2: ACM 2.14 & MCE 2.9
   - Version Pair 3: ACM 2.13 & MCE 2.8
   - Version Pair 4: ACM 2.12 & MCE 2.7
   - Version Pair 5: ACM 2.11 & MCE 2.6

2. **Each section includes:**
   - Combined components table (ACM + MCE)
   - Summary statistics ONLY

3. **What NOT to include:**
   - Do NOT add a "Cross-Version Analysis" section
   - Do NOT add an "Issues" list after each version pair
   - Do NOT add additional analysis, recommendations, or commentary
   - Keep the output clean and focused on the data tables and summaries

## Key Metrics to Track

For each version pair, track:

1. **Total Components**: Count of Server Foundation components
2. **Promotion Success Rate**: % of successful promotions
3. **Hermetic Build Rate**: % with hermetic builds enabled
4. **Enterprise Contract Compliance**: % compliant (excluding Push Failures and Not Compliant)
5. **Multi-Arch Support**: % with multi-arch enabled
6. **Issue Count**: Number of EC failures/issues

## Common Issues to Watch For

- **Persistent Issues**: Components failing across multiple versions
- **Regressions**: Components that were compliant in older versions but fail in newer ones
- **EC Push Failures**: Most common Enterprise Contract issue
- **Not Compliant Status**: Indicates configuration or policy violations

## Analysis Tips

1. **Compare version pairs** to identify trends (improving vs degrading)
2. **Track specific components** across versions to see their history
3. **Focus on latest version** (ACM 2.15 & MCE 2.10) for immediate action items
4. **Use older versions** (MCE 2.8, MCE 2.6) as reference for 100% compliant configurations

## Example Quick Analysis Commands

```bash
# Count Server Foundation components in a specific version
grep -i "Server Foundation" acm_2_15.csv | wc -l
grep -i "Server Foundation" mce_2_10.csv | wc -l

# Find EC failures in a specific version
grep -i "Server Foundation" mce_2_10.csv | grep -E "Push Failure|Not Compliant"

# View all Server Foundation component details
grep -i "Server Foundation" mce_2_10.csv
```

## Cleanup

After analysis completes, **automatically remove** the exported CSV files:

```bash
rm acm_*.csv mce_*.csv
```

This ensures the workspace stays clean and prevents stale data from being used in future analyses.

**IMPORTANT:** After cleanup, do NOT add any additional commentary. The analysis is complete once the 5 version pair sections are shown and CSV files are cleaned up.
