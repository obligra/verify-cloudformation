# Obligra Verify — Customer Deployment Templates

AWS CloudFormation and Terraform templates for deploying the Obligra Verify capture proxy into your own AWS account.

## Overview

The Verify capture proxy is a lightweight, customer-owned serverless relay that forwards decision record capture requests to the Obligra Verify API. It runs in your AWS account, giving you full control over networking, logging, and access policies.

## Status

**Early Integration Preview**

- Validated against the deployed Obligra Verify environment
- Suitable for evaluation, testing, and integration development
- Production custom domain (`api.obligra.ai`) will be available after cutover

## Current Environment

| Setting | Value |
|---|---|
| Verify API Base URL (current preview) | `https://y1h3onv0f1.execute-api.us-east-1.amazonaws.com/dev` |
| Verify API Base URL (production, after domain cutover) | `https://api.obligra.ai/api/v1` |

> **Note:** The current preview URL is a temporary raw AWS API Gateway endpoint. It will be replaced by `https://api.obligra.ai/api/v1` at production launch. Templates using the default value will need a parameter update at cutover.

## Available Templates

| Template | Path | Description |
|---|---|---|
| CloudFormation | `templates/verify-capture-proxy-preview.yaml` | Single-file template with inline Lambda |
| Terraform | `terraform/verify-capture-proxy-preview/` | HCL module with variables, outputs |

## Quick Start — CloudFormation

### Prerequisites

- AWS CLI configured with credentials for your target account
- An Obligra Verify API key (create in the Verify Console)
- `CAPABILITY_NAMED_IAM` permission to create named IAM roles

### Deploy

```bash
aws cloudformation deploy \
  --template-file templates/verify-capture-proxy-preview.yaml \
  --stack-name obligra-verify-capture-proxy-test \
  --parameter-overrides \
    VerifyApiBaseUrl=https://y1h3onv0f1.execute-api.us-east-1.amazonaws.com/dev \
    VerifyApiKey=obv_sandbox_YOUR_PREFIX.YOUR_SECRET \
    EnvironmentName=sandbox \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2
```

### Get Endpoint

```bash
aws cloudformation describe-stacks \
  --stack-name obligra-verify-capture-proxy-test \
  --query "Stacks[0].Outputs[?OutputKey=='ProxyEndpoint'].OutputValue" \
  --output text --region us-west-2
```

### Test Capture

```bash
PROXY_URL=$(aws cloudformation describe-stacks \
  --stack-name obligra-verify-capture-proxy-test \
  --query "Stacks[0].Outputs[?OutputKey=='ProxyEndpoint'].OutputValue" \
  --output text --region us-west-2)

curl -s -X POST "$PROXY_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "workflowId": "deployment-test",
    "operationalContext": {
      "source": "cloudformation-proxy",
      "claimId": "claim-001"
    },
    "model": {
      "provider": "anthropic",
      "modelId": "claude-sonnet-4-20250514"
    }
  }'
```

Expected response:

```json
{
  "decisionRecordId": "dr_...",
  "status": "recorded"
}
```

> **Do not delete the stack until validation is complete.** Verify the record appears in the Verify Console first.

### Cleanup

```bash
aws cloudformation delete-stack \
  --stack-name obligra-verify-capture-proxy-test \
  --region us-west-2

aws cloudformation wait stack-delete-complete \
  --stack-name obligra-verify-capture-proxy-test \
  --region us-west-2
```

## Quick Start — Terraform

See `terraform/verify-capture-proxy-preview/README.md` for Terraform-specific instructions.

## Resources Created

The template creates:

| Resource | Type | Purpose |
|---|---|---|
| Lambda Function | `verify-capture-proxy-sandbox` | Forwards capture requests to Verify API |
| IAM Role | `verify-capture-proxy-sandbox-role` | Lambda execution (CloudWatch Logs only) |
| API Gateway HTTP API | `verify-capture-proxy-sandbox` | Public endpoint for capture requests |
| CloudWatch Log Group | `/aws/lambda/verify-capture-proxy-sandbox` | Operational logs (no payloads logged) |

## Security

- API key is `NoEcho` in CloudFormation and `sensitive` in Terraform — never printed in outputs or logs
- Lambda logs only operational metadata: request ID, workflow ID, status code, duration
- Lambda never logs: payloads, prompts, responses, API keys, customer data
- IAM role has CloudWatch Logs permissions only — no other AWS service access
- No Obligra AWS account IDs are hardcoded

## Documentation

- [Customer Integration Reference Architecture](docs/customer-integration-reference-architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Architecture](docs/architecture.md)
- [Security](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Validation Summary](docs/cloudformation-validation-summary.md)

## License

Apache License 2.0
