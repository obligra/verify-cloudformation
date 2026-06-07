# Launch Validation Findings

## Purpose

This document tracks issues discovered during Builder onboarding validation, SDK validation, customer-console validation, deployment validation, and launch readiness testing.

Only validated findings belong here.

Ideas, feature requests, roadmap items, and future enhancements should be tracked elsewhere.

## Status Definitions

| Status | Meaning |
|---|---|
| Open | Finding identified, not yet assigned |
| In Progress | Investigation or fix underway |
| Fixed | Code change completed |
| Retest Passed | Validation confirms fix works |
| Closed | Fully resolved |

## Severity Definitions

| Severity | Meaning |
|---|---|
| P0 | Launch blocker. Customer cannot complete core workflow. |
| P1 | Major issue. Workflow possible but significantly impaired. |
| P2 | Minor issue. Workaround exists. |
| P3 | Cosmetic or enhancement-level issue. |

## Finding Template

### Finding ID

LVF-001

### Date

YYYY-MM-DD

### Area

Examples:

- Builder Onboarding
- Cognito
- SDK
- CloudFormation
- Terraform
- API Keys
- Decision Records
- Evidence Reports
- Support

### Severity

P0 / P1 / P2 / P3

### Environment

Examples:

- Verify Preview
- Verify Dev
- Builder Plan
- Production Plan

### Step

Reference the validation step where the issue occurred.

Examples:

- Builder E2E Step 4
- SDK Validation
- CloudFormation Deploy

### Expected Behavior

Describe the expected outcome.

### Actual Behavior

Describe what actually occurred.

### Evidence

Links, screenshots, logs, console output, request IDs, or supporting notes.

Do not include secrets.

### Suspected Cause

Optional.

### Owner

Person or system responsible for investigation.

### Status

Open / In Progress / Fixed / Retest Passed / Closed

### Resolution

Describe the implemented fix.

### Retest Notes

Document validation after the fix.

## Active Findings

None currently.

## Closed Findings

None currently.

## Launch Exit Criteria

The following must pass before launch:

- Builder signup
- Email verification
- First login
- Automatic provisioning
- API key creation
- SDK capture
- First record visibility
- Record verification
- Evidence Report generation
- Support ticket submission
- SES email delivery
- CloudFormation deployment
- Terraform deployment

All P0 and P1 findings must be Closed.

No known launch blockers may remain open.
