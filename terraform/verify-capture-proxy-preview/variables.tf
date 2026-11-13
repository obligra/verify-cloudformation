variable "verify_api_base_url" {
  type        = string
  default     = "https://api.obligra.ai"
  description = "Base URL of the Obligra Verify capture API. Example: https://api.obligra.ai"
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


variable "capture_policy_json" {
  type = string
  default = "{\"mode\":\"intent_only\"}"
  description = "JSON capture policy; empty uses intent_only and malformed configuration fails closed."
}
