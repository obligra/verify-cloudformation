> **Historical documentation, superseded for this remediation candidate.** This document describes an earlier implementation or test. Do not follow its deployment, authentication, API URL or security claims as current guidance. Use the [current README](../README.md), which describes IAM-signed requests, the current capture route and outstanding release gates. Historical results below have not been rerun by this documentation update.

# Deployment Guide

## Prerequisites

- AWS CLI configured with appropriate credentials
- An AWS account where you want to deploy the proxy
- An Obligra Verify API key (generate via the Verify Console or SDK)
- `CAPABILITY_NAMED_IAM` permission to create IAM roles

## Deploy

### Using AWS CLI

```bash
aws cloudformation deploy \
  --template-file templates/verify-capture-proxy-preview.yaml \
  --stack-name verify-capture-proxy \
  --parameter-overrides \
    VerifyApiKey=obv_sandbox_YOURPREFIX.YOURSECRET \
    EnvironmentName=sandbox \
    AllowedOrigins="https://app.yourcompany.com,http://localhost:3000" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### Using a Parameters File

```bash
aws cloudformation deploy \
  --template-file templates/verify-capture-proxy-preview.yaml \
  --stack-name verify-capture-proxy \
  --parameter-overrides file://examples/basic-parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## Get the Endpoint URL

After deployment:

```bash
aws cloudformation describe-stacks \
  --stack-name verify-capture-proxy \
  --query "Stacks[0].Outputs[?OutputKey=='ProxyEndpoint'].OutputValue" \
  --output text
```

## Test the Endpoint

```bash
PROXY_URL=$(aws cloudformation describe-stacks --stack-name verify-capture-proxy --query "Stacks[0].Outputs[?OutputKey=='ProxyEndpoint'].OutputValue" --output text)

curl -s -X POST "$PROXY_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "workflowId": "deployment-test",
    "operationalContext": {"test": "true"},
    "model": {"provider": "test", "modelId": "test"}
  }'
```

Expected response (with valid API key):

```json
{
  "decisionRecordId": "dr_...",
  "status": "recorded",
  "verificationState": "not_verified",
  ...
}
```

## Update the Stack

To update parameters (e.g., rotate API key):

```bash
aws cloudformation deploy \
  --template-file templates/verify-capture-proxy-preview.yaml \
  --stack-name verify-capture-proxy \
  --parameter-overrides \
    VerifyApiKey=obv_sandbox_NEWPREFIX.NEWSECRET \
    EnvironmentName=sandbox \
  --capabilities CAPABILITY_NAMED_IAM
```

## Delete the Stack

```bash
aws cloudformation delete-stack --stack-name verify-capture-proxy
```

## Parameters Reference

| Parameter | Required | Default | Description |
|---|---|---|---|
| `VerifyApiKey` | Yes | — | Your Verify API key (NoEcho, never logged) |
| `VerifyApiBaseUrl` | No | Verify production URL | Override for custom endpoints |
| `EnvironmentName` | No | `sandbox` | Environment label |
| `AllowedOrigins` | No | `*` | CORS origins (comma-separated) |
| `LogRetentionDays` | No | `14` | CloudWatch log retention |

## Production Considerations

Before deploying to production:

- Restrict `AllowedOrigins` to your specific domains
- Consider adding AWS WAF for request filtering
- Consider deploying within a VPC with NAT for egress control
- Add a custom domain name via Route 53 + ACM certificate
- Enable X-Ray tracing for observability
- Rotate API keys on a scheduled basis
- Review IAM role permissions
- Set appropriate CloudWatch alarms on errors and latency
