variable "verify_api_base_url" {
  type        = string
  default     = "https://verify-console.emergent.host/api/v1"
  description = "Base URL of the Obligra Verify capture API. Production (after cutover): https://api.obligra.ai/api/v1"
}

variable "verify_api_key" {
  type        = string
  sensitive   = true
  description = "Obligra Verify API key. Never logged or exposed in outputs."
}

variable "environment_name" {
  type        = string
  default     = "sandbox"
  description = "Environment label for naming and logging context."

  validation {
    condition     = contains(["sandbox", "dev", "staging", "production"], var.environment_name)
    error_message = "environment_name must be one of: sandbox, dev, staging, production."
  }
}

variable "allowed_origins" {
  type        = string
  default     = "*"
  description = "Comma-separated CORS origins. Use '*' for development only. Restrict in production."
}

variable "log_retention_days" {
  type        = number
  default     = 14
  description = "CloudWatch log group retention in days."

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90], var.log_retention_days)
    error_message = "log_retention_days must be one of: 1, 3, 5, 7, 14, 30, 60, 90."
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for deployment."
}
