# Verify Capture Proxy — Terraform (Early Preview)

Terraform module for deploying a customer-owned Obligra Verify capture proxy.

## Overview

This module deploys a serverless relay that forwards decision record capture requests from your application to the Obligra Verify API. The API key stays in your AWS account and is never exposed to client applications.

## This Module Is Optional

Direct SDK-to-Verify capture is also supported. Use this proxy only if:

- Your security policy requires all outbound traffic through customer-owned infrastructure
- You need WAF, VPC egress control, or custom domain on the capture path
- You want client-side (browser) capture without exposing the API key
- You need custom request validation before records reach Verify

## Usage

```hcl
module "verify_proxy" {
  source = "./terraform/verify-capture-proxy-preview"

  verify_api_key   = var.verify_api_key  # sensitive, from tfvars or secrets manager
  environment_name = "sandbox"
  allowed_origins  = "https://app.yourcompany.com,http://localhost:3000"
}

output "capture_endpoint" {
  value = module.verify_proxy.proxy_endpoint
}
```

## Deploy

```bash
terraform init
terraform plan -var="verify_api_key=obv_sandbox_YOURPREFIX.YOURSECRET"
terraform apply -var="verify_api_key=obv_sandbox_YOURPREFIX.YOURSECRET"
```

Or use a `.tfvars` file (do not commit to source control):

```bash
# terraform.tfvars (add to .gitignore)
verify_api_key   = "obv_sandbox_YOURPREFIX.YOURSECRET"
environment_name = "sandbox"
allowed_origins  = "https://app.yourcompany.com"
```

```bash
terraform init
terraform plan
terraform apply
```

## Test

```bash
PROXY_URL=$(terraform output -raw proxy_endpoint)

curl -s -X POST "$PROXY_URL" \
  -H "Content-Type: application/json" \
  -d '{"workflowId":"test","operationalContext":{"test":"true"},"model":{"provider":"test","modelId":"test"}}'
```

## Destroy

```bash
terraform destroy -var="verify_api_key=obv_sandbox_YOURPREFIX.YOURSECRET"
```

## Variables

| Variable | Type | Required | Default | Description |
|---|---|---|---|---|
| `verify_api_key` | string (sensitive) | Yes | — | Verify API key |
| `verify_api_base_url` | string | No | Verify production URL | API endpoint |
| `environment_name` | string | No | `sandbox` | Environment label |
| `allowed_origins` | string | No | `*` | CORS origins (comma-separated) |
| `log_retention_days` | number | No | `14` | Log retention |
| `aws_region` | string | No | `us-east-1` | Deployment region |

## Outputs

| Output | Description |
|---|---|
| `proxy_endpoint` | Capture proxy URL (`POST /decision-records`) |
| `proxy_function_name` | Lambda function name |
| `proxy_function_arn` | Lambda function ARN |
| `api_gateway_id` | HTTP API ID |

## Security

- `verify_api_key` is marked `sensitive = true` — never shown in plan output
- Lambda IAM role has only CloudWatch Logs permissions
- Lambda never logs payloads, API keys, prompts, responses, or customer data
- Only sanitized metadata is logged: requestId, workflowId, statusCode, durationMs

### Production Hardening

Before production use:

- Restrict `allowed_origins` to your specific domains
- Store API key in AWS Secrets Manager or Terraform Vault provider
- Consider deploying Lambda in a VPC with NAT
- Add WAF to API Gateway
- Add custom domain with ACM certificate
- Enable X-Ray tracing
- Add CloudWatch alarms on errors

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| 401 from proxy | Invalid API key | Update `verify_api_key` and `terraform apply` |
| CORS error in browser | `allowed_origins` missing your domain | Update variable and apply |
| 502 proxy error | Verify API unreachable or timeout | Check connectivity, retry |
| 429 rate limited | Too many requests | Implement backoff in your app |

## Status

**Early Preview** — interfaces may change before general availability. Review all security controls before production deployment.
