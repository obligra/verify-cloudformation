provider "aws" {
  region = var.aws_region
}

locals {
  function_name = "verify-capture-proxy-${var.environment_name}"
}

# ─── Lambda Function Code ──────────────────────────────────────────────────────

data "archive_file" "proxy_lambda" {
  type        = "zip"
  output_path = "${path.module}/.build/proxy.zip"

  source {
    content  = <<-NODEJS
const https = require('https');
const url = require('url');

const VERIFY_URL = process.env.VERIFY_API_BASE_URL;
const API_KEY = process.env.VERIFY_API_KEY;
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '*').split(',').map(s => s.trim());

exports.handler = async (event) => {
  const start = Date.now();
  const requestId = event.requestContext?.requestId || 'unknown';
  const method = event.requestContext?.http?.method || event.httpMethod;
  const origin = event.headers?.origin || event.headers?.Origin || '';

  if (method === 'OPTIONS') {
    return corsResponse(204, '', origin);
  }

  if (method !== 'POST') {
    log({ requestId, action: 'rejected', reason: 'method_not_allowed' });
    return corsResponse(405, JSON.stringify({ error: 'method_not_allowed' }), origin);
  }

  let body;
  try {
    body = JSON.parse(event.body || '{}');
  } catch {
    log({ requestId, action: 'rejected', reason: 'invalid_json' });
    return corsResponse(400, JSON.stringify({ error: 'invalid_json' }), origin);
  }

  if (!body.workflowId) {
    log({ requestId, action: 'rejected', reason: 'missing_workflow_id' });
    return corsResponse(400, JSON.stringify({ error: 'missing_workflow_id', message: 'workflowId is required' }), origin);
  }

  try {
    const result = await forwardToVerify(JSON.stringify(body));
    const duration = Date.now() - start;
    log({ requestId, action: 'forwarded', workflowId: body.workflowId, statusCode: result.statusCode, durationMs: duration });
    return corsResponse(result.statusCode, result.body, origin);
  } catch (err) {
    const duration = Date.now() - start;
    log({ requestId, action: 'error', workflowId: body.workflowId, errorCode: err.code || 'PROXY_ERROR', durationMs: duration });
    return corsResponse(502, JSON.stringify({ error: 'proxy_error', message: 'Failed to reach Verify API' }), origin);
  }
};

function forwardToVerify(payload) {
  return new Promise((resolve, reject) => {
    const target = new URL(VERIFY_URL + '/decision-records');
    const options = {
      hostname: target.hostname,
      port: 443,
      path: target.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Verify-Api-Key': API_KEY,
        'Content-Length': Buffer.byteLength(payload),
      },
      timeout: 10000,
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => { resolve({ statusCode: res.statusCode, body: data }); });
    });

    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('TIMEOUT')); });
    req.write(payload);
    req.end();
  });
}

function corsResponse(statusCode, body, origin) {
  const allowOrigin = ALLOWED_ORIGINS.includes('*') ? '*' : (ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]);
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': allowOrigin,
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
    body: body || '',
  };
}

function log(fields) {
  // SECURITY: Never log payloads, API keys, prompts, responses, or customer data.
  console.log(JSON.stringify({ timestamp: new Date().toISOString(), service: 'verify-capture-proxy', ...fields }));
}
NODEJS
    filename = "index.js"
  }
}

# ─── IAM Role ──────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "proxy_lambda" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "proxy_lambda_logs" {
  name = "CloudWatchLogsOnly"
  role = aws_iam_role.proxy_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.function_name}:*"
    }]
  })
}

# ─── CloudWatch Log Group ──────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "proxy" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

# ─── Lambda Function ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "proxy" {
  function_name    = local.function_name
  role             = aws_iam_role.proxy_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = 128
  timeout          = 15
  filename         = data.archive_file.proxy_lambda.output_path
  source_code_hash = data.archive_file.proxy_lambda.output_base64sha256

  environment {
    variables = {
      VERIFY_API_BASE_URL = var.verify_api_base_url
      VERIFY_API_KEY      = var.verify_api_key
      ENVIRONMENT_NAME    = var.environment_name
      ALLOWED_ORIGINS     = var.allowed_origins
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.proxy,
    aws_iam_role_policy.proxy_lambda_logs,
  ]
}

# ─── API Gateway HTTP API ──────────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "proxy" {
  name          = local.function_name
  protocol_type = "HTTP"
  description   = "Customer-owned Verify capture proxy endpoint"
}

resource "aws_apigatewayv2_integration" "proxy" {
  api_id                 = aws_apigatewayv2_api.proxy.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.proxy.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_capture" {
  api_id    = aws_apigatewayv2_api.proxy.id
  route_key = "POST /decision-records"
  target    = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_route" "options_capture" {
  api_id    = aws_apigatewayv2_api.proxy.id
  route_key = "OPTIONS /decision-records"
  target    = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.proxy.id
  name        = "$default"
  auto_deploy = true
}

# ─── Lambda Permission for API Gateway ─────────────────────────────────────────

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.proxy.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.proxy.execution_arn}/*"
}
