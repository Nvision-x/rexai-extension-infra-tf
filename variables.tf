# =====================================================================
# Application Module Variables
# =====================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "rexai"
}

# AWS Configuration
variable "region" {
  description = "AWS region"
  type        = string
}

# VPC Configuration
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

# IAM Role ARNs from Module 1
variable "app_runner_role_arn" {
  description = "ARN of App Runner instance role"
  type        = string
}

variable "lambda_execution_role_arn" {
  description = "ARN of Lambda execution role"
  type        = string
}

variable "lambda_authorizer_role_arn" {
  description = "ARN of Lambda authorizer role"
  type        = string
}

variable "step_function_role_arn" {
  description = "ARN of Step Function role"
  type        = string
}

variable "apprunner_ecr_access_role_arn" {
  description = "ARN of App Runner ECR access role"
  type        = string
}

variable "apprunner_private_ips" {
  description = "List of private IP addresses for App Runner ENIs from OpenSearch module"
  type        = list(string)
}

variable "cognito_cloudwatch_role_arn" {
  description = "ARN of Cognito CloudWatch logs role from IAM module"
  type        = string
}

variable "cognito_authenticated_role_arn" {
  description = "ARN of Cognito authenticated users role from IAM module"
  type        = string
}

# VPC Configuration - Additional
variable "public_subnets" {
  description = "Public subnet IDs for NLB"
  type        = list(string)
}

# OpenSearch Configuration from Module 2
variable "opensearch_domain_endpoint" {
  description = "OpenSearch domain endpoint"
  type        = string
}

variable "opensearch_domain_name" {
  description = "OpenSearch domain name for ENI lookup"
  type        = string
}

variable "opensearch_master_username" {
  description = "OpenSearch master username"
  type        = string
}

variable "opensearch_master_password" {
  description = "OpenSearch master password"
  type        = string
  sensitive   = true
}

# OpenSearch NLB Configuration
variable "opensearch_private_ips" {
  description = "List of private IP addresses for OpenSearch ENIs"
  type        = list(string)
  default     = []
}

variable "opensearch_nlb_allowed_cidr_blocks" {
  description = "Allowed CIDRs for OpenSearch NLB access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "opensearch_nlb_enable_deletion_protection" {
  description = "Enable deletion protection for OpenSearch NLB"
  type        = bool
  default     = false
}

variable "configure_opensearch_backend_roles" {
  description = "Whether to configure OpenSearch backend role mappings"
  type        = bool
  default     = true
}

# Container Image URIs
variable "lambda_image_uri" {
  description = "Lambda container image URI"
  type        = string
}

variable "backend_image_uri" {
  description = "Backend container image URI"
  type        = string
}

# Lambda Configuration
variable "lambda_security_group_name" {
  description = "Security group for Lambda"
  type        = string
  default     = "rexai-lambda-sg"
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

# App Runner Configuration
variable "apprunner_endpoint_id" {
  description = "App Runner VPC endpoint ID from Module 2"
  type        = string
  default     = ""
}

variable "create_apprunner_ingress_connection" {
  description = "Whether to create App Runner VPC ingress connection. Set to false during destroy to avoid issues."
  type        = bool
  default     = true
}

# S3 Configuration
variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string
}

# Step Function Configuration
variable "step_function_name" {
  description = "Step Function name"
  type        = string
}

variable "state_machine_definition_file" {
  description = "Path to Step Function state machine definition JSON"
  type        = string
  default     = "step_functions_config.json"
}

# API Gateway Configuration
variable "api_gateway_name" {
  description = "API Gateway name"
  type        = string
}

variable "api_gateway_description" {
  description = "API Gateway description"
  type        = string
}

variable "lambda_authorizer_name" {
  description = "Lambda Authorizer name"
  type        = string
}

variable "apigw_lambda_function_name" {
  description = "Lambda function for API Gateway Authorizer"
  type        = string
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "prod"
}

# JWT Secret
variable "jwt_secret_value" {
  description = "JWT secret value (if not provided, will be auto-generated)"
  type        = string
  default     = ""
  sensitive   = true
}

# OpenSearch Index Configuration
variable "records_schedule_index" {
  description = "OpenSearch index for record schedules"
  type        = string
}

variable "jobs_master_index" {
  description = "OpenSearch index for jobs master"
  type        = string
}

variable "jobs_files_index" {
  description = "OpenSearch index for jobs files"
  type        = string
}

variable "jobs_execute_index" {
  description = "OpenSearch index for job execution"
  type        = string
}

variable "chat_conversation_index" {
  description = "OpenSearch index for chat conversations"
  type        = string
}

variable "cleanup_status_index" {
  description = "OpenSearch index for cleanup status"
  type        = string
}

# ML Model Configuration
variable "embedding_model_id" {
  description = "Embedding model ID"
  type        = string
}

variable "llm_model_id" {
  description = "LLM model ID"
  type        = string
}

# Processing Configuration
variable "batch_size" {
  description = "Batch size for processing"
  type        = string
}

variable "execution_chunk_size" {
  description = "Execution chunk size"
  type        = string
}

