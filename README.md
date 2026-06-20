# Obligra Verify — CloudFormation Capture Proxy

> **Status: Early Integration Preview** — Validated against the deployed Obligra Verify environment. Suitable for evaluation, testing, and integration development.

## What This Is

A **customer-owned capture boundary** — a serverless proxy deployed via AWS CloudFormation that runs in your AWS account and controls what AI decision data becomes a retained record in Obligra Verify.

Verify is not a surveillance logger. You own the proxy. You own the policy. You decide what becomes a retained decision record. Policy evaluation occurs before data leaves your AWS account.

## Architecture

```
Customer Application
       │
       ▼
Customer-Owned API Gateway (your account)
       │
       ▼
Customer-Owned Lambda Capture Proxy (your account)
       │
       ▼
┌─────────────────────────────────────┐
│       Capture Policy Engine         │
│                                     │
│  Capture Decision Policy            │
│  (forward_all / intent_only/policy) │
│                                     │
│  Field Retention Policy             │
│  (allow / drop / redact / truncate) │
│                                     │
│  security.neverForward              │
│  (hard block — never leaves account)│
└─────────────────────────────────────┘
       │
       ▼  approved fields only
Obligra Verify API (Obligra-managed)
       │
       ▼
Decision Record (signed + stored)
       │
       ▼
Verify Console (retrieval + verification + audit)
```

**Key principle**: The Capture Policy Engine is the security and governance control point. Only fields that pass your policy reach Verify. Dropped and redacted fields never leave your AWS account.

## Customer-Owned Capture Policy

The capture policy is a first-class architectural component, not an implementation detail.

| Concern | How the Policy Addresses It |
|---------|----------------------------|
| Data governance | You explicitly declare what is retained vs dropped |
| Compliance auditability | Policy JSON is reviewable by compliance without reading code |
| Security boundary | Data physically cannot leave your account without passing through your policy |
| Trust model | You enforce your own rules — no need to trust Verify to drop fields |
| Explicit intent | Verify receives only what you consciously chose to send |

## Capture Decision Policy

The capture decision policy determines *whether* a request becomes a retained record.

| Mode | Behavior | Use Case |
|------|----------|----------|
| `forward_all` | Forwards all eligible requests | Sandbox, dev, testing |
| `intent_only` | Only workflowId + model metadata — no prompt/response/context | Application-controlled capture intent |
| `policy` | Proxy evaluates field rules before forwarding | Production, governance, enterprise |

## Field Retention Policy

When a request *is* captured, the field retention policy controls which fields are allowed to leave your account.

| Action | Behavior |
|--------|----------|
| `allow` | Field is forwarded to Verify |
| `drop` | Field is silently removed — never leaves the account |
| `redact` | Field name is preserved but value is removed |
| `truncate` | Field value is cut to `maxLength` characters |
| `neverForward` | Hard security block — field is always dropped regardless of other rules |

## Policy Example

```json
{
  "mode": "policy",
  "capture": {
    "operationalContext": {
      "allowedKeys": [
        "ticketId",
        "customerId",
        "severity",
        "environment"
      ],
      "dropUnknownKeys": true,
      "maxValueLength": 512
    },
    "prompt": {
      "allow": true,
      "maxLength": 500
    },
    "response": {
      "allow": true,
      "maxLength": 500
    },
    "model": {
      "includeProvider": true,
      "includeModelId": true
    }
  },
  "security": {
    "neverForward": [
      "authToken",
      "customerSSN",
      "internalNotes",
      "debugTrace",
      "rawPayload"
    ],
    "logRedactions": true
  }
}
```

## Policy Evaluation Example

Given an input with these fields:

| Input Field | Policy Action | Result |
|-------------|---------------|--------|
| `ticketId` | allow | ✅ Forwarded |
| `customerId` | allow | ✅ Forwarded |
| `severity` | allow | ✅ Forwarded |
| `environment` | allow | ✅ Forwarded |
| `prompt` | allow (max 500 chars) | ✅ Forwarded |
| `response` | allow (max 500 chars) | ✅ Forwarded |
| `authToken` | neverForward | ❌ Dropped |
| `customerSSN` | neverForward | ❌ Dropped |
| `internalNotes` | neverForward | ❌ Dropped |
| `debugTrace` | neverForward | ❌ Dropped |
| `rawPayload` | neverForward | ❌ Dropped |

