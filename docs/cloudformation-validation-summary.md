> **Historical documentation, superseded for this remediation candidate.** This document describes an earlier implementation or test. Do not follow its deployment, authentication, API URL or security claims as current guidance. Use the [current README](../README.md), which describes IAM-signed requests, the current capture route and outstanding release gates. Historical results below have not been rerun by this documentation update.

# CloudFormation Validation Summary

## Status: CF-LVF-001 RESOLVED ✅

**Classification:** Functional CloudFormation validation in Obligra Dev account.
**NOT a true external customer-account validation.** CF-CUST-001 remains open for account 063088900096.

## Validation Date

2026-06-15

## Deployment Details

| Item | Value |
|---|---|
| Account | Customer AWS account |
| Region | us-west-2 |
| Stack name | `obligra-verify-capture-proxy-test` |
| Template | `templates/verify-capture-proxy-preview.yaml` |
| Commit | `20e9f97` |
| Deploy method | `aws cloudformation deploy` from committed template |
| Manual Lambda env edits | **None** |
| Capabilities | `CAPABILITY_NAMED_IAM` |

## Validation Results

| Check | Result |
|---|---|
| Stack deployed from committed template only | ✅ |
| No manual Lambda environment edits | ✅ |
| Proxy returned HTTP 201 | ✅ |
| Response includes `status: recorded` | ✅ |
| Response includes `decisionRecordId` | ✅ `dr_5b70ba33-1a4a-403a-ab49-7c32b0342154` |
| Response includes `recordUrl` | ✅ |
| Ledger structural status valid | ✅ |
| CloudWatch logs confirmed safe | ✅ |
| API key NOT in logs | ✅ |
| Request payload NOT in logs | ✅ |
| Prompt/response NOT in logs | ✅ |
| Customer data NOT in logs | ✅ |
| IAM role has CloudWatch Logs only | ✅ |
| No Obligra account IDs hardcoded | ✅ |

## Created Resources

| Resource | Name |
|---|---|
| Lambda Function | `verify-capture-proxy-sandbox` |
| IAM Role | `verify-capture-proxy-sandbox-role` |
| API Gateway HTTP API | Customer-deployed proxy endpoint |
| CloudWatch Log Group | `/aws/lambda/verify-capture-proxy-sandbox` |

## Captured Record

| Field | Value |
|---|---|
| `decisionRecordId` | `dr_5b70ba33-1a4a-403a-ab49-7c32b0342154` |
| `status` | `recorded` |
| `workflowId` | `cfn-clean-validation` |
| `environment` | `sandbox` |
| `createdAt` | `2026-06-15T16:44:52.351Z` |
| `recordUrl` | `https://console.obligra.ai/records/dr_5b70ba33-1a4a-403a-ab49-7c32b0342154` |

## Current API Base URL

```
https://api.obligra.ai/api/v1
```

This is the Obligra Verify production API endpoint.

## Release Note

Before public release, update all templates and documentation to use:

```
https://api.obligra.ai/api/v1
```

The template `VerifyApiBaseUrl` parameter default and all README/documentation references must be updated at domain cutover.

## Open Items

| ID | Description | Status |
|---|---|---|
| CF-CUST-001 | Repeat CloudFormation deployment in true external customer account 063088900096 | Pending — requires SSO/profile access configuration |
| CF-PROD-001 | Update template default URL to `api.obligra.ai` at production domain cutover | Pending — blocked on domain availability |
| TF-VAL-001 | Terraform deployment validation (same scope as CloudFormation) | Not started |

## Cleanup

Resources remain deployed for manual inspection. Do not delete until explicitly approved.

Cleanup command (for later):

```bash
aws cloudformation delete-stack \
  --stack-name obligra-verify-capture-proxy-test \
  --region us-west-2 \
  --profile obligra-verify-dev

aws cloudformation wait stack-delete-complete \
  --stack-name obligra-verify-capture-proxy-test \
  --region us-west-2 \
  --profile obligra-verify-dev
```
