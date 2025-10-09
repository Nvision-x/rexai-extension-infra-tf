# =====================================================================
# Application Module Outputs
# =====================================================================

# S3 Bucket
output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.rexai_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.rexai_bucket.arn
}

# JWT Secret
output "jwt_secret_arn" {
  description = "ARN of the JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "jwt_secret_name" {
  description = "Name of the JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.name
}

# Lambda Function
output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "lambda_sg_id" {
  description = "Security group ID for Lambda"
  value       = aws_security_group.lambda_sg.id
}

# Step Function
output "step_function_arn" {
  description = "ARN of the Step Function state machine"
  value       = aws_sfn_state_machine.invoke_lambda_step_function.arn
}

output "step_function_name" {
  description = "Name of the Step Function"
  value       = aws_sfn_state_machine.invoke_lambda_step_function.name
}

# App Runner
output "app_runner_service_url" {
  description = "URL of the App Runner service"
  value       = module.app_runner_private.service_url
}

output "app_runner_service_arn" {
  description = "ARN of the App Runner service"
  value       = module.app_runner_private.service_arn
}

output "app_runner_service_id" {
  description = "ID of the App Runner service"
  value       = module.app_runner_private.service_id
}

# OpenSearch NLB Outputs
output "opensearch_nlb_dns" {
  description = "DNS name of the OpenSearch NLB"
  value       = aws_lb.opensearch_nlb.dns_name
}

output "opensearch_nlb_url" {
  description = "URL to access OpenSearch via NLB"
  value       = "https://${aws_lb.opensearch_nlb.dns_name}"
}

output "opensearch_nlb_zone_id" {
  description = "Zone ID of the OpenSearch NLB for Route53 alias records"
  value       = aws_lb.opensearch_nlb.zone_id
}

output "opensearch_nlb_arn" {
  description = "ARN of the OpenSearch NLB"
  value       = aws_lb.opensearch_nlb.arn
}

# NLB
output "nlb_dns_name" {
  description = "DNS name of the NLB"
  value       = aws_lb.nlb.dns_name
}

output "nlb_arn" {
  description = "ARN of the NLB"
  value       = aws_lb.nlb.arn
}

output "nlb_zone_id" {
  description = "Zone ID of the NLB"
  value       = aws_lb.nlb.zone_id
}

# API Gateway
output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.api.id
}

output "api_gateway_invoke_url" {
  description = "Invoke URL for the API Gateway"
  value       = aws_api_gateway_stage.api.invoke_url
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.api.stage_name
}

# Lambda Authorizer
output "lambda_authorizer_function_arn" {
  description = "ARN of the Lambda authorizer function"
  value       = aws_lambda_function.authorizer.arn
}

output "lambda_authorizer_function_name" {
  description = "Name of the Lambda authorizer function"
  value       = aws_lambda_function.authorizer.function_name
}

# =====================================================================
# Cognito Outputs
# =====================================================================

# User Pool Outputs
output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.rexai.id
}

output "cognito_user_pool_arn" {
  description = "The ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.rexai.arn
}

output "cognito_user_pool_endpoint" {
  description = "The endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.rexai.endpoint
}

output "cognito_user_pool_domain" {
  description = "The Cognito User Pool domain"
  value       = aws_cognito_user_pool_domain.rexai.domain
}

output "cognito_user_pool_domain_url" {
  description = "The URL of the Cognito User Pool domain"
  value       = "https://${aws_cognito_user_pool_domain.rexai.domain}.auth.${var.region}.amazoncognito.com"
}

# User Pool Client Outputs
output "cognito_user_pool_client_id" {
  description = "The ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.rexai.id
}

# Identity Pool Outputs
output "cognito_identity_pool_id" {
  description = "The ID of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.rexai.id
}

output "cognito_identity_pool_arn" {
  description = "The ARN of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.rexai.arn
}

# Note: IAM Role outputs have been moved to the IAM module (rexai-iam-tf)
# These are now passed in as variables from the IAM module outputs

# SAML Provider Outputs
output "cognito_saml_provider_name" {
  description = "The name of the SAML identity provider"
  value       = var.enable_saml_provider ? aws_cognito_identity_provider.okta[0].provider_name : null
}

