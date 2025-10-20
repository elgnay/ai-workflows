# Konflux Build Status Analysis

Automated analysis tool for tracking Server Foundation components' Konflux build status across ACM and MCE version pairs.

## Overview

This workflow downloads the latest Konflux tracking data from Google Sheets, analyzes Server Foundation components across all ACM and MCE version pairs, and generates comprehensive status reports.

## Prerequisites

- `gdocs` and `xlsx` tools from [google-docs](https://github.com/elgnay/google-docs)
  - `gdocs`: For downloading Google Sheets to local files
  - `xlsx`: For exporting Excel sheets to CSV format
- Google Sheets access to the Konflux Tracking spreadsheet

### Installing the Tools

Clone and build the tools from the repository:

```bash
git clone https://github.com/elgnay/google-docs.git
cd google-docs
# Follow the repository's build instructions
# Copy the built binaries to ./bin/ directory in this project
```

## Quick Start

1. Provide the Google Sheets URL when prompted
2. The tool will automatically:
   - Download the latest spreadsheet
   - Export all version sheets to CSV
   - Analyze Server Foundation components
   - Generate status tables
   - Clean up temporary files

## Version Pairs Analyzed

| ACM Version | MCE Version | Relationship |
|-------------|-------------|--------------|
| ACM 2.15    | MCE 2.10    | Latest       |
| ACM 2.14    | MCE 2.9     | Previous     |
| ACM 2.13    | MCE 2.8     | -            |
| ACM 2.12    | MCE 2.7     | -            |
| ACM 2.11    | MCE 2.6     | -            |

## Server Foundation Components

The analysis focuses exclusively on components where `Owning Squad` = "Server Foundation":

### ACM Components
- klusterlet-addon-controller

### MCE Components
- addon-manager
- cluster-proxy-addon
- cluster-proxy
- clusterlifecycle-state-metrics
- managed-serviceaccount
- managedcluster-import-controller
- multicloud-manager
- placement
- registration
- registration-operator
- work

## Metrics Tracked

For each component, the following metrics are analyzed:

1. **Promotion Status**: Success/failure of image promotions
2. **Hermetic Build Status**: Whether hermetic builds are enabled
3. **Enterprise Contract Status**: Compliance status (Compliant/Push Failure/Not Compliant)
4. **Multi-Arch Status**: Multi-architecture build support

## Status Indicators

- ✅ **Compliant/Successful/Enabled**: All checks passing
- ⚠️ **Push Failure**: Warning, needs attention
- ❌ **Failed/Not Compliant**: Critical issue requiring action

## Output Format

Each version pair includes:
- Combined components table (ACM + MCE)
- Summary statistics showing:
  - Promotion success rate
  - Hermetic build rate
  - Enterprise Contract compliance
  - Multi-arch support
  - Issue count

## Manual Commands

### Download Spreadsheet
```bash
./bin/gdocs -file "GOOGLE_SHEETS_URL" -format xlsx -output "Konflux Tracking (ACM _ MCE).xlsx"
```

### List Available Sheets
```bash
./bin/xlsx list --file "Konflux Tracking (ACM _ MCE).xlsx"
```

### Export Specific Version
```bash
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "ACM 2.15" --output acm_2_15.csv --format csv
./bin/xlsx export --file "Konflux Tracking (ACM _ MCE).xlsx" --sheet "MCE 2.10" --output mce_2_10.csv --format csv
```

### Filter Server Foundation Components
```bash
grep -i "Server Foundation" mce_2_10.csv
```

### Count Components
```bash
grep -i "Server Foundation" mce_2_10.csv | wc -l
```

### Find EC Failures
```bash
grep -i "Server Foundation" mce_2_10.csv | grep -E "Push Failure|Not Compliant"
```

## Workflow Details

See [CLAUDE.md](CLAUDE.md) for complete workflow instructions and automation guidelines.

## Notes

- Only components with `Owning Squad` exactly matching "Server Foundation" are included
- Temporary CSV files are automatically cleaned up after analysis
- The spreadsheet is downloaded fresh on each run to ensure latest data
