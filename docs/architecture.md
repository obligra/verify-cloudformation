> **Historical documentation, superseded for this remediation candidate.** This document describes an earlier implementation or test. Do not follow its deployment, authentication, API URL or security claims as current guidance. Use the [current README](../README.md), which describes IAM-signed requests, the current capture route and outstanding release gates. Historical results below have not been rerun by this documentation update.

# Architecture

## Overview

The Verify Capture Proxy is a customer-owned serverless relay that sits between your application and the Obligra Verify API.

```
Your Application
    │
    │  POST /decision-records
    │  (no API key in client)
    ▼
┌─────────────────────────────────┐
│  Customer-Owned AWS Account     │
│                                 │
│  API Gateway HTTP API           │
│       │                         │
│       ▼                         │
│  Lambda (capture proxy)         │
│       │                         │
│       │  POST /decision-records │
│       │  X-Verify-Api-Key: ...  │
│       ▼                         │
└─────────────────────────────────┘
         │
         │  HTTPS
         ▼
┌─────────────────────────────────┐
│  Obligra Verify API             │
│  (managed by Obligra)           │
└─────────────────────────────────┘
```

## Components

### API Gateway (HTTP API)

- Receives `POST /decision-records` from your application
- Handles CORS preflight (`OPTIONS`)
- Routes to Lambda proxy function
- No authentication configured by default (add your own if needed)

### Lambda Function

- Validates request body (requires `workflowId`)
- Forwards the payload to the Verify API
- Attaches `X-Verify-Api-Key` header (stored as environment variable, never logged)
- Returns the Verify API response to your application
- Logs only sanitized metadata: requestId, workflowId, statusCode, durationMs

### CloudWatch Logs

- Retains operational metadata only
- Never logs: payloads, prompts, responses, API keys, customer data
- Configurable retention (default 14 days)

### IAM Role

- Least privilege: CloudWatch Logs write only
- No DynamoDB, S3, SQS, or other service access
- No cross-account access

## Data Flow

1. Your application sends a capture request to the proxy endpoint
2. The proxy validates the request structure
3. The proxy forwards the request to Verify with the API key attached
4. Verify processes the record and returns a receipt
5. The proxy returns the receipt to your application
6. The proxy logs sanitized metadata (no payload content)

## What the Proxy Does NOT Do

- Does not persist decision record payloads
- Does not cache or buffer requests
- Does not modify the payload content
- Does not perform AI processing
- Does not access any other AWS services
- Does not log sensitive content

## Why Use a Proxy

| Use Case | Direct SDK | Capture Proxy |
|---|---|---|
| Simple server-side capture | ✅ Recommended | Optional |
| API key must not leave your network | — | ✅ Key stays in your account |
| Custom request validation needed | — | ✅ Add validation in Lambda |
| WAF / VPC egress control required | — | ✅ Deploy in VPC with NAT |
| Custom domain for capture endpoint | — | ✅ Add Route 53 + ACM |
| Client-side (browser) capture | — | ✅ Proxy holds the key |

## Alternative: Direct SDK Capture

If you don't need a proxy, the Verify SDK sends HTTPS requests directly:

```javascript
import { VerifyClient } from "@obligra/verify-sdk";

const verify = new VerifyClient({
  apiKey: process.env.VERIFY_API_KEY,
  environment: "sandbox"
});

await verify.captureDecisionRecord({ ... });
```

No additional infrastructure required.