variable "default_user_id" {
  description = "Default user ID"
  type        = string
}

variable "min_score" {
  description = "Minimum score threshold"
  type        = string
}

variable "min_matched_terms" {
  description = "Minimum matched terms"
  type        = string
}

# Tags
variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Terraform = "true"
    Module    = "rexai-application"
  }
}

# =====================================================================
# Cognito Configuration Variables
# =====================================================================

# Cognito Callback URLs
variable "cognito_callback_urls" {
  description = "List of allowed callback URLs for the Cognito app client"
  type        = list(string)
  default     = []
}

# Cognito Logout URLs
variable "cognito_logout_urls" {
  description = "List of allowed logout URLs for the Cognito app client"
  type        = list(string)
  default     = []
}

# SAML Configuration
variable "enable_saml_provider" {
  description = "Whether to enable SAML identity provider (Okta)"
  type        = bool
  default     = true
}

variable "saml_metadata_url" {
  description = "SAML metadata URL for the identity provider"
  type        = string
}

# User Import Configuration
variable "import_cognito_users" {
  description = "Whether to import users from CSV file (notification only)"
  type        = bool
  default     = false
}

variable "cognito_users_csv_path" {
  description = "Path to CSV file containing users to import"
  type        = string
  default     = "nx_cognito_users.csv"
}

# Cognito User Pool Configuration
variable "cognito_mfa_configuration" {
  description = "MFA configuration for Cognito User Pool"
  type        = string
  default     = "OFF"
  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.cognito_mfa_configuration)
    error_message = "MFA configuration must be OFF, ON, or OPTIONAL"
  }
}

# Password Policy
variable "cognito_password_minimum_length" {
  description = "Minimum password length for Cognito User Pool"
  type        = number
  default     = 8
}

variable "cognito_password_require_uppercase" {
  description = "Require uppercase letters in password"
  type        = bool
  default     = true
}

variable "cognito_password_require_lowercase" {
  description = "Require lowercase letters in password"
  type        = bool
  default     = true
}

variable "cognito_password_require_numbers" {
  description = "Require numbers in password"
  type        = bool
  default     = true
}

variable "cognito_password_require_symbols" {
  description = "Require symbols in password"
  type        = bool
  default     = true
}

# Token Validity Configuration
variable "cognito_refresh_token_validity" {
  description = "Refresh token validity in days"
  type        = number
  default     = 30
}

variable "cognito_access_token_validity" {
  description = "Access token validity in hours"
  type        = number
  default     = 1
}

variable "cognito_id_token_validity" {
  description = "ID token validity in hours"
  type        = number
  default     = 1
}

# =====================================================================
# Frontend App Runner Configuration Variables
# =====================================================================

# IAM Role Configuration
variable "frontend_apprunner_instance_role_arn" {
  description = "ARN of the frontend App Runner instance role from IAM module"
  type        = string
}

# Container Image Configuration
variable "frontend_image_uri" {
  description = "Frontend container image URI from ECR"
  type        = string
  default     = ""
}

# Frontend Environment Configuration
variable "frontend_okta_redirect_uri" {
  description = "Okta sign-in redirect URI for frontend"
  type        = string
}

# Auto Deployment Configuration
variable "frontend_auto_deployments_enabled" {
  description = "Enable automatic deployments for frontend when image is updated"
  type        = bool
  default     = false
}

# Health Check Configuration
variable "frontend_health_check_path" {
  description = "Health check path for frontend"
  type        = string
  default     = "/"
}

variable "frontend_health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 10
}

variable "frontend_health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "frontend_health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks required"
  type        = number
  default     = 2
}

variable "frontend_health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks before unhealthy"
  type        = number
  default     = 5
}

# Instance Configuration
variable "frontend_cpu" {
  description = "CPU units for frontend App Runner service"
  type        = string
  default     = "1024"
}

variable "frontend_memory" {
  description = "Memory for frontend App Runner service"
  type        = string
  default     = "2048"
}

# Auto Scaling Configuration
variable "frontend_max_concurrency" {
  description = "Maximum concurrent requests per instance"
  type        = number
  default     = 100
}

variable "frontend_max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "frontend_min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

# VPC Configuration
variable "frontend_enable_vpc_connector" {
  description = "Enable VPC connector for frontend App Runner"
  type        = bool
  default     = true
}

# Observability Configuration
variable "frontend_observability_enabled" {
  description = "Enable AWS X-Ray tracing for frontend"
  type        = bool
  default     = false
}

# Custom Domain Configuration
variable "frontend_custom_domain" {
  description = "Custom domain name for frontend (optional)"
  type        = string
  default     = ""
}

variable "api_custom_domain" {
  description = "Custom domain name for API Gateway (optional)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domains (must be in us-east-1 for API Gateway)"
  type        = string
  default     = ""
}

variable "frontend_enable_www_subdomain" {
  description = "Enable www subdomain for custom domain"
  type        = bool
  default     = false
}

# Logging Configuration
variable "frontend_log_retention_days" {
  description = "Number of days to retain frontend logs"
  type        = number
  default     = 7
}