# OAuth Endpoints
output "cognito_oauth_endpoints" {
  description = "OAuth 2.0 endpoints for the Cognito User Pool"
  value = {
    authorization = "https://${aws_cognito_user_pool_domain.rexai.domain}.auth.${var.region}.amazoncognito.com/oauth2/authorize"
    token         = "https://${aws_cognito_user_pool_domain.rexai.domain}.auth.${var.region}.amazoncognito.com/oauth2/token"
    userinfo      = "https://${aws_cognito_user_pool_domain.rexai.domain}.auth.${var.region}.amazoncognito.com/oauth2/userInfo"
    logout        = "https://${aws_cognito_user_pool_domain.rexai.domain}.auth.${var.region}.amazoncognito.com/logout"
  }
}

# Configuration Summary
output "cognito_configuration_summary" {
  description = "Summary of Cognito configuration for easy reference"
  value = {
    user_pool_id     = aws_cognito_user_pool.rexai.id
    client_id        = aws_cognito_user_pool_client.rexai.id
    identity_pool_id = aws_cognito_identity_pool.rexai.id
    region           = var.region
    domain           = aws_cognito_user_pool_domain.rexai.domain
  }
}

# =====================================================================
# Frontend App Runner Outputs
# =====================================================================

# Frontend Service Details
output "frontend_service_url" {
  description = "URL of the frontend App Runner service"
  value       = module.app_runner_frontend.service_url
}

output "frontend_service_arn" {
  description = "ARN of the frontend App Runner service"
  value       = module.app_runner_frontend.service_arn
}

output "frontend_service_id" {
  description = "ID of the frontend App Runner service"
  value       = module.app_runner_frontend.service_id
}

output "frontend_service_status" {
  description = "Status of the frontend App Runner service"
  value       = module.app_runner_frontend.service_status
}

# Frontend Auto Scaling Configuration
output "frontend_auto_scaling_arn" {
  description = "ARN of the frontend auto scaling configuration"
  value       = aws_apprunner_auto_scaling_configuration_version.frontend.arn
}

# Frontend Custom Domain (if configured)
output "frontend_custom_domain_validation_records" {
  description = "DNS validation records for frontend custom domain"
  value       = var.frontend_custom_domain != "" ? aws_apprunner_custom_domain_association.frontend[0].certificate_validation_records : null
}

# Frontend CloudWatch Log Group
output "frontend_log_group_name" {
  description = "Name of the CloudWatch log group for frontend"
  value       = aws_cloudwatch_log_group.frontend_apprunner.name
}

output "frontend_log_group_arn" {
  description = "ARN of the CloudWatch log group for frontend"
  value       = aws_cloudwatch_log_group.frontend_apprunner.arn
}

# Frontend Environment Configuration (for reference)
output "frontend_environment_config" {
  description = "Environment configuration for frontend service"
  value = {
    service_url         = module.app_runner_frontend.service_url
    user_pool_id        = aws_cognito_user_pool.rexai.id
    user_pool_client_id = aws_cognito_user_pool_client.rexai.id
    identity_pool_id    = aws_cognito_identity_pool.rexai.id
    cognito_domain      = aws_cognito_user_pool_domain.rexai.domain
    cognito_domain_url  = "https://${aws_cognito_user_pool_domain.rexai.domain}.auth.${var.region}.amazoncognito.com"
    okta_idp_name       = var.enable_saml_provider ? aws_cognito_identity_provider.okta[0].provider_name : null
    region              = var.region
  }
}

# =====================================================================
# Custom Domain DNS Configuration Outputs
# =====================================================================

output "frontend_custom_domain_dns" {
  description = "DNS configuration instructions for frontend custom domain"
  value = var.frontend_custom_domain != "" ? {
    custom_domain      = var.frontend_custom_domain
    cname_target       = try(aws_apprunner_custom_domain_association.frontend[0].dns_target, "")
    instructions       = "Create a CNAME record: ${var.frontend_custom_domain} -> ${try(aws_apprunner_custom_domain_association.frontend[0].dns_target, "")}"
    validation_records = try(aws_apprunner_custom_domain_association.frontend[0].certificate_validation_records, [])
  } : null
}

output "api_custom_domain_dns" {
  description = "DNS configuration instructions for API Gateway custom domain"
  value = var.api_custom_domain != "" && var.certificate_arn != "" ? {
    custom_domain = var.api_custom_domain
    cname_target  = try(aws_api_gateway_domain_name.api[0].regional_domain_name, "")
    instructions  = "Create a CNAME record: ${var.api_custom_domain} -> ${try(aws_api_gateway_domain_name.api[0].regional_domain_name, "")}"
    api_endpoint  = "https://${var.api_custom_domain}"
  } : null
}