Only the approved fields reach the Verify API. Dropped fields never leave the customer AWS account.

## Available Templates

| Template | Path | Description |
|----------|------|-------------|
| CloudFormation | `templates/verify-capture-proxy-preview.yaml` | Single-file template with inline Lambda |

Also available: [Terraform module](https://github.com/obligra/verify-terraform) for teams using Terraform.

## Resources Created

| Resource | Type | Purpose |
|----------|------|---------|
| Lambda Function | `verify-capture-proxy-{env}` | Applies capture policy, forwards to Verify |
| IAM Role | `verify-capture-proxy-{env}-role` | Lambda execution (CloudWatch Logs only) |
| API Gateway HTTP API | `verify-capture-proxy-{env}` | Invoke endpoint for capture requests |
| CloudWatch Log Group | `/aws/lambda/verify-capture-proxy-{env}` | Operational logs (no payloads logged) |

## Prerequisites

- AWS CLI configured with credentials for your target account
- An Obligra Verify API key (create in the Verify Console)
- `CAPABILITY_NAMED_IAM` permission to create named IAM roles

## Deploy

```bash
aws cloudformation deploy \
  --template-file templates/verify-capture-proxy-preview.yaml \
  --stack-name obligra-verify-capture-proxy \
  --parameter-overrides \
    VerifyApiKey=obv_your_key_here \
    EnvironmentName=sandbox \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2
```

### With Capture Policy

```bash
aws cloudformation deploy \
  --template-file templates/verify-capture-proxy-preview.yaml \
  --stack-name obligra-verify-capture-proxy \
  --parameter-overrides \
    VerifyApiKey=obv_your_key_here \
    EnvironmentName=sandbox \
    CapturePolicyJson='{"mode":"policy","capture":{"operationalContext":{"allowedKeys":["ticketId","severity"],"dropUnknownKeys":true},"prompt":{"allow":true,"maxLength":500},"response":{"allow":true,"maxLength":500}},"security":{"neverForward":["authToken","customerSSN"]}}' \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2
```

### Get Endpoint

```bash
aws cloudformation describe-stacks \
  --stack-name obligra-verify-capture-proxy \
  --query "Stacks[0].Outputs[?OutputKey=='ProxyEndpoint'].OutputValue" \
  --output text --region us-west-2
```

## Invoke Example

```bash
PROXY_URL=$(aws cloudformation describe-stacks \
  --stack-name obligra-verify-capture-proxy \
  --query "Stacks[0].Outputs[?OutputKey=='ProxyEndpoint'].OutputValue" \
  --output text --region us-west-2)

curl -s -X POST "$PROXY_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "workflowId": "my-workflow",
    "model": { "provider": "anthropic", "modelId": "claude-sonnet-4-20250514" },
    "operationalContext": {
      "ticketId": "TICKET-001",
      "severity": "medium",
      "environment": "production",
      "prompt": "Summarize this request.",
      "response": "The request has been summarized."
    }
  }'
```

Expected response (HTTP 201):
```json
{
  "decisionRecordId": "dr_...",
  "status": "recorded",
  "verificationState": "not_verified"
}
```

## Security & Logging

### Secrets Handling
- **CloudFormation**: `VerifyApiKey` parameter uses `NoEcho: true` — never printed in console, CLI output, or CloudFormation events
- **Lambda**: Key stored as encrypted environment variable (AWS Lambda service encryption)

### What Is Logged (safe metadata only)
- Timestamp, service name, request ID
- Workflow ID (not payload)
- Policy mode, HTTP status code, duration
- Dropped/redacted field counts (not field values)

### What Is Never Logged
- API keys
- Prompts or responses
- Dropped or redacted field values
- Auth tokens
- Customer PII
- Raw payloads

### IAM
- Least-privilege: the Lambda role can only write to its own CloudWatch log group
- No DynamoDB, S3, KMS, or other service access
- No network access beyond HTTPS egress to the Verify API

### Data Boundary
- The capture policy is applied *before* any data leaves your AWS account
- You own the Lambda, the API Gateway, and the policy
- Obligra has no access to your account, your VPC, or your data at rest

## What Happens After Deployment

1. Your application sends a POST to the proxy endpoint (from stack outputs)
2. The Lambda applies your capture policy (field filtering happens here)
3. Only approved fields are forwarded to the Verify API
4. Verify creates a signed decision record and returns a `decisionRecordId`
5. The record is retrievable and verifiable in the Verify Console
6. Verification confirms cryptographic integrity (hash + signature)

## Deployment Models

| Model | Who | When |
|-------|-----|------|
| **Builder** | Individual developer | Evaluation, sandbox, SDK testing — no proxy needed |
| **Production** | Engineering team | Single-team production workloads — proxy recommended |
| **Governance** | Platform/compliance team | Multi-team, compliance-required — proxy + policy required |
| **Enterprise** | Central infrastructure | Multi-account, regulated — proxy + policy + custom domain |

This CloudFormation template supports Production, Governance, and Enterprise patterns.

## Common Setup Issues

| Issue | Quick Fix | Details |
|-------|-----------|--------|
| Record never appears in Verify | Check API base URL and workspace alignment | [Troubleshooting →](docs/troubleshooting.md#record-never-appears-in-verify) |
| Invalid API key (401) | Ensure full key format `obv_{prefix}.{secret}` | [Troubleshooting →](docs/troubleshooting.md#invalid-api-key) |
| Capture policy skipping records | Check policy JSON for syntax errors | [Troubleshooting →](docs/troubleshooting.md#capture-policy-skipped-record) |
| Wrong AWS account deployment | Run `aws sts get-caller-identity` first | [Troubleshooting →](docs/troubleshooting.md#wrong-aws-account-deployment) |
| Verification unavailable | Confirm environment and workspace match | [Troubleshooting →](docs/troubleshooting.md#verification-issues) |
| CloudWatch logs appear empty | Check Lambda invocation and log group | [Troubleshooting →](docs/troubleshooting.md#cloudwatch-logs-look-empty) |
| CAPABILITY_NAMED_IAM error | Add `--capabilities CAPABILITY_NAMED_IAM` flag | [Troubleshooting →](docs/troubleshooting.md#capability_named_iam-required) |
| IAM role name collision (TF + CF same account) | Use unique `EnvironmentName` per deployment | [Troubleshooting →](docs/troubleshooting.md#terraform-and-cloudformation-iam-role-naming-collisions) |

## Validation Checklist

After deployment, confirm each step passes:

| # | Check | Expected |
|---|-------|----------|
| 1 | `aws sts get-caller-identity` | Correct account ID |
| 2 | Stack status | `CREATE_COMPLETE` |
| 3 | `ProxyEndpoint` output | Valid URL returned |
| 4 | POST to proxy endpoint | HTTP 201 + `decisionRecordId` |
| 5 | Record in Verify Console | Visible under correct workspace |
| 6 | Verify the record | `hashMatches: true`, `signatureValid: true` |
| 7 | Policy filtering | Allowed fields present, dropped fields absent |
| 8 | CloudWatch logs | No API keys, prompts, responses, or PII |

## Security Boundary

The capture proxy is the customer-owned security boundary between your application and Verify.

- **You own** the Lambda, the API Gateway, and the policy
- **You control** what fields leave your account
- **Obligra has no access** to your account, VPC, or data at rest
- **The policy is auditable** — compliance can review it without accessing application code
- **Secrets stay local** — API key uses `NoEcho` and encrypted Lambda env vars, never in logs or outputs

## Cleanup

```bash
aws cloudformation delete-stack \
  --stack-name obligra-verify-capture-proxy \
  --region us-west-2

aws cloudformation wait stack-delete-complete \
  --stack-name obligra-verify-capture-proxy \
  --region us-west-2
```

Removes all resources. No orphaned resources remain.

## Current Environment

| Setting | Value |
|---------|-------|
| Verify API Base URL | `https://api.obligra.ai/api/v1` |

The template uses the production URL as default.

## Learn More

- [Troubleshooting Verify Integrations](docs/troubleshooting.md)
- [Customer Integration Reference Architecture](docs/customer-integration-reference-architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Architecture](docs/architecture.md)
- [Security](docs/security.md)
- [Verify Node SDK](https://github.com/obligra/verify-node-sdk)
- [Terraform Deployment Option](https://github.com/obligra/verify-terraform)

## License

Apache License 2.0
