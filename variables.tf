variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "stepfunctions-poc"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "StepFunctions-POC"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "nodejs20.x"
}

variable "state_machine_timeout_seconds" {
  description = "Step Functions state machine timeout in seconds"
  type        = number
  default     = 3600 # 1 hour
}
