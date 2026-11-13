> **Historical documentation, superseded for this remediation candidate.** This document describes an earlier implementation or test. Do not follow its deployment, authentication, API URL or security claims as current guidance. Use the [current README](../README.md), which describes IAM-signed requests, the current capture route and outstanding release gates. Historical results below have not been rerun by this documentation update.

# Security

## API Key Protection

The Verify API key is:

- Passed as a `NoEcho` CloudFormation parameter (never visible in stack outputs or console)
- Stored as a Lambda environment variable (encrypted at rest by AWS)
- Sent only over HTTPS to the Verify API
- **Never logged** by the proxy function

### Recommendations

- Store API keys in AWS Secrets Manager and reference via dynamic parameters
- Rotate keys on a regular schedule (monthly or quarterly)
- Use separate keys per environment (sandbox, staging, production)
- Revoke compromised keys immediately via the Verify Console

## Logging Policy

The proxy logs **only sanitized operational metadata**:

| Logged | Not Logged |
|---|---|
| requestId | Request body / payload |
| workflowId (if present) | operationalContext values |
| HTTP status code | Prompts |
| Duration (ms) | AI responses |
| Error codes | API keys |
| Timestamp | Customer records |

This ensures CloudWatch logs contain no sensitive content even if accessed by operators or exported to monitoring tools.

## IAM Least Privilege

The Lambda execution role has exactly one permission:

```yaml
- logs:CreateLogGroup
- logs:CreateLogStream
- logs:PutLogEvents
```

It has **no access** to:
- DynamoDB
- S3
- SQS / SNS
- Secrets Manager
- Any other AWS service
- Any cross-account resource

## CORS Configuration

- Default: `*` (allow all origins) — suitable for development only
- Production: restrict `AllowedOrigins` to your specific application domains
- The proxy handles CORS preflight (`OPTIONS`) requests

## Network Security

### Default Deployment

- Lambda runs in the AWS-managed network (no VPC)
- Outbound HTTPS to the Verify API endpoint
- No inbound access except via API Gateway

### Production Hardening

Consider:

- Deploy Lambda in a VPC with NAT Gateway for controlled egress
- Add AWS WAF to the API Gateway for request filtering
- Add rate limiting at the API Gateway level
- Use a custom domain with ACM certificate
- Enable AWS X-Ray for request tracing

## Payload Handling

The proxy:

- Validates that `workflowId` is present (basic structural check)
- Forwards the payload as-is to the Verify API
- Does not parse, store, cache, or transform the payload content
- Does not retain any request or response data after the invocation completes

## What This Template Does NOT Provide

- Authentication/authorization on the proxy endpoint (add your own Cognito, API keys, or IAM auth)
- Request rate limiting (configure at API Gateway level)
- WAF rules
- VPC deployment
- Custom domain
- Monitoring alarms

These are left to the customer to configure based on their security requirements.

## Incident Response

If you suspect an API key has been compromised:

1. Revoke the key immediately in the Verify Console
2. Generate a new key
3. Update the CloudFormation stack with the new key
4. Review CloudWatch logs for unauthorized usage patterns
5. Contact security@obligra.ai if you need assistance
