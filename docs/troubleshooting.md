# Troubleshooting

## Common Issues

### 401 — Invalid API Key

**Symptom:** Proxy returns `{"error":"unauthorized","message":"Invalid API key."}`

**Causes:**
- API key parameter is incorrect
- API key has been revoked
- API key format is malformed

**Resolution:**
1. Verify the key is active in the Verify Console
2. Confirm the full key value (prefix + secret) is passed to the stack
3. Redeploy the stack with the correct key:
   ```bash
   aws cloudformation deploy \
     --template-file templates/verify-capture-proxy-preview.yaml \
     --stack-name verify-capture-proxy \
     --parameter-overrides VerifyApiKey=obv_sandbox_CORRECT.KEYVALUE \
     --capabilities CAPABILITY_IAM
   ```
4. Check Lambda environment variables (key value is hidden but confirm it was updated by checking `LastModified`)

### 403 — CORS Blocked

**Symptom:** Browser console shows `Access-Control-Allow-Origin` error

**Causes:**
- `AllowedOrigins` parameter does not include your application's origin
- Origin header not sent in the request

**Resolution:**
1. Update `AllowedOrigins` to include your domain:
   ```bash
   aws cloudformation deploy \
     --template-file templates/verify-capture-proxy-preview.yaml \
     --stack-name verify-capture-proxy \
     --parameter-overrides AllowedOrigins="https://app.yourcompany.com" \
     --capabilities CAPABILITY_IAM
   ```
2. For development, use `*` (not recommended for production)
3. Confirm your request includes the `Origin` header

### 429 — Rate Limited

**Symptom:** Proxy returns HTTP 429 from the Verify API

**Causes:**
- Too many requests sent in a short period
- API rate limit exceeded for your plan

**Resolution:**
1. Implement exponential backoff in your application
2. The Verify SDK handles retries automatically — use it as a reference
3. If sustained, contact Obligra to discuss rate limit adjustments
4. Consider batching or throttling at the application level

### 502 — Proxy Error

**Symptom:** Proxy returns `{"error":"proxy_error","message":"Failed to reach Verify API"}`

**Causes:**
- Network timeout reaching the Verify API
- DNS resolution failure
- Verify API temporarily unavailable

**Resolution:**
1. Check Lambda CloudWatch logs for the error details:
   ```bash
   aws logs tail /aws/lambda/verify-capture-proxy-sandbox --since 5m
   ```
2. Verify the `VerifyApiBaseUrl` parameter is correct
3. Test connectivity from your account:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" https://verify-console.emergent.host/api/v1/health
   ```
4. If the Verify API is down, retry later or contact support

### 400 — Missing workflowId

**Symptom:** Proxy returns `{"error":"missing_workflow_id","message":"workflowId is required"}`

**Cause:** Request body does not contain a `workflowId` field.

**Resolution:** Ensure your request includes:
```json
{
  "workflowId": "your-workflow-name",
  "operationalContext": { ... },
  "model": { "provider": "...", "modelId": "..." }
}
```

### 400 — Invalid JSON

**Symptom:** Proxy returns `{"error":"invalid_json"}`

**Cause:** Request body is not valid JSON.

**Resolution:** Check `Content-Type: application/json` header and valid JSON body.

## Debugging

### View Proxy Logs

```bash
aws logs tail /aws/lambda/verify-capture-proxy-sandbox --since 10m --follow
```

Logs contain:
- `action: "forwarded"` — successful relay
- `action: "rejected"` — validation failure
- `action: "error"` — upstream failure
- `workflowId` — which workflow was captured
- `statusCode` — Verify API response code
- `durationMs` — round-trip time

### Check Lambda Configuration

```bash
aws lambda get-function-configuration \
  --function-name verify-capture-proxy-sandbox \
  --query "{Runtime:Runtime,MemorySize:MemorySize,Timeout:Timeout,LastModified:LastModified}"
```

### Check Stack Status

```bash
aws cloudformation describe-stacks \
  --stack-name verify-capture-proxy \
  --query "Stacks[0].{Status:StackStatus,Outputs:Outputs}"
```

## Getting Help

- General support: contact@obligra.ai
- Security issues: security@obligra.ai
- Include your stack name, region, and sanitized error output (no API keys or payloads)
